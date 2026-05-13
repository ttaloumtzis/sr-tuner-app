# Repository Guidelines

## Project Structure & Module Organization

`lib/` contains the Flutter desktop app. Core app state and backend access live in `lib/src/project_controller.dart`, `lib/src/backend_client.dart`, and `lib/src/backend_process.dart`; workspace tabs are under `lib/src/workspace/`.  
`backend/src/sr_tuner_api/` contains the FastAPI backend, with endpoint modules, schemas, jobs, metrics, inference, and project persistence. Backend tests live in `backend/tests/`; Flutter tests live in `test/`.  
`openspec/` stores active and archived change proposals/specs/tasks. `scripts/` contains local setup, dev, and cleanup helpers.

## Build, Test, and Development Commands

- `scripts/dev_backend.sh`: start FastAPI on `127.0.0.1:8765` with reload.
- `scripts/dev_frontend.sh`: start the Flutter Linux desktop frontend.
- `uv run --project backend pytest backend/tests/ -q`: run backend unit/integration tests.
- `flutter analyze`: run Dart static analysis with `flutter_lints`.
- `flutter test`: run Flutter widget/model tests.
- `python3 scripts/gen_fixtures.py`: regenerate backend PNG fixtures if missing.
- `scripts/clean.sh` or `scripts/clean.sh --venv`: remove generated artifacts; `--venv` also deletes `backend/.venv`.

## Coding Style & Naming Conventions

Use standard Dart formatting (`dart format`) and Python formatting consistent with existing files. Dart files use `snake_case.dart`; classes use `UpperCamelCase`; private Dart members start with `_`. Python modules use `snake_case.py`; API error codes and IDs should be stable, lowercase, and machine-readable. Prefer existing helpers and schemas over ad hoc parsing or duplicated models.

## Testing Guidelines

Backend tests use `pytest` and FastAPI `TestClient`; no live server is required. Tests that need unavailable ML dependencies should skip cleanly. Flutter tests use `flutter_test`. Name tests after behavior, not implementation details, and cover API contracts when changing schemas, error payloads, project persistence, jobs, inference, or live metrics.

## Commit & Pull Request Guidelines

Recent commits are short, imperative summaries (for example, `new fixes`, `more changes`). Use clearer equivalents: `add inference diagnostics`, `fix project recovery error`. PRs should include a concise description, test commands run, linked OpenSpec change when applicable, and screenshots for UI changes.

## Security & Configuration Tips

The local backend is protected by `SR_TUNER_SESSION_TOKEN`; mutating API calls must send `x-sr-tuner-token`. Do not log or commit tokens, local paths with private data, generated build output, virtualenvs, or `config/sr_tuner.local.json`. For larger feature work, capture intent in `openspec/changes/<change-name>/` before implementation.
