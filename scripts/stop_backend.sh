#!/usr/bin/env sh
set -eu

echo "Stopping sr-tuner backend..."

# Kill uvicorn processes running on port 8765
pkill -f "uvicorn sr_tuner_api.main:app" || echo "No uvicorn processes found"

# Alternative: kill by port
# lsof -ti:8765 | xargs kill || echo "No processes found on port 8765"

echo "Backend stopped."
