#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$ROOT/backend/.venv/bin/python"
ROCM_WHEEL_INDEX="${ROCM_WHEEL_INDEX:-https://download.pytorch.org/whl/rocm7.1}"
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
  --index-url "$ROCM_WHEEL_INDEX"

"$PYTHON" - <<'PY'
import torch
from PIL import Image

print("torch", torch.__version__)
print("rocm", torch.version.hip)
print("pillow", Image.__version__)
print("gpu_available", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu_count", torch.cuda.device_count())
    for index in range(torch.cuda.device_count()):
        print(f"gpu_{index}", torch.cuda.get_device_name(index))
PY
