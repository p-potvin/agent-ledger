[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$ConfigPath,
    [string]$StatePath,
    [switch]$FullRebuild
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $LedgerRoot 'work-impact.config.json'
}

if (-not $StatePath) {
    $StatePath = Join-Path $LedgerRoot 'work-impact.state.json'
}

. (Join-Path $PSScriptRoot 'resolve-project-alias.ps1')
$aliasMapPath = Join-Path $LedgerRoot 'project-aliases.json'

function Normalize-RawProjectName {
    param([string]$Name)
    # Drop entries that are clearly meta/junk (contain encoded unicode, "SSOT", "Phase 5", etc.)
    if ($Name -match 'Ã|Phase \d|SSOT|Cleanup & Infrastructure|System Verification') {
        return 'General Tasks'
    }
    # Multi-project entries: pick the first project name
    if ($Name -match '[,+]') {
        $first = ($Name -split '\s*[,+]\s*')[0].Trim()
        if ($first) { return $first }
    }
    # "VaultWares – Some Description" meta entries (em-dash/en-dash followed by a space)
    # Must NOT match valid repo slugs like "vaultwares-pipelines"
    if ($Name -cmatch "^VaultWares\s+[$([char]0x2013)$([char]0x2014)]\s+") {
        return 'General Tasks'
    }
    return $Name
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

function Safe-ParseLocalDate {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    try {
        $d = [datetime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        return [datetime]::SpecifyKind($d.Date, [System.DateTimeKind]::Local)
    }
    catch {
        return $null
    }
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

function Add-FlagCounts {
    param([hashtable]$Table,[object]$Flags)
    if ($null -eq $Flags) { return }
    foreach ($p in $Flags.psobject.Properties) {
        $k = [string]$p.Name
        if ([string]::IsNullOrWhiteSpace($k)) { continue }
        if (-not $Table.ContainsKey($k)) { $Table[$k] = 0 }
        $Table[$k] = [int]$Table[$k] + 1
    }
}
function Add-StatBucket {
    param(
        [object]$Bucket,
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
        $Table[$Project] = [pscustomobject]@{
            project = $Project
            entries = 0
            firstDay = ''
            lastDay = ''
            kinds = @{}
            flagCounts = @{}
            recent = New-Object System.Collections.Generic.List[object]
            lineRaw = [pscustomobject]@{ insertions = 0; deletions = 0; files = 0 }
            lineClean = [pscustomobject]@{ insertions = 0; deletions = 0; files = 0 }
            lineExcluded = [pscustomobject]@{ insertions = 0; deletions = 0; files = 0 }
        }
    }
    return $Table[$Project]
}

function Ensure-DayBucket {
    param([hashtable]$Table, [string]$Day)
    if (-not $Table.ContainsKey($Day)) {
        $Table[$Day] = [pscustomobject]@{
            day = $Day
            entries = 0
            projects = New-Object System.Collections.Generic.HashSet[string]
            kinds = @{}
        }
    }
    return $Table[$Day]
}

function Get-NumstatForCommit {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Commitish
    )
    $lines = @(& git -C $RepoRoot show --numstat --pretty=format: $Commitish 2>$null)
    return $lines
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath"
}

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$startLocal = Safe-ParseLocalDate ([string]$config.startDate)
if (-not $startLocal) {
    throw "Invalid config startDate: '$($config.startDate)'. Expected a date like 2026-03-11."
}

$excludePathRegex = if ($config.excludePathRegex) { [string]$config.excludePathRegex } else { '' }
if ([string]::IsNullOrWhiteSpace($excludePathRegex)) {
    throw "Config excludePathRegex is missing or empty."
}

$state = $null
if ((-not $FullRebuild) -and (Test-Path -LiteralPath $StatePath)) {
    try { $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json } catch { $state = $null }
}

$schemaVersion = 1
$needRebuild = $FullRebuild.IsPresent -or (-not $state) -or ($state.schemaVersion -ne $schemaVersion)

if (-not $needRebuild) {
    # If config changed in a meaningful way, force rebuild
    if ($state.config.startDate -ne $config.startDate -or $state.config.excludePathRegex -ne $excludePathRegex) {
        $needRebuild = $true
    }
}

if ($needRebuild) {
    $state = [ordered]@{
        schemaVersion = $schemaVersion
        lastUpdatedUtc = $null
        config = [ordered]@{
            startDate = [string]$config.startDate
            primaryCommitMetric = [string]$config.primaryCommitMetric
            excludePathRegex = $excludePathRegex
        }
        processed = [ordered]@{
            eventIds = @()
            commitKeys = @()
        }
        data = $null
    }
}

$processedEventIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($id in @($state.processed.eventIds)) { [void]$processedEventIds.Add([string]$id) }

$processedCommitKeys = New-Object System.Collections.Generic.HashSet[string]
foreach ($k in @($state.processed.commitKeys)) { [void]$processedCommitKeys.Add([string]$k) }

# Initialize or reuse aggregates
$dayBuckets = @{}
$monthCounts = @{}
$kindCounts = @{}
$projectBuckets = @{}
$commitCache = @{} # commitKey -> stats
$commitSamples = New-Object System.Collections.Generic.List[object]

$minUtc = $null
$maxUtc = $null
$commitEventsWithStats = 0

# New: hour-of-day, day-of-week, agent data
# Typed int arrays ensure each element is an independent integer (not an object reference).
$hourCounts = [int[]](0..23 | ForEach-Object { 0 })   # 24 int zeros, index = local hour 0-23
$dowCounts  = [int[]](0..6  | ForEach-Object { 0 })   # 7 int zeros, index = Mon=0 .. Sun=6
$agentActorCounts = @{}
$agentModelCounts = @{}
$agentToolCounts = @{}
$agentMcpCounts = @{}
$agentDayBuckets = @{}        # day -> { count; actors HashSet; models HashSet }
$agentTotalEvents = 0

if ($state.data) {
    # Rehydrate from prior state for fast incremental updates.
    try {
        $rehydrate = $state.data
        foreach ($d in @($rehydrate.series.days)) {
            $b = [pscustomobject]@{ day = [string]$d.day; entries = [int]$d.entries; projects = New-Object System.Collections.Generic.HashSet[string]; kinds = @{} }
            foreach ($p in @($d.projects)) { [void]$b.projects.Add([string]$p) }
            foreach ($kv in $d.kinds.PSObject.Properties) { $b.kinds[[string]$kv.Name] = [int]$kv.Value }
            $dayBuckets[[string]$b.day] = $b
        }
        foreach ($m in @($rehydrate.series.months)) { $monthCounts[[string]$m.month] = [int]$m.count }
        foreach ($k in @($rehydrate.series.kinds)) { $kindCounts[[string]$k.kind] = [int]$k.count }
        foreach ($p in @($rehydrate.series.projects)) {
            $pb = Ensure-ProjectBucket -Table $projectBuckets -Project ([string]$p.project)
            $pb.entries = [int]$p.entries
            $pb.firstDay = [string]$p.firstDay
            $pb.lastDay = [string]$p.lastDay
            foreach ($kv in $p.kinds.PSObject.Properties) { $pb.kinds[[string]$kv.Name] = [int]$kv.Value }
            if ($p.PSObject.Properties.Name -contains 'flagCounts' -and $p.flagCounts) {
                foreach ($kv in $p.flagCounts.PSObject.Properties) { $pb.flagCounts[[string]$kv.Name] = [int]$kv.Value }
            }
            $pb.recent.Clear()
            foreach ($r in @($p.recent)) { $pb.recent.Add([ordered]@{ createdAt = ''; summary = [string]$r }) }
            $pb.lineRaw = $p.lineRaw
            $pb.lineClean = $p.lineClean
            $pb.lineExcluded = $p.lineExcluded
        }
        foreach ($s in @($rehydrate.commitSamples)) {
            $commitSamples.Add($s) | Out-Null
            # Only mark as processed if this commit already has line data.
            # Zero-stat commits are re-tried on the next run so the regex fix
            # (or a future -FullRebuild) can populate them without requiring a
            # full rebuild every time.
            $hasStats = (($s.rawChurnLines -ne $null) -and ([int]$s.rawChurnLines -gt 0)) -or
                        (($s.cleanChurnLines -ne $null) -and ([int]$s.cleanChurnLines -gt 0)) -or
                        (($s.filesTouched -ne $null) -and ([int]$s.filesTouched -gt 0))
            if ($s.commitKey -and $hasStats) { [void]$processedCommitKeys.Add([string]$s.commitKey) }
        }
        $commitEventsWithStats = [int]$rehydrate.totals.commitEventsWithStats
        $minUtc = Safe-ParseUtc ([string]$rehydrate._minCreatedAtUtc)
        $maxUtc = Safe-ParseUtc ([string]$rehydrate._maxCreatedAtUtc)
    }
    catch {
        # If rehydrate fails, fall back to rebuild.
        $needRebuild = $true
        $state.data = $null
        $dayBuckets = @{}; $monthCounts = @{}; $kindCounts = @{}; $projectBuckets = @{}
        $commitCache = @{}; $commitSamples = New-Object System.Collections.Generic.List[object]
        $minUtc = $null; $maxUtc = $null; $commitEventsWithStats = 0
        $processedEventIds.Clear()
        $processedCommitKeys.Clear()
    }
}

# Hour/dow/agent counters are always rebuilt from all events (fast, no git I/O).
# Resetting here (not just on first run) guarantees correctness even when rehydration
# brought in prior state – these counters must always reflect ALL events in the window.
$hourCounts = [int[]](0..23 | ForEach-Object { 0 })
$dowCounts  = [int[]](0..6  | ForEach-Object { 0 })
$agentActorCounts = @{}
$agentModelCounts = @{}
$agentToolCounts = @{}
$agentMcpCounts = @{}
$agentDayBuckets = @{}
$agentTotalEvents = 0

$eventsRoot = Join-Path $LedgerRoot 'events'
$historyRoot = Join-Path $LedgerRoot 'history'
if (-not (Test-Path -LiteralPath $eventsRoot)) {
    throw "Events folder not found: $eventsRoot"
}

$newEventsProcessed = 0

# On full rebuild, read both events/ and history/ directories
$eventDirs = @($eventsRoot)
if ($FullRebuild -and (Test-Path -LiteralPath $historyRoot)) {
    $eventDirs += $historyRoot
}

$eventDirs | ForEach-Object { Get-ChildItem -Path $_ -Recurse -File -Filter '*.json' } |
    Sort-Object -Property FullName |
    ForEach-Object {
        $path = $_.FullName
        $e = $null
        try { $e = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json } catch { return }
        if (-not $e) { return }

        $eventId = $null
        try { $eventId = [string]$e.id } catch { $eventId = '' }
        if ([string]::IsNullOrWhiteSpace($eventId)) {
            try { $eventId = [string]$e.contentHash } catch { $eventId = '' }
        }
        if ([string]::IsNullOrWhiteSpace($eventId)) {
            $eventId = (Split-Path $path -Leaf)
        }

        if ($processedEventIds.Contains($eventId)) { return }

        $utc = Safe-ParseUtc ([string]$e.createdAt)
        if (-not $utc) { return }
        $local = To-LocalTime $utc
        if ($local -lt $startLocal) { return }

        $project = if ($e.project) { [string]$e.project } else { 'General Tasks' }
        $project = Normalize-RawProjectName $project
        $project = Resolve-ProjectAlias -Project $project -AliasMapPath $aliasMapPath
        $kind = if ($e.kind) { [string]$e.kind } else { 'general' }
        $day = $local.ToString('yyyy-MM-dd')
        $month = $local.ToString('yyyy-MM')

        [void]$processedEventIds.Add($eventId)
        $newEventsProcessed += 1

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
        if ($e.telemetry -and $e.telemetry.flags) { Add-FlagCounts -Table $projBucket.flagCounts -Flags $e.telemetry.flags }
        if ([string]::IsNullOrWhiteSpace($projBucket.firstDay) -or ($day -lt $projBucket.firstDay)) { $projBucket.firstDay = $day }
        if ([string]::IsNullOrWhiteSpace($projBucket.lastDay) -or ($day -gt $projBucket.lastDay)) { $projBucket.lastDay = $day }

        $summary = Limit-Line ([string]$e.summary) 180
        if (-not [string]::IsNullOrWhiteSpace($summary)) {
            $projBucket.recent.Add([ordered]@{ createdAt = ([string]$e.createdAt); summary = $summary })
            while ($projBucket.recent.Count -gt 6) { $projBucket.recent.RemoveAt(0) }
        }

        if ($summary -match 'Backfill:\s*commit\s+([0-9a-fA-F]{7,40})\b') {
            $commitish = $matches[1]
            $repoRoot = $null
            try { $repoRoot = [string]$e.git.root } catch { $repoRoot = $null }
            if ($repoRoot -and (Test-Path -LiteralPath $repoRoot)) {
                $commitKey = "$repoRoot`n$commitish"

                if (-not $processedCommitKeys.Contains($commitKey)) {
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
                        $p = [string]$cols[2]

                        $rawIns += $ins; $rawDel += $del; $filesRaw += 1
                        if ($p -match $excludePathRegex) {
                            $exclIns += $ins; $exclDel += $del; $filesExcl += 1
                        }
                        else {
                            $cleanIns += $ins; $cleanDel += $del; $filesClean += 1
                        }
                    }

                    $commitCache[$commitKey] = [ordered]@{
                        rawIns = $rawIns; rawDel = $rawDel
                        cleanIns = $cleanIns; cleanDel = $cleanDel
                        exclIns = $exclIns; exclDel = $exclDel
                        filesRaw = $filesRaw; filesClean = $filesClean; filesExcl = $filesExcl
                    }

                    [void]$processedCommitKeys.Add($commitKey)

                    $commitSamples.Add([ordered]@{
                        commitKey = $commitKey
                        repoRoot = $repoRoot
                        commit = $commitish
                        project = $project
                        day = $day
                        month = $month
                        cleanChurnLines = ($cleanIns + $cleanDel)
                        cleanNetLines = ($cleanIns - $cleanDel)
                        rawChurnLines = ($rawIns + $rawDel)
                        excludedChurnLines = ($exclIns + $exclDel)
                        filesTouched = $filesRaw
                        filesClean = $filesClean
                        filesExcluded = $filesExcl
                    }) | Out-Null

                    # Attribute commit volume once (at first sighting) to the event's project.
                    Add-StatBucket -Bucket $projBucket.lineRaw -Add $rawIns -Del $rawDel -FilesDelta $filesRaw
                    Add-StatBucket -Bucket $projBucket.lineClean -Add $cleanIns -Del $cleanDel -FilesDelta $filesClean
                    Add-StatBucket -Bucket $projBucket.lineExcluded -Add $exclIns -Del $exclDel -FilesDelta $filesExcl
                }

                # Count events that reference a commit we have stats for (even if the commit was processed earlier).
                if ($processedCommitKeys.Contains($commitKey)) {
                    $commitEventsWithStats += 1
                }
            }
        }
    }

# --- Second pass: hour-of-day, day-of-week, agent data (all events, fast, no git I/O) ---
$eventDirs | ForEach-Object { Get-ChildItem -Path $_ -Recurse -File -Filter '*.json' } |
    Sort-Object -Property FullName |
    ForEach-Object {
        $path2 = $_.FullName
        $e2 = $null
        try { $e2 = Get-Content -Raw -LiteralPath $path2 | ConvertFrom-Json } catch { return }
        if (-not $e2) { return }

        $utc2 = Safe-ParseUtc ([string]$e2.createdAt)
        if (-not $utc2) { return }
        $local2 = To-LocalTime $utc2
        if ($local2 -lt $startLocal) { return }

        $hour2 = [int]$local2.Hour
        $dow2 = [int]$local2.DayOfWeek   # 0=Sun..6=Sat, convert to Mon=0
        $dowMon = if ($dow2 -eq 0) { 6 } else { $dow2 - 1 }
        $hourCounts[$hour2] += 1
        $dowCounts[$dowMon] += 1

        # Agent data: only events with a runtime field
        if ($e2.runtime) {
            $agentTotalEvents += 1
            $actor2 = if ($e2.actor) { [string]$e2.actor } else { 'Unknown' }
            $model2 = if ($e2.runtime.model) { [string]$e2.runtime.model } else { 'unknown' }

            Add-Count -Table $agentActorCounts -Key $actor2
            Add-Count -Table $agentModelCounts -Key $model2

            $tools2 = @($e2.runtime.toolsUsed)
            foreach ($tool2 in $tools2) {
                $ts = ([string]$tool2).Trim()
                if (-not [string]::IsNullOrWhiteSpace($ts)) { Add-Count -Table $agentToolCounts -Key $ts }
            }
            $mcpRaw = [string]$e2.runtime.mcpServersAccessed
            if (-not [string]::IsNullOrWhiteSpace($mcpRaw) -and $mcpRaw.ToLower() -ne 'none') {
                foreach ($mc in ($mcpRaw -split ',')) {
                    $ms2 = $mc.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($ms2)) { Add-Count -Table $agentMcpCounts -Key $ms2 }
                }
            }

            $day2 = $local2.ToString('yyyy-MM-dd')
            if (-not $agentDayBuckets.ContainsKey($day2)) {
                $agentDayBuckets[$day2] = [pscustomobject]@{
                    day = $day2; count = 0
                    actors = New-Object System.Collections.Generic.HashSet[string]
                    models = New-Object System.Collections.Generic.HashSet[string]
                }
            }
            $agentDayBuckets[$day2].count += 1
            [void]$agentDayBuckets[$day2].actors.Add($actor2)
            [void]$agentDayBuckets[$day2].models.Add($model2)
        }
    }

