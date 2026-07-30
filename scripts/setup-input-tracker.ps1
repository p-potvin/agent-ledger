<#
.SYNOPSIS
    VaultWares Daily Input Tracker — Setup & Scheduler

.DESCRIPTION
    1. Verifies Python + pip are available
    2. Installs pynput and pyperclip
    3. Registers a Windows Scheduled Task that starts the tracker at every logon
    4. Optionally starts the tracker immediately

.PARAMETER PythonExe
    Path to python.exe. We deliberately use python.exe (not pythonw.exe) so the
    scheduled task stays attached to the daemon for its full lifetime and shows
    State=Running while the tracker runs. Defaults to the local Python install,
    then python on PATH.

.PARAMETER StartNow
    Switch — if present, starts the tracker task immediately after registration.

.EXAMPLE
    .\setup-input-tracker.ps1 -StartNow
#>
[CmdletBinding()]
param(
    [string]$PythonExe  = "",
    [string]$ApiUrl = "https://api.vaultwares.ca",
    [switch]$StartNow
)

$ErrorActionPreference = "Stop"

$ScriptDir     = Split-Path $MyInvocation.MyCommand.Path -Parent
$LedgerRoot    = Split-Path $ScriptDir -Parent
$TrackerScript = Join-Path $ScriptDir "track-input.py"
$TrackerLauncher = Join-Path $ScriptDir "start-input-tracker.ps1"
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
if (-not (Test-Path $TrackerLauncher)) {
    throw "Tracker launcher not found: $TrackerLauncher"
}
# Resolve pythonw full path. Avoid the WindowsApps shim for scheduled tasks.
$pythonResolved = $null
if ($PythonExe) {
    $pythonCommand = Get-Command $PythonExe -ErrorAction SilentlyContinue
    if ($pythonCommand) { $pythonResolved = $pythonCommand.Source }
    if (-not $pythonResolved -and (Test-Path $PythonExe)) { $pythonResolved = $PythonExe }
}
if (-not $pythonResolved) {
    $pythonCore = Get-ChildItem "$env:LOCALAPPDATA\Python" -Recurse -Filter python.exe -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($pythonCore) { $pythonResolved = $pythonCore.FullName }
}
if (-not $pythonResolved) {
    $pythonCommand = Get-Command "python" -ErrorAction SilentlyContinue
    if ($pythonCommand) { $pythonResolved = $pythonCommand.Source }
}
if ($pythonResolved -like "*\WindowsApps\*") {
    $pythonCore = Get-ChildItem "$env:LOCALAPPDATA\Python" -Recurse -Filter python.exe -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($pythonCore) { $pythonResolved = $pythonCore.FullName }
}
if (-not $pythonResolved) {
    throw "Python not found. Install Python 3.8+ first."
}
Write-Host "Python:  $pythonResolved" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. Install dependencies
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
& $pythonResolved -m pip install --quiet --upgrade pynput pyperclip
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

$taskConhost = (Get-Command "conhost.exe" -ErrorAction Stop).Source
$taskPowerShell = (Get-Command "pwsh.exe" -ErrorAction Stop).Source
[Environment]::SetEnvironmentVariable("VW_API_URL", $ApiUrl, "User")
[Environment]::SetEnvironmentVariable("VW_API_URL", $ApiUrl, "Machine")
$existingKey = $env:VW_TELEMETRY_API_KEY
if (-not $existingKey) { $existingKey = [Environment]::GetEnvironmentVariable("VW_TELEMETRY_API_KEY", "User") }
if ($existingKey) {
    [Environment]::SetEnvironmentVariable("VW_TELEMETRY_API_KEY", $existingKey, "Machine")
}
$trackerAction = New-ScheduledTaskAction `
    -Execute    $taskConhost `
    -Argument   "--headless `"$taskPowerShell`" -NoProfile -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File `"$TrackerLauncher`" -PythonExe `"$pythonResolved`"" `
    -WorkingDirectory $ScriptDir

$trackerTriggerLogon  = New-ScheduledTaskTrigger -AtLogOn
$trackerSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  `
    -MultipleInstances  Parallel                 `
    -RestartCount       99                       `
    -RestartInterval    (New-TimeSpan -Minutes 1)`
    -StartWhenAvailable
$trackerPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

Register-ScheduledTask `
    -TaskName   $TrackerTask `
    -Action     $trackerAction `
    -Trigger    $trackerTriggerLogon `
    -Settings   $trackerSettings `
    -Principal  $trackerPrincipal `
    -Description "VaultWares: silently tracks privacy-safe input metrics and batches them to vaultwares-api. Starts at logon + unlock, restarts automatically on crash." `
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
$apiBase = $env:VW_API_URL
if (-not $apiBase) { $apiBase = $env:VW_PIPELINES_URL }
if (-not $apiBase) { $apiBase = "https://api.vaultwares.ca" }
Write-Host "  API endpoint  →  $apiBase/api/telemetry/input/batches"
Write-Host "  Spool fallback→  $LedgerRoot\input-spool\YYYY-MM-DD.jsonl"
Write-Host ""
Write-Host "Set VW_API_URL and VW_TELEMETRY_API_KEY before starting the task if the defaults do not match this machine." -ForegroundColor DarkGray
Write-Host "Replay failed batches with:" -ForegroundColor DarkGray
Write-Host "  python .\replay-input-spool.py" -ForegroundColor White
Write-Host ""
Write-Host "To start tracker immediately without rebooting:" -ForegroundColor DarkGray
Write-Host "  .\setup-input-tracker.ps1 -StartNow" -ForegroundColor White
Write-Host "  — or —" -ForegroundColor DarkGray
Write-Host "  Start-ScheduledTask -TaskName '$TrackerTask'" -ForegroundColor White
Write-Host ""
