[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [switch]$FullRebuild
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$configPath = Join-Path $LedgerRoot 'work-impact.config.json'
$statePath = Join-Path $LedgerRoot 'work-impact.state.json'

& (Join-Path $LedgerRoot 'scripts\update-work-impact-state.ps1') -LedgerRoot $LedgerRoot -ConfigPath $configPath -StatePath $statePath -FullRebuild:$($FullRebuild.IsPresent) | Out-Null
& (Join-Path $LedgerRoot 'scripts\render-work-impact.ps1') -LedgerRoot $LedgerRoot -StatePath $statePath | Out-Null

Write-Output "Updated WORK_IMPACT.html"
