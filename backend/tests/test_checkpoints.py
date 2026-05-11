from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from sr_tuner_api.checkpoints import (
    CHECKPOINT_SCHEMA_VERSION,
    CheckpointMetadata,
    _assign_markers,
    delete_checkpoint,
    derive_project_checkpoints,
    list_run_checkpoints,
    onnx_readiness,
    save_checkpoint,
    validate_checkpoint_payload,
)
from sr_tuner_api.ids import new_id
from sr_tuner_api.jobs import utc_now_iso
from sr_tuner_api.main import app
from sr_tuner_api.project_store import open_project, write_project
from sr_tuner_api.runs import RunObject, create_run, RunSetupRequest


client = TestClient(app)
TOKEN = "test-token"


def auth_headers() -> dict[str, str]:
    return {"x-sr-tuner-token": TOKEN}


# ── helpers ────────────────────────────────────────────────────────────────────

def _make_project(tmp_path: Path, monkeypatch, name: str = "proj") -> tuple[str, Path]:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    resp = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": name},
        headers=auth_headers(),
    )
    assert resp.status_code == 200
    return resp.json()["project_id"], tmp_path / name


def _inject_checkpoint(project_root: Path, run_id: str, **overrides) -> CheckpointMetadata:
    """Directly inject a fake checkpoint record into a run without real files."""
    meta = CheckpointMetadata(
        run_id=run_id,
        epoch=overrides.get("epoch", 1),
        iteration=overrides.get("iteration", 100),
        path=f"runs/{run_id}/checkpoints/epoch_0001_iter_000100.pth",
        size_bytes=overrides.get("size_bytes", 512),
        metrics=overrides.get("metrics", {}),
        tags=overrides.get("tags", []),
        model_architecture=overrides.get("model_architecture", "internal_residual_pixelshuffle"),
        scale=overrides.get("scale", 4),
    )
    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run_id:
            existing = raw.get("checkpoints", [])
            existing.append(meta.model_dump())
            raw["checkpoints"] = existing
            project.runs[index] = raw
            break
    write_project(project)
    return meta


def _make_pth_file(path: Path, *, schema_version: int = CHECKPOINT_SCHEMA_VERSION, architecture: str = "internal_residual_pixelshuffle", scale: int = 4) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": schema_version,
        "app_version": "0.1.0",
        "epoch": 1,
        "iteration": 100,
        "model_config": {"num_features": 32, "num_blocks": 4},
        "dataset_id": "dataset_001",
        "scale": scale,
        "architecture": architecture,
        "metrics": {"train_loss_total": 0.5, "val_psnr": 30.0},
    }
    path.write_bytes(json.dumps(payload).encode())


def _make_run(project_root: Path, project_id: str, monkeypatch) -> str:
    """Create a minimal dataset+model+run and return the run_id."""
    import struct
    def write_png(p: Path, width: int = 16, height: int = 16) -> None:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + struct.pack(">I", 13)
            + b"IHDR"
            + struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
            + b"\x00\x00\x00\x00"
        )

    ds_path = project_root / "ext_ds"
    write_png(ds_path / "HR" / "a.png", 64, 64)
    write_png(ds_path / "LR" / "a.png", 16, 16)

    ds_resp = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "ds",
            "dataset_path": str(ds_path),
            "scale": 4,
            "validation_mode": "quick",
            "storage_operation": "reference",
        },
        headers=auth_headers(),
    )
    assert ds_resp.status_code == 200
    dataset_id = ds_resp.json()["project"]["datasets"][0]["id"]

    model_resp = client.post(
        f"/projects/{project_id}/models",
        json={"name": "m", "scale": 4, "num_features": 32, "num_blocks": 4},
        headers=auth_headers(),
    )
    assert model_resp.status_code == 200
    model_id = model_resp.json()["project"]["models"][0]["id"]

    run_resp = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "run1",
            "dataset_id": dataset_id,
            "model_id": model_id,
            "train_mode": "new",
            "device": "cpu",
            "epochs": 2,
            "checkpoint_cadence": 1,
            "validation_percentage": 0.0,
            "validation_seed": 42,
            "validation_shuffle": False,
            "tensorboard": False,
            "precision": "float32",
            "compile": False,
            "warmup_epochs": 0,
            "scheduler_type": "none",
            "diff_mode": "absolute",
        },
        headers=auth_headers(),
    )
    assert run_resp.status_code == 200
    return run_resp.json()["project"]["runs"][0]["id"]


