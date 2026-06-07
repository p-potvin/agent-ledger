<#
.SYNOPSIS
    VaultWares Daily Input Tracker — Setup & Scheduler

.DESCRIPTION
    1. Verifies Python + pip are available
    2. Installs pynput and pyperclip
    3. Registers a Windows Scheduled Task that starts the tracker at every logon
    4. Optionally starts the tracker immediately

.PARAMETER PythonExe
    Path to pythonw.exe (silent, no console window). Defaults to "pythonw" on PATH.

.PARAMETER StartNow
    Switch — if present, starts the tracker task immediately after registration.

.EXAMPLE
    .\setup-input-tracker.ps1 -StartNow
#>
[CmdletBinding()]
param(
    [string]$PythonExe  = "pythonw",
    [switch]$StartNow
)

$ErrorActionPreference = "Stop"

$ScriptDir     = Split-Path $MyInvocation.MyCommand.Path -Parent
$LedgerRoot    = Split-Path $ScriptDir -Parent
$TrackerScript = Join-Path $ScriptDir "track-input.py"
$TrackerTask   = "VaultWares-InputTracker"

# ---------------------------------------------------------------------------
# 1. Sanity checks
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   VaultWares Daily Input Tracker — Setup             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $TrackerScript)) {
    throw "Tracker script not found: $TrackerScript"
}
# Resolve pythonw full path
$pythonResolved = (Get-Command $PythonExe -ErrorAction SilentlyContinue)?.Source
if (-not $pythonResolved) {
    # Try python.exe and derive pythonw from same dir
    $py = (Get-Command "python" -ErrorAction SilentlyContinue)?.Source
    if ($py) {
        $pythonResolved = Join-Path (Split-Path $py -Parent) "pythonw.exe"
        if (-not (Test-Path $pythonResolved)) { $pythonResolved = $py }
    } else {
        throw "Python not found on PATH. Install Python 3.8+ first."
    }
}
Write-Host "Python:  $pythonResolved" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. Install dependencies
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
& python -m pip install --quiet --upgrade pynput pyperclip
if ($LASTEXITCODE -ne 0) {
    Write-Warning "pip install returned non-zero. Tracker may still work if packages are already installed."
} else {
    Write-Host "  pynput + pyperclip — OK" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Register tracker task (runs at every logon, indefinitely)
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Registering scheduled task: $TrackerTask ..." -ForegroundColor Yellow

Unregister-ScheduledTask -TaskName $TrackerTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$conhost = "$env:SystemRoot\System32\conhost.exe"
$trackerAction = New-ScheduledTaskAction `
    -Execute    $conhost `
    -Argument   "--headless powershell.exe -NoProfile -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command `"& '$pythonResolved' '$TrackerScript'`"" `
    -WorkingDirectory $ScriptDir

$trackerTriggerLogon  = New-ScheduledTaskTrigger -AtLogOn
# Also trigger on workstation unlock so the tracker resumes after a locked screen
$trackerTriggerUnlock = New-CimInstance -Namespace ROOT\Microsoft\Windows\TaskScheduler `
    -ClassName MSFT_TaskSessionStateChangeTrigger `
    -Property @{ StateChange = 8; Enabled = $true } -ClientOnly   # 8 = SESSION_UNLOCK
$trackerSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  `
    -MultipleInstances  IgnoreNew                `
    -RestartCount       99                       `
    -RestartInterval    (New-TimeSpan -Minutes 1)`
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName   $TrackerTask `
    -Action     $trackerAction `
    -Trigger    @($trackerTriggerLogon, $trackerTriggerUnlock) `
    -Settings   $trackerSettings `
    -RunLevel   Highest `
    -Description "VaultWares: silently tracks privacy-safe input metrics and batches them to vaultwares-pipelines. Starts at logon + unlock, restarts automatically on crash." `
    | Out-Null

Write-Host "  Task '$TrackerTask' registered — starts at every logon." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Optionally start tracker now
# ---------------------------------------------------------------------------

if ($StartNow) {
    Write-Host ""
    Write-Host "Starting tracker now..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $TrackerTask
    Start-Sleep -Milliseconds 800
    $state = (Get-ScheduledTask -TaskName $TrackerTask).State
    Write-Host "  Tracker state: $state" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Setup complete." -ForegroundColor Cyan
Write-Host ""
$apiBase = $env:VW_PIPELINES_URL
if (-not $apiBase) { $apiBase = "http://127.0.0.1:9001" }
Write-Host "  API endpoint  →  $apiBase/api/telemetry/input/batches"
Write-Host "  Spool fallback→  $LedgerRoot\input-spool\YYYY-MM-DD.jsonl"
Write-Host ""
Write-Host "Set VW_PIPELINES_URL and VW_PIPELINES_API_KEY before starting the task if the defaults do not match this machine." -ForegroundColor DarkGray
Write-Host "Replay failed batches with:" -ForegroundColor DarkGray
Write-Host "  python .\replay-input-spool.py" -ForegroundColor White
Write-Host ""
Write-Host "To start tracker immediately without rebooting:" -ForegroundColor DarkGray
Write-Host "  .\setup-input-tracker.ps1 -StartNow" -ForegroundColor White
Write-Host "  — or —" -ForegroundColor DarkGray
Write-Host "  Start-ScheduledTask -TaskName '$TrackerTask'" -ForegroundColor White
Write-Host ""
