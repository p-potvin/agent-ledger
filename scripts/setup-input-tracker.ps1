<#
.SYNOPSIS
    VaultWares Daily Input Tracker — Setup & Scheduler

.DESCRIPTION
    1. Verifies Python + pip are available
    2. Installs pynput and pyperclip
    3. Registers a Windows Scheduled Task that starts the tracker at every logon
    4. Registers a Windows Scheduled Task that renders the dashboard daily at midnight
    5. Optionally starts the tracker immediately

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
$RenderScript  = Join-Path $ScriptDir "render-daily-dashboard.ps1"
$TrackerTask   = "VaultWares-InputTracker"
$RendererTask  = "VaultWares-DailyDashboard"

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
if (-not (Test-Path $RenderScript)) {
    Write-Warning "Renderer not found at: $RenderScript  (dashboard task will still be registered)"
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

$trackerAction = New-ScheduledTaskAction `
    -Execute    $pythonResolved `
    -Argument   "`"$TrackerScript`"" `
    -WorkingDirectory $ScriptDir

$trackerTrigger  = New-ScheduledTaskTrigger -AtLogOn
$trackerSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  `
    -MultipleInstances  IgnoreNew                `
    -RestartCount       3                        `
    -RestartInterval    (New-TimeSpan -Minutes 1)`
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName   $TrackerTask `
    -Action     $trackerAction `
    -Trigger    $trackerTrigger `
    -Settings   $trackerSettings `
    -RunLevel   Highest `
    -Description "VaultWares: silently tracks keystrokes, mouse movement, saves, and copy/paste events." `
    | Out-Null

Write-Host "  Task '$TrackerTask' registered — starts at every logon." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Register renderer task (runs daily at 00:05)
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Registering scheduled task: $RendererTask ..." -ForegroundColor Yellow

Unregister-ScheduledTask -TaskName $RendererTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$midnight = (Get-Date -Hour 0 -Minute 5 -Second 0).ToString("HH:mm")

$renderAction = New-ScheduledTaskAction `
    -Execute    "powershell.exe" `
    -Argument   "-NonInteractive -WindowStyle Hidden -File `"$RenderScript`" -LedgerRoot `"$LedgerRoot`"" `
    -WorkingDirectory $LedgerRoot

$renderTrigger  = New-ScheduledTaskTrigger -Daily -At $midnight
$renderSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName   $RendererTask `
    -Action     $renderAction `
    -Trigger    $renderTrigger `
    -Settings   $renderSettings `
    -RunLevel   Highest `
    -Description "VaultWares: renders DAILY_DASHBOARD.html from input-logs + agent ledger." `
    | Out-Null

Write-Host "  Task '$RendererTask' registered — runs daily at 00:05." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Optionally start tracker now
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
Write-Host "  Tracker logs  →  $LedgerRoot\input-logs\YYYY-MM-DD.json"
Write-Host "  Dashboard     →  $LedgerRoot\DAILY_DASHBOARD.html"
Write-Host ""
Write-Host "To render the dashboard manually at any time, run:" -ForegroundColor DarkGray
Write-Host "  .\render-daily-dashboard.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To start tracker immediately without rebooting:" -ForegroundColor DarkGray
Write-Host "  .\setup-input-tracker.ps1 -StartNow" -ForegroundColor White
Write-Host "  — or —" -ForegroundColor DarkGray
Write-Host "  Start-ScheduledTask -TaskName '$TrackerTask'" -ForegroundColor White
Write-Host ""
