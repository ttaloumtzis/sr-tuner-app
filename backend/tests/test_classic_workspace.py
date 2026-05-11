from __future__ import annotations

import json
import struct
from pathlib import Path

from fastapi.testclient import TestClient

from sr_tuner_api.checkpoints import CheckpointMetadata
from sr_tuner_api.main import app
from sr_tuner_api.project_store import open_project, write_project


client = TestClient(app)
TOKEN = "test-token"


def auth_headers() -> dict[str, str]:
    return {"x-sr-tuner-token": TOKEN}


def make_paired_dataset(root: Path, *, scale: int = 4) -> None:
    (root / "HR").mkdir(parents=True)
    (root / "LR").mkdir(parents=True)
    _write_png(root / "HR" / "frame_001.png", 64, 64)
    _write_png(root / "LR" / "frame_001.png", 64 // scale, 64 // scale)


def _write_png(path: Path, width: int, height: int) -> None:
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + struct.pack(">I", 13)
        + b"IHDR"
        + struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
        + b"\x00\x00\x00\x00"
    )


def _make_project(tmp_path: Path, monkeypatch, name: str = "demo") -> tuple[str, Path]:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    monkeypatch.setenv("SR_TUNER_RECENT_PROJECTS_FILE", str(tmp_path / "recent.json"))
    response = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": name},
        headers=auth_headers(),
    )
    assert response.status_code == 200
    return response.json()["project_id"], tmp_path / name


def _add_dataset_model_run(project_id: str, project_root: Path, tmp_path: Path) -> tuple[str, str, str]:
    dataset_root = tmp_path / "paired"
    make_paired_dataset(dataset_root)
    dataset = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "pairs",
            "dataset_path": str(dataset_root),
            "scale": 4,
            "validation_mode": "quick",
            "storage_operation": "reference",
        },
        headers=auth_headers(),
    )
    assert dataset.status_code == 200
    dataset_id = dataset.json()["project"]["datasets"][0]["id"]
    model = client.post(
        f"/projects/{project_id}/models",
        json={"name": "model", "scale": 4, "num_features": 32, "num_blocks": 4},
        headers=auth_headers(),
    )
    assert model.status_code == 200
    model_id = model.json()["project"]["models"][0]["id"]
    run = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "run",
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
    assert run.status_code == 200
    return dataset_id, model_id, run.json()["project"]["runs"][0]["id"]


def test_workspace_preferences_and_recent_projects(tmp_path, monkeypatch) -> None:
    project_id, root = _make_project(tmp_path, monkeypatch)

    updated = client.put(
        f"/projects/{project_id}/workspace",
        json={"selected_tab": 6, "theme": "dark", "density": "compact", "per_project_ui_state": {"inference": {"selected": "x"}}},
        headers=auth_headers(),
    )
    assert updated.status_code == 200
    workspace = updated.json()["project"]["workspace"]
    assert workspace["selected_tab"] == 6
    assert workspace["theme"] == "dark"
    assert workspace["density"] == "compact"

    prefs = client.get(f"/projects/{project_id}/workspace")
    assert prefs.status_code == 200
    assert prefs.json()["per_project_ui_state"]["inference"]["selected"] == "x"

    recents = client.get("/projects/recent")
    assert recents.status_code == 200
    first = recents.json()["projects"][0]
    assert first["path"] == str(root.resolve())
    assert first["status"] == "available"

    missing_root = tmp_path / "missing"
    recent_file = tmp_path / "recent.json"
    recent_file.write_text(json.dumps([{"path": str(missing_root), "last_opened_at": "now"}]), encoding="utf-8")
    stale = client.get("/projects/recent")
    assert stale.json()["projects"][0]["status"] == "missing"


def test_dashboard_activity_guidance_and_status(tmp_path, monkeypatch) -> None:
    project_id, root = _make_project(tmp_path, monkeypatch)
    empty = client.get(f"/projects/{project_id}/dashboard")
    assert empty.status_code == 200
    assert empty.json()["next_step"]["state"] == "missing_dataset"
    assert empty.json()["status_bar"]["project_path"] == str(root.resolve())

    dataset_id, _model_id, run_id = _add_dataset_model_run(project_id, root, tmp_path)
    project = open_project(root)
    project.runs[0]["checkpoints"] = [
        CheckpointMetadata(
            run_id=run_id,
            epoch=1,
            iteration=10,
            path=f"runs/{run_id}/checkpoints/a.pth",
            metrics={"val_psnr": 31.5},
            scale=4,
            model_architecture="internal_residual_pixelshuffle",
        ).model_dump()
    ]
    write_project(project)

    dashboard = client.get(f"/projects/{project_id}/dashboard")
    assert dashboard.status_code == 200
    body = dashboard.json()
    assert body["dataset_count"] == 1
    assert body["dataset_pair_total"] == 1
    assert body["best_psnr"] == 31.5
    assert body["next_step"]["state"] == "inference_ready"

    activity = client.get(f"/projects/{project_id}/activity")
    assert activity.status_code == 200
    categories = {event["category"] for event in activity.json()["events"]}
    assert {"dataset", "model", "run", "checkpoint"} <= categories

    detail = client.get(f"/projects/{project_id}/datasets/{dataset_id}/detail")
    assert detail.status_code == 200
    assert detail.json()["sources"][0]["pair_count"] == 1
    assert detail.json()["resynthesis"]["supported"] is False


def test_backend_domain_view_endpoints_return_supported_or_unavailable_states(tmp_path, monkeypatch) -> None:
    project_id, root = _make_project(tmp_path, monkeypatch)
    dataset_id, model_id, run_id = _add_dataset_model_run(project_id, root, tmp_path)

    video_meta = client.post(
        f"/projects/{project_id}/datasets/video/metadata",
        json={"name": "video", "source_video": str(tmp_path / "missing.mp4"), "scale": 4, "fps": 1.0},
        headers=auth_headers(),
    )
    assert video_meta.status_code == 200
    assert video_meta.json()["readiness"]["code"] == "video_missing"

    templates = client.get(f"/projects/{project_id}/model-templates")
    assert templates.status_code == 200
    assert templates.json()["templates"][0]["support_state"] == "supported"
    assert any(template["unavailable"] for template in templates.json()["templates"][1:])

    estimate = client.post(
        f"/projects/{project_id}/training/estimate",
        json={
            "name": "estimate",
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
    assert estimate.status_code == 200
    assert estimate.json()["low_pair_guard"]["code"] == "low_pair_count"
    assert estimate.json()["ema"]["supported"] is False

    live = client.get(f"/projects/{project_id}/live/detail")
    assert live.status_code == 200
    assert live.json()["run"]["id"] == run_id

    snapshot = client.post(f"/projects/{project_id}/runs/{run_id}/snapshot", headers=auth_headers())
    assert snapshot.status_code == 200
    assert snapshot.json()["unavailable"]["code"] == "snapshot_unavailable"

    aggregate = client.get(f"/projects/{project_id}/checkpoints/aggregate")
    assert aggregate.status_code == 200
    assert aggregate.json()["actions"]["compare"]["supported"] is False

    inspector = client.get(f"/projects/{project_id}/inference/inspector")
    assert inspector.status_code == 200
    assert {item["id"] for item in inspector.json()["blocked_checklist"]} == {"dataset", "model", "checkpoint"}
