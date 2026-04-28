[CmdletBinding()]
param(
    [string]$TaskName = 'AgentLedgerSync',
    [int]$EveryMinutes = 5,
    [string]$LedgerRoot
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$script = Join-Path $LedgerRoot 'scripts\sync-agent-ledger.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) {
    $pwsh = (Get-Command powershell -ErrorAction Stop).Source
}

$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Sync append-only AI agent ledger events to GitHub.' -Force | Out-Null

Write-Output "Registered scheduled task '$TaskName' to sync every $EveryMinutes minute(s)."
