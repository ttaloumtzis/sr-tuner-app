from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .ids import new_id


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class HealthResponse(BaseModel):
    status: Literal["ok"]
    app: str
    version: str


class VersionResponse(BaseModel):
    app: str
    version: str
    api_version: str = "v1"


class CreateProjectRequest(BaseModel):
    parent_path: str
    name: str
    create_here: bool = False

    @field_validator("name")
    @classmethod
    def valid_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Project name is required.")
        if any(part in cleaned for part in ("/", "\\")):
            raise ValueError("Project name must not contain path separators.")
        return cleaned


class OpenProjectRequest(BaseModel):
    path: str


class WorkspaceState(BaseModel):
    selected_tab: int = 0
    last_opened_at: str | None = None
    theme: Literal["system", "light", "dark"] = "system"
    density: Literal["comfortable", "compact"] = "comfortable"
    per_project_ui_state: dict[str, Any] = Field(default_factory=dict)


class ProjectState(BaseModel):
    model_config = ConfigDict(extra="allow")

    schema_version: int = 1
    app: str = "sr-tuner"
    id: str = Field(default_factory=lambda: new_id("project"))
    name: str
    root_path: str | None = None
    created_at: str = Field(default_factory=utc_now_iso)
    updated_at: str = Field(default_factory=utc_now_iso)
    workspace: WorkspaceState = Field(default_factory=WorkspaceState)
    datasets: list[dict[str, Any]] = Field(default_factory=list)
    models: list[dict[str, Any]] = Field(default_factory=list)
    runs: list[dict[str, Any]] = Field(default_factory=list)
    checkpoints: list[dict[str, Any]] = Field(default_factory=list)
    inference_history: list[dict[str, Any]] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class ProjectResponse(BaseModel):
    project: ProjectState
    project_id: str
    root_path: str
    project_file: str


class SaveWorkspaceRequest(BaseModel):
    selected_tab: int | None = Field(default=None, ge=0, le=6)
    theme: Literal["system", "light", "dark"] | None = None
    density: Literal["comfortable", "compact"] | None = None
    per_project_ui_state: dict[str, Any] | None = None


class PathInfo(BaseModel):
    original: str
    stored: str
    mode: Literal["relative", "absolute"]


class ApiErrorShape(BaseModel):
    code: str
    message: str
    details: dict[str, Any] = Field(default_factory=dict)
    recoverable: bool = True


class ApiErrorResponse(BaseModel):
    error: ApiErrorShape


def normalize_path(value: str) -> Path:
    return Path(value).expanduser().resolve()
