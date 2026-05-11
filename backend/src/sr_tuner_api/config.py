from __future__ import annotations

from pathlib import Path

APP_NAME = "sr-tuner"
PROJECT_FILE_NAME = "sr-tuner.project.json"
PROJECT_SUBFOLDERS = (
    "datasets",
    "models",
    "runs",
    "checkpoints",
    "inference",
    "cache",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]
