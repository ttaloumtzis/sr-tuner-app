from __future__ import annotations

import json
import struct
from pathlib import Path

from fastapi.testclient import TestClient

from sr_tuner_api.config import PROJECT_FILE_NAME, PROJECT_SUBFOLDERS
from sr_tuner_api.ids import new_id, slugify
from sr_tuner_api.main import app
from sr_tuner_api.project_store import BACKUP_FILE_NAME, store_asset_path
from sr_tuner_api.runs import split_indexes


client = TestClient(app)
TOKEN = "test-token"


def auth_headers() -> dict[str, str]:
    return {"x-sr-tuner-token": TOKEN}


def write_png(path: Path, width: int, height: int, *, color_type: int = 2, bit_depth: int = 8) -> None:
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + struct.pack(">I", 13)
        + b"IHDR"
        + struct.pack(">IIBBBBB", width, height, bit_depth, color_type, 0, 0, 0)
        + b"\x00\x00\x00\x00"
    )


def make_project(tmp_path, monkeypatch, name: str = "demo") -> tuple[str, Path]:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    created = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": name},
        headers=auth_headers(),
    )
    assert created.status_code == 200
    return created.json()["project_id"], tmp_path / name


def make_paired_dataset(root: Path, *, scale: int = 4, grayscale: bool = False) -> None:
    (root / "HR").mkdir(parents=True)
    (root / "LR").mkdir(parents=True)
    write_png(root / "HR" / "frame_001.png", 64, 64, color_type=0 if grayscale else 2)
    write_png(root / "LR" / "frame_001.png", 64 // scale, 64 // scale)


def test_health_and_version() -> None:
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["status"] == "ok"

    version = client.get("/version")
    assert version.status_code == 200
    assert version.json()["app"] == "sr-tuner"


def test_create_and_open_project(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    created = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers=auth_headers(),
    )
    assert created.status_code == 200
    body = created.json()
    root = tmp_path / "demo"
    assert body["project"]["name"] == "demo"
    assert body["project_id"] == body["project"]["id"]
    assert body["root_path"] == str(root.resolve())
    assert (root / PROJECT_FILE_NAME).exists()
    for folder in PROJECT_SUBFOLDERS:
        assert (root / folder).is_dir()

    saved = json.loads((root / PROJECT_FILE_NAME).read_text(encoding="utf-8"))
    assert saved["datasets"] == []
    assert saved["workspace"]["selected_tab"] == 0
    assert "root_path" not in saved

    opened = client.post("/projects/open", json={"path": str(root)}, headers=auth_headers())
    assert opened.status_code == 200
    assert opened.json()["project"]["root_path"] == str(root.resolve())
    assert opened.json()["project"]["workspace"]["last_opened_at"] is not None


def test_workspace_state_persists(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    created = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers=auth_headers(),
    )
    root = tmp_path / "demo"
    project_id = created.json()["project_id"]

    response = client.put(
        f"/projects/{project_id}/workspace",
        json={"selected_tab": 3},
        headers=auth_headers(),
    )
    assert response.status_code == 200

    opened = client.post("/projects/open", json={"path": str(root)}, headers=auth_headers())
    assert opened.json()["project"]["workspace"]["selected_tab"] == 3


def test_project_relative_path_helper(tmp_path) -> None:
    root = tmp_path / "demo"
    inside = root / "datasets" / "set_a"
    outside = tmp_path / "external"
    inside.mkdir(parents=True)
    outside.mkdir()

    relative = store_asset_path(root, inside)
    assert relative.mode == "relative"
    assert relative.stored == "datasets/set_a"

    absolute = store_asset_path(root, outside)
    assert absolute.mode == "absolute"
    assert absolute.stored == str(outside.resolve())


def test_mutating_requests_require_session_token(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)

    missing = client.post("/projects", json={"parent_path": str(tmp_path), "name": "demo"})
    assert missing.status_code == 401
    assert missing.json()["error"]["code"] == "invalid_session_token"

    wrong = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers={"x-sr-tuner-token": "wrong"},
    )
    assert wrong.status_code == 401


def test_create_refuses_non_empty_non_project_folder(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    root = tmp_path / "demo"
    root.mkdir()
    (root / "notes.txt").write_text("existing content", encoding="utf-8")

    response = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers=auth_headers(),
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "target_folder_not_empty"

    confirmed = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo", "create_here": True},
        headers=auth_headers(),
    )
    assert confirmed.status_code == 200


