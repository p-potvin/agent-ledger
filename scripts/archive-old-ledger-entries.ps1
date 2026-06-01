<#
.SYNOPSIS
    Archives agent-ledger event files older than N days to the history directory.

.DESCRIPTION
    This script maintains the "hot" ledger performance by moving older JSON events
    to a project-root 'history/' directory while preserving the on-disk directory
    structure.

    Rename-aware behavior:
    - If events are stored under a project folder (e.g. events/<project>/YYYY/MM),
      the project folder is normalized via project-aliases.json so renamed projects
      land under their canonical folder name in history/.

    Scheduled to run daily.
#>

[CmdletBinding()]
param(
    [int]$ThresholdDays = 15,
    [string]$LedgerRoot
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$eventsDir = Join-Path $LedgerRoot 'events'
$historyDir = Join-Path $LedgerRoot 'history'
$cutoffDate = (Get-Date).AddDays(-$ThresholdDays)

if (-not (Test-Path -LiteralPath $eventsDir)) {
    throw "Events directory not found: $eventsDir"
}

if (-not (Test-Path -LiteralPath $historyDir)) {
    New-Item -Path $historyDir -ItemType Directory -Force | Out-Null
}

. (Join-Path $PSScriptRoot 'resolve-project-alias.ps1')
$aliasMapPath = Join-Path $LedgerRoot 'project-aliases.json'

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$AliasMapPath
    )

    $relative = $null
    if ($FullPath.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $FullPath.Substring($BasePath.Length).TrimStart('\', '/')
    }
    else {
        $relative = Split-Path -Leaf $FullPath
    }

    if ([string]::IsNullOrWhiteSpace($relative)) { return $relative }

    $parts = $relative -split '[\\/]'
    if ($parts.Count -eq 0) { return $relative }

    # Handle legacy layouts like events/<project>/YYYY/MM/*.json by normalizing the project folder.
    # If the first segment is a year folder, we keep the current behavior (events/YYYY/MM).
    $first = [string]$parts[0]
    if ($first -notmatch '^\d{4}$') {
        $canonical = Resolve-ProjectAlias -Project $first -AliasMapPath $AliasMapPath
        if ($canonical -and $canonical -ne $first) {
            $parts[0] = $canonical
        }
    }

    return ($parts -join '\')
}

# Find all JSON files in events/ older than cutoff
$filesToArchive = Get-ChildItem -Path $eventsDir -Filter '*.json' -Recurse -File |
    Where-Object { $_.LastWriteTime -lt $cutoffDate }

if (-not $filesToArchive -or $filesToArchive.Count -eq 0) {
    Write-Host "No events older than $ThresholdDays days found. Skipping archive."
    exit 0
}

Write-Host "Archiving $($filesToArchive.Count) events (older than $ThresholdDays days)..."

$moved = 0
$skipped = 0

foreach ($file in $filesToArchive) {
    $normalizedRel = Get-NormalizedRelativePath -FullPath $file.FullName -BasePath $eventsDir -AliasMapPath $aliasMapPath
    if ([string]::IsNullOrWhiteSpace($normalizedRel)) {
        $skipped++
        continue
    }

    $targetPath = Join-Path $historyDir $normalizedRel
    $targetDir = Split-Path -Parent $targetPath

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path -LiteralPath $targetPath) {
        Write-Warning "archive-old-ledger-entries: target already exists, skipping: $targetPath"
        $skipped++
        continue
    }

    Move-Item -LiteralPath $file.FullName -Destination $targetPath
    $moved++
}

Write-Host "Archive complete. moved=$moved skipped=$skipped"
