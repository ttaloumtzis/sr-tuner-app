#!/usr/bin/env sh
# Remove generated build artifacts, Python caches, and known smoke-test temporaries.
set -eu

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

echo "Cleaning $ROOT …"

# Flutter build output
if [ -d build ]; then
  flutter clean --quiet || true
  echo "  flutter build cleaned"
fi

# Python __pycache__ and .pyc files
find backend -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find backend -name "*.pyc" -delete 2>/dev/null || true
echo "  Python caches cleaned"

# pytest cache
rm -rf backend/.pytest_cache
echo "  pytest cache cleaned"

# uv virtual environment (keeps uv.lock – re-run uv sync to recreate)
if [ "${1:-}" = "--venv" ]; then
  rm -rf backend/.venv
  echo "  backend/.venv removed (run: uv sync --project backend)"
fi

# Smoke-test generated files (test_project_* folders left in /tmp by pytest are
# cleaned by the OS; this removes any that land in the repo root accidentally)
find . -maxdepth 1 -type d -name "smoke_proj*" -exec rm -rf {} + 2>/dev/null || true
find . -maxdepth 1 -type d -name "test_proj*"  -exec rm -rf {} + 2>/dev/null || true

# Dart/Flutter tool caches (keeps .dart_tool/package_config.json used by IDEs)
rm -rf .dart_tool/flutter_build 2>/dev/null || true

echo "Done. Pass --venv to also remove the backend virtual environment."