def test_schema_too_new_is_rejected_without_modifying_file(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    root = tmp_path / "demo"
    root.mkdir()
    file_path = root / PROJECT_FILE_NAME
    payload = {
        "schema_version": 999,
        "app": "sr-tuner",
        "id": "project_test",
        "name": "demo",
        "root_path": str(root),
    }
    file_path.write_text(json.dumps(payload), encoding="utf-8")

    response = client.post("/projects/open", json={"path": str(root)}, headers=auth_headers())
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "project_schema_too_new"
    assert json.loads(file_path.read_text(encoding="utf-8"))["schema_version"] == 999


def test_atomic_write_keeps_backup(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    created = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers=auth_headers(),
    )
    project_id = created.json()["project_id"]
    root = tmp_path / "demo"

    client.put(
        f"/projects/{project_id}/workspace",
        json={"selected_tab": 2},
        headers=auth_headers(),
    )

    backup = root / BACKUP_FILE_NAME
    assert backup.exists()
    assert json.loads((root / PROJECT_FILE_NAME).read_text(encoding="utf-8"))["workspace"]["selected_tab"] == 2
    assert json.loads(backup.read_text(encoding="utf-8"))["workspace"]["selected_tab"] == 0


def test_corrupt_project_reports_backup_recovery(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    root = tmp_path / "demo"
    root.mkdir()
    (root / PROJECT_FILE_NAME).write_text("{not-json", encoding="utf-8")
    (root / BACKUP_FILE_NAME).write_text(
        json.dumps({"schema_version": 1, "app": "sr-tuner", "id": "project_test", "name": "demo"}),
        encoding="utf-8",
    )

    response = client.post("/projects/open", json={"path": str(root)}, headers=auth_headers())
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "project_file_invalid"
    assert error["details"]["recovery_available"] is True


def test_id_and_slug_helpers_are_stable_shape() -> None:
    assert slugify("My Model x4!") == "my-model-x4"
    assert slugify("   ") == "item"
    generated = new_id("model config")
    assert generated.startswith("model-config_")
    assert len(generated.split("_", maxsplit=1)[1]) == 16


def test_jobs_status_logs_and_cancel(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    created = client.post(
        "/projects",
        json={"parent_path": str(tmp_path), "name": "demo"},
        headers=auth_headers(),
    )
    project_id = created.json()["project_id"]

    job_response = client.post(
        "/jobs",
        json={"type": "dataset_copy", "project_id": project_id, "object_id": "dataset_1"},
        headers=auth_headers(),
    )
    assert job_response.status_code == 200
    job = job_response.json()
    assert job["status"] == "queued"

    fetched = client.get(f"/jobs/{job['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["id"] == job["id"]

    logs = client.get(f"/jobs/{job['id']}/logs")
    assert logs.status_code == 200
    assert logs.json()["logs"] == []

    canceled = client.post(f"/jobs/{job['id']}/cancel", headers=auth_headers())
    assert canceled.status_code == 200
    assert canceled.json()["status"] == "canceling"


def make_dataset_and_model(tmp_path, monkeypatch, *, scale: int = 4) -> tuple[str, Path, dict, dict]:
    project_id, project_root = make_project(tmp_path, monkeypatch)
    dataset_root = tmp_path / "external_dataset"
    make_paired_dataset(dataset_root, scale=scale)
    dataset_response = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "dataset_x4",
            "dataset_path": str(dataset_root),
            "scale": scale,
            "validation_mode": "full",
            "storage_operation": "reference",
        },
        headers=auth_headers(),
    )
    assert dataset_response.status_code == 200
    dataset = dataset_response.json()["project"]["datasets"][0]
    model_response = client.post(
        f"/projects/{project_id}/models",
        json={"name": "model_x4", "scale": scale, "num_features": 32, "num_blocks": 4},
        headers=auth_headers(),
    )
    assert model_response.status_code == 200
    model = model_response.json()["project"]["models"][0]
    return project_id, project_root, dataset, model


def test_create_run_persists_id_named_folder_and_split(tmp_path, monkeypatch) -> None:
    project_id, project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)

    response = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "Editable Display Name",
            "dataset_id": dataset["id"],
            "model_id": model["id"],
            "epochs": 3,
            "checkpoint_cadence": 1,
            "validation_percentage": 0.5,
            "validation_seed": 7,
            "validation_shuffle": False,
        },
        headers=auth_headers(),
    )

    assert response.status_code == 200
    run = response.json()["project"]["runs"][0]
    assert run["state"] == "configured"
    assert run["folder"] == f"runs/{run['id']}"
    assert (project_root / "runs" / run["id"]).is_dir()
    assert run["name"] == "Editable Display Name"
    assert run["train_indexes"] == [0]
    assert run["validation_indexes"] == []


