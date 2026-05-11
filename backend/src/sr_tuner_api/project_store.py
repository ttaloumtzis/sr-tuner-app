from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from .config import PROJECT_FILE_NAME, PROJECT_SUBFOLDERS
from .errors import ApiError
from .schemas import PathInfo, ProjectState, utc_now_iso

CURRENT_PROJECT_SCHEMA_VERSION = 1
SUPPORTED_PROJECT_SCHEMA_VERSIONS = {1}
BACKUP_FILE_NAME = f"{PROJECT_FILE_NAME}.bak"


def project_file(project_root: Path) -> Path:
    return project_root / PROJECT_FILE_NAME


def backup_file(project_root: Path) -> Path:
    return project_root / BACKUP_FILE_NAME


def ensure_project_folders(project_root: Path) -> None:
    project_root.mkdir(parents=True, exist_ok=True)
    for folder in PROJECT_SUBFOLDERS:
        (project_root / folder).mkdir(parents=True, exist_ok=True)


def _read_project_json(file_path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(file_path.read_text(encoding="utf-8"))
    except Exception as exc:
        backup = backup_file(file_path.parent)
        details: dict[str, Any] = {"path": str(file_path)}
        if backup.exists():
            details["backup_path"] = str(backup)
            details["recovery_available"] = True
        raise ApiError(
            422,
            "project_file_invalid",
            "Project file is unreadable. Restore from backup or repair the JSON.",
            details=details,
        ) from exc
    if not isinstance(raw, dict):
        raise ApiError(422, "project_file_invalid", "Project file must contain a JSON object.")
    return raw


def _validate_schema(raw: dict[str, Any]) -> None:
    version = raw.get("schema_version")
    if not isinstance(version, int):
        raise ApiError(
            422,
            "project_schema_invalid",
            "Project schema version is missing or invalid.",
            recoverable=True,
        )
    if version > CURRENT_PROJECT_SCHEMA_VERSION:
        raise ApiError(
            409,
            "project_schema_too_new",
            "This project was created by a newer sr-tuner version.",
            details={"project_schema_version": version, "supported_schema_version": CURRENT_PROJECT_SCHEMA_VERSION},
            recoverable=True,
        )
    if version not in SUPPORTED_PROJECT_SCHEMA_VERSIONS:
        raise ApiError(
            422,
            "project_schema_unsupported",
            "Project schema version is not supported by this backend.",
            details={"project_schema_version": version},
            recoverable=False,
        )


def migrate_project(project_root: Path, raw: dict[str, Any]) -> tuple[ProjectState, bool]:
    _validate_schema(raw)
    project = ProjectState.model_validate(raw)
    migrated = project.schema_version != CURRENT_PROJECT_SCHEMA_VERSION
    project.schema_version = CURRENT_PROJECT_SCHEMA_VERSION
    project.root_path = str(project_root)
    return project, migrated


def write_project(project: ProjectState) -> ProjectState:
    if project.root_path is None:
        raise ApiError(500, "project_root_missing", "Project root is not bound for this local session.", recoverable=False)
    root = Path(project.root_path).expanduser().resolve()
    ensure_project_folders(root)
    project.root_path = str(root)
    project.updated_at = utc_now_iso()
    file_path = project_file(root)
    backup = backup_file(root)
    if file_path.exists():
        shutil.copy2(file_path, backup)
    temp_path = root / f".{PROJECT_FILE_NAME}.tmp"
    temp_path.write_text(
        json.dumps(
            project.model_dump(exclude={"root_path"}, exclude_none=True),
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    temp_path.replace(file_path)
    return project


def create_project(parent_path: Path, name: str, *, create_here: bool = False) -> ProjectState:
    root = (parent_path / name).expanduser().resolve()
    if project_file(root).exists():
        raise ApiError(409, "project_exists", "Project already exists.", details={"path": str(root)})
    if root.exists() and any(root.iterdir()) and not create_here:
        raise ApiError(
            409,
            "target_folder_not_empty",
            "Target folder is non-empty and is not an sr-tuner project.",
            details={"path": str(root)},
            recoverable=True,
        )
    ensure_project_folders(root)
    project = ProjectState(name=name, root_path=str(root))
    return write_project(project)


def open_project(path: Path) -> ProjectState:
    root = path.expanduser().resolve()
    file_path = project_file(root)
    if not file_path.exists():
        raise ApiError(404, "project_file_missing", "sr-tuner.project.json was not found.", details={"path": str(root)})
    raw = _read_project_json(file_path)
    project, migrated = migrate_project(root, raw)
    project.root_path = str(root)
    project.workspace.last_opened_at = utc_now_iso()
    ensure_project_folders(root)
    if migrated:
        shutil.copy2(file_path, backup_file(root))
    return write_project(project)


def load_project(path: Path) -> ProjectState:
    return open_project(path)


def store_asset_path(project_root: Path, asset_path: Path) -> PathInfo:
    asset = asset_path.expanduser().resolve()
    root = project_root.expanduser().resolve()
    try:
        relative = asset.relative_to(root)
    except ValueError:
        return PathInfo(original=str(asset_path), stored=str(asset), mode="absolute")
    return PathInfo(original=str(asset_path), stored=relative.as_posix(), mode="relative")
