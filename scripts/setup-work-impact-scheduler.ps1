[CmdletBinding()]
param(
    [string]$TaskName = 'AgentLedgerWorkImpactRefresh',
    [int]$EveryMinutes = 15,
    [string]$LedgerRoot
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$script = Join-Path $LedgerRoot 'scripts\update-work-impact.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) {
    $pwsh = (Get-Command powershell -ErrorAction Stop).Source
}

$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Refresh WORK_IMPACT.html incrementally from new ledger events (no git sync).' -Force | Out-Null

Write-Output "Registered scheduled task '$TaskName' to refresh every $EveryMinutes minute(s)."