# ── marker calculation ─────────────────────────────────────────────────────────

def test_marker_latest_is_most_recent() -> None:
    checkpoints = [
        CheckpointMetadata(run_id="r1", epoch=1, iteration=10, path="a.pth", saved_at="2024-01-01T00:00:00+00:00"),
        CheckpointMetadata(run_id="r1", epoch=2, iteration=20, path="b.pth", saved_at="2024-01-02T00:00:00+00:00"),
    ]
    _assign_markers(checkpoints)
    assert "latest" in checkpoints[1].tags
    assert "latest" not in checkpoints[0].tags


def test_marker_best_psnr() -> None:
    checkpoints = [
        CheckpointMetadata(run_id="r1", epoch=1, iteration=10, path="a.pth", metrics={"val_psnr": 28.0}),
        CheckpointMetadata(run_id="r1", epoch=2, iteration=20, path="b.pth", metrics={"val_psnr": 32.0}),
        CheckpointMetadata(run_id="r1", epoch=3, iteration=30, path="c.pth", metrics={"val_psnr": 30.0}),
    ]
    _assign_markers(checkpoints)
    assert "best_psnr" in checkpoints[1].tags
    assert "best_psnr" not in checkpoints[0].tags
    assert "best_psnr" not in checkpoints[2].tags


def test_marker_best_loss() -> None:
    checkpoints = [
        CheckpointMetadata(run_id="r1", epoch=1, iteration=10, path="a.pth", metrics={"train_loss_total": 0.8}),
        CheckpointMetadata(run_id="r1", epoch=2, iteration=20, path="b.pth", metrics={"train_loss_total": 0.2}),
    ]
    _assign_markers(checkpoints)
    assert "best_loss" in checkpoints[1].tags
    assert "best_loss" not in checkpoints[0].tags


def test_deleted_checkpoints_excluded_from_markers() -> None:
    checkpoints = [
        CheckpointMetadata(run_id="r1", epoch=1, iteration=10, path="a.pth", saved_at="2024-01-01T00:00:00+00:00", metrics={"val_psnr": 35.0}, deleted=True),
        CheckpointMetadata(run_id="r1", epoch=2, iteration=20, path="b.pth", saved_at="2024-01-02T00:00:00+00:00", metrics={"val_psnr": 28.0}),
    ]
    _assign_markers(checkpoints)
    assert "latest" in checkpoints[1].tags
    assert "best_psnr" in checkpoints[1].tags
    assert not any(t in checkpoints[0].tags for t in ("latest", "best_psnr", "best_loss"))


# ── checkpoint payload validation ──────────────────────────────────────────────

def test_validate_payload_ok(tmp_path: Path) -> None:
    pth = tmp_path / "ckpt.pth"
    _make_pth_file(pth)
    payload = validate_checkpoint_payload(tmp_path, str(pth))
    assert payload["epoch"] == 1
    assert payload["scale"] == 4


def test_validate_payload_missing_fields(tmp_path: Path) -> None:
    pth = tmp_path / "ckpt.pth"
    pth.write_bytes(json.dumps({"schema_version": 1, "epoch": 1}).encode())
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        validate_checkpoint_payload(tmp_path, str(pth))
    assert exc_info.value.detail["code"] == "checkpoint_payload_invalid"


