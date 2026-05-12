#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$ROOT/backend/.venv/bin/python"
TORCH_SPEC="${PYTORCH_VERSION:+torch==$PYTORCH_VERSION}"
TORCHVISION_SPEC="${TORCHVISION_VERSION:+torchvision==$TORCHVISION_VERSION}"
TORCHAUDIO_SPEC="${TORCHAUDIO_VERSION:+torchaudio==$TORCHAUDIO_VERSION}"

if [ ! -x "$PYTHON" ]; then
  uv venv "$ROOT/backend/.venv"
fi

uv sync --project "$ROOT/backend" --extra dev --extra training
uv pip install --python "$PYTHON" \
  "${TORCH_SPEC:-torch}" \
  "${TORCHVISION_SPEC:-torchvision}" \
  "${TORCHAUDIO_SPEC:-torchaudio}" \
  --index-url https://download.pytorch.org/whl/cpu

"$PYTHON" - <<'PY'
import torch
from PIL import Image

print("torch", torch.__version__)
print("device", "cpu")
print("pillow", Image.__version__)
PY
