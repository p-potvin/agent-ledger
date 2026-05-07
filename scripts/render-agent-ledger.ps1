[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$ParentChangesPath,
    [string]$ParentHtmlPath
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

function ConvertTo-HtmlText {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return [System.Net.WebUtility]::HtmlEncode((ConvertTo-MarkdownLine $Value))
}

function Limit-Line {
    param(
        [AllowNull()][string]$Value,
        [int]$MaxLength = 180
    )

    $line = ConvertTo-MarkdownLine $Value
    if ($line.Length -le $MaxLength) {
        return $line
    }

    return "$($line.Substring(0, $MaxLength - 3))..."
}

if (-not $ParentChangesPath) {
    $ParentChangesPath = Join-Path (Split-Path $LedgerRoot -Parent) 'CHANGES.md'
}

if (-not $ParentHtmlPath) {
    $ParentHtmlPath = Join-Path (Split-Path $LedgerRoot -Parent) 'CHANGES.html'
}

$eventsRoot = Join-Path $LedgerRoot 'events'
$changesPath = Join-Path $LedgerRoot 'CHANGES.md'
$changesHtmlPath = Join-Path $LedgerRoot 'CHANGES.html'

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
        $summaryPreview = ConvertTo-HtmlText (Limit-Line $event.summary)
        $projectPreview = ConvertTo-HtmlText $project
        $createdPreview = ConvertTo-HtmlText $created
        $kindPreview = ConvertTo-HtmlText $kind

        if ($summaryPreview) {
            $summaryPreview = " - $summaryPreview"
        }

        $lines.Add('<details>')
        $lines.Add("<summary><strong>$createdPreview - $projectPreview</strong> <code>$kindPreview</code>$summaryPreview</summary>")
        $lines.Add('')
        $lines.Add("- Kind: $kind")
        if ($event.actor) {
            $lines.Add("- Actor: $($event.actor)")
        }
        if ($event.agentHeader) {
            $lines.Add("- Agent Header:")
            $lines.Add('  ```text')
            foreach ($headerLine in ("$($event.agentHeader)" -split "`r?`n")) {
                $lines.Add("  $(ConvertTo-MarkdownLine $headerLine)")
            }
            $lines.Add('  ```')
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
        $lines.Add('</details>')
        $lines.Add('')
    }
}

$content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -LiteralPath $changesPath -Value $content -Encoding utf8
Set-Content -LiteralPath $ParentChangesPath -Value $content -Encoding utf8

$htmlLines = New-Object System.Collections.Generic.List[string]
$htmlLines.Add('<!doctype html>')
$htmlLines.Add('<html lang="en">')
$htmlLines.Add('<head>')
$htmlLines.Add('  <meta charset="utf-8">')
$htmlLines.Add('  <meta name="viewport" content="width=device-width, initial-scale=1">')
$htmlLines.Add('  <title>Agent Ledger</title>')
$htmlLines.Add('  <style>')
$htmlLines.Add('    :root { color-scheme: light dark; font-family: "Segoe UI", system-ui, sans-serif; }')
$htmlLines.Add('    body { margin: 0; padding: 32px; background: Canvas; color: CanvasText; }')
$htmlLines.Add('    main { max-width: 1120px; margin: 0 auto; }')
$htmlLines.Add('    h1 { margin: 0 0 8px; font-size: 28px; }')
$htmlLines.Add('    .meta { margin: 0 0 24px; color: color-mix(in srgb, CanvasText 68%, transparent); }')
$htmlLines.Add('    details { border: 1px solid color-mix(in srgb, CanvasText 16%, transparent); border-radius: 8px; margin: 10px 0; background: color-mix(in srgb, Canvas 94%, CanvasText 6%); }')
$htmlLines.Add('    details[open] { background: Canvas; }')
$htmlLines.Add('    summary { cursor: pointer; padding: 12px 14px; line-height: 1.45; }')
$htmlLines.Add('    summary:hover { background: color-mix(in srgb, CanvasText 7%, transparent); }')
$htmlLines.Add('    .entry-body { padding: 0 14px 14px 34px; }')
$htmlLines.Add('    .kind { font-family: Consolas, monospace; font-size: 12px; padding: 2px 6px; border-radius: 999px; background: color-mix(in srgb, CanvasText 11%, transparent); }')
$htmlLines.Add('    .summary { margin: 10px 0; }')
$htmlLines.Add('    code { font-family: Consolas, monospace; font-size: 13px; }')
$htmlLines.Add('    li { margin: 4px 0; }')
$htmlLines.Add('  </style>')
$htmlLines.Add('</head>')
$htmlLines.Add('<body>')
$htmlLines.Add('<main>')
$htmlLines.Add('  <h1>Agent Ledger</h1>')
$htmlLines.Add('  <p class="meta">Generated from <code>agent-ledger/events</code>. Open a row to see commands, files, and details.</p>')

