[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$CommitMessage
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

if (-not $CommitMessage) {
    $CommitMessage = "Record agent ledger events $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

Invoke-Git -C $LedgerRoot fetch origin
Invoke-Git -C $LedgerRoot rebase --autostash origin/main
& (Join-Path $LedgerRoot 'scripts\render-agent-ledger.ps1') | Out-Null
& (Join-Path $LedgerRoot 'scripts\render-work-impact.ps1') | Out-Null

$candidatePaths = @(
    'README.md',
    'CHANGES.md',
    'CHANGES.html',
    'WORK_IMPACT.html',
    'work-impact.state.json',
    'work-impact.config.json',
    'project-aliases.json',
    'AGENTS.md',
    'CLAUDE.md',
    '.claude',
    '.github',
    'api',
    'deploy',
    'events',
    'history',
    'scripts',
    'site',
    'stats-app'
)

$pathsToAdd = @($candidatePaths | Where-Object { Test-Path -LiteralPath (Join-Path $LedgerRoot $_) })
if (-not $pathsToAdd -or $pathsToAdd.Count -eq 0) {
    throw "No sync paths found under LedgerRoot: $LedgerRoot"
}

Invoke-Git -C $LedgerRoot add -- @pathsToAdd
$cached = git -C $LedgerRoot diff --cached --name-only
if (-not $cached) {
    Write-Output 'No ledger changes to sync.'
    exit 0
}

Invoke-Git -C $LedgerRoot commit -m $CommitMessage
Invoke-Git -C $LedgerRoot push
Write-Output 'Agent ledger synced.'
