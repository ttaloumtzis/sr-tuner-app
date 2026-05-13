# Set error handling (similar to set -e)
$ErrorActionPreference = "Continue"

$ROOT = Resolve-Path "$PSScriptRoot\.."
Set-Location $ROOT

Write-Host "Cleaning $ROOT ..." -ForegroundColor Cyan

# Flutter build output
if (Test-Path "build") {
    flutter clean --quiet
    Write-Host "  flutter build cleaned"
}

# Python __pycache__ and .pyc files
Get-ChildItem -Path "backend" -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "backend" -Recurse -Filter "*.pyc" | Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host "  Python caches cleaned"

# pytest cache
if (Test-Path "backend\.pytest_cache") {
    Remove-Item -Recurse -Force "backend\.pytest_cache"
    Write-Host "  pytest cache cleaned"
}

# uv virtual environment
if ($args -contains "--venv") {
    if (Test-Path "backend\.venv") {
        Remove-Item -Recurse -Force "backend\.venv"
        Write-Host "  backend\.venv removed (run: uv sync --project backend)"
    }
}

# Smoke-test generated files
Get-ChildItem -Path "." -Depth 0 -Directory -Filter "smoke_proj*" | Remove-Item -Recurse -Force
Get-ChildItem -Path "." -Depth 0 -Directory -Filter "test_proj*" | Remove-Item -Recurse -Force

# Dart/Flutter tool caches
if (Test-Path ".dart_tool\flutter_build") {
    Remove-Item -Recurse -Force ".dart_tool\flutter_build"
}

Write-Host "Done. Pass --venv to also remove the backend virtual environment."