def test_tensorboard_dependency_blocks_when_enabled(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, _project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(
        runs_module,
        "_module_available",
        lambda name: False if name in {"torch.utils.tensorboard", "tensorboard"} else True,
    )

    response = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "tb_run",
            "dataset_id": dataset["id"],
            "model_id": model["id"],
            "tensorboard": True,
        },
        headers=auth_headers(),
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "tensorboard_dependency_missing"


def test_run_launch_mapping_and_one_active_enforcement(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, _project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(runs_module, "_module_available", lambda name: True)

    first = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "run_one", "dataset_id": dataset["id"], "model_id": model["id"]},
        headers=auth_headers(),
    )
    second = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "run_two", "dataset_id": dataset["id"], "model_id": model["id"]},
        headers=auth_headers(),
    )
    assert first.status_code == 200
    assert second.status_code == 200
    first_run_id = first.json()["project"]["runs"][0]["id"]
    second_run_id = second.json()["project"]["runs"][1]["id"]

    launched = client.post(
        f"/projects/{project_id}/runs/{first_run_id}/launch",
        json={"run_id": first_run_id},
        headers=auth_headers(),
    )
    assert launched.status_code == 200
    assert launched.json()["project"]["runs"][0]["state"] == "running"

    blocked = client.post(
        f"/projects/{project_id}/runs/{second_run_id}/launch",
        json={"run_id": second_run_id},
        headers=auth_headers(),
    )
    assert blocked.status_code == 409
    assert blocked.json()["error"]["code"] == "active_run_exists"

    stopped = client.post(f"/projects/{project_id}/runs/{first_run_id}/stop", headers=auth_headers())
    assert stopped.status_code == 200
    assert stopped.json()["project"]["runs"][0]["state"] == "stopped"


def test_interrupted_run_recovery_on_open(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(runs_module, "_module_available", lambda name: True)
    created = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "run_one", "dataset_id": dataset["id"], "model_id": model["id"]},
        headers=auth_headers(),
    )
    run_id = created.json()["project"]["runs"][0]["id"]
    launched = client.post(
        f"/projects/{project_id}/runs/{run_id}/launch",
        json={"run_id": run_id},
        headers=auth_headers(),
    )
    assert launched.json()["project"]["runs"][0]["state"] == "running"

    reopened = client.post("/projects/open", json={"path": str(project_root)}, headers=auth_headers())
    assert reopened.status_code == 200
    assert reopened.json()["project"]["runs"][0]["state"] == "interrupted"


def test_split_indexes_are_deterministic_and_do_not_move_files() -> None:
    train_a, val_a = split_indexes(pair_count=10, validation_percentage=0.2, seed=11, shuffle=True)
    train_b, val_b = split_indexes(pair_count=10, validation_percentage=0.2, seed=11, shuffle=True)
    assert train_a == train_b
    assert val_a == val_b
    assert sorted(train_a + val_a) == list(range(10))


def test_launch_initializes_metric_files_definitions_and_active_status(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(runs_module, "_module_available", lambda name: True)
    created = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "metrics_run", "dataset_id": dataset["id"], "model_id": model["id"]},
        headers=auth_headers(),
    )
    run_id = created.json()["project"]["runs"][0]["id"]

    launched = client.post(
        f"/projects/{project_id}/runs/{run_id}/launch",
        json={"run_id": run_id},
        headers=auth_headers(),
    )

    assert launched.status_code == 200
    run = launched.json()["project"]["runs"][0]
    assert (project_root / run["folder"] / "metrics.jsonl").exists()
    assert (project_root / run["folder"] / "metric_definitions.json").exists()

    metrics = client.get(f"/projects/{project_id}/runs/{run_id}/metrics")
    assert metrics.status_code == 200
    assert "val_psnr" in metrics.json()["definitions"]
    assert metrics.json()["definitions"]["val_psnr"]["channel_policy"] == "RGB"
    assert metrics.json()["records"][0]["components"]["l1"] == 0

    active = client.get(f"/projects/{project_id}/active-run")
    assert active.status_code == 200
    assert active.json()["run"]["id"] == run_id
    assert active.json()["latest_metrics"]["progress"] == 0