def test_validate_payload_bad_schema_version(tmp_path: Path) -> None:
    pth = tmp_path / "ckpt.pth"
    payload = {
        "schema_version": 999,
        "epoch": 1,
        "iteration": 0,
        "model_config": {},
        "dataset_id": "x",
        "scale": 4,
        "architecture": "internal_residual_pixelshuffle",
        "metrics": {},
    }
    pth.write_bytes(json.dumps(payload).encode())
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        validate_checkpoint_payload(tmp_path, str(pth))
    assert exc_info.value.detail["code"] == "checkpoint_schema_unsupported"


def test_validate_payload_architecture_mismatch(tmp_path: Path) -> None:
    pth = tmp_path / "ckpt.pth"
    _make_pth_file(pth, architecture="some_other_arch")
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        validate_checkpoint_payload(tmp_path, str(pth), expected_architecture="internal_residual_pixelshuffle")
    assert exc_info.value.detail["code"] == "checkpoint_architecture_mismatch"


def test_validate_payload_scale_mismatch(tmp_path: Path) -> None:
    pth = tmp_path / "ckpt.pth"
    _make_pth_file(pth, scale=4)
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        validate_checkpoint_payload(tmp_path, str(pth), expected_scale=2)
    assert exc_info.value.detail["code"] == "checkpoint_scale_mismatch"


def test_validate_payload_missing_file(tmp_path: Path) -> None:
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        validate_checkpoint_payload(tmp_path, str(tmp_path / "nonexistent.pth"))
    assert exc_info.value.detail["code"] == "checkpoint_file_missing"


# ── run-owned metadata ─────────────────────────────────────────────────────────