$agentDaySeries = @($agentDayBuckets.Values | Sort-Object -Property day | ForEach-Object {
    @{ day = $_.day; count = $_.count; actors = @($_.actors | Sort-Object); models = @($_.models | Sort-Object) }
})
$agentActorList = @($agentActorCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { @($_.Key, $_.Value) })
$agentModelList = @($agentModelCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { @($_.Key, $_.Value) })
$agentToolList  = @($agentToolCounts.GetEnumerator()  | Sort-Object -Property Value -Descending | Select-Object -First 15 | ForEach-Object { @($_.Key, $_.Value) })
$agentMcpList   = @($agentMcpCounts.GetEnumerator()   | Sort-Object -Property Value -Descending | ForEach-Object { @($_.Key, $_.Value) })

$dowLabels = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')

# Overall line stats are derived from per-project buckets, which are updated once per newly-seen commit.
$overallRaw = @{ insertions = 0; deletions = 0; files = 0 }
$overallClean = @{ insertions = 0; deletions = 0; files = 0 }
$overallExcluded = @{ insertions = 0; deletions = 0; files = 0 }
foreach ($p in $projectBuckets.Values) {
    $overallRaw.insertions += [int]$p.lineRaw.insertions
    $overallRaw.deletions += [int]$p.lineRaw.deletions
    $overallRaw.files += [int]$p.lineRaw.files
    $overallClean.insertions += [int]$p.lineClean.insertions
    $overallClean.deletions += [int]$p.lineClean.deletions
    $overallClean.files += [int]$p.lineClean.files
    $overallExcluded.insertions += [int]$p.lineExcluded.insertions
    $overallExcluded.deletions += [int]$p.lineExcluded.deletions
    $overallExcluded.files += [int]$p.lineExcluded.files
}