def test_hardware_telemetry_marks_unavailable_fields(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, _project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(runs_module, "_module_available", lambda name: True)
    created = client.post(
        f"/projects/{project_id}/runs",
        json={"name": "telemetry_run", "dataset_id": dataset["id"], "model_id": model["id"]},
        headers=auth_headers(),
    )
    run_id = created.json()["project"]["runs"][0]["id"]
    client.post(
        f"/projects/{project_id}/runs/{run_id}/launch",
        json={"run_id": run_id},
        headers=auth_headers(),
    )

    telemetry = client.get(f"/projects/{project_id}/hardware")
    assert telemetry.status_code == 200
    body = telemetry.json()
    assert body["device"] == "cpu"
    assert body["memory_used"]["available"] == "unavailable"
    assert body["memory_used"]["value"] is None


def test_validation_preview_metadata_and_assets(tmp_path, monkeypatch) -> None:
    import sr_tuner_api.runs as runs_module

    project_id, _project_root, dataset, model = make_dataset_and_model(tmp_path, monkeypatch)
    monkeypatch.setattr(runs_module, "_module_available", lambda name: True)
    created = client.post(
        f"/projects/{project_id}/runs",
        json={
            "name": "preview_run",
            "dataset_id": dataset["id"],
            "model_id": model["id"],
            "diff_mode": "both",
        },
        headers=auth_headers(),
    )
    run_id = created.json()["project"]["runs"][0]["id"]
    client.post(
        f"/projects/{project_id}/runs/{run_id}/launch",
        json={"run_id": run_id},
        headers=auth_headers(),
    )

    preview = client.get(f"/projects/{project_id}/runs/{run_id}/preview")
    assert preview.status_code == 200
    kinds = {asset["kind"] for asset in preview.json()["assets"]}
    assert {"lr", "sr", "hr", "diff_absolute", "diff_heatmap"} <= kinds

    asset = client.get(f"/projects/{project_id}/runs/{run_id}/preview-assets/lr")
    assert asset.status_code == 200
    assert asset.content.startswith(b"\x89PNG")


def test_unknown_project_session_rejected(monkeypatch) -> None:
    monkeypatch.setenv("SR_TUNER_SESSION_TOKEN", TOKEN)
    response = client.put(
        "/projects/project_missing/workspace",
        json={"selected_tab": 1},
        headers=auth_headers(),
    )
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "project_session_not_found"


def test_register_type1_dataset_validates_pairs_scale_and_external_storage(tmp_path, monkeypatch) -> None:
    project_id, root = make_project(tmp_path, monkeypatch)
    dataset_root = tmp_path / "external_dataset"
    make_paired_dataset(dataset_root, grayscale=True)

    response = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "Anime Faces",
            "dataset_path": str(dataset_root),
            "scale": 4,
            "validation_mode": "quick",
            "storage_operation": "reference",
        },
        headers=auth_headers(),
    )
    assert response.status_code == 200
    dataset = response.json()["project"]["datasets"][0]
    assert dataset["storage_mode"] == "external"
    assert dataset["validation"]["usable"] is True
    assert dataset["validation"]["pair_count"] == 1
    assert dataset["validation"]["validated_scale"] == 4
    assert dataset["validation"]["warnings"]
    saved = json.loads((root / PROJECT_FILE_NAME).read_text(encoding="utf-8"))
    assert saved["datasets"][0]["name"] == "Anime Faces"


def test_register_type1_dataset_reports_unmatched_and_scale_errors(tmp_path, monkeypatch) -> None:
    project_id, _root = make_project(tmp_path, monkeypatch)
    dataset_root = tmp_path / "bad_dataset"
    (dataset_root / "HR").mkdir(parents=True)
    (dataset_root / "LR").mkdir(parents=True)
    write_png(dataset_root / "HR" / "a.png", 64, 64)
    write_png(dataset_root / "LR" / "a.png", 20, 20)
    write_png(dataset_root / "LR" / "orphan.png", 16, 16)

    response = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "Bad",
            "dataset_path": str(dataset_root),
            "scale": 4,
            "validation_mode": "full",
        },
        headers=auth_headers(),
    )
    assert response.status_code == 200
    validation = response.json()["project"]["datasets"][0]["validation"]
    assert validation["usable"] is False
    assert validation["validated_scale"] is None
    assert validation["unmatched_lr"] == ["orphan.png"]
    assert any("Scale mismatch" in error for error in validation["errors"])


