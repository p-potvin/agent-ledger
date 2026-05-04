[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$ParentHtmlPath
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function ConvertTo-OneLine {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return ($Value -replace "`r?`n", ' ').Trim()
}

function Limit-Line {
    param(
        [AllowNull()][string]$Value,
        [int]$MaxLength = 180
    )
    $line = ConvertTo-OneLine $Value
    if ($line.Length -le $MaxLength) { return $line }
    return "$($line.Substring(0, $MaxLength - 3))..."
}

function Safe-ParseUtc {
    param([AllowNull()][string]$Iso)
    if ([string]::IsNullOrWhiteSpace($Iso)) { return $null }
    try {
        return ([datetimeoffset]::Parse($Iso)).UtcDateTime
    }
    catch {
        return $null
    }
}

function To-LocalTime {
    param([datetime]$Utc)
    return [System.TimeZoneInfo]::ConvertTimeFromUtc($Utc, [System.TimeZoneInfo]::Local)
}

if (-not $ParentHtmlPath) {
    $ParentHtmlPath = Join-Path (Split-Path $LedgerRoot -Parent) 'WORK_IMPACT.html'
}

$eventsRoot = Join-Path $LedgerRoot 'events'
$outHtmlPath = Join-Path $LedgerRoot 'WORK_IMPACT.html'

if (-not (Test-Path $eventsRoot)) {
    throw "Events folder not found: $eventsRoot"
}

$excludePathRegex = '(^|/|\\)(node_modules|\.venv|venv|env|vendor|dist|build|target|obj|bin|__pycache__|\.next|\.nuxt|\.turbo|\.cache|coverage)(/|\\|$)|\.(pyc|pyo|class|dll|exe|obj|cache|map)$'

function Get-NumstatForCommit {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Commitish
    )
    $lines = @(& git -C $RepoRoot show --numstat --pretty=format: $Commitish 2>$null)
    return $lines
}

function Add-Count {
    param(
        [hashtable]$Table,
        [string]$Key,
        [int]$Delta = 1
    )
    if (-not $Table.ContainsKey($Key)) { $Table[$Key] = 0 }
    $Table[$Key] = [int]$Table[$Key] + $Delta
}

function Add-StatBucket {
    param(
        [hashtable]$Bucket,
        [int]$Add,
        [int]$Del,
        [int]$FilesDelta
    )
    $Bucket.insertions = [int]$Bucket.insertions + $Add
    $Bucket.deletions = [int]$Bucket.deletions + $Del
    $Bucket.files = [int]$Bucket.files + $FilesDelta
}

function Ensure-ProjectBucket {
    param([hashtable]$Table, [string]$Project)
    if (-not $Table.ContainsKey($Project)) {
        $Table[$Project] = [ordered]@{
            project = $Project
            entries = 0
            firstDay = ''
            lastDay = ''
            kinds = @{}
            recent = New-Object System.Collections.Generic.List[string]
            lineRaw = [ordered]@{ insertions = 0; deletions = 0; files = 0 }
            lineClean = [ordered]@{ insertions = 0; deletions = 0; files = 0 }
            lineExcluded = [ordered]@{ insertions = 0; deletions = 0; files = 0 }
        }
    }
    return $Table[$Project]
}

function Ensure-DayBucket {
    param([hashtable]$Table, [string]$Day)
    if (-not $Table.ContainsKey($Day)) {
        $Table[$Day] = [ordered]@{
            day = $Day
            entries = 0
            projects = New-Object System.Collections.Generic.HashSet[string]
            kinds = @{}
        }
    }
    return $Table[$Day]
}

$events = @()
Get-ChildItem -Path $eventsRoot -Recurse -File -Filter '*.json' |
    ForEach-Object {
        try {
            $e = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
            $e | Add-Member -NotePropertyName sourcePath -NotePropertyValue $_.FullName -Force
            $e
        }
        catch {
            $null
        }
    } |
    Where-Object { $_ } |
    ForEach-Object { $events += $_ }

if (-not $events -or $events.Count -eq 0) {
    throw "No events found under: $eventsRoot"
}

$dayBuckets = @{}
$monthCounts = @{}
$kindCounts = @{}
$projectBuckets = @{}

$minUtc = $null
$maxUtc = $null

# Recompute line stats from commits referenced in backfill summaries.
# We cache per (repoRoot + commit) so a commit is never processed twice even if referenced multiple times.
$commitCache = @{} # key -> [ordered]@{ rawIns, rawDel, cleanIns, cleanDel, exclIns, exclDel, filesRaw, filesClean, filesExcl }
$commitEventsWithStats = 0

