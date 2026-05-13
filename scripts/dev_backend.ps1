Set-Location "$PSScriptRoot\.."
uv run --project backend uvicorn sr_tuner_api.main:app --app-dir backend/src --host 127.0.0.1 --port 8765 --reload