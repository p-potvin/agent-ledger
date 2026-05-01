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

Invoke-Git -C $LedgerRoot add README.md CHANGES.md CHANGES.html events scripts AGENTS.md AGENT_LEDGER_INSTRUCTIONS.md .github
$cached = git -C $LedgerRoot diff --cached --name-only
if (-not $cached) {
    Write-Output 'No ledger changes to sync.'
    exit 0
}

Invoke-Git -C $LedgerRoot commit -m $CommitMessage
Invoke-Git -C $LedgerRoot push
Write-Output 'Agent ledger synced.'
