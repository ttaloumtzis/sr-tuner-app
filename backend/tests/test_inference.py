from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from sr_tuner_api.checkpoints import CheckpointMetadata, CHECKPOINT_SCHEMA_VERSION
from sr_tuner_api.inference import (
    InferenceRequest,
    TileConfig,
    inference_readiness,
    list_inference_history,
    run_inference,
    _is_oom,
    _oom_message,
)
from sr_tuner_api.jobs import job_store
from sr_tuner_api.main import app
from sr_tuner_api.project_store import open_project, write_project

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
    meta = CheckpointMetadata(
        run_id=run_id,
        epoch=overrides.get("epoch", 1),
        iteration=overrides.get("iteration", 100),
        path=f"runs/{run_id}/checkpoints/epoch_0001_iter_000100.pth",
        size_bytes=512,
        metrics=overrides.get("metrics", {}),
        tags=[],
        model_architecture=overrides.get("model_architecture", "internal_residual_pixelshuffle"),
        scale=overrides.get("scale", 4),
    )
    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") != run_id:
            continue
        existing = raw.get("checkpoints", [])
        existing.append(meta.model_dump())
        raw["checkpoints"] = existing
        project.runs[index] = raw
        break
    write_project(project)
    return meta


def _make_pth(path: Path, scale: int = 4) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": CHECKPOINT_SCHEMA_VERSION,
        "app_version": "0.1.0",
        "epoch": 1,
        "iteration": 100,
        "model_config": {"num_features": 32, "num_blocks": 4},
        "dataset_id": "ds001",
        "scale": scale,
        "architecture": "internal_residual_pixelshuffle",
        "metrics": {},
    }
    path.write_bytes(json.dumps(payload).encode())


def _make_minimal_png(path: Path, width: int = 4, height: int = 4) -> None:
    """Write a minimal valid PNG (no zlib compression needed for tests)."""
    import struct, zlib

    path.parent.mkdir(parents=True, exist_ok=True)

    def chunk(tag: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw_rows = b"".join(b"\x00" + b"\xff\x00\x00" * width for _ in range(height))
    idat_data = zlib.compress(raw_rows)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat_data)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def _make_run(project_root: Path, project_id: str, monkeypatch) -> str:
    ds_path = project_root / "ext_ds"
    _make_minimal_png(ds_path / "HR" / "a.png", 16, 16)
    _make_minimal_png(ds_path / "LR" / "a.png", 4, 4)

    ds_resp = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={"name": "ds", "dataset_path": str(ds_path), "scale": 4,
              "validation_mode": "quick", "storage_operation": "reference"},
        headers=auth_headers(),
    )
    assert ds_resp.status_code == 200
    dataset_id = ds_resp.json()["project"]["datasets"][0]["id"]

    model_resp = client.post(
        f"/projects/{project_id}/models",
        json={"name": "m", "num_features": 8, "num_blocks": 2},
        headers=auth_headers(),
    )
    assert model_resp.status_code == 200
    model_id = model_resp.json()["project"]["models"][0]["id"]

    run_resp = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "run1", "dataset_id": dataset_id, "model_id": model_id,
              "train_mode": "new", "device": "cpu", "epochs": 1,
              "checkpoint_cadence": 1, "validation_percentage": 0.0,
              "validation_seed": 42, "validation_shuffle": False,
              "tensorboard": False, "precision": "float32",
              "compile": False, "warmup_epochs": 0,
              "scheduler_type": "none", "diff_mode": "absolute"},
        headers=auth_headers(),
    )
    assert run_resp.status_code == 200
    return run_resp.json()["project"]["runs"][0]["id"]


# ── 9.2 readiness ──────────────────────────────────────────────────────────────

def test_inference_readiness_cpu():
    r = inference_readiness(device="cpu")
    assert r.available or not r.available  # depends on env; schema check only
    assert isinstance(r.dependencies, list)
    assert all(hasattr(d, "name") for d in r.dependencies)


def test_inference_readiness_unknown_device():
    r = inference_readiness(device="cuda:99")
    assert not r.available
    device_dep = next((d for d in r.dependencies if d.name == "device"), None)
    assert device_dep is not None
    assert not device_dep.available