$projects = @($projectBuckets.Values) | Sort-Object -Property entries -Descending
$kinds = $kindCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { [pscustomobject]@{ kind = $_.Key; count = $_.Value } }
$months = $monthCounts.GetEnumerator() | Sort-Object -Property Key | ForEach-Object { [pscustomobject]@{ month = $_.Key; count = $_.Value } }
$days = $dayBuckets.Values | Sort-Object -Property day

$seriesDays = @($days | ForEach-Object {
    @{
        day = $_.day
        entries = $_.entries
        projects = ($_.projects | Sort-Object)
        kinds = $_.kinds
    }
})

$seriesProjects = @($projects | ForEach-Object {
    @{
        project = $_.project
        entries = $_.entries
        firstDay = $_.firstDay
        lastDay = $_.lastDay
        kinds = $_.kinds
        flagCounts = $_.flagCounts
        recent = @($_.recent | ForEach-Object { [string]$_.summary } | Select-Object -Last 3)
        lineRaw = $_.lineRaw
        lineClean = $_.lineClean
        lineExcluded = $_.lineExcluded
    }
})

$activeDays = ($dayBuckets.Keys | Measure-Object).Count
$projectCount = ($projectBuckets.Keys | Measure-Object).Count
$totalEvents = ($processedEventIds | Measure-Object).Count

