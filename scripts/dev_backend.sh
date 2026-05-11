#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."
uv run --project backend uvicorn sr_tuner_api.main:app --app-dir backend/src --host 127.0.0.1 --port 8765 --reload
