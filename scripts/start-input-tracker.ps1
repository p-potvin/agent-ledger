<#
.SYNOPSIS
    Starts the VaultWares input tracker from Windows Task Scheduler.

.DESCRIPTION
    This wrapper keeps the scheduled task action simple and durable. It loads
    API settings from the user environment, starts the tracker from a stable
    working directory, and appends runtime output to input-state logs.
#>
[CmdletBinding()]
param(
    [string]$PythonExe = "",
    [switch]$NoRestartExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$LedgerRoot = Split-Path $ScriptDir -Parent
$TrackerScript = Join-Path $ScriptDir "track-input.py"
$LauncherScript = [System.IO.Path]::GetFullPath($PSCommandPath)
$StateDir = Join-Path $LedgerRoot "input-state"

if (-not (Test-Path $TrackerScript)) {
    throw "Tracker script not found: $TrackerScript"
}
if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}

$logPath = Join-Path $StateDir ("input-tracker-task-{0}.log" -f (Get-Date -Format "yyyyMMdd"))

function Write-TrackerLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"), $Message
    try {
        Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # The previous long-running wrapper may still hold the log file while
        # we are trying to stop it. Logging must never block the restart path.
    }
}

function Stop-ExistingTrackerProcesses {
    $scriptPath = [System.IO.Path]::GetFullPath($TrackerScript)
    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.CommandLine -and
            (
                $_.CommandLine.IndexOf($scriptPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                $_.CommandLine.IndexOf($LauncherScript, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            )
        }

    foreach ($process in $processes) {
        Write-TrackerLog "Stopping existing tracker process PID $($process.ProcessId) before launch"
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

if (-not $NoRestartExisting) {
    Stop-ExistingTrackerProcesses
}

$apiUrl = [Environment]::GetEnvironmentVariable("VW_API_URL", "User")
if (-not $apiUrl) { $apiUrl = [Environment]::GetEnvironmentVariable("VW_PIPELINES_URL", "User") }
if (-not $apiUrl) { $apiUrl = "http://100.67.25.118:9001" }
$env:VW_API_URL = $apiUrl

$apiKey = [Environment]::GetEnvironmentVariable("VW_TELEMETRY_API_KEY", "User")
if (-not $apiKey) { $apiKey = [Environment]::GetEnvironmentVariable("VW_PIPELINES_API_KEY", "User") }
if ($apiKey) { $env:VW_TELEMETRY_API_KEY = $apiKey }

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
if (-not $pythonResolved) {
    throw "Python not found. Set VW_INPUT_PYTHON_EXE or pass -PythonExe from setup-input-tracker.ps1."
}
if ($pythonResolved -like "*\WindowsApps\*") {
    $pythonCore = Get-ChildItem "$env:LOCALAPPDATA\Python" -Recurse -Filter python.exe -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($pythonCore) { $pythonResolved = $pythonCore.FullName }
}

Set-Location $ScriptDir

& $pythonResolved $TrackerScript *>> $logPath
exit $LASTEXITCODE