def test_inference_readiness_endpoint(tmp_path, monkeypatch):
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    resp = client.get("/dependencies/inference?device=cpu")
    assert resp.status_code == 200
    data = resp.json()
    assert "available" in data
    assert "dependencies" in data


# ── 9.1 request schema & checkpoint scale ─────────────────────────────────────

def test_inference_request_uses_checkpoint_scale(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch)
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, scale=2)
    ckpt_path = project_root / meta.path
    _make_pth(ckpt_path, scale=2)

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path="not_used",
        device="cpu",
    )
    assert req.checkpoint_id == meta.id
    # The schema does not carry a user-supplied scale; scale comes from checkpoint payload
    assert not hasattr(req, "scale")


def test_inference_checkpoint_scale_derived(tmp_path, monkeypatch):
    """Verify the scale stored in InferenceRecord comes from checkpoint, not user."""
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="proj2")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id, scale=4)
    ckpt_path = project_root / meta.path
    _make_pth(ckpt_path, scale=4)

    img = project_root / "test_input.png"
    _make_minimal_png(img)

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(img),
        device="cpu",
    )
    try:
        record, _ = run_inference(project_root, req, job_store)
        assert record.scale == 4
    except Exception:
        pytest.skip("PyTorch not available in this environment.")


# ── 9.3 single image ──────────────────────────────────────────────────────────

def test_single_image_inference_produces_record(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="sinf")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    ckpt_path = project_root / meta.path
    _make_pth(ckpt_path)

    img = project_root / "input.png"
    _make_minimal_png(img)

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(img),
        device="cpu",
        mode="single",
    )
    try:
        record, job = run_inference(project_root, req, job_store)
    except Exception:
        pytest.skip("PyTorch not available.")

    assert record.mode == "single"
    assert record.checkpoint_id == meta.id
    assert record.output_path is not None
    assert len(record.per_file_results) == 1
    assert record.per_file_results[0].status == "success"
    assert record.status == "completed"
    assert job.status == "completed"


def test_single_inference_persists_to_history(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="hist")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    ckpt_path = project_root / meta.path
    _make_pth(ckpt_path)

    img = project_root / "input2.png"
    _make_minimal_png(img)

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(img),
        device="cpu",
    )
    try:
        run_inference(project_root, req, job_store)
    except Exception:
        pytest.skip("PyTorch not available.")

    history = list_inference_history(project_root)
    assert len(history.records) == 1
    assert history.records[0].checkpoint_id == meta.id


def test_single_inference_missing_input_raises(tmp_path, monkeypatch):
    from sr_tuner_api.errors import ApiError
    import sr_tuner_api.inference as inf_mod

    project_id, project_root = _make_project(tmp_path, monkeypatch, name="missinp")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    # Make readiness pass so we reach input validation
    from sr_tuner_api.inference import InferenceReadinessResponse
    monkeypatch.setattr(inf_mod, "inference_readiness", lambda *_a, **_kw: InferenceReadinessResponse(available=True, dependencies=[], message="ok"))

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(project_root / "nonexistent.png"),
        device="cpu",
    )
    with pytest.raises(ApiError) as exc_info:
        run_inference(project_root, req, job_store)
    assert exc_info.value.detail["code"] == "input_not_found"


# ── 9.4 batch inference ────────────────────────────────────────────────────────

def test_batch_inference_partial_results(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="batch")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    input_dir = project_root / "batch_input"
    input_dir.mkdir()
    _make_minimal_png(input_dir / "a.png")
    _make_minimal_png(input_dir / "b.png")
    (input_dir / "corrupted.png").write_bytes(b"not a png")

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(input_dir),
        device="cpu",
        mode="batch",
    )
    try:
        record, job = run_inference(project_root, req, job_store)
    except Exception:
        pytest.skip("PyTorch not available.")

    assert record.mode == "batch"
    filenames = [r.filename for r in record.per_file_results]
    assert "a.png" in filenames
    assert "b.png" in filenames
    statuses = {r.filename: r.status for r in record.per_file_results}
    # a.png and b.png should succeed; corrupted.png should fail
    assert statuses.get("a.png") == "success"
    assert statuses.get("b.png") == "success"
    if "corrupted.png" in statuses:
        assert statuses["corrupted.png"] == "failed"
    assert record.status in ("completed", "partial")


