$ErrorActionPreference = "Stop"

$ROOT = Resolve-Path "$PSScriptRoot\.."
$PYTHON = "$ROOT\backend\.venv\Scripts\python.exe"

# Environment specs from variables or defaults
$TORCH_SPEC = if ($env:PYTORCH_VERSION) { "torch==$($env:PYTORCH_VERSION)" } else { "torch" }
$TORCHVISION_SPEC = if ($env:TORCHVISION_VERSION) { "torchvision==$($env:TORCHVISION_VERSION)" } else { "torchvision" }
$TORCHAUDIO_SPEC = if ($env:TORCHAUDIO_VERSION) { "torchaudio==$($env:TORCHAUDIO_VERSION)" } else { "torchaudio" }

if (-not (Test-Path $PYTHON)) {
    uv venv "$ROOT\backend\.venv"
}

uv sync --project "$ROOT\backend" --extra dev --extra training
uv pip install --python $PYTHON `
  $TORCH_SPEC `
  $TORCHVISION_SPEC `
  $TORCHAUDIO_SPEC `
  --index-url https://download.pytorch.org/whl/cpu

# Run verification
& $PYTHON -c @"
import torch
from PIL import Image
print(f'torch {torch.__version__}')
print('device cpu')
print(f'pillow {Image.__version__}')
"@