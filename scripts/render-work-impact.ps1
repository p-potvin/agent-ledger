[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$StatePath,
    [string]$ParentHtmlPath,
    [int]   $DaysBack = 90
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) { $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
if (-not $StatePath)  { $StatePath  = Join-Path $LedgerRoot 'work-impact.state.json' }
if (-not $ParentHtmlPath) { $ParentHtmlPath = Join-Path (Split-Path $LedgerRoot -Parent) 'WORK_IMPACT.html' }

$outHtmlPath = Join-Path $LedgerRoot 'WORK_IMPACT.html'
$LogDir      = Join-Path $LedgerRoot 'input-logs'
$HistDir     = Join-Path $LedgerRoot 'history'
$EventsDir   = Join-Path $LedgerRoot 'events'

if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "State file not found: $StatePath"
}

# ---------------------------------------------------------------------------
# i18n table
# ---------------------------------------------------------------------------
function New-I18nTable {
    return [ordered]@{
        en = [ordered]@{
            title = 'Work Impact'
            subtitle = 'A plain-language view of the work recorded in your agent ledger.'
            generated = 'Generated'
            range = 'Range'
            langLabel = 'Language'
            intro = 'This report helps non-technical readers understand effort: how often you worked, how widely you spread across projects, and how the pace evolved.'
            metricEvents = 'Work entries'
            metricDays = 'Active days'
            metricProjects = 'Projects touched'
            metricStreak = 'Current streak'
            metricLongestStreak = 'Longest streak'
            metricBusiestDay = 'Busiest day'
            metricBusiestWeek = 'Busiest week'
            calendarTitle = 'Work activity by day'
            calendarHint = 'Hover a square to see that day.'
            less = 'Less'
            more = 'More'
            monthlyTitle = 'Work recorded per month'
            kindsTitle = 'What kind of work'
            projectsTitle = 'Top projects by activity'
            projectsNote = 'Raw repo names are shown.'
            commitSizeTitle = 'Commit size (clean churn lines)'
            commitSizeHint = 'Derived from git commits referenced by backfill events. Clean churn = additions + deletions, excluding generated/vendor paths.'
            commitStatMean = 'Mean'
            commitStatMedian = 'Median'
            commitStatMode = 'Mode'
            commitStatSamples = 'Commits sampled'
            commitHistTitle = 'Size distribution'
            commitBoxTitle = 'By month (quartiles)'
            commitOutliersTitle = 'Largest commits'
            techTitle = 'Technical volume (clean vs raw)'
            techHint = 'Line counts are one imperfect proxy for effort. Clean excludes generated/vendor paths.'
            statType = 'Metric'
            statAdds = 'Additions'
            statDels = 'Deletions'
            statFiles = 'Files'
            statChurn = 'Churn'
            statNet = 'Net'
            statExcluded = 'Excluded churn'
            filesTouchedTitle = 'Files touched per commit'
            concentrationTitle = 'Work concentration'
            concentrationHint = 'Share of total activity in the top 5 projects.'
            highlightsTitle = 'Top projects'
            highlightsHint = 'Projects with the most recorded activity.'
            hlMostConsistentMonth = 'Most consistent month'
            hlWidestProjectDay = 'Widest project spread'
            hlStrongestWeek = 'Strongest week'
            hlMilestones = 'Milestones'
            labelProjects = 'Projects'
            labelKinds = 'Kinds'
            labelClean = 'Clean'
            labelRaw = 'Raw'
            labelExcluded = 'Excluded'
            evidenceTitle = 'Activity by project'
            evidenceHint = 'Expand any project to see its recent activity entries.'
            colProject = 'Project'
            colEntries = 'Entries'
            colFirst = 'First'
            colLast = 'Last'
            colExamples = 'Recent entries'
            agentTitle = 'Agent activity'
            agentHint = 'Entries recorded with an agent runtime header (available from May 2026).'
            activityTitle = 'When work happens'
            activityHint = 'Hour of day and day of week distributions across all entries.'
            noCommitData = 'No commit data yet.'
            commitLineDataUnavailable = '{n} commits referenced. Line-count statistics are populated the next time update-work-impact.ps1 runs. If counts remain at zero, run with -FullRebuild to reprocess all commits.'
            lineStatsUnavailable = 'Line-count data requires local access to git repositories. Run update-work-impact.ps1 locally.'
            fileDataUnavailable = '{n} commits referenced. File count data requires local git access.'
            noMcpData = 'No MCP servers.'
            noAgentDays = 'No agent activity days yet.'
            noSummaries = 'No summaries.'
            agentEventsLabel = 'Agent events'
            distinctActors = 'Distinct actors'
            modelsUsed = 'Models used'
            toolsUsed = 'Tools used'
            streakMax = 'Max: {n} days'
            kindLabels = [ordered]@{
                'code-change' = 'Built / changed'
                'plan' = 'Planning'
                'verification' = 'Verification'
                'commands' = 'Operations'
                'handoff' = 'Handoffs'
                'general' = 'Other'
            }
            units = [ordered]@{
                days = 'days'
                entries = 'entries'
                commits = 'commits'
                lines = 'lines'
                files = 'files'
            }
        }
        qc = [ordered]@{
            title = 'Impact du travail'
            subtitle = "Une vue simple du travail enregistr$([char]0x00e9) dans ton agent ledger."
            generated = "G$([char]0x00e9)n$([char]0x00e9)r$([char]0x00e9)"
            range = "P$([char]0x00e9)riode"
            langLabel = 'Langue'
            intro = "Ce rapport aide des gens non-tech $([char]0x00e0) comprendre l$([char]0x2019)effort$([char]0x00a0): $([char]0x00e0) quelle fr$([char]0x00e9)quence tu as travaill$([char]0x00e9), sur combien de projets, et comment le rythme a $([char]0x00e9)volu$([char]0x00e9)."
            metricEvents = "Entr$([char]0x00e9)es de travail"
            metricDays = 'Jours actifs'
            metricProjects = "Projets touch$([char]0x00e9)s"
            metricStreak = "S$([char]0x00e9)rie en cours"
            metricLongestStreak = "Plus longue s$([char]0x00e9)rie"
            metricBusiestDay = 'Jour le plus actif'
            metricBusiestWeek = 'Semaine la plus active'
            calendarTitle = "Activit$([char]0x00e9) de travail par jour"
            calendarHint = "Survole un carr$([char]0x00e9) pour voir la journ$([char]0x00e9)e."
            less = 'Moins'
            more = 'Plus'
            monthlyTitle = "Travail enregistr$([char]0x00e9) par mois"
            kindsTitle = "Type de travail"
            projectsTitle = 'Projets les plus actifs'
            projectsNote = "Les noms bruts des repos sont affich$([char]0x00e9)s."
            commitSizeTitle = 'Taille des commits (churn propre)'
            commitSizeHint = "D$([char]0x00e9)riv$([char]0x00e9) des commits r$([char]0x00e9)f$([char]0x00e9)renc$([char]0x00e9)s par les $([char]0x00e9)v$([char]0x00e9)nements de backfill."
            commitStatMean = 'Moyenne'
            commitStatMedian = "M$([char]0x00e9)diane"
            commitStatMode = 'Mode'
            commitStatSamples = "Commits mesur$([char]0x00e9)s"
            commitHistTitle = 'Distribution des tailles'
            commitBoxTitle = 'Par mois (quartiles)'
            commitOutliersTitle = 'Plus gros commits'
            techTitle = 'Volume technique (propre vs brut)'
            techHint = "Le nombre de lignes est un indicateur imparfait."
            statType = "M$([char]0x00e9)trique"
            statAdds = 'Ajouts'
            statDels = 'Suppressions'
            statFiles = 'Fichiers'
            statChurn = 'Churn'
            statNet = 'Net'
            statExcluded = 'Churn exclu'
            filesTouchedTitle = "Fichiers touch$([char]0x00e9)s par commit"
            concentrationTitle = 'Concentration du travail'
            concentrationHint = "Part de l$([char]0x2019)activit$([char]0x00e9) totale dans les 5 premiers projets."
            highlightsTitle = 'Meilleurs projets'
            highlightsHint = "Projets avec le plus d$([char]0x2019)activit$([char]0x00e9) enregistr$([char]0x00e9)e."
            hlMostConsistentMonth = 'Mois le plus constant'
            hlWidestProjectDay = 'Jour avec le plus de projets'
            hlStrongestWeek = 'Semaine la plus forte'
            hlMilestones = 'Jalons'
            labelProjects = 'Projets'
            labelKinds = 'Types'
            labelClean = 'Propre'
            labelRaw = 'Brut'
            labelExcluded = 'Exclu'
            evidenceTitle = "Activit$([char]0x00e9) par projet"
            evidenceHint = "D$([char]0x00e9)pliez un projet pour voir ses entr$([char]0x00e9)es r$([char]0x00e9)centes."
            colProject = 'Projet'
            colEntries = "Entr$([char]0x00e9)es"
            colFirst = 'Premier'
            colLast = 'Dernier'
            colExamples = "Entr$([char]0x00e9)es r$([char]0x00e9)centes"
            agentTitle = "Activit$([char]0x00e9) des agents"
            agentHint = "Entr$([char]0x00e9)es avec un en-t$([char]0x00ea)te d$([char]0x2019)agent runtime."
            activityTitle = 'Quand le travail se passe'
            activityHint = 'Distribution par heure du jour et jour de la semaine.'
            noCommitData = 'Pas encore de commits.'
            commitLineDataUnavailable = "{n} commits r$([char]0x00e9)f$([char]0x00e9)renc$([char]0x00e9)s. Les statistiques de lignes seront peupl$([char]0x00e9)es au prochain passage."
            lineStatsUnavailable = "Les donn$([char]0x00e9)es de lignes n$([char]0x00e9)cessitent un acc$([char]0x00e8)s local aux d$([char]0x00e9)p$([char]0x00f4)ts git."
            fileDataUnavailable = "{n} commits r$([char]0x00e9)f$([char]0x00e9)renc$([char]0x00e9)s. Donn$([char]0x00e9)es de fichiers non disponibles sans acc$([char]0x00e8)s local."
            noMcpData = 'Aucun serveur MCP.'
            noAgentDays = "Aucune journ$([char]0x00e9)e avec agent."
            noSummaries = "Aucun r$([char]0x00e9)sum$([char]0x00e9)."
            agentEventsLabel = "$([char]0x00c9)v$([char]0x00e9)nements d$([char]0x2019)agent"
            distinctActors = 'Acteurs distincts'
            modelsUsed = "Mod$([char]0x00e8)les utilis$([char]0x00e9)s"
            toolsUsed = "Outils utilis$([char]0x00e9)s"
            streakMax = "Max$([char]0x00a0): {n} jours"
            kindLabels = [ordered]@{
                'code-change' = "Construit / modifi$([char]0x00e9)"
                'plan' = 'Planification'
                'verification' = "V$([char]0x00e9)rification"
                'commands' = "Op$([char]0x00e9)rations"
                'handoff' = 'Passations'
                'general' = 'Autre'
            }
            units = [ordered]@{
                days = 'jours'
                entries = "entr$([char]0x00e9)es"
                commits = 'commits'
                lines = 'lignes'
                files = 'fichiers'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Load WORK_IMPACT state
# ---------------------------------------------------------------------------
$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
if (-not $state -or -not $state.data) {
    throw "State file has no data. Run scripts/update-work-impact.ps1 first: $StatePath"
}
$payload = [ordered]@{ config=$state.config; data=$state.data; lastUpdatedUtc=$state.lastUpdatedUtc }
$payloadJson = ($payload | ConvertTo-Json -Depth 24 -Compress)
$i18nJson    = ((New-I18nTable) | ConvertTo-Json -Depth 24 -Compress)

$aliasesFilePath = Join-Path $PSScriptRoot "..\project-aliases.json"
$aliasReverseMap = [ordered]@{}
if (Test-Path -LiteralPath $aliasesFilePath) {
    try {
        $aliasData = Get-Content -Raw -LiteralPath $aliasesFilePath | ConvertFrom-Json
        foreach ($entry in $aliasData.projects) {
            if ($entry.canonical -and $entry.aliases) {
                $validAliases = @($entry.aliases | Where-Object { $_ -and $_.Trim() -ne '' })
                if ($validAliases.Count -gt 0) { $aliasReverseMap[$entry.canonical] = $validAliases }
            }
        }
    } catch { }
}
$aliasMapJson = ($aliasReverseMap | ConvertTo-Json -Depth 4 -Compress)

# ---------------------------------------------------------------------------
# Load input-log files
# ---------------------------------------------------------------------------
$inputDays = [System.Collections.Generic.List[object]]::new()
if (Test-Path $LogDir) {
    $cutoff = (Get-Date).AddDays(-$DaysBack).Date
    Get-ChildItem -Path $LogDir -Filter "*.json" -File | Sort-Object Name |
        Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}$' } |
        ForEach-Object {
            try {
                $dt = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
                if ($dt -ge $cutoff) {
                    $inputDays.Add((Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json))
                }
            } catch { }
        }
}

# ---------------------------------------------------------------------------
# Load ledger events (slim) from history/ and events/
# ---------------------------------------------------------------------------
$ledgerEvents = [System.Collections.Generic.List[object]]::new()
$seenIds      = [System.Collections.Generic.HashSet[string]]::new()

function Import-LedgerDir {
    param([string]$Dir, [datetime]$Cutoff)
    if (-not (Test-Path $Dir)) { return }
    Get-ChildItem -Path $Dir -Filter "*.json" -Recurse -File | Sort-Object Name |
        ForEach-Object {
            try {
                $raw = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $dt  = [datetime]::Parse($raw.createdAt)
                $id  = if ($raw.id) { $raw.id } else { $_.BaseName }
                if ($dt.Date -ge $Cutoff -and $seenIds.Add($id)) {
                    $script:ledgerEvents.Add([pscustomobject]@{
                        date    = $dt.ToString("yyyy-MM-dd")
                        project = if ($raw.project) { $raw.project } else { "General" }
                        kind    = if ($raw.kind)    { $raw.kind }    else { "general" }
                        model   = if ($raw.runtime -and $raw.runtime.model) { $raw.runtime.model } else { "unknown" }
                        actor   = if ($raw.actor)   { $raw.actor }   else { "unknown" }
                    })
                }
            } catch { }
        }
}
$cutoff = (Get-Date).AddDays(-$DaysBack).Date
Import-LedgerDir -Dir $HistDir   -Cutoff $cutoff
Import-LedgerDir -Dir $EventsDir -Cutoff $cutoff

$inputDaysJson = if ($inputDays.Count -eq 0)    { "[]" } else { $inputDays    | ConvertTo-Json -Depth 6 -Compress }
$ledgerJson    = if ($ledgerEvents.Count -eq 0)  { "[]" } else { $ledgerEvents | ConvertTo-Json -Depth 3 -Compress }
$generatedAt   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")

# ---------------------------------------------------------------------------
# HTML template  (@'...'@ -- no dollar expansion, safe for large JSON inject)
# ---------------------------------------------------------------------------
$template = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Work Impact -- VaultWares</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap">
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
<style>
:root{--font-sans:"Inter","Segoe UI",ui-sans-serif,system-ui,sans-serif;--font-mono:"JetBrains Mono","Cascadia Code",Consolas,ui-monospace,monospace;--bg:#0e0c18;--surface:#161320;--surface2:#1c1826;--surface3:#231e30;--border:rgba(255,255,255,0.07);--fg:#d8d0f0;--muted:rgba(216,208,240,0.48);--dim:rgba(216,208,240,0.24);--card:#161320;--accent:#b8882e;--gold:#b8882e;--gold-glow:rgba(184,136,46,0.28);--gold-dim:rgba(184,136,46,0.12);--amber:#c49840;--violet:#8a62c0;--violet-glow:rgba(138,98,192,0.28);--green:#4e9954;--red:#a84e5a;--orange:#a86840;--v-gold:#b8882e;--v-gold-muted:rgba(184,136,46,0.12);--v-gold-dim:rgba(184,136,46,0.28);--v-green:#4e9954;--v-burgundy:#a84e5a;--v-slate:rgba(216,208,240,0.48);--v-muted-color:rgba(216,208,240,0.28);--v-border:rgba(255,255,255,0.07);--chip:rgba(184,136,46,0.12);--link:#b8882e;--good0:rgba(255,255,255,0.05);--good1:rgba(138,98,192,0.25);--good2:rgba(138,98,192,0.48);--good3:rgba(138,98,192,0.72);--good4:#8a62c0}
*,*::before,*::after{box-sizing:border-box}
body{margin:0;font-family:var(--font-sans);background:var(--bg);color:var(--fg);line-height:1.5;-webkit-font-smoothing:antialiased}
main{max-width:1200px;margin:0 auto;padding:24px 16px 80px}
a{color:var(--gold)}canvas{display:block}
header{display:flex;align-items:flex-start;justify-content:space-between;flex-wrap:wrap;gap:14px;padding-bottom:18px;border-bottom:1px solid var(--border);margin-bottom:4px}
.brand{display:flex;align-items:center;gap:10px}
.brand-badge{background:var(--gold-dim);border:1px solid var(--gold-glow);border-radius:6px;padding:3px 10px;font-size:10px;font-weight:800;color:var(--gold);letter-spacing:.1em;text-transform:uppercase}
h1{margin:0;font-size:22px;font-weight:800;letter-spacing:-.01em}h1 span{color:var(--gold)}
.meta-row{color:var(--muted);font-size:12px;margin-top:2px}
.header-right{display:flex;flex-direction:column;align-items:flex-end;gap:8px}
.lang{display:flex;gap:8px;align-items:center}.lang span{font-size:12px;color:var(--muted);font-weight:600}
.toggle{display:inline-flex;border:1px solid var(--border);border-radius:999px;overflow:hidden}
.toggle button{appearance:none;border:0;padding:6px 12px;cursor:pointer;background:transparent;color:var(--fg);font-size:12px;font-weight:600;font-family:var(--font-sans);transition:background .1s}
.toggle button[aria-pressed="true"]{background:var(--chip);color:var(--accent)}
.range-row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.range-row label{font-size:11px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.range-btn{appearance:none;border:1px solid var(--border);border-radius:6px;padding:5px 12px;background:var(--surface2);color:var(--muted);font-size:11px;font-weight:600;cursor:pointer;font-family:var(--font-sans);transition:all .15s}
.range-btn:hover{border-color:var(--gold);color:var(--gold)}
.range-btn.active{background:var(--gold-dim);border-color:var(--gold);color:var(--gold)}
.custom-row{display:none;gap:8px;align-items:center;margin-top:4px}.custom-row.visible{display:flex}
.custom-row input{appearance:none;border:1px solid var(--border);border-radius:6px;padding:4px 8px;background:var(--surface2);color:var(--fg);font-size:11px;font-family:var(--font-mono)}
.custom-row button{appearance:none;border:1px solid var(--gold-glow);border-radius:6px;padding:4px 10px;background:var(--gold-dim);color:var(--gold);font-size:11px;font-weight:700;cursor:pointer;font-family:var(--font-sans)}
section{margin-top:20px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(12,1fr)}
.span2{grid-column:span 2}.span3{grid-column:span 3}.span4{grid-column:span 4}.span6{grid-column:span 6}.span8{grid-column:span 8}.span12{grid-column:span 12}
@media(max-width:980px){.span2,.span3,.span4,.span6,.span8{grid-column:span 6}}
@media(max-width:560px){.span2,.span3,.span4,.span6,.span8{grid-column:span 12}}
.card{border:1px solid var(--border);background:var(--surface);border-radius:10px;padding:14px}
.card h2{margin:0 0 8px;font-size:11px;color:var(--muted);font-weight:700;text-transform:uppercase;letter-spacing:.06em}
section>h2{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 10px}
.big{font-size:28px;font-weight:700;line-height:1.1}.big-accent{color:var(--accent)}
.sub{margin-top:4px;font-size:12px;color:var(--muted)}.kicker{margin:12px 0 2px;font-size:13px;color:var(--fg);line-height:1.65;opacity:.85}
.quiet{color:var(--muted)}.row{display:flex;gap:10px;align-items:center;justify-content:space-between;flex-wrap:wrap}
.pill{display:inline-block;padding:2px 8px;border-radius:999px;background:var(--chip);border:1px solid var(--gold-dim);font-size:11px;color:var(--accent);font-weight:700;vertical-align:middle}
.no-data{color:var(--muted);font-size:12px;font-style:italic;padding:8px 0}
.info-note{font-size:11px;color:var(--muted);background:rgba(184,136,46,.06);border:1px solid var(--gold-dim);border-radius:6px;padding:6px 10px;margin-top:8px}
.led-card{border-radius:10px;padding:14px 14px 12px;background:var(--surface2);border:1px solid var(--border);display:flex;flex-direction:column;gap:4px}
.led-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;animation:ledpulse 3s ease-in-out infinite}
@keyframes ledpulse{0%,100%{opacity:1}60%{opacity:.4}}
.led-header{display:flex;align-items:center;gap:7px}
.led-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}
.led-value{font-size:24px;font-weight:800;font-family:var(--font-mono);line-height:1.1;font-variant-numeric:tabular-nums}
.led-unit{font-size:10px;font-weight:600;opacity:.6;margin-left:2px}.led-sub{font-size:11px;color:var(--muted);margin-top:2px}
.led-gold .led-dot{background:var(--gold);box-shadow:0 0 5px var(--gold)}.led-gold .led-value{color:var(--gold)}
.led-violet .led-dot{background:var(--violet);box-shadow:0 0 5px var(--violet)}.led-violet .led-value{color:var(--violet)}
.led-green .led-dot{background:var(--green);box-shadow:0 0 5px var(--green)}.led-green .led-value{color:var(--green)}
.led-amber .led-dot{background:var(--amber);box-shadow:0 0 5px var(--amber)}.led-amber .led-value{color:var(--amber)}
.led-orange .led-dot{background:var(--orange);box-shadow:0 0 5px var(--orange)}.led-orange .led-value{color:var(--orange)}
.led-red .led-dot{background:var(--red);box-shadow:0 0 5px var(--red)}.led-red .led-value{color:var(--red)}
.chart-wrap{position:relative;width:100%;height:220px}.chart-wrap-sm{position:relative;width:100%;height:180px}
.barlist{display:flex;flex-direction:column;gap:8px}
.bar{display:flex;align-items:center;gap:10px}
.bar label{width:190px;font-size:12px;color:var(--fg);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex-shrink:0}
.bar .track{flex:1;height:8px;border-radius:999px;background:rgba(184,136,46,.08);overflow:hidden;min-width:50px}
.bar .fill{height:100%;background:var(--accent);border-radius:999px;transition:width .3s ease}
.bar .n{width:68px;text-align:right;font-variant-numeric:tabular-nums;color:var(--muted);font-size:12px;flex-shrink:0}
.bar.green .fill{background:var(--green)}.bar.violet .fill{background:var(--violet)}
.heatWrap{overflow-x:auto;scrollbar-width:thin}
.heat{display:grid;grid-auto-flow:column;grid-auto-columns:13px;gap:3px;align-items:start;padding:8px 6px 4px}
.heatCol{display:grid;grid-template-rows:repeat(7,13px);gap:3px}
.cell{width:13px;height:13px;border-radius:3px;background:var(--good0);cursor:default;transition:transform .1s}
.cell:hover{transform:scale(1.4)}.lvl1{background:var(--good1)}.lvl2{background:var(--good2)}.lvl3{background:var(--good3)}.lvl4{background:var(--good4)}
.heatLegend{display:flex;gap:8px;align-items:center;justify-content:flex-end;font-size:11px;color:var(--muted);padding:4px 6px}
.legendSwatch{display:flex;gap:3px;align-items:center}
.focus-timeline{position:relative;height:44px;background:var(--surface2);border-radius:8px;overflow:hidden;margin-top:8px}
.focus-block{position:absolute;top:8px;height:28px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;font-family:var(--font-mono);color:rgba(0,0,0,.7);cursor:default}
.focus-axis{display:flex;justify-content:space-between;padding:0 2px;margin-top:4px}
.focus-axis span{font-size:9px;color:var(--dim);font-family:var(--font-mono)}
.focus-empty{text-align:center;color:var(--muted);font-size:12px;padding:14px 0;font-style:italic}
.score-ring-wrap{display:flex;flex-direction:column;align-items:center;gap:6px;padding:4px 0}
.score-label{font-size:11px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.score-ring{position:relative;width:100px;height:100px}.score-ring svg{transform:rotate(-90deg)}
.score-inner{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.score-num{font-size:26px;font-weight:800;font-family:var(--font-mono);color:var(--violet)}.score-max{font-size:10px;color:var(--muted)}.score-title{font-size:12px;font-weight:700;color:var(--violet)}
.fun-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:10px;margin-top:8px}
.fun-card{background:var(--surface2);border:1px solid var(--border);border-radius:10px;padding:12px;display:flex;flex-direction:column;gap:4px}
.fun-icon{font-size:12px;font-weight:700;color:var(--muted);font-family:var(--font-mono)}.fun-stat{font-size:17px;font-weight:800;font-family:var(--font-mono);color:var(--fg)}.fun-desc{font-size:11px;color:var(--muted)}
.split{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}.split>*{flex:1 1 300px;min-width:0}
.hist{display:flex;flex-direction:column;gap:5px}.histRow{display:flex;gap:10px;align-items:center}.histRow .lab{width:90px;font-size:12px;color:var(--fg);flex-shrink:0}.histRow .track{flex:1;height:8px;border-radius:999px;background:rgba(184,136,46,.08);overflow:hidden}.histRow .fill{height:100%;background:var(--accent);border-radius:999px}.histRow .n{width:50px;text-align:right;font-variant-numeric:tabular-nums;color:var(--muted);font-size:12px;flex-shrink:0}
.boxlist{display:flex;flex-direction:column;gap:8px}.boxRow{display:flex;gap:10px;align-items:center}.boxRow .lab{width:80px;font-size:12px;color:var(--fg);flex-shrink:0}.boxRow .track{position:relative;flex:1;height:14px;border-radius:999px;background:rgba(184,136,46,.08)}.boxRow .iqr{position:absolute;top:3px;height:8px;border-radius:6px;background:rgba(184,136,46,.4)}.boxRow .med{position:absolute;top:1px;width:2px;height:12px;background:var(--accent);border-radius:2px}.boxRow .n{width:60px;text-align:right;font-variant-numeric:tabular-nums;color:var(--muted);font-size:12px;flex-shrink:0}
table{width:100%;border-collapse:collapse;font-size:12px}th,td{text-align:left;padding:8px;border-bottom:1px solid var(--border);vertical-align:top}th{color:var(--muted);font-weight:700;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em}tr:last-child td{border-bottom:none}code{font-family:var(--font-mono);font-size:11.5px}
details{border:1px solid var(--border);border-radius:10px;background:var(--card);margin-bottom:6px}
summary{cursor:pointer;padding:12px 16px;line-height:1.4;list-style:none;display:flex;align-items:center;gap:10px;user-select:none}
summary::-webkit-details-marker{display:none}.s-arrow{display:inline-block;width:16px;height:16px;color:var(--muted);flex-shrink:0;font-style:normal;transition:transform .15s;text-align:center;line-height:16px;font-size:10px}
details[open] .s-arrow{transform:rotate(90deg)}summary strong{font-size:13px;font-weight:600}.detailsBody{padding:0 16px 16px}.proj-meta{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:8px;font-size:12px;color:var(--muted)}.proj-recent li{font-size:12px;margin-bottom:3px;color:var(--fg)}
.agent-kpi{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:8px}.agent-kpi-card{background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:10px 14px;min-width:120px}.agent-kpi-card h3{margin:0 0 4px;font-size:10px;color:var(--muted);font-weight:700;text-transform:uppercase;letter-spacing:.06em}.agent-kpi-card .val{font-size:22px;font-weight:700;font-family:var(--font-mono)}
.kchip{display:inline-block;padding:1px 6px;border-radius:4px;font-size:10px;font-weight:600;background:var(--chip);color:var(--accent);border:1px solid var(--gold-dim);margin:1px}
.tooltip{position:fixed;z-index:50;pointer-events:none;background:var(--surface3);border:1px solid var(--border);border-radius:10px;padding:10px 12px;max-width:320px;box-shadow:0 16px 48px rgba(0,0,0,.45);display:none}.tooltip .t{font-size:12px;color:var(--fg);font-weight:700}.tooltip .m{font-size:12px;color:var(--muted);margin-top:6px;white-space:pre-line}
#ddTip{position:fixed;z-index:51;pointer-events:none;background:var(--surface3);border:1px solid var(--border);border-radius:10px;padding:10px 12px;max-width:280px;box-shadow:0 16px 48px rgba(0,0,0,.45);display:none}#ddTip .tt{font-size:12px;font-weight:700;color:var(--fg)}#ddTip .tm{font-size:12px;color:var(--muted);margin-top:5px;white-space:pre-line}
.microbar-wrap{display:flex;gap:4px;align-items:flex-end;height:70px;margin-top:10px}.microbar-col{display:flex;flex-direction:column;align-items:center;flex:1;gap:3px;min-width:0}.microbar-bar{width:100%;background:var(--accent);border-radius:3px 3px 0 0;min-height:2px}.microbar-label{font-size:9px;color:var(--muted);text-align:center;white-space:nowrap;overflow:hidden;width:100%}
.tag{display:inline-block;padding:1px 7px;border-radius:999px;font-size:10px;font-weight:700;border:1px solid}.tag-violet{background:var(--surface3);border-color:rgba(138,98,192,.3);color:var(--violet)}.tag-gold{background:var(--gold-dim);border-color:var(--gold-glow);color:var(--gold)}
</style>
</head>
<body><main>
<header>
  <div class="brand">
    <div class="brand-badge">VaultWares</div>
    <div><h1>Work <span>Impact</span></h1><div class="meta-row">Generated <span id="generated"></span> &nbsp;&middot;&nbsp; <span id="range"></span></div></div>
  </div>
  <div class="header-right">
    <div class="lang"><span>Language</span><div class="toggle" role="group"><button id="lang-en" type="button" aria-pressed="false">EN</button><button id="lang-qc" type="button" aria-pressed="false">QC</button></div></div>
    <div>
      <div class="range-row"><label>Activity range</label><button class="range-btn" data-range="1">Today</button><button class="range-btn" data-range="7">7 days</button><button class="range-btn active" data-range="30">30 days</button><button class="range-btn" data-range="90">90 days</button><button class="range-btn" data-range="custom">Custom</button></div>
      <div class="custom-row" id="customRow"><input type="date" id="customFrom"><span style="color:var(--muted);font-size:11px">to</span><input type="date" id="customTo"><button onclick="applyCustom()">Apply</button></div>
    </div>
  </div>
</header>
<p class="kicker" id="intro" data-i18n="intro"></p>
<section>
  <div class="grid">
    <div class="led-card led-gold span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Keystrokes</div></div><div class="led-value" id="v-keys">--</div><div class="led-sub" id="s-keys"></div></div>
    <div class="led-card led-violet span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Mouse Travel</div></div><div class="led-value" id="v-mouse">--<span class="led-unit">m</span></div><div class="led-sub" id="s-mouse"></div></div>
    <div class="led-card led-green span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Saves</div></div><div class="led-value" id="v-saves">--</div><div class="led-sub" id="s-saves"></div></div>
    <div class="led-card led-amber span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Copies</div></div><div class="led-value" id="v-copies">--</div><div class="led-sub" id="s-copies"></div></div>
    <div class="led-card led-orange span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Chars Typed</div></div><div class="led-value" id="v-chars">--</div><div class="led-sub" id="s-chars"></div></div>
    <div class="led-card led-red span2"><div class="led-header"><div class="led-dot"></div><div class="led-label">Pastes</div></div><div class="led-value" id="v-pastes">--</div><div class="led-sub" id="s-pastes"></div></div>
  </div>
</section>
<section class="grid">
  <div class="card span3"><h2 data-i18n="metricEvents">Work entries</h2><div class="big big-accent" id="m-events">0</div></div>
  <div class="card span3"><h2 data-i18n="metricDays">Active days</h2><div class="big" id="m-days">0</div></div>
  <div class="card span3"><h2 data-i18n="metricProjects">Projects touched</h2><div class="big" id="m-projects">0</div></div>
  <div class="card span3"><h2 data-i18n="metricStreak">Current streak</h2><div class="big" id="m-streak">0</div><div class="sub" id="m-streak-sub"></div></div>
  <div class="card span3"><h2 data-i18n="metricLongestStreak">Longest streak</h2><div class="big" id="m-longest">0</div></div>
  <div class="card span3"><h2 data-i18n="metricBusiestDay">Busiest day</h2><div class="big" id="m-bday">-</div><div class="sub" id="m-bday-sub"></div></div>
  <div class="card span3"><h2 data-i18n="metricBusiestWeek">Busiest week</h2><div class="big" id="m-bweek">-</div><div class="sub" id="m-bweek-sub"></div></div>
  <div class="card span3"><h2 data-i18n="commitStatSamples">Commits sampled</h2><div class="big" id="m-commits">0</div><div class="sub" id="m-commits-sub"></div></div>
</section>
<section><h2 id="hourlyTitle">Hourly Activity</h2><div class="card span12"><div class="chart-wrap"><canvas id="hourlyChart"></canvas></div></div></section>
<section>
  <div class="grid">
    <div class="card span9">
      <div class="row"><div><h2 style="margin:0" data-i18n="calendarTitle">Work activity by day</h2><div class="sub" data-i18n="calendarHint">Hover a square to see that day.</div></div><div class="heatLegend"><span data-i18n="less">Less</span><span class="legendSwatch"><span class="cell"></span><span class="cell lvl1"></span><span class="cell lvl2"></span><span class="cell lvl3"></span><span class="cell lvl4"></span></span><span data-i18n="more">More</span></div></div>
      <div class="heatWrap"><div id="heat" class="heat"></div></div>
      <div class="tooltip" id="tip"><div class="t" id="tip-title"></div><div class="m" id="tip-meta"></div></div>
    </div>
    <div class="card span3" style="display:flex;flex-direction:column;align-items:center;justify-content:center">
      <div class="score-ring-wrap">
        <div class="score-label">Deep Work Score</div>
        <div class="score-ring"><svg width="100" height="100" viewBox="0 0 100 100"><circle cx="50" cy="50" r="42" fill="none" stroke="rgba(138,98,192,0.12)" stroke-width="9"/><circle id="scoreArc" cx="50" cy="50" r="42" fill="none" stroke="var(--violet)" stroke-width="9" stroke-linecap="round" stroke-dasharray="264" stroke-dashoffset="264" style="transition:stroke-dashoffset 1s ease"/></svg><div class="score-inner"><div class="score-num" id="scoreNum">--</div><div class="score-max">/100</div></div></div>
        <div class="score-title" id="scoreTitle">--</div><div style="font-size:11px;color:var(--muted);text-align:center;max-width:130px" id="scoreDesc"></div>
      </div>
    </div>
  </div>
</section>
<section><div class="grid"><div class="card span6"><h2>Daily Keystroke Trend</h2><div class="chart-wrap-sm"><canvas id="trendChart"></canvas></div></div><div class="card span6"><h2>Time-of-Day Rhythm (avg keystrokes/hr)</h2><div class="chart-wrap-sm"><canvas id="rhythmChart"></canvas></div></div></div></section>
<section><div class="card span12"><h2>Focus Blocks -- Today <span class="tag tag-violet" style="margin-left:6px">&gt;= 1 hr uninterrupted</span></h2><div class="focus-timeline" id="focusTimeline"></div><div class="focus-axis"><span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>23:59</span></div></div></section>
<section class="grid"><div class="card span6"><h2 data-i18n="monthlyTitle">Work recorded per month</h2><div class="barlist" id="monthlyBars"></div></div><div class="card span6"><h2>AI Model Usage</h2><div class="chart-wrap-sm"><canvas id="modelChart"></canvas></div></div></section>
<section class="grid"><div class="card span4"><h2 data-i18n="projectsTitle">Top projects by activity</h2><div class="barlist" id="projectBars"></div></div><div class="card span4"><h2 data-i18n="kindsTitle">What kind of work</h2><div class="chart-wrap-sm"><canvas id="kindsChart"></canvas></div></div><div class="card span4"><h2>Context Switches per Day</h2><div class="chart-wrap-sm"><canvas id="switchChart"></canvas></div></div></section>
<section><h2>Fun Stats</h2><div class="fun-grid" id="funFacts"></div></section>
<section class="card"><h2 data-i18n="commitSizeTitle">Commit size (clean churn lines)</h2><div class="sub" data-i18n="commitSizeHint"></div><div id="commitSizeContent" style="margin-top:10px"></div></section>
<section class="grid"><div class="card span6"><h2 data-i18n="techTitle">Technical volume</h2><div class="sub" data-i18n="techHint"></div><div id="techVolumeContent" style="margin-top:8px"></div></div><div class="card span6"><h2 data-i18n="filesTouchedTitle">Files touched per commit</h2><div id="filesTouchedContent"></div><div style="margin-top:14px"><h2 data-i18n="concentrationTitle">Work concentration</h2><div class="sub" data-i18n="concentrationHint"></div><div class="barlist" id="concentrationBars" style="margin-top:8px"></div></div></div></section>
<section class="grid"><div class="card span4"><h2 data-i18n="hlMostConsistentMonth">Most consistent month</h2><div class="big" id="hl-consistent">-</div><div class="sub" id="hl-consistent-sub"></div></div><div class="card span4"><h2 data-i18n="hlWidestProjectDay">Widest project spread</h2><div class="big" id="hl-spread">-</div><div class="sub" id="hl-spread-sub"></div></div><div class="card span4"><h2 data-i18n="hlStrongestWeek">Strongest week</h2><div class="big" id="hl-week">-</div><div class="sub" id="hl-week-sub"></div></div><div class="card span6"><h2 data-i18n="hlMilestones">Milestones</h2><div class="barlist" id="hl-milestones" style="margin-top:6px"></div></div><div class="card span6"><h2 data-i18n="highlightsTitle">Top projects</h2><div class="barlist" id="hl-top-projects" style="margin-top:6px"></div></div></section>
<section class="grid"><div class="card span12"><h2 data-i18n="activityTitle">When work happens -- day of week</h2><div class="microbar-wrap" id="dowChart"></div></div></section>
<section class="card" id="agentSection" style="display:none"><div class="row" style="margin-bottom:10px"><div><h2 style="margin:0" data-i18n="agentTitle">Agent activity</h2><div class="sub" data-i18n="agentHint"></div></div><span class="pill" id="agentPill">0 events</span></div><div class="agent-kpi" id="agentKpi"></div><div class="grid" style="margin-top:12px"><div class="card span6" style="padding:10px 12px"><h2>Tools used</h2><div class="barlist" id="agentTools"></div></div><div class="card span6" style="padding:10px 12px"><h2>MCP servers &amp; actors</h2><div class="barlist" id="agentMcp"></div><div class="barlist" id="agentActors" style="margin-top:12px"></div></div></div><div style="margin-top:12px"><h2>Agent activity by day</h2><div class="barlist" id="agentDays"></div></div></section>
<section><h2 style="font-size:14px;font-weight:700;color:var(--fg);margin:0 0 10px;display:flex;align-items:center;gap:10px"><span data-i18n="evidenceTitle">Activity by project</span><span style="flex:1;height:1px;background:var(--border)"></span></h2><p class="sub" data-i18n="evidenceHint" style="margin:0 0 10px"></p><div id="projectCards"></div></section>
<div id="ddTip"><div class="tt" id="ddTipTitle"></div><div class="tm" id="ddTipBody"></div></div>
<script>
const PAYLOAD=__PAYLOAD_JSON__;
const I18N=__I18N_JSON__;
const ALIASES=__ALIAS_MAP_JSON__;
const INPUT_DAYS=__INPUT_DAYS__;
const LEDGER_EVENTS=__LEDGER_EVENTS__;
const GENERATED_AT="__GENERATED_AT__";
</script>
<script>
const dayMap={};for(const d of INPUT_DAYS)dayMap[d.date]=d;
let activeRange=30,customFrom,customTo;
function dateStr(d){return d.toISOString().slice(0,10);}
function parseDateStr(s){const[y,m,dy]=s.split('-');return new Date(y,m-1,dy);}
function rangeWindow(){const today=new Date();today.setHours(23,59,59,999);if(activeRange===0)return{from:customFrom||today,to:customTo||today};const from=new Date(today);from.setDate(from.getDate()-(activeRange-1));from.setHours(0,0,0,0);return{from,to:today};}
function daysInRange(r){const out=[],cur=new Date(r.from);cur.setHours(0,0,0,0);while(cur<=r.to){out.push(dateStr(cur));cur.setDate(cur.getDate()+1);}return out;}
function sumField(days,field){let t=0;for(const d of days){const row=dayMap[d];if(!row)continue;for(const h of row.hourly)t+=(h[field]||0);}return t;}
function hourlyAvg(days,field){const tots=new Array(24).fill(0),cnts=new Array(24).fill(0);for(const d of days){const row=dayMap[d];if(!row)continue;for(const h of row.hourly){tots[h.hour]+=(h[field]||0);cnts[h.hour]++;}}return tots.map((v,i)=>cnts[i]?v/cnts[i]:0);}
function hourlySum(day,field){const row=dayMap[day];if(!row)return new Array(24).fill(0);const out=new Array(24).fill(0);for(const h of row.hourly)out[h.hour]=(h[field]||0);return out;}
function dailyTotals(days,field){return days.map(d=>{const row=dayMap[d];return row?row.hourly.reduce((s,h)=>s+(h[field]||0),0):0;});}
function ledgerInRange(range){const f=dateStr(range.from).slice(0,10),t=dateStr(range.to).slice(0,10);return LEDGER_EVENTS.filter(e=>e.date>=f&&e.date<=t);}
function countBy(arr,key){const m={};for(const x of arr){const v=x[key]||'unknown';m[v]=(m[v]||0)+1;}return m;}
function countByKinds(arr){const m={};for(const x of arr){for(const k of(x.kind||'general').split(',')){const v=k.trim()||'general';m[v]=(m[v]||0)+1;}}return m;}
const ddTip=document.getElementById('ddTip');
function showTip(e,title,body){document.getElementById('ddTipTitle').textContent=title;document.getElementById('ddTipBody').textContent=body;ddTip.style.display='block';moveTip(e);}
function moveTip(e){ddTip.style.left=Math.min(e.clientX+14,innerWidth-290)+'px';ddTip.style.top=Math.max(e.clientY-10,4)+'px';}
function hideTip(){ddTip.style.display='none';}
Chart.defaults.color='rgba(216,208,240,0.48)';Chart.defaults.borderColor='rgba(255,255,255,0.07)';Chart.defaults.font.family='"Inter","Segoe UI",sans-serif';Chart.defaults.font.size=11;
const DONUT_COLORS=['#b8882e','#8a62c0','#4e9954','#c49840','#a86840','#a84e5a','#9a7428','#6a4aa0','#3a7840','#8a5830'];
const barOpts={responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{x:{grid:{color:'rgba(255,255,255,0.04)'}},y:{grid:{color:'rgba(255,255,255,0.04)'},beginAtZero:true}}};
function mkC(id,cfg){return new Chart(document.getElementById(id).getContext('2d'),cfg);}
let hourlyC,trendC,rhythmC,modelC,kindsC,switchC;
function initCharts(){
  hourlyC=mkC('hourlyChart',{type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:[],borderRadius:4,borderSkipped:false}]},options:{...barOpts,plugins:{...barOpts.plugins,tooltip:{callbacks:{label:c=>' '+Number(c.parsed.y).toLocaleString()+' keystrokes'}}}}});
  trendC=mkC('trendChart',{type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:'rgba(184,136,46,0.55)',borderRadius:3,borderSkipped:false}]},options:barOpts});
  rhythmC=mkC('rhythmChart',{type:'bar',data:{labels:Array.from({length:24},(_,i)=>i+'h'),datasets:[{data:[],backgroundColor:'rgba(138,98,192,0.55)',borderRadius:3,borderSkipped:false}]},options:barOpts});
  modelC=mkC('modelChart',{type:'doughnut',data:{labels:[],datasets:[{data:[],backgroundColor:DONUT_COLORS,borderWidth:0,hoverOffset:8}]},options:{responsive:true,maintainAspectRatio:false,cutout:'62%',plugins:{legend:{position:'bottom',labels:{boxWidth:10,padding:10,font:{size:10}}}}}});
  kindsC=mkC('kindsChart',{type:'doughnut',data:{labels:[],datasets:[{data:[],backgroundColor:DONUT_COLORS,borderWidth:0,hoverOffset:8}]},options:{responsive:true,maintainAspectRatio:false,cutout:'62%',plugins:{legend:{position:'bottom',labels:{boxWidth:10,padding:10,font:{size:10}}}}}});
  switchC=mkC('switchChart',{type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:'rgba(184,136,46,0.5)',borderRadius:3,borderSkipped:false}]},options:barOpts});
}
function render(){
  const range=rangeWindow(),days=daysInRange(range),today=dateStr(new Date());
  const totKeys=sumField(days,'keystrokes'),totMouse=sumField(days,'mouse_distance_m');
  const totSaves=sumField(days,'saves'),totCopies=sumField(days,'copies');
  const totChars=sumField(days,'chars_typed'),totPastes=sumField(days,'pastes'),totPasted=sumField(days,'chars_pasted');
  const activeDays=Math.max(days.filter(d=>dayMap[d]).length,1);
  const n=(v)=>Number(v).toLocaleString(),nd=(v,dp=1)=>Number(v).toLocaleString(undefined,{maximumFractionDigits:dp});
  document.getElementById('v-keys').innerHTML=n(totKeys);
  document.getElementById('s-keys').textContent=activeDays>1?'~'+n(Math.round(totKeys/activeDays))+' / day':'';
  document.getElementById('v-mouse').innerHTML=nd(totMouse)+'<span class="led-unit">m</span>';
  document.getElementById('s-mouse').textContent=totMouse>=1000?nd(totMouse/1000,2)+' km total':'';
  document.getElementById('v-saves').innerHTML=n(totSaves);
  document.getElementById('s-saves').textContent=activeDays>1?'~'+nd(totSaves/activeDays,1)+' / day':'';
  document.getElementById('v-copies').innerHTML=n(totCopies);
  document.getElementById('s-copies').textContent=totPastes?totPastes+' pastes':'';
  document.getElementById('v-chars').innerHTML=n(totChars);
  document.getElementById('s-chars').textContent=totChars?'~'+n(Math.round(totChars/5))+' words':'';
  document.getElementById('v-pastes').innerHTML=n(totPastes);
  document.getElementById('s-pastes').textContent=totPasted?n(totPasted)+' chars':'';
  let hData;
  if(days.length===1){hData=hourlySum(days[0],'keystrokes');document.getElementById('hourlyTitle').textContent='Hourly Activity -- '+days[0];}
  else{hData=hourlyAvg(days,'keystrokes');document.getElementById('hourlyTitle').textContent='Avg Hourly Activity -- '+days.length+' days';}
  const maxH=Math.max(...hData,1);
  hourlyC.data.labels=Array.from({length:24},(_,i)=>i+'h');
  hourlyC.data.datasets[0].data=hData;
  hourlyC.data.datasets[0].backgroundColor=hData.map(v=>{const r=v/maxH;return r>.75?'rgba(184,136,46,0.9)':r>.5?'rgba(184,136,46,0.65)':r>.25?'rgba(184,136,46,0.42)':'rgba(184,136,46,0.2)';});
  hourlyC.update();
  const tLabels=days.length>60?days.filter((_,i)=>i%2===0):days;
  trendC.data.labels=tLabels;trendC.data.datasets[0].data=dailyTotals(days,'keystrokes').filter((_,i)=>days.length<=60||i%2===0);trendC.update();
  rhythmC.data.datasets[0].data=hourlyAvg(days,'keystrokes');rhythmC.update();
  const events=ledgerInRange(range);
  buildDonut(modelC,countBy(events,'model'));buildDonut(kindsC,countByKinds(events));buildSwitchChart(days,events);
  buildScore(today);buildFocus(today);buildFun(totKeys,totMouse,totSaves,totCopies,totChars,totPastes,totPasted,activeDays);
}
function buildDonut(chart,counts){const e=Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,10);chart.data.labels=e.map(x=>x[0]);chart.data.datasets[0].data=e.map(x=>x[1]);chart.update();}
function buildSwitchChart(days,events){const byDate={};for(const e of events){if(!byDate[e.date])byDate[e.date]=new Set();byDate[e.date].add(e.project);}const labels=days.length>60?days.filter((_,i)=>i%2===0):days;switchC.data.labels=labels;switchC.data.datasets[0].data=labels.map(d=>byDate[d]?Math.max(0,byDate[d].size-1):0);switchC.update();}
function buildScore(today){const row=dayMap[today];if(!row){document.getElementById('scoreNum').textContent='--';document.getElementById('scoreTitle').textContent='No data';return;}const hourlyK=row.hourly.map(h=>h.keystrokes||0),totalK=hourlyK.reduce((a,b)=>a+b,0);let maxBlock=0,cur=0;for(const k of hourlyK){if(k>30){cur++;if(cur>maxBlock)maxBlock=cur;}else cur=0;}const saves=row.hourly.reduce((s,h)=>s+(h.saves||0),0);const score=Math.min(100,Math.round(Math.min(40,maxBlock*8)+Math.min(30,Math.floor(totalK/100))+Math.min(15,Math.floor((saves/Math.max(totalK,1))*3000))+Math.max(0,15-(new Set(LEDGER_EVENTS.filter(e=>e.date===today).map(e=>e.project)).size-1)*3)));document.getElementById('scoreNum').textContent=score;document.getElementById('scoreArc').style.strokeDashoffset=264*(1-score/100);const titles={80:'Elite',60:'Strong',40:'Solid',20:'Warming up',0:'Quiet day'};const t=Object.entries(titles).sort((a,b)=>b[0]-a[0]).find(([k])=>score>=+k)[1];document.getElementById('scoreTitle').textContent=t;document.getElementById('scoreDesc').textContent={Elite:'Peak focus. In the zone.',Strong:'Great session.',Solid:'Good work.','Warming up':'Light day.','Quiet day':'Rest is productive.'}[t];}
function buildFocus(today){const tl=document.getElementById('focusTimeline');tl.innerHTML='';const row=dayMap[today];if(!row){tl.innerHTML='<div class="focus-empty">No input data for today yet.</div>';return;}const hourlyK=row.hourly.map(h=>h.keystrokes||0);const COLORS=['#b8882e','#8a62c0','#4e9954','#c49840','#a86840'];let blocks=[],s=-1;for(let h=0;h<24;h++){if(hourlyK[h]>30){if(s===-1)s=h;}else{if(s!==-1){blocks.push({start:s,end:h});s=-1;}}}if(s!==-1)blocks.push({start:s,end:24});blocks=blocks.filter(b=>b.end-b.start>=1);if(!blocks.length){tl.innerHTML='<div class="focus-empty">No focus blocks detected today.</div>';return;}blocks.forEach(function(b,i){const div=document.createElement('div');div.className='focus-block';div.style.cssText='left:'+(b.start/24*100).toFixed(1)+'%;width:'+((b.end-b.start)/24*100).toFixed(1)+'%;background:'+COLORS[i%COLORS.length]+';';div.textContent=(b.end-b.start)+'h';div.title=b.start+':00 - '+b.end+':00';tl.appendChild(div);});}
function buildFun(keys,mouseM,saves,copies,chars,pastes,pastedChars,activeDays){const n=(v)=>Number(v).toLocaleString(),nd=(v,d=1)=>Number(v).toLocaleString(undefined,{maximumFractionDigits:d});const facts=[];if(chars>0)facts.push({i:'[pg]',s:nd(Math.round(chars/5)/250,1)+' pages',d:'of text typed'});if(mouseM>0)facts.push({i:'[mv]',s:mouseM>=1000?nd(mouseM/1000,2)+' km':nd(mouseM)+' m',d:'mouse travel distance'});if(mouseM>=42195)facts.push({i:'[run]',s:nd(mouseM/1000/42.195,3)+'x',d:'a marathon in mouse movement'});if(saves>0)facts.push({i:'[sv]',s:n(saves),d:'times you saved your work'});if(copies>0&&pastes>0)facts.push({i:'[cp]',s:nd(copies/pastes,2)+'x',d:'copy-to-paste ratio'});if(chars>0)facts.push({i:'[wpm]',s:nd((chars/5)/(activeDays*8*60),1)+' WPM',d:'est. typing speed'});if(keys>=500000)facts.push({i:'[kbd]',s:nd(keys/500000,4)+'x',d:'a novel worth of keystrokes'});if(pastedChars>0)facts.push({i:'[in]',s:n(pastedChars),d:'characters pasted'});const el=document.getElementById('funFacts');if(!facts.length){el.innerHTML='<div class="no-data">Start the input tracker to unlock fun stats.</div>';return;}el.innerHTML=facts.map(function(f){return'<div class="fun-card"><div class="fun-icon">'+f.i+'</div><div class="fun-stat">'+f.s+'</div><div class="fun-desc">'+f.d+'</div></div>';}).join('');}
document.querySelectorAll('.range-btn').forEach(function(btn){btn.addEventListener('click',function(){document.querySelectorAll('.range-btn').forEach(function(b){b.classList.remove('active');});btn.classList.add('active');const r=btn.dataset.range;document.getElementById('customRow').classList.toggle('visible',r==='custom');if(r!=='custom'){activeRange=parseInt(r);render();}});});
function applyCustom(){const f=document.getElementById('customFrom').value,t=document.getElementById('customTo').value;if(!f||!t)return;activeRange=0;customFrom=parseDateStr(f);customTo=parseDateStr(t);customTo.setHours(23,59,59,999);render();}
(function(){
  const data=PAYLOAD.data;
  const clampInt=(v)=>Number.isFinite(v)?Math.trunc(v):0;
  const fmtInt=(n)=>new Intl.NumberFormat(undefined).format(clampInt(n));
  const fmt1=(n)=>new Intl.NumberFormat(undefined,{maximumFractionDigits:1}).format(n);
  const fmtSigned=(n)=>(n>=0?"+":"")+fmtInt(n);
  const esc=(s)=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;");
  const supported=Object.keys(I18N);let saved=null;try{saved=localStorage.getItem("workImpactLang");}catch{}
  const browser=(navigator.language||"en").toLowerCase();
  let lang=(saved&&supported.includes(saved))?saved:(browser.startsWith("fr")?"qc":"en");
  if(!supported.includes(lang))lang=supported[0]||"en";
  const setLang=(next)=>{lang=next;try{localStorage.setItem("workImpactLang",lang);}catch{}document.getElementById("lang-en").setAttribute("aria-pressed",String(lang==="en"));document.getElementById("lang-qc").setAttribute("aria-pressed",String(lang==="qc"));applyI18n();renderAll();};
  const t=(key)=>(I18N[lang]&&I18N[lang][key])?I18N[lang][key]:key;
  function applyI18n(){document.querySelectorAll("[data-i18n]").forEach(el=>{el.textContent=t(el.getAttribute("data-i18n"));});document.title=t("title");}
  document.getElementById("lang-en").addEventListener("click",()=>setLang("en"));
  document.getElementById("lang-qc").addEventListener("click",()=>setLang("qc"));
  document.getElementById("generated").textContent=data.generatedAtLocal||"";
  document.getElementById("range").textContent=(data.range?.start||"")+" to "+(data.range?.end||"");
  function parseLocalDate(s){if(!s)return null;const d=new Date(s+"T00:00:00");return Number.isNaN(d.getTime())?null:d;}
  function dayKey(d){return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0");}
  function addDays(d,n){const out=new Date(d);out.setDate(out.getDate()+n);return out;}
  const daySeries=Array.isArray(data.series?.days)?data.series.days:[];
  const activeDaysSet=new Set(daySeries.map(d=>d.day));
  function computeStreaks(){if(activeDaysSet.size===0)return{current:0,longest:0};const end=parseLocalDate(data.range?.end)||new Date();let cur=0;for(let i=0;i<4000;i++){const k=dayKey(addDays(end,-i));if(activeDaysSet.has(k))cur++;else break;}const daysSorted=Array.from(activeDaysSet).sort();let longest=1,run=1;for(let i=1;i<daysSorted.length;i++){const prev=parseLocalDate(daysSorted[i-1]),now=parseLocalDate(daysSorted[i]);if(!prev||!now)continue;const diff=Math.round((now-prev)/(24*3600*1000));if(diff===1){run++;if(run>longest)longest=run;}else run=1;}return{current:cur,longest};}
  function computeBusiest(){let busiestDay=null;for(const d of daySeries){if(!busiestDay||(d.entries||0)>(busiestDay.entries||0))busiestDay=d;}const weekCounts=new Map();for(const d of daySeries){const dt=parseLocalDate(d.day);if(!dt)continue;const dow=(dt.getDay()+6)%7;const monday=addDays(dt,-dow);const wk=dayKey(monday);weekCounts.set(wk,(weekCounts.get(wk)||0)+(d.entries||0));}let busiestWeek=null;for(const[wk,count]of weekCounts){if(!busiestWeek||count>busiestWeek.count)busiestWeek={wk,count};}return{busiestDay,busiestWeek};}
  function quantile(sorted,q){if(sorted.length===0)return 0;const pos=(sorted.length-1)*q,base=Math.floor(pos),rest=pos-base;if(sorted[base+1]===undefined)return sorted[base];return sorted[base]+rest*(sorted[base+1]-sorted[base]);}
  function histogramBuckets(values){const edges=[0,10,25,50,100,200,400,800,1600,3200,6400];const bins=edges.map((lo,i)=>({lo,hi:edges[i+1],count:0}));bins.push({lo:edges[edges.length-1],hi:null,count:0});for(const v of values){const n=Math.max(0,Math.floor(v));let placed=false;for(const b of bins){if(b.hi===null){b.count++;placed=true;break;}if(n>=b.lo&&n<b.hi){b.count++;placed=true;break;}}if(!placed)bins[bins.length-1].count++;}return bins;}
  function makeBar(label,count,max,container,colorClass){const row=document.createElement("div");row.className="bar"+(colorClass?" "+colorClass:"");const lab=document.createElement("label");lab.title=label;lab.textContent=label;const track=document.createElement("div");track.className="track";const fill=document.createElement("div");fill.className="fill";fill.style.width=(max?(count/max*100):0).toFixed(2)+"%";track.appendChild(fill);const n=document.createElement("div");n.className="n";n.textContent=fmtInt(count);row.appendChild(lab);row.appendChild(track);row.appendChild(n);container.appendChild(row);}
  function makeBarFrac(label,value,max,container,suffix){const row=document.createElement("div");row.className="bar";const lab=document.createElement("label");lab.title=label;lab.textContent=label;const track=document.createElement("div");track.className="track";const fill=document.createElement("div");fill.className="fill";fill.style.width=(max?(value/max*100):0).toFixed(2)+"%";track.appendChild(fill);const n=document.createElement("div");n.className="n";n.textContent=fmt1(value)+(suffix?" "+suffix:"");row.appendChild(lab);row.appendChild(track);row.appendChild(n);container.appendChild(row);}
  function renderHeatmap(){const heat=document.getElementById("heat");heat.innerHTML="";const tip=document.getElementById("tip"),tipTitle=document.getElementById("tip-title"),tipMeta=document.getElementById("tip-meta");const start=parseLocalDate(data.range?.start),end=parseLocalDate(data.range?.end);if(!start||!end)return;const startDow=start.getDay(),alignedStart=addDays(start,-startDow);const byDay=new Map(daySeries.map(d=>[d.day,d]));const daysTotal=Math.round((end-alignedStart)/(24*3600*1000))+1,weeks=Math.ceil(daysTotal/7);const counts=daySeries.map(d=>d.entries||0),sorted=[...counts].sort((a,b)=>a-b);const q1=quantile(sorted,0.25),q2=quantile(sorted,0.50),q3=quantile(sorted,0.75);function level(c){if(c<=0)return 0;if(c<=q1)return 1;if(c<=q2)return 2;if(c<=q3)return 3;return 4;}for(let w=0;w<weeks;w++){const col=document.createElement("div");col.className="heatCol";for(let r=0;r<7;r++){const dt=addDays(alignedStart,w*7+r),key=dayKey(dt);const cell=document.createElement("div"),rec=byDay.get(key),c=rec?(rec.entries||0):0;cell.className="cell"+(c>0?(" lvl"+level(c)):"");cell.setAttribute("aria-label",key+": "+c);cell.addEventListener("mouseenter",(ev)=>{const dict=I18N[lang],projects=rec?.projects||[],kindsObj=rec?.kinds||{};const kindParts=Object.keys(kindsObj).sort().map(k=>(dict.kindLabels?.[k]||k)+": "+fmtInt(kindsObj[k]));tipTitle.textContent=key+" · "+fmtInt(c)+" "+(dict.units?.entries||"entries");tipMeta.textContent=(projects.length?(dict.labelProjects+": "+projects.join(", ")):"")+(kindParts.length?("\n"+kindParts.join("\n")):"");tip.style.display="block";tip.style.left=(ev.clientX+12)+"px";tip.style.top=(ev.clientY+12)+"px";});cell.addEventListener("mouseleave",()=>{tip.style.display="none";});col.appendChild(cell);}heat.appendChild(col);}}
  function renderBars(){const monthlyBars=document.getElementById("monthlyBars");monthlyBars.innerHTML="";const months=Array.isArray(data.series?.months)?data.series.months.slice(-18):[];const mmax=Math.max(1,...months.map(x=>x.count||0));months.forEach(x=>makeBar(String(x.month),clampInt(x.count||0),mmax,monthlyBars));const projectBars=document.getElementById("projectBars");projectBars.innerHTML="";const projects=Array.isArray(data.series?.projects)?data.series.projects.slice(0,12):[];const pmax=Math.max(1,...projects.map(x=>x.entries||0));projects.forEach(x=>makeBar(String(x.project),clampInt(x.entries||0),pmax,projectBars));}
  function renderCommitStats(){const samples=Array.isArray(data.commitSamples)?data.commitSamples:[];const values=samples.map(s=>clampInt(s.cleanChurnLines||0));const totalSamples=samples.length,hasLineData=values.some(v=>v>0);document.getElementById("m-commits").textContent=fmtInt(totalSamples);document.getElementById("m-commits-sub").textContent=totalSamples?fmtInt(totalSamples)+" "+(I18N[lang]?.units?.commits||"commits"):"";const container=document.getElementById("commitSizeContent");container.innerHTML="";if(totalSamples===0){container.innerHTML='<div class="no-data">'+esc(t("noCommitData"))+'</div>';return;}if(!hasLineData){const note=document.createElement("div");note.className="info-note";note.textContent=t("commitLineDataUnavailable").replace("{n}",fmtInt(totalSamples));container.appendChild(note);return;}const sorted=[...values].sort((a,b)=>a-b),mean=sorted.reduce((a,b)=>a+b,0)/sorted.length,median=quantile(sorted,0.5);const bins=histogramBuckets(sorted),modeBin=bins.reduce((best,b)=>(b.count>(best?.count||-1)?b:best),null);const modeLabel=modeBin?(modeBin.hi===null?(modeBin.lo+"+"):(modeBin.lo+"-"+(modeBin.hi-1))):"-";const units=I18N[lang]?.units||{};container.innerHTML='<div class="split"></div>';const split=container.querySelector('.split');const leftDiv=document.createElement("div");const statsGrid=document.createElement("div");statsGrid.className="grid";statsGrid.innerHTML='<div class="card span4" style="padding:10px"><h2>'+t("commitStatMean")+'</h2><div class="big">'+fmt1(mean)+'<span style="font-size:14px;font-weight:400;opacity:.6"> '+(units.lines||"lines")+'</span></div></div><div class="card span4" style="padding:10px"><h2>'+t("commitStatMedian")+'</h2><div class="big">'+fmt1(median)+'<span style="font-size:14px;font-weight:400;opacity:.6"> '+(units.lines||"lines")+'</span></div></div><div class="card span4" style="padding:10px"><h2>'+t("commitStatMode")+'</h2><div class="big" style="font-size:18px">'+modeLabel+'</div></div>';leftDiv.appendChild(statsGrid);const histCard=document.createElement("div");histCard.className="card";histCard.style.marginTop="12px";histCard.innerHTML='<h2>'+t("commitHistTitle")+'</h2>';const histEl=document.createElement("div");histEl.className="hist";const hmax=Math.max(1,...bins.map(b=>b.count));bins.forEach(b=>{if(b.count===0)return;const lab=(b.hi===null)?(b.lo+"+"):(b.lo+"-"+(b.hi-1));const row=document.createElement("div");row.className="histRow";row.innerHTML='<div class="lab">'+lab+'</div><div class="track"><div class="fill" style="width:'+(b.count/hmax*100).toFixed(2)+'%"></div></div><div class="n">'+fmtInt(b.count)+'</div>';histEl.appendChild(row);});histCard.appendChild(histEl);leftDiv.appendChild(histCard);split.appendChild(leftDiv);const rightDiv=document.createElement("div");const byMonth=new Map();samples.forEach(s=>{const m=String(s.month||"");if(!m)return;if(!byMonth.has(m))byMonth.set(m,[]);byMonth.get(m).push(clampInt(s.cleanChurnLines||0));});const boxMonths=Array.from(byMonth.keys()).sort().slice(-12),globalMax=Math.max(1,quantile([...sorted],0.98));const boxCard=document.createElement("div");boxCard.className="card";boxCard.innerHTML='<h2>'+t("commitBoxTitle")+'</h2>';const boxEl=document.createElement("div");boxEl.className="boxlist";boxMonths.forEach(m=>{const vals=(byMonth.get(m)||[]).filter(v=>v>=0).sort((a,b)=>a-b);if(vals.length===0)return;const bq1=quantile(vals,0.25),bq2=quantile(vals,0.5),bq3=quantile(vals,0.75);const left=(bq1/globalMax)*100,width=((bq3-bq1)/globalMax)*100,med=(bq2/globalMax)*100;const row=document.createElement("div");row.className="boxRow";row.innerHTML='<div class="lab">'+m+'</div><div class="track"><div class="iqr" style="left:'+left.toFixed(2)+'%;width:'+Math.max(0.5,width).toFixed(2)+'%"></div><div class="med" style="left:'+med.toFixed(2)+'%"></div></div><div class="n">'+fmtInt(vals.length)+'</div>';boxEl.appendChild(row);});boxCard.appendChild(boxEl);rightDiv.appendChild(boxCard);const out=[...samples].sort((a,b)=>(b.cleanChurnLines||0)-(a.cleanChurnLines||0)).slice(0,5);const outCard=document.createElement("div");outCard.className="card";outCard.style.marginTop="12px";outCard.innerHTML='<h2>'+t("commitOutliersTitle")+'</h2>';const outEl=document.createElement("div");outEl.className="barlist";const omax=Math.max(1,...out.map(x=>x.cleanChurnLines||0));out.forEach(x=>{const label=(x.project?String(x.project):"?")+" "+String(x.commit||"").slice(0,10);makeBar(label,clampInt(x.cleanChurnLines||0),omax,outEl);});outCard.appendChild(outEl);rightDiv.appendChild(outCard);split.appendChild(rightDiv);}
  function renderTechVolume(){const container=document.getElementById("techVolumeContent");container.innerHTML="";const raw=data.lineStats?.raw||{insertions:0,deletions:0,files:0},clean=data.lineStats?.clean||{insertions:0,deletions:0,files:0},excl=data.lineStats?.excluded||{insertions:0,deletions:0,files:0};const hasData=(raw.insertions||0)+(raw.deletions||0)+(clean.insertions||0)+(clean.deletions||0)>0;if(!hasData){const note=document.createElement("div");note.className="info-note";note.textContent=t("lineStatsUnavailable");container.appendChild(note);return;}const dict=I18N[lang]||{};const addRow=(label,s)=>{const adds=clampInt(s.insertions||0),dels=clampInt(s.deletions||0),files=clampInt(s.files||0),churn=adds+dels,net=adds-dels;return'<tr><td>'+label+'</td><td>'+fmtInt(adds)+'</td><td>'+fmtInt(dels)+'</td><td>'+fmtInt(files)+'</td><td>'+fmtInt(churn)+'</td><td>'+fmtSigned(net)+'</td></tr>';};const tw=document.createElement("div");tw.style.overflow="auto";tw.innerHTML='<table><thead><tr><th>'+(dict.statType||"Metric")+'</th><th>'+(dict.statAdds||"Adds")+'</th><th>'+(dict.statDels||"Dels")+'</th><th>'+(dict.statFiles||"Files")+'</th><th>'+(dict.statChurn||"Churn")+'</th><th>'+(dict.statNet||"Net")+'</th></tr></thead><tbody>'+addRow(dict.labelClean||"Clean",clean)+addRow(dict.labelRaw||"Raw",raw)+addRow(dict.labelExcluded||"Excl",excl)+'</tbody></table>';container.appendChild(tw);const sub=document.createElement("div");sub.className="sub";sub.style.marginTop="8px";sub.textContent=(dict.statExcluded||"Excluded")+": "+fmtInt(clampInt(excl.insertions||0)+clampInt(excl.deletions||0));container.appendChild(sub);}
  function renderFilesTouched(){const container=document.getElementById("filesTouchedContent");container.innerHTML="";const samples=Array.isArray(data.commitSamples)?data.commitSamples:[];const files=samples.map(s=>clampInt(s.filesClean??s.filesTouched??0)),hasData=files.some(v=>v>0),totalSamples=files.length;if(totalSamples===0){container.innerHTML='<div class="no-data">'+esc(t("noCommitData"))+'</div>';return;}if(!hasData){const note=document.createElement("div");note.className="info-note";note.textContent=t("fileDataUnavailable").replace("{n}",fmtInt(totalSamples));container.appendChild(note);return;}const sorted=[...files].filter(v=>v>=0).sort((a,b)=>a-b);const mean=sorted.reduce((a,b)=>a+b,0)/sorted.length,median=quantile(sorted,0.5),p90=quantile(sorted,0.9),max=Math.max(1,...sorted);const units=I18N[lang]?.units||{};const el=document.createElement("div");el.className="barlist";makeBarFrac(t("commitStatMean"),mean,max,el,units.files||"files");makeBarFrac(t("commitStatMedian"),median,max,el,units.files||"files");makeBarFrac("P90",p90,max,el,units.files||"files");container.appendChild(el);}
  function renderConcentration(){const el=document.getElementById("concentrationBars");el.innerHTML="";const projects=Array.isArray(data.series?.projects)?data.series.projects:[];const total=projects.reduce((s,p)=>s+(p.entries||0),0);if(total<=0)return;const top=projects.slice(0,5),maxShare=Math.max(1,...top.map(p=>(p.entries||0)/total*100));top.forEach(p=>{const share=(p.entries||0)/total*100,label=String(p.project);const row=document.createElement("div");row.className="bar";const lab=document.createElement("label");lab.title=label;lab.textContent=label;const track=document.createElement("div");track.className="track";const fill=document.createElement("div");fill.className="fill";fill.style.width=(maxShare?(share/maxShare*100):0).toFixed(2)+"%";track.appendChild(fill);const n=document.createElement("div");n.className="n";n.textContent=fmt1(share)+"%";row.appendChild(lab);row.appendChild(track);row.appendChild(n);el.appendChild(row);});}
  function renderHighlights(){const monthToDays=new Map();for(const d of daySeries){const m=String(d.day||"").slice(0,7);if(!m)continue;if(!monthToDays.has(m))monthToDays.set(m,new Set());monthToDays.get(m).add(String(d.day));}let bestMonth=null;for(const[m,set]of monthToDays){if(!bestMonth||set.size>bestMonth.active)bestMonth={m,active:set.size};}if(bestMonth){document.getElementById("hl-consistent").textContent=bestMonth.m;document.getElementById("hl-consistent-sub").textContent=fmtInt(bestMonth.active)+" "+(I18N[lang]?.units?.days||"days");}let spread=null;for(const d of daySeries){const n=Array.isArray(d.projects)?d.projects.length:0;if(!spread||n>spread.n)spread={day:d.day,n};}if(spread){document.getElementById("hl-spread").textContent=spread.day;document.getElementById("hl-spread-sub").textContent=fmtInt(spread.n)+" "+t("labelProjects").toLowerCase();}const{busiestWeek}=computeBusiest();if(busiestWeek){document.getElementById("hl-week").textContent=busiestWeek.wk;document.getElementById("hl-week-sub").textContent=fmtInt(busiestWeek.count||0)+" "+(I18N[lang]?.units?.entries||"entries");}const ms=document.getElementById("hl-milestones");ms.innerHTML="";const milestones=[{label:I18N[lang]?.metricEvents||"Events",cur:clampInt(data.totals?.events||0),steps:[50,100,250,500,1000,2000,5000]},{label:I18N[lang]?.metricDays||"Days",cur:clampInt(data.totals?.activeDays||0),steps:[10,25,50,100,200,365]},{label:I18N[lang]?.metricProjects||"Projects",cur:clampInt(data.totals?.projects||0),steps:[5,10,25,50,100]},{label:I18N[lang]?.commitStatSamples||"Commits",cur:clampInt(Array.isArray(data.commitSamples)?data.commitSamples.length:0),steps:[25,50,100,250,500,1000,2000]}];for(const m of milestones){const next=m.steps.find(s=>s>m.cur)||m.cur;const pct=Math.min(100,next>0?(m.cur/next*100):100);const row=document.createElement("div");row.className="bar";const lab=document.createElement("label");lab.title=m.label;lab.textContent=m.label;const track=document.createElement("div");track.className="track";const fill=document.createElement("div");fill.className="fill";fill.style.width=pct.toFixed(2)+"%";track.appendChild(fill);const n=document.createElement("div");n.className="n";n.textContent=fmtInt(m.cur)+" / "+fmtInt(next);row.appendChild(lab);row.appendChild(track);row.appendChild(n);ms.appendChild(row);}const tp=document.getElementById("hl-top-projects");tp.innerHTML="";const projects=Array.isArray(data.series?.projects)?data.series.projects.slice(0,5):[];const pmax=Math.max(1,...projects.map(x=>x.entries||0));projects.forEach(x=>makeBar(String(x.project),clampInt(x.entries||0),pmax,tp));}
  function renderTopMetrics(){document.getElementById("m-events").textContent=fmtInt(data.totals?.events||0);document.getElementById("m-days").textContent=fmtInt(data.totals?.activeDays||0);document.getElementById("m-projects").textContent=fmtInt(data.totals?.projects||0);const{current,longest}=computeStreaks();document.getElementById("m-streak").textContent=fmtInt(current);document.getElementById("m-longest").textContent=fmtInt(longest);document.getElementById("m-streak-sub").textContent=t("streakMax").replace("{n}",fmtInt(longest));const{busiestDay,busiestWeek}=computeBusiest();if(busiestDay){document.getElementById("m-bday").textContent=busiestDay.day;document.getElementById("m-bday-sub").textContent=fmtInt(busiestDay.entries||0)+" "+(I18N[lang]?.units?.entries||"entries");}if(busiestWeek){document.getElementById("m-bweek").textContent=busiestWeek.wk;document.getElementById("m-bweek-sub").textContent=fmtInt(busiestWeek.count||0)+" "+(I18N[lang]?.units?.entries||"entries");}}
  function renderMicroBar(containerId,items,labelKey,countKey){const el=document.getElementById(containerId);if(!el)return;el.innerHTML="";const maxVal=Math.max(1,...items.map(x=>x[countKey]||0)),CHART_H=56;items.forEach(item=>{const col=document.createElement("div");col.className="microbar-col";const barH=Math.max(2,Math.round((item[countKey]||0)/maxVal*CHART_H));const bar=document.createElement("div");bar.className="microbar-bar";bar.style.height=barH+"px";const label=document.createElement("div");label.className="microbar-label";label.textContent=item[labelKey];label.title=item[labelKey]+": "+fmtInt(item[countKey]||0);col.appendChild(bar);col.appendChild(label);el.appendChild(col);});}
  function renderAgentSection(){const ag=data.agentData;if(!ag||ag.totalEvents===0){document.getElementById("agentSection").style.display="none";return;}document.getElementById("agentSection").style.display="";document.getElementById("agentPill").textContent=fmtInt(ag.totalEvents)+" "+(I18N[lang]?.units?.entries||"entries");const kpiEl=document.getElementById("agentKpi");kpiEl.innerHTML="";[{label:t("agentEventsLabel"),val:fmtInt(ag.totalEvents)},{label:t("distinctActors"),val:fmtInt((ag.actors||[]).length)},{label:t("modelsUsed"),val:fmtInt((ag.models||[]).length)},{label:t("toolsUsed"),val:fmtInt((ag.tools||[]).length)}].forEach(k=>{const card=document.createElement("div");card.className="agent-kpi-card";card.innerHTML='<h3>'+esc(k.label)+'</h3><div class="val">'+k.val+'</div>';kpiEl.appendChild(card);});const toolsEl=document.getElementById("agentTools");toolsEl.innerHTML="";const tools=(ag.tools||[]).slice(0,12),tmax=Math.max(1,...tools.map(([,c])=>c));tools.forEach(([name,count])=>makeBar(String(name),count,tmax,toolsEl,'violet'));const mcpEl=document.getElementById("agentMcp");mcpEl.innerHTML="";if((ag.mcpServers||[]).length>0){const mmax=Math.max(1,...ag.mcpServers.map(([,c])=>c||0));ag.mcpServers.forEach(([name,count])=>makeBar("MCP: "+String(name),count,mmax,mcpEl,'green'));}else{mcpEl.innerHTML='<div class="no-data">'+esc(t("noMcpData"))+'</div>';}const actorsEl=document.getElementById("agentActors");actorsEl.innerHTML="";const actorList=ag.actors||[];if(actorList.length>0){const amax=Math.max(1,...actorList.map(([,c])=>c||0));actorList.forEach(([name,count])=>makeBar(String(name),count,amax,actorsEl));}const daysEl=document.getElementById("agentDays");daysEl.innerHTML="";const days=ag.daySeries||[];if(days.length>0){const dmax=Math.max(1,...days.map(d=>d.count||0));days.forEach(d=>{const label=d.day+" "+(d.actors||[]).join(", ");makeBar(label,d.count||0,dmax,daysEl);});}else{daysEl.innerHTML='<div class="no-data">'+esc(t("noAgentDays"))+'</div>';}}
  function renderProjectCards(){const container=document.getElementById("projectCards");container.innerHTML="";const projects=Array.isArray(data.series?.projects)?data.series.projects:[];projects.forEach(p=>{const kinds=p.kinds||{};const kindChips=Object.entries(kinds).map(([k,v])=>'<span class="kchip kchip-'+esc(k)+'">'+esc(I18N[lang]?.kindLabels?.[k]||k)+' '+v+'</span>').join(' ');const recent=(p.recent||[]).slice(0,3);const recentHtml=recent.length?'<ul class="proj-recent" style="margin:0;padding-left:18px;">'+recent.map(s=>'<li>'+esc(String(s))+'</li>').join('')+'</ul>':'<div class="no-data">'+esc(t("noSummaries"))+'</div>';const details=document.createElement("details");details.className="proj-card";details.innerHTML='<summary><i class="s-arrow">&#9654;</i><strong><code>'+esc(String(p.project))+'</code></strong><span class="pill" style="margin-left:auto;">'+fmtInt(p.entries||0)+'</span></summary><div class="detailsBody"><div class="proj-meta"><span>'+esc(t("colFirst"))+': '+esc(p.firstDay||"")+'</span><span>'+esc(t("colLast"))+': '+esc(p.lastDay||"")+'</span>'+kindChips+'</div><div>'+recentHtml+'</div></div>';container.appendChild(details);});}
  function renderAll(){renderTopMetrics();renderHeatmap();renderBars();renderCommitStats();renderTechVolume();renderFilesTouched();renderConcentration();renderHighlights();const dowSeries=Array.isArray(data.dowSeries)?data.dowSeries:[];if(dowSeries.length>0)renderMicroBar("dowChart",dowSeries,"label","count");renderAgentSection();renderProjectCards();}
  setLang(lang);
})();
initCharts();
render();
</script>
</main></body></html>

'@

$content=$template.Replace('__PAYLOAD_JSON__',$payloadJson).Replace('__I18N_JSON__',$i18nJson).Replace('__ALIAS_MAP_JSON__',$aliasMapJson).Replace('__INPUT_DAYS__',$inputDaysJson).Replace('__LEDGER_EVENTS__',$ledgerJson).Replace('__GENERATED_AT__',$generatedAt)
$utf8NoBom=New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outHtmlPath,$content,$utf8NoBom)
try{[System.IO.File]::WriteAllText($ParentHtmlPath,$content,$utf8NoBom)}catch{}
$siteDataDir=Join-Path(Join-Path(Join-Path $LedgerRoot 'site')'public')'data'
if(Test-Path(Join-Path $LedgerRoot 'site')){if(-not(Test-Path $siteDataDir)){New-Item -ItemType Directory -Path $siteDataDir -Force|Out-Null}Set-Content -LiteralPath(Join-Path $siteDataDir 'work-impact-data.json')-Value($payload|ConvertTo-Json -Depth 24)-Encoding utf8}
Write-Output "Rendered Work Impact:"
Write-Output "  $outHtmlPath"
Write-Output "  $ParentHtmlPath"
Write-Output "  Input days: $($inputDays.Count)  Ledger events: $($ledgerEvents.Count)"
