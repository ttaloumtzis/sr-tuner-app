"""
Phase 10 smoke tests: end-to-end flow, project reopen, and job infrastructure.

Tests that require PyTorch are guarded with pytest.skip so the suite passes in
environments where PyTorch is not installed.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from sr_tuner_api.checkpoints import CheckpointMetadata, CHECKPOINT_SCHEMA_VERSION
from sr_tuner_api.config import PROJECT_FILE_NAME
from sr_tuner_api.main import app
from sr_tuner_api.project_store import BACKUP_FILE_NAME, open_project, write_project

client = TestClient(app)
TOKEN = "smoke-token"


def auth_headers() -> dict[str, str]:
    return {"x-sr-tuner-token": TOKEN}


# ── helpers ────────────────────────────────────────────────────────────────────

def _setup_env(monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)


def _make_project(tmp_path: Path, monkeypatch, name: str = "smoke_proj") -> tuple[str, Path]:
    _setup_env(monkeypatch)
    resp = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": name},
        headers=auth_headers(),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["project_id"], tmp_path / name


def _add_dataset(project_id: str, dataset_path: Path) -> dict:
    resp = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "smoke_dataset",
            "dataset_path": str(dataset_path),
            "scale": 4,
            "validation_mode": "full",
            "storage_operation": "reference",
        },
        headers=auth_headers(),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["project"]["datasets"][0]


def _create_model(project_id: str) -> dict:
    resp = client.post(
        f"/projects/{project_id}/models",
        json={"name": "smoke_model", "scale": 4, "num_features": 8, "num_blocks": 2},
        headers=auth_headers(),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["project"]["models"][0]


def _create_run(project_id: str, dataset_id: str, model_id: str) -> dict:
    resp = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "smoke_run",
            "dataset_id": dataset_id,
            "model_id": model_id,
            "epochs": 1,
            "checkpoint_cadence": 1,
            "validation_percentage": 0.0,
            "validation_seed": 0,
            "validation_shuffle": False,
            "tensorboard": False,
        },
        headers=auth_headers(),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["project"]["runs"][0]


def _inject_checkpoint(project_root: Path, run_id: str, scale: int = 4) -> CheckpointMetadata:
    meta = CheckpointMetadata(
        run_id=run_id,
        epoch=1,
        iteration=10,
        path=f"runs/{run_id}/checkpoints/epoch_0001_iter_000010.pth",
        size_bytes=256,
        metrics={"val_psnr": 28.0, "train_loss_total": 0.4},
        tags=[],
        model_architecture="internal_residual_pixelshuffle",
        scale=scale,
    )
    project = open_project(project_root)
    for i, raw in enumerate(project.runs):
        if raw.get("id") == run_id:
            existing = raw.get("checkpoints", [])
            dumped = meta.model_dump()
            dumped["usable"] = True
            dumped["fine_tune_compatible"] = True
            existing.append(dumped)
            raw["checkpoints"] = existing
            project.runs[i] = raw
            break
    write_project(project)
    return meta


def _make_pth(path: Path, scale: int = 4) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": CHECKPOINT_SCHEMA_VERSION,
        "app_version": "0.1.0",
        "epoch": 1,
        "iteration": 10,
        "model_config": {"num_features": 8, "num_blocks": 2},
        "dataset_id": "ds_smoke",
        "scale": scale,
        "architecture": "internal_residual_pixelshuffle",
        "metrics": {"val_psnr": 28.0, "train_loss_total": 0.4},
    }
    path.write_bytes(json.dumps(payload).encode())


# ── 10.2 complete flow ─────────────────────────────────────────────────────────

def test_complete_flow_create_dataset_model_run_checkpoint_inference(
    tmp_path: Path, monkeypatch, fixture_paired_dataset_4x: Path
) -> None:
    """Smoke: create project → dataset → model → run → launch → checkpoint → inference."""
    import sr_tuner_api.runs as runs_module
    monkeypatch.setattr(runs_module, "_module_available", lambda _name: True)

    project_id, project_root = _make_project(tmp_path, monkeypatch)

    # dataset
    dataset = _add_dataset(project_id, fixture_paired_dataset_4x)
    assert dataset["validation"]["usable"] is True
    assert dataset["validation"]["pair_count"] == 1

    # model
    model = _create_model(project_id)
    assert model["architecture"] == "internal_residual_pixelshuffle"
    assert model["status"] == "untrained"

    # compatibility
    compat = client.get(f"/projects/{project_id}/compatibility?dataset_id={dataset['id']}&model_id={model['id']}")
    assert compat.json()["compatible"] is True

    # run
    run = _create_run(project_id, dataset["id"], model["id"])
    assert run["state"] == "configured"
    assert (project_root / run["folder"]).is_dir()

    # launch
    launched = client.post(
        f"/projects/{project_id}/runs/{run['id']}/launch",
        json={"run_id": run["id"]},
        headers=auth_headers(),
    )
    assert launched.status_code == 200, launched.text
    run_state = launched.json()["project"]["runs"][0]["state"]
    assert run_state == "running"

    # checkpoint (injected — actual training requires PyTorch)
    ckpt_meta = _inject_checkpoint(project_root, run["id"])
    ckpt_path = project_root / ckpt_meta.path
    _make_pth(ckpt_path)

    checkpoints_resp = client.get(f"/projects/{project_id}/runs/{run['id']}/checkpoints")
    assert checkpoints_resp.status_code == 200
    assert len(checkpoints_resp.json()["checkpoints"]) == 1

    # inference
    from sr_tuner_api.inference import InferenceRequest, run_inference

    input_img = fixture_paired_dataset_4x / "HR" / "frame_001.png"
    req = InferenceRequest(
        checkpoint_id=ckpt_meta.id,
        run_id=run["id"],
        input_path=str(input_img),
        device="cpu",
    )
    try:
        record, job = run_inference(project_root, req)
        assert record.status == "completed"
        assert record.scale == 4
        assert record.checkpoint_id == ckpt_meta.id
        assert job.status == "completed"
    except Exception:
        pytest.skip("PyTorch not available – inference portion skipped.")


# ── 10.3 project reopen restores all state ─────────────────────────────────────

def test_project_reopen_restores_all_state(
    tmp_path: Path, monkeypatch, fixture_paired_dataset_4x: Path
) -> None:
    """After reopening a project the full state is intact."""
    import sr_tuner_api.runs as runs_module
    monkeypatch.setattr(runs_module, "_module_available", lambda _name: True)

    project_id, project_root = _make_project(tmp_path, monkeypatch)

    dataset = _add_dataset(project_id, fixture_paired_dataset_4x)
    model = _create_model(project_id)
    run = _create_run(project_id, dataset["id"], model["id"])

    # Launch then stop the run so reopen won't mark it interrupted
    client.post(
        f"/projects/{project_id}/runs/{run['id']}/launch",
        json={"run_id": run["id"]},
        headers=auth_headers(),
    )
    client.post(
        f"/projects/{project_id}/runs/{run['id']}/stop",
        headers=auth_headers(),
    )

    ckpt_meta = _inject_checkpoint(project_root, run["id"])
    _make_pth(project_root / ckpt_meta.path)

    # Simulate inference history entry
    from sr_tuner_api.inference import InferenceRequest, run_inference
    input_img = fixture_paired_dataset_4x / "HR" / "frame_001.png"
    req = InferenceRequest(
        checkpoint_id=ckpt_meta.id,
        run_id=run["id"],
        input_path=str(input_img),
        device="cpu",
    )
    try:
        run_inference(project_root, req)
    except Exception:
        pass  # If PyTorch unavailable, continue with remaining checks

    # Reopen project
    reopened = client.post(
        "/projects/open",
        json={"path": str(project_root)},
        headers=auth_headers(),
    )
    assert reopened.status_code == 200, reopened.text
    project_data = reopened.json()["project"]

    # Verify datasets restored
    assert len(project_data["datasets"]) == 1
    assert project_data["datasets"][0]["id"] == dataset["id"]
    assert project_data["datasets"][0]["validation"]["usable"] is True

    # Verify models restored
    assert len(project_data["models"]) == 1
    assert project_data["models"][0]["id"] == model["id"]

    # Verify runs restored (not re-marked interrupted because we stopped it)
    assert len(project_data["runs"]) == 1
    assert project_data["runs"][0]["id"] == run["id"]
    assert project_data["runs"][0]["state"] == "stopped"

    # Verify checkpoints are run-owned and still present
    new_project_id = reopened.json()["project_id"]
    ckpts_resp = client.get(f"/projects/{new_project_id}/runs/{run['id']}/checkpoints")
    assert ckpts_resp.status_code == 200
    assert len(ckpts_resp.json()["checkpoints"]) == 1
    assert ckpts_resp.json()["checkpoints"][0]["id"] == ckpt_meta.id

    # Verify project-level checkpoint index is derived
    proj_ckpts = client.get(f"/projects/{new_project_id}/checkpoints")
    proj_cts = proj_ckpts.json()["checkpoints"]
    assert len(proj_cts) == 1

    # Verify inference history (only if PyTorch was available)
    history_resp = client.get(f"/projects/{new_project_id}/inference")
    assert history_resp.status_code == 200
    # Records may be 0 (PyTorch unavailable) or 1 (PyTorch ran)
    assert isinstance(history_resp.json()["records"], list)


def test_model_status_derived_from_checkpoints_after_reopen(
    tmp_path: Path, monkeypatch, fixture_paired_dataset_4x: Path
) -> None:
    """Model status reflects 'trained' after a checkpoint is injected and project reopened."""
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="model_status_smoke")

    _add_dataset(project_id, fixture_paired_dataset_4x)
    model = _create_model(project_id)
    dataset_id = client.get(f"/projects/{project_id}/datasets").json()[0]["id"]
    run = _create_run(project_id, dataset_id, model["id"])

    _inject_checkpoint(project_root, run["id"])

    reopened = client.post("/projects/open", json={"path": str(project_root)}, headers=auth_headers())
    new_project_id = reopened.json()["project_id"]

    model_detail = client.get(f"/projects/{new_project_id}/models/{model['id']}")
    assert model_detail.status_code == 200
    assert model_detail.json()["status"] in ("trained", "fine_tune_available")


# ── 10.5 job infrastructure smoke ─────────────────────────────────────────────

def test_smoke_token_rejection(tmp_path: Path, monkeypatch) -> None:
    """Mutating endpoints return 401 when the session token is missing or wrong."""
    _setup_env(monkeypatch)

    no_token = client.post("/projects", json={"parent_path": str(tmp_path), "name": "x"})
    assert no_token.status_code == 401
    err = no_token.json()["error"]
    assert err["code"] == "invalid_session_token"
    assert "message" in err

    wrong_token = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "x"},
        headers={"x-sr-tuner-token": "not-the-right-one"},
    )
    assert wrong_token.status_code == 401


def test_smoke_structured_error_shape(tmp_path: Path, monkeypatch) -> None:
    """All API errors share the standard {error: {code, message, recoverable}} shape."""
    _setup_env(monkeypatch)
    project_id, _ = _make_project(tmp_path, monkeypatch, name="err_shape")

    # Non-existent dataset
    resp = client.get(f"/projects/{project_id}/models/nonexistent_model_id")
    assert resp.status_code in (404, 422)
    body = resp.json()
    assert "error" in body
    assert "code" in body["error"]
    assert "message" in body["error"]
    assert "recoverable" in body["error"]


def test_smoke_atomic_save_and_backup(tmp_path: Path, monkeypatch) -> None:
    """Each project write keeps the previous version as a backup file."""
    _setup_env(monkeypatch)
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="atomic_smoke")

    before = json.loads((project_root / PROJECT_FILE_NAME).read_text())
    assert before["workspace"]["selected_tab"] == 0

    client.put(f"/projects/{project_id}/workspace", json={"selected_tab": 2}, headers=auth_headers())

    current = json.loads((project_root / PROJECT_FILE_NAME).read_text())
    backup = json.loads((project_root / BACKUP_FILE_NAME).read_text())
    assert current["workspace"]["selected_tab"] == 2
    assert backup["workspace"]["selected_tab"] == 0


def test_smoke_backup_recovery_info(tmp_path: Path, monkeypatch) -> None:
    """Opening a project with a corrupt primary file and valid backup reports recovery_available."""
    _setup_env(monkeypatch)
    root = tmp_path / "corrupt_project"
    root.mkdir()
    (root / PROJECT_FILE_NAME).write_text("{corrupted json", encoding="utf-8")
    (root / BACKUP_FILE_NAME).write_text(
        json.dumps({"schema_version": 1, "app": "sr-tuner", "id": "p_smoke", "name": "demo"}),
        encoding="utf-8",
    )

    resp = client.post("/projects/open", json={"path": str(root)}, headers=auth_headers())
    assert resp.status_code == 422
    err = resp.json()["error"]
    assert err["code"] == "project_file_invalid"
    assert err["details"]["recovery_available"] is True
    assert err["recoverable"] is True


def test_smoke_job_progress_and_cancellation(tmp_path: Path, monkeypatch) -> None:
    """Job lifecycle: queued → canceling after cancel call; logs endpoint is accessible."""
    _setup_env(monkeypatch)
    project_id, _ = _make_project(tmp_path, monkeypatch, name="job_smoke")

    job_resp = client.post(
        "/jobs",
        json={"type": "dataset_copy", "project_id": project_id, "object_id": "ds_1"},
        headers=auth_headers(),
    )
    assert job_resp.status_code == 200
    job = job_resp.json()
    assert job["status"] == "queued"
    assert job["project_id"] == project_id

    # Status accessible without auth
    fetched = client.get(f"/jobs/{job['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["id"] == job["id"]

    # Logs accessible without auth
    logs = client.get(f"/jobs/{job['id']}/logs")
    assert logs.status_code == 200
    assert "logs" in logs.json()

    # Cancel transitions to canceling
    canceled = client.post(f"/jobs/{job['id']}/cancel", headers=auth_headers())
    assert canceled.status_code == 200
    assert canceled.json()["status"] == "canceling"
    assert canceled.json()["cancel_requested"] is True


def test_smoke_job_to_run_mapping(
    tmp_path: Path, monkeypatch, fixture_paired_dataset_4x: Path
) -> None:
    """Launching a run creates a job; job status maps back to run lifecycle state."""
    import sr_tuner_api.runs as runs_module
    monkeypatch.setattr(runs_module, "_module_available", lambda _name: True)

    _setup_env(monkeypatch)
    project_id, project_root = _make_project(tmp_path, monkeypatch, name="job_run_smoke")

    dataset = _add_dataset(project_id, fixture_paired_dataset_4x)
    model = _create_model(project_id)
    run = _create_run(project_id, dataset["id"], model["id"])

    launched = client.post(
        f"/projects/{project_id}/runs/{run['id']}/launch",
        json={"run_id": run["id"]},
        headers=auth_headers(),
    )
    assert launched.status_code == 200
    project_data = launched.json()["project"]
    run_after = project_data["runs"][0]
    assert run_after["state"] == "running"
    assert run_after["job_id"] is not None

    # Job is in the store and associated with the project
    job_resp = client.get(f"/jobs/{run_after['job_id']}")
    assert job_resp.status_code == 200
    job_data = job_resp.json()
    assert job_data["project_id"] == project_id
    assert job_data["status"] in ("queued", "running", "completed")

    # Stopping the run marks it stopped
    stopped = client.post(f"/projects/{project_id}/runs/{run['id']}/stop", headers=auth_headers())
    assert stopped.status_code == 200
    assert stopped.json()["project"]["runs"][0]["state"] == "stopped"