def test_dataset_storage_estimate_and_copy_job(tmp_path, monkeypatch) -> None:
    project_id, root = make_project(tmp_path, monkeypatch)
    dataset_root = tmp_path / "copy_dataset"
    make_paired_dataset(dataset_root)

    estimate = client.post(
        f"/projects/{project_id}/datasets/storage-estimate",
        json={"dataset_path": str(dataset_root), "name": "Copy Set", "operation": "copy"},
        headers=auth_headers(),
    )
    assert estimate.status_code == 200
    assert estimate.json()["file_count"] == 2

    response = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={
            "name": "Copy Set",
            "dataset_path": str(dataset_root),
            "scale": 4,
            "storage_operation": "copy",
        },
        headers=auth_headers(),
    )
    assert response.status_code == 200
    dataset = response.json()["project"]["datasets"][0]
    assert dataset["storage_mode"] == "project"
    assert (root / "datasets" / "copy-set" / "HR" / "frame_001.png").exists()


def test_video_dependency_readiness_and_missing_video(tmp_path, monkeypatch) -> None:
    project_id, _root = make_project(tmp_path, monkeypatch)
    readiness = client.get("/dependencies/video")
    assert readiness.status_code == 200
    assert readiness.json()["tool"] == "ffmpeg"

    missing = client.post(
        f"/projects/{project_id}/datasets/video",
        json={"name": "Video Set", "source_video": str(tmp_path / "missing.mp4"), "scale": 4},
        headers=auth_headers(),
    )
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "video_missing"


def test_model_create_list_update_loss_validation_and_defaults(tmp_path, monkeypatch) -> None:
    project_id, _root = make_project(tmp_path, monkeypatch)
    defaults = client.get("/model-defaults/internal-residual-pixelshuffle")
    assert defaults.status_code == 200
    assert 4 in defaults.json()["supported_scales"]

    created = client.post(
        f"/projects/{project_id}/models",
        json={"name": "Tiny x4", "scale": 4, "num_features": 16, "num_blocks": 2},
        headers=auth_headers(),
    )
    assert created.status_code == 200
    model = created.json()["project"]["models"][0]
    assert model["architecture"] == "internal_residual_pixelshuffle"
    assert model["status"] == "untrained"

    listed = client.get(f"/projects/{project_id}/models")
    assert listed.status_code == 200
    assert listed.json()[0]["name"] == "Tiny x4"

    updated = client.put(
        f"/projects/{project_id}/models/{model['id']}",
        json={"optimizer": {"type": "adam", "lr": 0.0001, "beta1": 0.9, "beta2": 0.99}},
        headers=auth_headers(),
    )
    assert updated.status_code == 200
    assert updated.json()["project"]["models"][0]["optimizer"]["lr"] == 0.0001

    unsupported_loss = client.post(
        f"/projects/{project_id}/models",
        json={"name": "GAN x4", "scale": 4, "loss_weights": {"l1": 1, "perceptual": 1, "adversarial": 0}},
        headers=auth_headers(),
    )
    assert unsupported_loss.status_code == 422
    assert unsupported_loss.json()["error"]["code"] == "unsupported_loss"


def test_model_status_and_dataset_compatibility(tmp_path, monkeypatch) -> None:
    project_id, root = make_project(tmp_path, monkeypatch)
    dataset_root = tmp_path / "dataset"
    make_paired_dataset(dataset_root)
    dataset_response = client.post(
        f"/projects/{project_id}/datasets/paired",
        json={"name": "Set x4", "dataset_path": str(dataset_root), "scale": 4},
        headers=auth_headers(),
    )
    dataset_id = dataset_response.json()["project"]["datasets"][0]["id"]

    model_response = client.post(
        f"/projects/{project_id}/models",
        json={"name": "Tiny x4", "scale": 4},
        headers=auth_headers(),
    )
    model_id = model_response.json()["project"]["models"][0]["id"]

    compatible = client.get(f"/projects/{project_id}/compatibility?dataset_id={dataset_id}&model_id={model_id}")
    assert compatible.status_code == 200
    assert compatible.json()["compatible"] is True

    saved = json.loads((root / PROJECT_FILE_NAME).read_text(encoding="utf-8"))
    saved["runs"] = [
        {
            "id": "run_1",
            "model_id": model_id,
            "checkpoints": [{"id": "ckpt_1", "usable": True, "scale": 4, "fine_tune_compatible": True}],
        }
    ]
    (root / PROJECT_FILE_NAME).write_text(json.dumps(saved), encoding="utf-8")

    model = client.get(f"/projects/{project_id}/models/{model_id}")
    assert model.status_code == 200
    assert model.json()["status"] == "fine_tune_available"