foreach ($event in $events) {
    $project = if ($event.project) { [string]$event.project } else { 'General Tasks' }
    $kind = if ($event.kind) { [string]$event.kind } else { 'general' }
    $utc = Safe-ParseUtc ([string]$event.createdAt)
    if (-not $utc) { continue }
    $local = To-LocalTime $utc
    $day = $local.ToString('yyyy-MM-dd')
    $month = $local.ToString('yyyy-MM')

    if (-not $minUtc -or $utc -lt $minUtc) { $minUtc = $utc }
    if (-not $maxUtc -or $utc -gt $maxUtc) { $maxUtc = $utc }

    Add-Count -Table $monthCounts -Key $month -Delta 1
    Add-Count -Table $kindCounts -Key $kind -Delta 1

    $dayBucket = Ensure-DayBucket -Table $dayBuckets -Day $day
    $dayBucket.entries = [int]$dayBucket.entries + 1
    [void]$dayBucket.projects.Add($project)
    Add-Count -Table $dayBucket.kinds -Key $kind -Delta 1

    $projBucket = Ensure-ProjectBucket -Table $projectBuckets -Project $project
    $projBucket.entries = [int]$projBucket.entries + 1
    Add-Count -Table $projBucket.kinds -Key $kind -Delta 1
    if ([string]::IsNullOrWhiteSpace($projBucket.firstDay) -or ($day -lt $projBucket.firstDay)) { $projBucket.firstDay = $day }
    if ([string]::IsNullOrWhiteSpace($projBucket.lastDay) -or ($day -gt $projBucket.lastDay)) { $projBucket.lastDay = $day }

    $summary = ConvertTo-OneLine ([string]$event.summary)
    if ($summary) {
        if ($projBucket.recent.Count -lt 3) {
            $projBucket.recent.Add((Limit-Line $summary 180))
        }
        else {
            # Keep a rolling window of the most recent 3 by event time
            # (events are not guaranteed sorted; we approximate by replacing when the project lastDay matches)
            # For non-technical viewers, exact ordering is not critical here.
            $projBucket.recent.RemoveAt(0)
            $projBucket.recent.Add((Limit-Line $summary 180))
        }
    }

    if ($summary -match 'Backfill:\s*commit\s+([0-9a-fA-F]{7,40})\b') {
        $commitish = $matches[1]
        $repoRoot = $null
        try { $repoRoot = [string]$event.git.root } catch { $repoRoot = $null }
        if ($repoRoot -and (Test-Path $repoRoot)) {
            $cacheKey = "$repoRoot`n$commitish"
            if (-not $commitCache.ContainsKey($cacheKey)) {
                $rawIns = 0; $rawDel = 0
                $cleanIns = 0; $cleanDel = 0
                $exclIns = 0; $exclDel = 0
                $filesRaw = 0; $filesClean = 0; $filesExcl = 0

                $numstat = Get-NumstatForCommit -RepoRoot $repoRoot -Commitish $commitish
                foreach ($line in $numstat) {
                    if (-not $line) { continue }
                    $cols = $line -split "`t"
                    if ($cols.Count -lt 3) { continue }
                    if ($cols[0] -notmatch '^\d+$' -or $cols[1] -notmatch '^\d+$') { continue }

                    $ins = [int]$cols[0]
                    $del = [int]$cols[1]
                    $path = [string]$cols[2]

                    $rawIns += $ins; $rawDel += $del; $filesRaw += 1
                    if ($path -match $excludePathRegex) {
                        $exclIns += $ins; $exclDel += $del; $filesExcl += 1
                    }
                    else {
                        $cleanIns += $ins; $cleanDel += $del; $filesClean += 1
                    }
                }

                $commitCache[$cacheKey] = [ordered]@{
                    rawIns = $rawIns
                    rawDel = $rawDel
                    cleanIns = $cleanIns
                    cleanDel = $cleanDel
                    exclIns = $exclIns
                    exclDel = $exclDel
                    filesRaw = $filesRaw
                    filesClean = $filesClean
                    filesExcl = $filesExcl
                }
            }

            $s = $commitCache[$cacheKey]
            $commitEventsWithStats += 1

            Add-StatBucket -Bucket $projBucket.lineRaw -Add $s.rawIns -Del $s.rawDel -FilesDelta $s.filesRaw
            Add-StatBucket -Bucket $projBucket.lineClean -Add $s.cleanIns -Del $s.cleanDel -FilesDelta $s.filesClean
            Add-StatBucket -Bucket $projBucket.lineExcluded -Add $s.exclIns -Del $s.exclDel -FilesDelta $s.filesExcl
        }
    }
}

# Overall line stats (deduped per commit).
$overallRaw = [ordered]@{ insertions = 0; deletions = 0; files = 0 }
$overallClean = [ordered]@{ insertions = 0; deletions = 0; files = 0 }
$overallExcluded = [ordered]@{ insertions = 0; deletions = 0; files = 0 }

foreach ($k in $commitCache.Keys) {
    $s = $commitCache[$k]
    $overallRaw.insertions += [int]$s.rawIns
    $overallRaw.deletions += [int]$s.rawDel
    $overallRaw.files += [int]$s.filesRaw
    $overallClean.insertions += [int]$s.cleanIns
    $overallClean.deletions += [int]$s.cleanDel
    $overallClean.files += [int]$s.filesClean
    $overallExcluded.insertions += [int]$s.exclIns
    $overallExcluded.deletions += [int]$s.exclDel
    $overallExcluded.files += [int]$s.filesExcl
}

$projects = $projectBuckets.Values | Sort-Object -Property entries -Descending
$kinds = $kindCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { [pscustomobject]@{ kind = $_.Key; count = $_.Value } }
$months = $monthCounts.GetEnumerator() | Sort-Object -Property Key | ForEach-Object { [pscustomobject]@{ month = $_.Key; count = $_.Value } }
$days = $dayBuckets.Values | Sort-Object -Property day

