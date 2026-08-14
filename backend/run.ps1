# MetroPaws Backend - local run script.
#
# Usage (from anywhere - it switches to the backend directory itself):
#   .\run.ps1                     # DEV with auto-reload (the default)
#   .\run.ps1 -Port 8080          # DEV on another port
#   .\run.ps1 -BindHost 0.0.0.0   # DEV reachable from your phone on the LAN
#   .\run.ps1 -Env prod           # PROD - asks for confirmation, no auto-reload
#
# APP_ENV is set only inside the child process, never in this shell, so
# pressing Ctrl+C can never leave your terminal pointed at production.

param(
    [ValidateSet("dev", "prod")]
    [string]$Env = "dev",

    [int]$Port = 8000,

    # 127.0.0.1 keeps the server off the network; 0.0.0.0 exposes it to the LAN.
    [string]$BindHost = "127.0.0.1",

    [switch]$Reload,
    [switch]$NoReload
)

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

# Auto-reload defaults on for dev and off for prod: the reloader re-imports the
# app on every file save, and each import runs create_all against the selected
# database.
$useReload = if ($Reload) { $true } elseif ($NoReload) { $false } else { $Env -eq "dev" }

# ── Safety: confirm before pointing a local server at the live database ───────
if ($Env -eq "prod") {
    Write-Host ""
    Write-Host "!! APP_ENV=prod - this server will read and write the LIVE database." -ForegroundColor Red
    Write-Host "   Starting the app also runs create_all against it (creates missing tables)." -ForegroundColor Red
    if ($useReload) {
        Write-Host "   -Reload will re-run that on every file save." -ForegroundColor Red
    }
    $confirm = Read-Host "   Type PROD to continue"
    if ($confirm -cne "PROD") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "No .venv found - falling back to the python on PATH." -ForegroundColor Yellow
    $python = "python"
}

$uvicornArgs = "-m uvicorn main:app --host $BindHost --port $Port"
if ($useReload) { $uvicornArgs += " --reload" }

Write-Host ""
Write-Host "Environment : $($Env.ToUpper())" -ForegroundColor Cyan
Write-Host "Listening   : http://$BindHost`:$Port    (docs at /docs)" -ForegroundColor Cyan
Write-Host "Auto-reload : $(if ($useReload) { 'on' } else { 'off' })" -ForegroundColor Cyan
Write-Host ""

# `set` inside cmd scopes APP_ENV to this child process only - the parent shell
# never has it, so an interrupted run leaves nothing behind to clean up.
cmd /c "set APP_ENV=$Env&& `"$python`" $uvicornArgs"
