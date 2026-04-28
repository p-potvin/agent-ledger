[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$ParentChangesPath
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function ConvertTo-MarkdownLine {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ($Value -replace "`r?`n", ' ').Trim()
}

if (-not $ParentChangesPath) {
    $ParentChangesPath = Join-Path (Split-Path $LedgerRoot -Parent) 'CHANGES.md'
}

$eventsRoot = Join-Path $LedgerRoot 'events'
$changesPath = Join-Path $LedgerRoot 'CHANGES.md'

$events = @()
if (Test-Path $eventsRoot) {
    $events = Get-ChildItem -Path $eventsRoot -Recurse -File -Filter '*.json' |
        ForEach-Object {
            try {
                $event = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
                $event | Add-Member -NotePropertyName sourcePath -NotePropertyValue $_.FullName -Force
                $event
            }
            catch {
                Write-Warning "Skipping invalid event file: $($_.FullName)"
            }
        } |
        Sort-Object -Property createdAt -Descending
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Agent Ledger')
$lines.Add('')
$lines.Add('Generated from `agent-ledger/events`. Do not edit by hand; use `agent-ledger/scripts/record-agent-change.ps1`.')
$lines.Add('')

if (-not $events -or $events.Count -eq 0) {
    $lines.Add('_No agent activity has been recorded yet._')
}
else {
    foreach ($event in $events) {
        $project = if ($event.project) { $event.project } else { 'General Tasks' }
        $created = if ($event.createdAtLocal) { $event.createdAtLocal } else { $event.createdAt }
        $kind = if ($event.kind) { $event.kind } else { 'general' }
        $summary = ConvertTo-MarkdownLine $event.summary

        $lines.Add("## $created - $project")
        $lines.Add('')
        $lines.Add("- Kind: $kind")
        if ($event.actor) {
            $lines.Add("- Actor: $($event.actor)")
        }
        if ($summary) {
            $lines.Add("- Summary: $summary")
        }
        if ($event.commands -and $event.commands.Count -gt 0) {
            $lines.Add("- Commands:")
            foreach ($command in $event.commands) {
                $lines.Add("  - ``$(ConvertTo-MarkdownLine $command)``")
            }
        }
        if ($event.files -and $event.files.Count -gt 0) {
            $lines.Add("- Files:")
            foreach ($file in $event.files) {
                $lines.Add("  - ``$(ConvertTo-MarkdownLine $file)``")
            }
        }
        if ($event.planPath) {
            $lines.Add("- Plan: ``$($event.planPath)``")
        }
        if ($event.git) {
            $gitBits = @()
            if ($event.git.repo) { $gitBits += "repo=$($event.git.repo)" }
            if ($event.git.branch) { $gitBits += "branch=$($event.git.branch)" }
            if ($event.git.head) { $gitBits += "head=$($event.git.head)" }
            if ($gitBits.Count -gt 0) {
                $lines.Add("- Git: $($gitBits -join ', ')")
            }
        }
        $lines.Add('')
    }
}

$content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -LiteralPath $changesPath -Value $content -Encoding utf8
Set-Content -LiteralPath $ParentChangesPath -Value $content -Encoding utf8

Write-Output "Rendered $($events.Count) event(s) to:"
Write-Output "  $changesPath"
Write-Output "  $ParentChangesPath"