$activeDays = ($dayBuckets.Keys | Measure-Object).Count
$projectCount = ($projectBuckets.Keys | Measure-Object).Count
$totalEvents = $events.Count
$rangeStart = (To-LocalTime $minUtc).ToString('yyyy-MM-dd')
$rangeEnd = (To-LocalTime $maxUtc).ToString('yyyy-MM-dd')

$data = [ordered]@{
    generatedAtLocal = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    range = [ordered]@{ start = $rangeStart; end = $rangeEnd }
    totals = [ordered]@{
        events = $totalEvents
        projects = $projectCount
        activeDays = $activeDays
        commitEventsWithStats = $commitEventsWithStats
        uniqueCommitsRecomputed = $commitCache.Count
    }
    lineStats = [ordered]@{
        raw = $overallRaw
        clean = $overallClean
        excluded = $overallExcluded
    }
    series = [ordered]@{
        months = $months
        days = $days | ForEach-Object {
            [ordered]@{
                day = $_.day
                entries = $_.entries
                projects = ($_.projects | Sort-Object)
                kinds = $_.kinds
            }
        }
        kinds = $kinds
        projects = $projects | ForEach-Object {
            [ordered]@{
                project = $_.project
                entries = $_.entries
                firstDay = $_.firstDay
                lastDay = $_.lastDay
                kinds = $_.kinds
                recent = @($_.recent)
                lineRaw = $_.lineRaw
                lineClean = $_.lineClean
                lineExcluded = $_.lineExcluded
            }
        }
    }
    exclusions = [ordered]@{
        pathRegex = $excludePathRegex
        notes = @(
            'Line stats are recomputed from git commits referenced by Backfill events.',
            'Clean stats exclude common dependency/build/cache/generated folders (regex above).'
        )
    }
}

$json = $data | ConvertTo-Json -Depth 10 -Compress