if (-not $events -or $events.Count -eq 0) {
    $htmlLines.Add('  <p>No agent activity has been recorded yet.</p>')
}
else {
    foreach ($event in $events) {
        $project = if ($event.project) { $event.project } else { 'General Tasks' }
        $created = if ($event.createdAtLocal) { $event.createdAtLocal } else { $event.createdAt }
        $kind = if ($event.kind) { $event.kind } else { 'general' }
        $summary = ConvertTo-HtmlText $event.summary
        $summaryPreview = ConvertTo-HtmlText (Limit-Line $event.summary)

        if ($summaryPreview) {
            $summaryPreview = " - $summaryPreview"
        }

        $htmlLines.Add('  <details>')
        $htmlLines.Add("    <summary><strong>$(ConvertTo-HtmlText $created) - $(ConvertTo-HtmlText $project)</strong> <span class=""kind"">$(ConvertTo-HtmlText $kind)</span>$summaryPreview</summary>")
        $htmlLines.Add('    <div class="entry-body">')
        $htmlLines.Add("      <p><strong>Kind:</strong> $(ConvertTo-HtmlText $kind)</p>")
        if ($event.actor) {
            $htmlLines.Add("      <p><strong>Actor:</strong> $(ConvertTo-HtmlText $event.actor)</p>")
        }
        if ($event.agentHeader) {
            $htmlLines.Add('      <p><strong>Agent Header:</strong></p>')
            $htmlLines.Add("      <pre><code>$(ConvertTo-HtmlText $event.agentHeader)</code></pre>")
        }
        if ($summary) {
            $htmlLines.Add("      <p class=""summary""><strong>Summary:</strong> $summary</p>")
        }
        if ($event.commands -and $event.commands.Count -gt 0) {
            $htmlLines.Add('      <p><strong>Commands:</strong></p>')
            $htmlLines.Add('      <ul>')
            foreach ($command in $event.commands) {
                $htmlLines.Add("        <li><code>$(ConvertTo-HtmlText $command)</code></li>")
            }
            $htmlLines.Add('      </ul>')
        }
        if ($event.files -and $event.files.Count -gt 0) {
            $htmlLines.Add('      <p><strong>Files:</strong></p>')
            $htmlLines.Add('      <ul>')
            foreach ($file in $event.files) {
                $htmlLines.Add("        <li><code>$(ConvertTo-HtmlText $file)</code></li>")
            }
            $htmlLines.Add('      </ul>')
        }
        if ($event.planPath) {
            $htmlLines.Add("      <p><strong>Plan:</strong> <code>$(ConvertTo-HtmlText $event.planPath)</code></p>")
        }
        if ($event.git) {
            $gitBits = @()
            if ($event.git.repo) { $gitBits += "repo=$(ConvertTo-HtmlText $event.git.repo)" }
            if ($event.git.branch) { $gitBits += "branch=$(ConvertTo-HtmlText $event.git.branch)" }
            if ($event.git.head) { $gitBits += "head=$(ConvertTo-HtmlText $event.git.head)" }
            if ($gitBits.Count -gt 0) {
                $htmlLines.Add("      <p><strong>Git:</strong> $($gitBits -join ', ')</p>")
            }
        }
        $htmlLines.Add('    </div>')
        $htmlLines.Add('  </details>')
    }
}

$htmlLines.Add('</main>')
$htmlLines.Add('</body>')
$htmlLines.Add('</html>')

$htmlContent = ($htmlLines -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -LiteralPath $changesHtmlPath -Value $htmlContent -Encoding utf8
Set-Content -LiteralPath $ParentHtmlPath -Value $htmlContent -Encoding utf8

Write-Output "Rendered $($events.Count) event(s) to:"
Write-Output "  $changesPath"
Write-Output "  $ParentChangesPath"
Write-Output "  $changesHtmlPath"
Write-Output "  $ParentHtmlPath"

exit 0
