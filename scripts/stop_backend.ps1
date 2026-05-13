Write-Host "Stopping sr-tuner backend..." -ForegroundColor Yellow

# Find and kill the specific uvicorn process
$processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*uvicorn sr_tuner_api.main:app*" }

if ($processes) {
    $processes | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Write-Host "Backend stopped." -ForegroundColor Green
} else {
    Write-Host "No uvicorn processes found."
}