function HtmlEncode([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }

$html = @()
$html += '<!doctype html>'
$html += '<html lang="en">'
$html += '<head>'
$html += '  <meta charset="utf-8">'
$html += '  <meta name="viewport" content="width=device-width, initial-scale=1">'
$html += '  <title>Work Impact / Impact du travail</title>'
$html += '  <style>'
$html += '    :root {'
$html += '      color-scheme: light dark;'
$html += '      --bg: Canvas;'
$html += '      --fg: CanvasText;'
$html += '      --muted: color-mix(in srgb, CanvasText 62%, transparent);'
$html += '      --border: color-mix(in srgb, CanvasText 16%, transparent);'
$html += '      --card: color-mix(in srgb, Canvas 94%, CanvasText 6%);'
$html += '      --chip: color-mix(in srgb, CanvasText 11%, transparent);'
$html += '      --accent: #1f6feb;'
$html += '      --good0: color-mix(in srgb, CanvasText 10%, transparent);'
$html += '      --good1: #0e4429;'
$html += '      --good2: #006d32;'
$html += '      --good3: #26a641;'
$html += '      --good4: #39d353;'
$html += '    }'
$html += '    @media (prefers-color-scheme: light) {'
$html += '      :root {'
$html += '        --good0: #ebedf0;'
$html += '        --good1: #9be9a8;'
$html += '        --good2: #40c463;'
$html += '        --good3: #30a14e;'
$html += '        --good4: #216e39;'
$html += '      }'
$html += '    }'
$html += '    body { margin: 0; font-family: "Segoe UI", system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--fg); }'
$html += '    main { max-width: 1120px; margin: 0 auto; padding: 28px 18px 64px; }'
$html += '    header { display:flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }'
$html += '    h1 { font-size: 24px; margin: 0; letter-spacing: 0; }'
$html += '    .meta { margin: 8px 0 0; color: var(--muted); font-size: 13px; }'
$html += '    .lang { display:flex; gap: 8px; align-items: center; }'
$html += '    .toggle { display:inline-flex; border: 1px solid var(--border); border-radius: 999px; overflow:hidden; }'
$html += '    .toggle button { appearance:none; border:0; padding: 8px 10px; cursor:pointer; background: transparent; color: var(--fg); font-size: 13px; }'
$html += '    .toggle button[aria-pressed="true"] { background: var(--chip); }'
$html += '    section { margin-top: 22px; }'
$html += '    .grid { display:grid; gap: 12px; grid-template-columns: repeat(12, 1fr); }'
$html += '    .card { border: 1px solid var(--border); background: var(--card); border-radius: 8px; padding: 12px 12px; }'
$html += '    .card h2 { margin: 0 0 8px; font-size: 14px; color: var(--muted); font-weight: 600; }'
$html += '    .big { font-size: 22px; font-weight: 700; }'
$html += '    .sub { margin-top: 4px; font-size: 12px; color: var(--muted); }'
$html += '    .span4 { grid-column: span 4; }'
$html += '    .span6 { grid-column: span 6; }'
$html += '    .span12 { grid-column: span 12; }'
$html += '    @media (max-width: 920px) { .span4, .span6 { grid-column: span 12; } }'
$html += '    .kicker { margin: 10px 0 0; font-size: 14px; color: var(--fg); }'
$html += '    .quiet { color: var(--muted); }'
$html += '    .row { display:flex; gap: 10px; align-items: center; justify-content: space-between; flex-wrap: wrap; }'
$html += '    .barlist { display:flex; flex-direction: column; gap: 8px; }'
$html += '    .bar { display:flex; align-items:center; gap: 10px; }'
$html += '    .bar label { width: 160px; font-size: 12px; color: var(--fg); overflow:hidden; text-overflow: ellipsis; white-space: nowrap; }'
$html += '    .bar .track { flex: 1; height: 10px; border-radius: 999px; background: color-mix(in srgb, CanvasText 10%, transparent); overflow:hidden; }'
$html += '    .bar .fill { height: 100%; background: var(--accent); }'
$html += '    .bar .n { width: 70px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; }'
$html += '    details { border: 1px solid var(--border); border-radius: 8px; background: var(--card); }'
$html += '    summary { cursor: pointer; padding: 12px 14px; line-height: 1.35; }'
$html += '    summary strong { font-size: 13px; }'
$html += '    .detailsBody { padding: 0 14px 14px; }'
$html += '    table { width: 100%; border-collapse: collapse; font-size: 12px; }'
$html += '    th, td { text-align:left; padding: 8px 6px; border-bottom: 1px solid var(--border); vertical-align: top; }'
$html += '    th { color: var(--muted); font-weight: 600; }'
$html += '    code { font-family: Consolas, monospace; font-size: 12px; }'
$html += '    .pill { display:inline-block; padding: 2px 8px; border-radius: 999px; background: var(--chip); font-size: 12px; color: var(--fg); }'
$html += '    .heatWrap { overflow-x: auto; }'
$html += '    .heat { display: grid; grid-auto-flow: column; grid-auto-columns: 12px; gap: 3px; align-items: start; padding: 8px 6px 2px; }'
$html += '    .heatCol { display:grid; grid-template-rows: repeat(7, 12px); gap: 3px; }'
$html += '    .cell { width: 12px; height: 12px; border-radius: 3px; background: var(--good0); border: 1px solid color-mix(in srgb, CanvasText 10%, transparent); cursor: default; }'
$html += '    .lvl1 { background: var(--good1); border-color: transparent; }'
$html += '    .lvl2 { background: var(--good2); border-color: transparent; }'
$html += '    .lvl3 { background: var(--good3); border-color: transparent; }'
$html += '    .lvl4 { background: var(--good4); border-color: transparent; }'
$html += '    .heatLegend { display:flex; gap: 8px; align-items:center; justify-content:flex-end; font-size: 12px; color: var(--muted); padding: 0 6px 10px; }'
$html += '    .legendSwatch { display:flex; gap: 3px; align-items:center; }'
$html += '    .tooltip { position: fixed; z-index: 50; pointer-events:none; background: color-mix(in srgb, Canvas 90%, CanvasText 10%); border: 1px solid var(--border); border-radius: 8px; padding: 10px 10px; max-width: 320px; box-shadow: 0 10px 30px rgba(0,0,0,.25); display:none; }'
$html += '    .tooltip .t { font-size: 12px; color: var(--fg); }'
$html += '    .tooltip .m { margin-top: 4px; font-size: 12px; color: var(--muted); }'
$html += '  </style>'
$html += '</head>'
$html += '<body>'
$html += '<main>'
$html += '  <header>'
$html += '    <div>'
$html += '      <h1 data-i18n="title">Work Impact</h1>'
$html += '      <div class="meta"><span data-i18n="generated">Generated</span>: ' + (HtmlEncode $data.generatedAtLocal) + ' · <span data-i18n="range">Range</span>: ' + (HtmlEncode $rangeStart) + ' → ' + (HtmlEncode $rangeEnd) + '</div>'
$html += '    </div>'
$html += '    <div class="lang">'
$html += '      <span class="pill" data-i18n="langLabel">Language</span>'
$html += '      <div class="toggle" role="group" aria-label="Language toggle">'
$html += '        <button type="button" id="lang-en" aria-pressed="true">EN</button>'
$html += '        <button type="button" id="lang-fr" aria-pressed="false">FR</button>'
$html += '      </div>'
$html += '    </div>'
$html += '  </header>'
$html += ''
$html += '  <p class="kicker" data-i18n="intro">'
$html += '    This report turns your agent ledger into plain-language visuals: how often you worked, how many projects you touched, and how the effort changed over time.'
$html += '  </p>'
$html += ''
$html += '  <section class="grid">'
$html += '    <div class="card span4"><h2 data-i18n="metricEvents">Work entries</h2><div class="big" id="m-events"></div><div class="sub" id="m-events-sub"></div></div>'
$html += '    <div class="card span4"><h2 data-i18n="metricDays">Active days</h2><div class="big" id="m-days"></div><div class="sub" data-i18n="metricDaysSub">Days with at least one recorded work entry</div></div>'
$html += '    <div class="card span4"><h2 data-i18n="metricProjects">Projects touched</h2><div class="big" id="m-projects"></div><div class="sub" data-i18n="metricProjectsSub">Distinct repos/projects with activity</div></div>'
$html += '    <div class="card span12">'
$html += '      <div class="row"><h2 style="margin:0" data-i18n="calendarTitle">Work activity by day</h2><div class="heatLegend"><span data-i18n="less">Less</span><span class="legendSwatch"><span class="cell"></span><span class="cell lvl1"></span><span class="cell lvl2"></span><span class="cell lvl3"></span><span class="cell lvl4"></span></span><span data-i18n="more">More</span></div></div>'
$html += '      <div class="quiet" style="font-size:12px;margin-top:6px" data-i18n="calendarHint">Hover a square to see that day''s activity.</div>'
$html += '      <div class="heatWrap"><div class="heat" id="heat"></div></div>'
$html += '    </div>'
$html += '  </section>'
$html += ''
$html += '  <section class="grid">'
$html += '    <div class="card span6">'
$html += '      <h2 data-i18n="monthlyTitle">Work recorded per month</h2>'
$html += '      <div class="barlist" id="monthlyBars"></div>'
$html += '    </div>'
$html += '    <div class="card span6">'
$html += '      <h2 data-i18n="kindsTitle">What kind of work it was</h2>'
$html += '      <div class="barlist" id="kindBars"></div>'
$html += '    </div>'
$html += '  </section>'
$html += ''
$html += '  <section class="grid">'
$html += '    <div class="card span6">'
$html += '      <h2 data-i18n="projectsTitle">Projects with the most activity</h2>'
$html += '      <div class="barlist" id="projectBars"></div>'
$html += '      <div class="sub"><span data-i18n="projectsNote">Raw repo names are shown.</span></div>'
$html += '    </div>'
$html += '    <div class="card span6">'
$html += '      <h2 data-i18n="volumeTitle">Technical volume handled (estimate)</h2>'
$html += '      <div class="big" id="m-lines"></div>'
$html += '      <div class="sub" id="m-lines-sub"></div>'
$html += '      <div class="sub" style="margin-top:10px" data-i18n="volumeCaveat">This is an imperfect proxy: it counts lines changed in git commits and is shown mainly to convey scale.</div>'
$html += '      <details style="margin-top:10px"><summary><strong data-i18n="volumeDetails">Details</strong></summary><div class="detailsBody">'
$html += '        <p class="quiet" style="margin:8px 0 10px;font-size:12px" data-i18n="volumeExplain">Clean numbers exclude common dependency/build/cache/generated folders.</p>'
$html += '        <table><thead><tr><th data-i18n="statType">Metric</th><th data-i18n="statAdds">Additions</th><th data-i18n="statDels">Deletions</th><th data-i18n="statFiles">Files</th></tr></thead>'
$html += '        <tbody id="lineStatsRows"></tbody></table>'
$html += '        <p class="quiet" style="margin:10px 0 0;font-size:12px"><span data-i18n="commitStats">Commit stats recomputed</span>: ' + (HtmlEncode ([string]$data.totals.uniqueCommitsRecomputed)) + ' · <span data-i18n="eventsWithCommits">events with commits</span>: ' + (HtmlEncode ([string]$data.totals.commitEventsWithStats)) + '</p>'
$html += '      </div></details>'
$html += '    </div>'
$html += '  </section>'
$html += ''
$html += '  <section>'
$html += '    <details open>'
$html += '      <summary><strong data-i18n="evidenceTitle">Evidence by project</strong> <span class="quiet" data-i18n="evidenceHint">Expand a row to see examples.</span></summary>'
$html += '      <div class="detailsBody">'
$html += '        <table>'
$html += '          <thead><tr><th data-i18n="colProject">Project</th><th data-i18n="colEntries">Entries</th><th data-i18n="colFirst">First</th><th data-i18n="colLast">Last</th><th data-i18n="colExamples">Examples</th></tr></thead>'
$html += '          <tbody id="projectTable"></tbody>'
$html += '        </table>'
$html += '      </div>'
$html += '    </details>'
$html += '  </section>'
$html += ''
$html += '  <div class="tooltip" id="tip"><div class="t" id="tipT"></div><div class="m" id="tipM"></div></div>'
$html += ''
$html += '  <script id="data" type="application/json">' + $json + '</script>'
$html += '  <script>'
$html += '  (function(){'
$html += '    const data = JSON.parse(document.getElementById("data").textContent);'
$html += '    const i18n = {'
$html += '      en: {'
$html += '        title: "Work Impact",'
$html += '        generated: "Generated",'
$html += '        range: "Range",'
$html += '        langLabel: "Language",'
$html += '        intro: "This report turns your agent ledger into plain-language visuals: how often you worked, how many projects you touched, and how the effort changed over time.",'
$html += '        metricEvents: "Work entries",'
$html += '        metricDays: "Active days",'
$html += '        metricDaysSub: "Days with at least one recorded work entry",'
$html += '        metricProjects: "Projects touched",'
$html += '        metricProjectsSub: "Distinct repos/projects with activity",'
$html += '        calendarTitle: "Work activity by day",'
$html += '        calendarHint: "Hover a square to see that day''s activity.",'
$html += '        less: "Less",'
$html += '        more: "More",'
$html += '        monthlyTitle: "Work recorded per month",'
$html += '        kindsTitle: "What kind of work it was",'
$html += '        projectsTitle: "Projects with the most activity",'
$html += '        projectsNote: "Raw repo names are shown.",'
$html += '        volumeTitle: "Technical volume handled (estimate)",'
$html += '        volumeCaveat: "This is an imperfect proxy: it counts lines changed in git commits and is shown mainly to convey scale.",'
$html += '        volumeDetails: "Details",'
$html += '        volumeExplain: "Clean numbers exclude common dependency/build/cache/generated folders.",'
$html += '        statType: "Metric", statAdds: "Additions", statDels: "Deletions", statFiles: "Files",'
$html += '        commitStats: "Unique commits recomputed",'
$html += '        eventsWithCommits: "events referencing commits",'
$html += '        evidenceTitle: "Evidence by project",'
$html += '        evidenceHint: "Expand a row to see examples.",'
$html += '        colProject: "Project", colEntries: "Entries", colFirst: "First", colLast: "Last", colExamples: "Examples",'
$html += '        kindLabels: {'
$html += '          "code-change": "Built or changed things",'
$html += '          "plan": "Planning",'
$html += '          "verification": "Checked the work",'
$html += '          "commands": "Operations run",'
$html += '          "handoff": "Handovers",'
$html += '          "general": "Other"'
$html += '        }'
$html += '      },'
$html += '      fr: {'
$html += '        title: "Impact du travail",'
$html += '        generated: "Genere",'
$html += '        range: "Periode",'
$html += '        langLabel: "Langue",'
$html += '        intro: "Ce rapport transforme votre agent ledger en visuels faciles a comprendre : a quelle frequence vous avez travaille, combien de projets vous avez touches, et comment l effort evolue dans le temps.",'
$html += '        metricEvents: "Entrees de travail",'
$html += '        metricDays: "Jours actifs",'
$html += '        metricDaysSub: "Jours avec au moins une entree de travail",'
$html += '        metricProjects: "Projets touches",'
$html += '        metricProjectsSub: "Repos/projets distincts avec activite",'
$html += '        calendarTitle: "Activite de travail par jour",'
$html += '        calendarHint: "Survolez un carre pour voir l activite de ce jour.",'
$html += '        less: "Moins",'
$html += '        more: "Plus",'
$html += '        monthlyTitle: "Travail enregistre par mois",'
$html += '        kindsTitle: "Type de travail",'
$html += '        projectsTitle: "Projets avec le plus d activite",'
$html += '        projectsNote: "Les noms de repos bruts sont affiches.",'
$html += '        volumeTitle: "Volume technique traite (estimation)",'
$html += '        volumeCaveat: "C est un indicateur imparfait : il compte les lignes modifiees dans les commits git et sert surtout a montrer l ampleur.",'
$html += '        volumeDetails: "Details",'
$html += '        volumeExplain: "Les chiffres propres excluent des dossiers frequents de dependances/build/cache/genere.",'
$html += '        statType: "Mesure", statAdds: "Ajouts", statDels: "Suppressions", statFiles: "Fichiers",'
$html += '        commitStats: "Commits uniques recalcules",'
$html += '        eventsWithCommits: "entrees qui referencent des commits",'
$html += '        evidenceTitle: "Preuves par projet",'
$html += '        evidenceHint: "Ouvrez une ligne pour voir des exemples.",'
$html += '        colProject: "Projet", colEntries: "Entrees", colFirst: "Debut", colLast: "Fin", colExamples: "Exemples",'
$html += '        kindLabels: {'
$html += '          "code-change": "Construit ou modifie",'
$html += '          "plan": "Planification",'
$html += '          "verification": "Verification",'
$html += '          "commands": "Operations",'
$html += '          "handoff": "Passation",'
$html += '          "general": "Autre"'
$html += '        }'
$html += '      }'
$html += '    };'
$html += ''
$html += '    const fmtInt = (n) => (n||0).toLocaleString(undefined);'
$html += '    const fmtSigned = (n) => (n>=0?"+":"") + (n||0).toLocaleString(undefined);'
$html += '    const getLangDefault = () => {'
$html += '      const saved = localStorage.getItem("workImpactLang");'
$html += '      if(saved==="en"||saved==="fr") return saved;'
$html += '      const nav = (navigator.language||"en").toLowerCase();'
$html += '      return nav.startsWith("fr") ? "fr" : "en";'
$html += '    };'
$html += ''
$html += '    let lang = getLangDefault();'
$html += '    const applyI18n = () => {'
$html += '      const dict = i18n[lang];'
$html += '      document.querySelectorAll("[data-i18n]").forEach(el => {'
$html += '        const k = el.getAttribute("data-i18n");'
$html += '        if(dict[k]) el.textContent = dict[k];'
$html += '      });'
$html += '      document.getElementById("lang-en").setAttribute("aria-pressed", lang==="en");'
$html += '      document.getElementById("lang-fr").setAttribute("aria-pressed", lang==="fr");'
$html += '      document.documentElement.lang = lang;'
$html += '      renderBars();'
$html += '    };'
$html += ''
$html += '    document.getElementById("lang-en").addEventListener("click", () => { lang="en"; localStorage.setItem("workImpactLang","en"); applyI18n(); });'
$html += '    document.getElementById("lang-fr").addEventListener("click", () => { lang="fr"; localStorage.setItem("workImpactLang","fr"); applyI18n(); });'
$html += ''
$html += '    // Metrics'
$html += '    document.getElementById("m-events").textContent = fmtInt(data.totals.events);'
$html += '    document.getElementById("m-events-sub").textContent = `${fmtInt(data.totals.commitEventsWithStats)} entries include per-commit stats`;'
$html += '    document.getElementById("m-days").textContent = fmtInt(data.totals.activeDays);'
$html += '    document.getElementById("m-projects").textContent = fmtInt(data.totals.projects);'
$html += ''
$html += '    // Lines (clean)'
$html += '    const clean = data.lineStats.clean;'
$html += '    const raw = data.lineStats.raw;'
$html += '    const excl = data.lineStats.excluded;'
$html += '    const cleanNet = (clean.insertions||0) - (clean.deletions||0);'
$html += '    document.getElementById("m-lines").textContent = `${fmtSigned(cleanNet)} net lines`;'
$html += '    document.getElementById("m-lines-sub").textContent = `${fmtInt(clean.insertions)} additions, ${fmtInt(clean.deletions)} deletions (cleaned)`;'
$html += ''
$html += '    const lineRows = document.getElementById("lineStatsRows");'
$html += '    const renderLineRows = () => {'
$html += '      lineRows.innerHTML = "";'
$html += '      if(lang==="fr"){'
$html += '        addLineRow("Propre (recommande)", clean);'
$html += '        addLineRow("Brut (tous fichiers suivis)", raw);'
$html += '        addLineRow("Exclus (deps/build/cache)", excl);'
$html += '      } else {'
$html += '        addLineRow("Clean (recommended)", clean);'
$html += '        addLineRow("Raw (all tracked files)", raw);'
$html += '        addLineRow("Excluded (deps/build/cache)", excl);'
$html += '      }'
$html += '    };'
$html += '    const addLineRow = (label, s) => {'
$html += '      const tr = document.createElement("tr");'
$html += '      tr.innerHTML = `<td>${label}</td><td>${fmtInt(s.insertions)}</td><td>${fmtInt(s.deletions)}</td><td>${fmtInt(s.files)}</td>`;'
$html += '      lineRows.appendChild(tr);'
$html += '    };'
$html += '    renderLineRows();'
$html += ''
$html += '    // Heatmap'
$html += '    const tip = document.getElementById("tip");'
$html += '    const tipT = document.getElementById("tipT");'
$html += '    const tipM = document.getElementById("tipM");'
$html += '    const dayMap = new Map(data.series.days.map(d => [d.day, d]));'
$html += '    const start = new Date(data.range.start + "T00:00:00");'
$html += '    const end = new Date(data.range.end + "T00:00:00");'
$html += '    // Align start to Sunday for GitHub-like columns'
$html += '    const startAligned = new Date(start);'
$html += '    startAligned.setDate(startAligned.getDate() - startAligned.getDay());'
$html += '    const endAligned = new Date(end);'
$html += '    endAligned.setDate(endAligned.getDate() + (6 - endAligned.getDay()));'
$html += '    const daysTotal = Math.round((endAligned - startAligned) / 86400000) + 1;'
$html += '    const weeks = Math.ceil(daysTotal / 7);'
$html += ''
$html += '    const counts = [];'
$html += '    for(let i=0;i<daysTotal;i++){'
$html += '      const d = new Date(startAligned); d.setDate(d.getDate()+i);'
$html += '      const key = d.toISOString().slice(0,10);'
$html += '      counts.push(dayMap.has(key) ? (dayMap.get(key).entries||0) : 0);'
$html += '    }'
$html += '    const nonZero = counts.filter(x => x>0).sort((a,b)=>a-b);'
$html += '    const q = (p)=> nonZero.length? nonZero[Math.floor((nonZero.length-1)*p)] : 0;'
$html += '    const t1=q(0.25), t2=q(0.5), t3=q(0.75);'
$html += ''
$html += '    const levelFor = (c)=>{'
$html += '      if(!c) return 0;'
$html += '      if(c<=t1) return 1;'
$html += '      if(c<=t2) return 2;'
$html += '      if(c<=t3) return 3;'
$html += '      return 4;'
$html += '    };'
$html += ''
$html += '    const heat = document.getElementById("heat");'
$html += '    for(let w=0; w<weeks; w++){'
$html += '      const col = document.createElement("div");'
$html += '      col.className = "heatCol";'
$html += '      for(let dow=0; dow<7; dow++){'
$html += '        const i = w*7 + dow;'
$html += '        const d = new Date(startAligned); d.setDate(d.getDate()+i);'
$html += '        const key = d.toISOString().slice(0,10);'
$html += '        const c = (i < counts.length) ? counts[i] : 0;'
$html += '        const lvl = levelFor(c);'
$html += '        const cell = document.createElement("div");'
$html += '        cell.className = "cell" + (lvl?(" lvl"+lvl):"");'
$html += '        cell.dataset.day = key;'
$html += '        cell.dataset.count = c;'
$html += '        cell.addEventListener("mouseenter", (ev)=>{'
$html += '          const rec = dayMap.get(key);'
$html += '          const projects = rec ? (rec.projects||[]) : [];'
$html += '          if(lang==="fr"){'
$html += '            tipT.textContent = `${key} · ${fmtInt(c)} entrees`;'
$html += '            tipM.textContent = projects.length ? `${fmtInt(projects.length)} projets: ${projects.slice(0,4).join(", ")}${projects.length>4?"…":""}` : "Aucune activite enregistree";'
$html += '          } else {'
$html += '            tipT.textContent = `${key} · ${fmtInt(c)} entries`;'
$html += '            tipM.textContent = projects.length ? `${fmtInt(projects.length)} projects: ${projects.slice(0,4).join(", ")}${projects.length>4?"…":""}` : "No recorded activity";'
$html += '          }'
$html += '          tip.style.display = "block";'
$html += '        });'
$html += '        cell.addEventListener("mousemove", (ev)=>{'
$html += '          const x = Math.min(window.innerWidth - 20, ev.clientX + 14);'
$html += '          const y = Math.min(window.innerHeight - 20, ev.clientY + 14);'
$html += '          tip.style.left = x + "px";'
$html += '          tip.style.top = y + "px";'
$html += '        });'
$html += '        cell.addEventListener("mouseleave", ()=>{ tip.style.display = "none"; });'
$html += '        col.appendChild(cell);'
$html += '      }'
$html += '      heat.appendChild(col);'
$html += '    }'
$html += ''
$html += '    // Bars'
$html += '    const maxOf = (arr)=> arr.reduce((m,x)=>Math.max(m,x.count||0),0);'
$html += '    const makeBar = (label, count, max, container)=>{'
$html += '      const row = document.createElement("div"); row.className = "bar";'
$html += '      const lab = document.createElement("label"); lab.title = label; lab.textContent = label;'
$html += '      const track = document.createElement("div"); track.className = "track";'
$html += '      const fill = document.createElement("div"); fill.className = "fill";'
$html += '      fill.style.width = (max? (count/max*100):0).toFixed(2) + "%";'
$html += '      track.appendChild(fill);'
$html += '      const n = document.createElement("div"); n.className = "n"; n.textContent = fmtInt(count);'
$html += '      row.appendChild(lab); row.appendChild(track); row.appendChild(n);'
$html += '      container.appendChild(row);'
$html += '    };'
$html += ''
$html += '    function renderBars(){'
$html += '      const dict = i18n[lang];'
$html += '      // monthly'
$html += '      const m = document.getElementById("monthlyBars"); m.innerHTML="";'
$html += '      const months = data.series.months.slice(-18);'
$html += '      const mmax = Math.max(1, ...months.map(x=>x.count));'
$html += '      months.forEach(x=> makeBar(x.month, x.count, mmax, m));'
$html += '      // kinds'
$html += '      const k = document.getElementById("kindBars"); k.innerHTML="";'
$html += '      const kinds = data.series.kinds;'
$html += '      const kmax = Math.max(1, ...kinds.map(x=>x.count));'
$html += '      kinds.forEach(x=>{'
$html += '        const label = dict.kindLabels[x.kind] || x.kind;'
$html += '        makeBar(label, x.count, kmax, k);'
$html += '      });'
$html += '      // projects'
$html += '      const p = document.getElementById("projectBars"); p.innerHTML="";'
$html += '      const projects = data.series.projects.slice(0,12).map(x=>({label:x.project, count:x.entries}));'
$html += '      const pmax = Math.max(1, ...projects.map(x=>x.count));'
$html += '      projects.forEach(x=> makeBar(x.label, x.count, pmax, p));'
$html += '    }'
$html += ''
$html += '    // Project table'
$html += '    const pt = document.getElementById("projectTable");'
$html += '    data.series.projects.forEach(p => {'
$html += '      const tr = document.createElement("tr");'
$html += '      const ex = (p.recent||[]).map(s=>`• ${s}`).join("\\n");'
$html += '      tr.innerHTML = `<td><code>${p.project}</code></td><td>${fmtInt(p.entries)}</td><td>${p.firstDay||""}</td><td>${p.lastDay||""}</td><td><pre style="margin:0;white-space:pre-wrap;font-family:inherit">${ex}</pre></td>`;'
$html += '      pt.appendChild(tr);'
$html += '    });'
$html += ''
$html += '    // Localize one dynamic string for events-sub'
$html += '    const updateDynamicStrings = () => {'
$html += '      const n = fmtInt(data.totals.commitEventsWithStats);'
$html += '      if(lang==="fr"){'
$html += '        document.getElementById("m-events-sub").textContent = `${n} entrees incluent des stats par commit`;'
$html += '        document.getElementById("m-lines").textContent = `${fmtSigned(cleanNet)} lignes nettes`;'
$html += '        document.getElementById("m-lines-sub").textContent = `${fmtInt(clean.insertions)} ajouts, ${fmtInt(clean.deletions)} suppressions (propre)`;'
$html += '      } else {'
$html += '        document.getElementById("m-events-sub").textContent = `${n} entries include per-commit stats`;'
$html += '        document.getElementById("m-lines").textContent = `${fmtSigned(cleanNet)} net lines`;'
$html += '        document.getElementById("m-lines-sub").textContent = `${fmtInt(clean.insertions)} additions, ${fmtInt(clean.deletions)} deletions (cleaned)`;'
$html += '      }'
$html += '      renderLineRows();'
$html += '    };'
$html += ''
$html += '    const applyAndUpdate = () => { applyI18n(); updateDynamicStrings(); };'
$html += '    // Patch toggles to refresh dynamic strings'
$html += '    document.getElementById("lang-en").addEventListener("click", () => { setTimeout(updateDynamicStrings, 0); });'
$html += '    document.getElementById("lang-fr").addEventListener("click", () => { setTimeout(updateDynamicStrings, 0); });'
$html += '    applyAndUpdate();'
$html += '  })();'
$html += '  </script>'
$html += '</main>'
$html += '</body>'
$html += '</html>'

$content = ($html -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -LiteralPath $outHtmlPath -Value $content -Encoding utf8
Set-Content -LiteralPath $ParentHtmlPath -Value $content -Encoding utf8

Write-Output "Rendered work impact to:"
Write-Output "  $outHtmlPath"
Write-Output "  $ParentHtmlPath"