def test_checkpoint_metadata_is_run_owned(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    _inject_checkpoint(project_root, run_id, epoch=1, metrics={"val_psnr": 30.0})

    project = open_project(project_root)
    run_raw = next(r for r in project.runs if r["id"] == run_id)
    assert len(run_raw["checkpoints"]) == 1
    assert run_raw["checkpoints"][0]["run_id"] == run_id


# ── derived project-level index ────────────────────────────────────────────────

def test_derive_project_checkpoints(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    _inject_checkpoint(project_root, run_id, epoch=1)
    _inject_checkpoint(project_root, run_id, epoch=2)

    index = derive_project_checkpoints(project_root)
    assert len(index.checkpoints) == 2
    assert all(c.run_id == run_id for c in index.checkpoints)


def test_derived_index_excludes_deleted(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)

    project = open_project(project_root)
    for i, raw in enumerate(project.runs):
        if raw["id"] == run_id:
            raw["checkpoints"][0]["deleted"] = True
            project.runs[i] = raw
    write_project(project)

    index = derive_project_checkpoints(project_root)
    non_deleted = [c for c in index.checkpoints if not c.deleted]
    assert len(non_deleted) == 0


# ── checkpoint deletion and reference preservation ─────────────────────────────

def test_delete_checkpoint_marks_deleted_and_preserves_metadata(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)

    result = delete_checkpoint(project_root, run_id, meta.id)
    assert len(result.checkpoints) == 1
    assert result.checkpoints[0].deleted is True
    assert result.checkpoints[0].id == meta.id

    project = open_project(project_root)
    run_raw = next(r for r in project.runs if r["id"] == run_id)
    assert run_raw["checkpoints"][0]["deleted"] is True


def test_delete_removes_physical_file(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)

    ckpt_path = project_root / "runs" / run_id / "checkpoints" / "epoch_0001_iter_000100.pth"
    _make_pth_file(ckpt_path)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)
    meta_with_path = _inject_checkpoint.__doc__  # documentation only
    project = open_project(project_root)
    for i, raw in enumerate(project.runs):
        if raw["id"] == run_id:
            raw["checkpoints"][-1]["path"] = str(ckpt_path)
            project.runs[i] = raw
    write_project(project)

    reloaded = open_project(project_root)
    run_raw = next(r for r in reloaded.runs if r["id"] == run_id)
    checkpoint_id = run_raw["checkpoints"][-1]["id"]
    delete_checkpoint(project_root, run_id, checkpoint_id)
    assert not ckpt_path.exists()


def test_delete_nonexistent_checkpoint_raises(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        delete_checkpoint(project_root, run_id, "ckpt_nonexistent")
    assert exc_info.value.detail["code"] == "checkpoint_not_found"


def test_deleted_checkpoint_cannot_be_used_for_export(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)

    delete_checkpoint(project_root, run_id, meta.id)

    from sr_tuner_api.errors import ApiError
    with pytest.raises(ApiError) as exc_info:
        from sr_tuner_api.checkpoints import export_checkpoint_pth
        export_checkpoint_pth(project_root, run_id, meta.id, str(tmp_path))
    assert exc_info.value.detail["code"] == "checkpoint_deleted"


# ── list run checkpoints API ───────────────────────────────────────────────────

def test_list_run_checkpoints_via_api(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    _inject_checkpoint(project_root, run_id, epoch=1, metrics={"val_psnr": 30.0, "train_loss_total": 0.5})
    _inject_checkpoint(project_root, run_id, epoch=2, metrics={"val_psnr": 32.0, "train_loss_total": 0.3})

    resp = client.get(f"/projects/{project_id}/runs/{run_id}/checkpoints")
    assert resp.status_code == 200
    body = resp.json()
    assert body["run_id"] == run_id
    checkpoints = body["checkpoints"]
    assert len(checkpoints) == 2
    tags_all = [t for c in checkpoints for t in c["tags"]]
    assert "latest" in tags_all
    assert "best_psnr" in tags_all
    assert "best_loss" in tags_all


def test_project_checkpoint_index_via_api(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    _inject_checkpoint(project_root, run_id, epoch=1)

    resp = client.get(f"/projects/{project_id}/checkpoints")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["checkpoints"]) == 1


def test_delete_checkpoint_via_api(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)

    resp = client.delete(
        f"/projects/{project_id}/runs/{run_id}/checkpoints/{meta.id}",
        headers=auth_headers(),
    )
    assert resp.status_code == 200
    assert resp.json()["checkpoints"][0]["deleted"] is True


# ── ONNX readiness ─────────────────────────────────────────────────────────────

def test_onnx_readiness_endpoint() -> None:
    resp = client.get("/dependencies/onnx")
    assert resp.status_code == 200
    body = resp.json()
    assert "available" in body
    assert "message" in body


def test_onnx_readiness_without_onnx_package() -> None:
    readiness = onnx_readiness()
    assert isinstance(readiness.available, bool)
    assert isinstance(readiness.message, str)


def test_export_onnx_fails_when_onnx_unavailable(tmp_path: Path, monkeypatch) -> None:
    import importlib
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, epoch=1)

    monkeypatch.setattr("sr_tuner_api.checkpoints._module_available", lambda name: False)

    resp = client.post(
        f"/projects/{project_id}/runs/{run_id}/checkpoints/{meta.id}/export-onnx",
        json={"destination": str(tmp_path)},
        headers=auth_headers(),
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "onnx_unavailable"


# ── export .pth ────────────────────────────────────────────────────────────────

def test_export_pth_copies_file(tmp_path: Path, monkeypatch) -> None:
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)

    ckpt_path = project_root / "runs" / run_id / "checkpoints" / "epoch_0001.pth"
    _make_pth_file(ckpt_path)

    meta = _inject_checkpoint(project_root, run_id, epoch=1)
    project = open_project(project_root)
    for i, raw in enumerate(project.runs):
        if raw["id"] == run_id:
            raw["checkpoints"][-1]["path"] = str(ckpt_path)
            project.runs[i] = raw
    write_project(project)

    export_dir = tmp_path / "exports"
    export_dir.mkdir()

    reloaded = open_project(project_root)
    run_raw = next(r for r in reloaded.runs if r["id"] == run_id)
    checkpoint_id = run_raw["checkpoints"][-1]["id"]

    resp = client.post(
        f"/projects/{project_id}/runs/{run_id}/checkpoints/{checkpoint_id}/export-pth",
        json={"destination": str(export_dir)},
        headers=auth_headers(),
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "completed"
    exported = list(export_dir.iterdir())
    assert len(exported) == 1
    assert exported[0].suffix == ".pth"