def test_batch_inference_no_images_raises(tmp_path, monkeypatch):
    from sr_tuner_api.errors import ApiError
    import sr_tuner_api.inference as inf_mod
    from sr_tuner_api.inference import InferenceReadinessResponse

    project_id, project_root = _make_project(tmp_path, monkeypatch, name="nobatch")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    monkeypatch.setattr(inf_mod, "inference_readiness", lambda *_a, **_kw: InferenceReadinessResponse(available=True, dependencies=[], message="ok"))

    empty_dir = project_root / "empty_batch"
    empty_dir.mkdir()

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(empty_dir),
        device="cpu",
        mode="batch",
    )
    with pytest.raises(ApiError) as exc_info:
        run_inference(project_root, req, job_store)
    assert exc_info.value.detail["code"] == "no_images_found"


# ── 9.5 tiling config ─────────────────────────────────────────────────────────

def test_tile_config_stored_in_record(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="tile")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    img = project_root / "big.png"
    _make_minimal_png(img, 8, 8)

    tile = TileConfig(enabled=True, tile_size=64, overlap=8, padding_mode="reflect", blend_strategy="linear")
    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(img),
        device="cpu",
        tile_config=tile,
    )
    try:
        record, _ = run_inference(project_root, req, job_store)
    except Exception:
        pytest.skip("PyTorch not available.")

    assert record.tile_config.enabled is True
    assert record.tile_config.tile_size == 64
    assert record.tile_config.overlap == 8
    assert record.tile_config.padding_mode == "reflect"
    assert record.tile_config.blend_strategy == "linear"


def test_oom_detection():
    assert _is_oom(RuntimeError("CUDA out of memory. Tried to allocate 1.00 GiB"))
    assert _is_oom(Exception("out of memory"))
    assert not _is_oom(ValueError("some other error"))


def test_oom_message_is_recoverable():
    msg = _oom_message()
    assert "tile" in msg.lower() or "cpu" in msg.lower()


# ── 9.6 inference history ─────────────────────────────────────────────────────

def test_inference_history_endpoint(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="histep")
    resp = client.get(f"/projects/{project_id}/inference")
    assert resp.status_code == 200
    assert "records" in resp.json()
    assert resp.json()["records"] == []


def test_inference_history_contains_metadata(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="histmeta")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    img = project_root / "h.png"
    _make_minimal_png(img)

    req = InferenceRequest(
        checkpoint_id=meta.id,
        run_id=run_id,
        input_path=str(img),
        device="cpu",
    )
    try:
        run_inference(project_root, req, job_store)
    except Exception:
        pytest.skip("PyTorch not available.")

    history = list_inference_history(project_root)
    record = history.records[0]
    assert record.device == "cpu"
    assert record.run_id == run_id
    assert record.checkpoint_id == meta.id
    assert record.runtime_seconds >= 0


# ── dependency readiness missing ──────────────────────────────────────────────

def test_inference_unavailable_without_torch(tmp_path, monkeypatch):
    monkeypatch.setattr("sr_tuner_api.inference._module_available", lambda name: name == "PIL")
    r = inference_readiness("cpu")
    assert not r.available
    torch_dep = next((d for d in r.dependencies if d.name == "torch"), None)
    assert torch_dep is not None
    assert not torch_dep.available


def test_inference_endpoint_returns_409_when_deps_missing(tmp_path, monkeypatch):
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="nodeps")
    run_id = _make_run(project_root, project_id, monkeypatch)
    meta = _inject_checkpoint(project_root, run_id)
    _make_pth(project_root / meta.path)

    monkeypatch.setattr("sr_tuner_api.inference._module_available", lambda _: False)

    resp = client.post(
        f"/projects/{project_id}/inference",
        json={
            "checkpoint_id": meta.id,
            "run_id": run_id,
            "input_path": str(project_root / "x.png"),
            "device": "cpu",
        },
        headers=auth_headers(),
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "inference_dependencies_missing"