$rangeStart = $startLocal.ToString('yyyy-MM-dd')
$rangeEnd = if ($maxUtc) { (To-LocalTime $maxUtc).ToString('yyyy-MM-dd') } else { $rangeStart }

$minIso = $null
if ($minUtc) { $minIso = $minUtc.ToString('o') }
$maxIso = $null
if ($maxUtc) { $maxIso = $maxUtc.ToString('o') }

$data = @{
    schemaVersion = $schemaVersion
    generatedAtLocal = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    range = @{ start = $rangeStart; end = $rangeEnd }
    totals = @{
        events = $totalEvents
        projects = $projectCount
        activeDays = $activeDays
        commitEventsWithStats = $commitEventsWithStats
        uniqueCommitsRecomputed = $processedCommitKeys.Count
    }
    lineStats = @{
        raw = $overallRaw
        clean = $overallClean
        excluded = $overallExcluded
    }
    series = @{
        months = $months
        days = $seriesDays
        kinds = $kinds
        projects = $seriesProjects
    }
    commitSamples = @($commitSamples.ToArray())
    exclusions = @{
        pathRegex = $excludePathRegex
        notes = @(
            'Line stats are recomputed from git commits referenced by Backfill events.',
            'Clean stats exclude common dependency/build/cache/generated folders (regex above).'
        )
    }
    hourSeries = @(0..23 | ForEach-Object { @{ hour = $_; count = $hourCounts[$_] } })
    dowSeries = @(0..6 | ForEach-Object { @{ dow = $_; label = $dowLabels[$_]; count = $dowCounts[$_] } })
    agentData = @{
        totalEvents = $agentTotalEvents
        actors     = $agentActorList
        models     = $agentModelList
        tools      = $agentToolList
        mcpServers = $agentMcpList
        daySeries  = $agentDaySeries
    }
    _minCreatedAtUtc = $minIso
    _maxCreatedAtUtc = $maxIso
}

$state.lastUpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
$state.config.startDate = [string]$config.startDate
$state.config.primaryCommitMetric = [string]$config.primaryCommitMetric
$state.config.excludePathRegex = $excludePathRegex
$state.processed.eventIds = @($processedEventIds)
$state.processed.commitKeys = @($processedCommitKeys)
$state.data = $data

$state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $StatePath -Encoding utf8

Write-Output "Updated work impact state: $StatePath (newEvents=$newEventsProcessed)"



