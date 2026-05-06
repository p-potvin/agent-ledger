[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$StatePath,
    [string]$ParentHtmlPath
)

$ErrorActionPreference = 'Stop'

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

if (-not $StatePath) {
    $StatePath = Join-Path $LedgerRoot 'work-impact.state.json'
}

if (-not $ParentHtmlPath) {
    $ParentHtmlPath = Join-Path (Split-Path $LedgerRoot -Parent) 'WORK_IMPACT.html'
}

$outHtmlPath = Join-Path $LedgerRoot 'WORK_IMPACT.html'

if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "State file not found: $StatePath"
}

function New-I18nTable {
    # Emit as JSON into the HTML so quotes/accents never break JS parsing.
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
            commitLineDataUnavailable = '{n} commits referenced. Line-count data requires local access to the git repositories. Run update-work-impact.ps1 locally to populate.'
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
            commitSizeHint = "D$([char]0x00e9)riv$([char]0x00e9) des commits r$([char]0x00e9)f$([char]0x00e9)renc$([char]0x00e9)s par les $([char]0x00e9)v$([char]0x00e9)nements de backfill. Churn propre = ajouts + suppressions, hors chemins g$([char]0x00e9)n$([char]0x00e9)r$([char]0x00e9)s/vendeur."
            commitStatMean = 'Moyenne'
            commitStatMedian = "M$([char]0x00e9)diane"
            commitStatMode = 'Mode'
            commitStatSamples = "Commits mesur$([char]0x00e9)s"
            commitHistTitle = 'Distribution des tailles'
            commitBoxTitle = 'Par mois (quartiles)'
            commitOutliersTitle = 'Plus gros commits'
            techTitle = 'Volume technique (propre vs brut)'
            techHint = "Le nombre de lignes est un indicateur imparfait. Propre exclut les chemins g$([char]0x00e9)n$([char]0x00e9)r$([char]0x00e9)s/vendeur."
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
            agentHint = "Entr$([char]0x00e9)es avec un en-t$([char]0x00ea)te d$([char]0x2019)agent runtime (disponible depuis mai 2026)."
            activityTitle = 'Quand le travail se passe'
            activityHint = 'Distribution par heure du jour et jour de la semaine.'
            noCommitData = 'Pas encore de commits.'
            commitLineDataUnavailable = "{n} commits r$([char]0x00e9)f$([char]0x00e9)renc$([char]0x00e9)s. Les donn$([char]0x00e9)es de lignes n$([char]0x00e9)cessitent un acc$([char]0x00e8)s local aux d$([char]0x00e9)p$([char]0x00f4)ts git."
            lineStatsUnavailable = "Les donn$([char]0x00e9)es de lignes n$([char]0x00e9)cessitent un acc$([char]0x00e8)s local aux d$([char]0x00e9)p$([char]0x00f4)ts git. Ex$([char]0x00e9)cutez update-work-impact.ps1 localement."
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

$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
if (-not $state -or -not $state.data) {
    throw "State file has no data. Run scripts/update-work-impact.ps1 first: $StatePath"
}

$payload = [ordered]@{
    config = $state.config
    data = $state.data
    lastUpdatedUtc = $state.lastUpdatedUtc
}

$payloadJson = ($payload | ConvertTo-Json -Depth 24 -Compress)
$i18nJson = ((New-I18nTable) | ConvertTo-Json -Depth 24 -Compress)

$template = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Work Impact</title>
  <style>
    /* === VaultWares Design Tokens === */
    :root {
      --v-base: #12161f;
      --v-surface: #1c2232;
      --v-surface2: #242c3e;
      --v-gold: #c4a44a;
      --v-gold-muted: rgba(196,164,74,0.14);
      --v-gold-dim: rgba(196,164,74,0.32);
      --v-cyan: #18b8d0;
      --v-green: #2ea86b;
      --v-burgundy: #8a2424;
      --v-slate: #7d8fa5;
      --v-muted-color: #5c6d82;
      --v-border: rgba(125,143,165,0.18);
      --bg: var(--v-base);
      --fg: #e8ecf2;
      --muted: var(--v-slate);
      --border: var(--v-border);
      --card: var(--v-surface);
      --chip: var(--v-gold-muted);
      --accent: var(--v-gold);
      --link: var(--v-cyan);
      --good0: rgba(125,143,165,0.10);
      --good1: rgba(196,164,74,0.22);
      --good2: rgba(196,164,74,0.48);
      --good3: rgba(196,164,74,0.75);
      --good4: #c4a44a;
    }
    @media (prefers-color-scheme: light) {
      :root {
        --v-base: #f4efe6;
        --v-surface: #ffffff;
        --v-surface2: #ede8df;
        --v-gold: #8c6820;
        --v-gold-muted: rgba(140,104,32,0.10);
        --v-gold-dim: rgba(140,104,32,0.25);
        --v-cyan: #0a7590;
        --v-green: #1a6940;
        --v-burgundy: #7b1a1a;
        --v-slate: #4a5a6d;
        --v-muted-color: #7a8898;
        --v-border: rgba(26,31,44,0.14);
        --bg: var(--v-base);
        --fg: #1a1f2c;
        --muted: var(--v-slate);
        --border: var(--v-border);
        --card: var(--v-surface);
        --chip: var(--v-gold-muted);
        --accent: var(--v-gold);
        --link: var(--v-cyan);
        --good0: #e8e4dc;
        --good1: rgba(140,104,32,0.22);
        --good2: rgba(140,104,32,0.48);
        --good3: rgba(140,104,32,0.75);
        --good4: #8c6820;
      }
    }

    /* === Base === */
    *, *::before, *::after { box-sizing: border-box; }
    body { margin: 0; font-family: "Segoe UI", system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--fg); line-height: 1.5; -webkit-font-smoothing: antialiased; }
    main { max-width: 1140px; margin: 0 auto; padding: 24px 16px 80px; }
    a { color: var(--link); }

    /* === Header === */
    header { display:flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; padding-bottom: 18px; border-bottom: 1px solid var(--border); margin-bottom: 2px; }
    .header-left { display: flex; gap: 12px; align-items: center; }
    .brand-badge { background: var(--v-gold-muted); border: 1px solid var(--v-gold-dim); border-radius: 6px; padding: 3px 9px; font-size: 10px; font-weight: 800; color: var(--accent); letter-spacing: 0.08em; text-transform: uppercase; flex-shrink: 0; }
    h1 { font-size: 21px; margin: 0; font-weight: 700; }
    .meta { margin: 5px 0 0; color: var(--muted); font-size: 13px; }
    .lang { display:flex; gap: 8px; align-items: center; flex-shrink: 0; }
    .toggle { display:inline-flex; border: 1px solid var(--border); border-radius: 999px; overflow:hidden; }
    .toggle button { appearance:none; border:0; padding: 7px 12px; cursor:pointer; background: transparent; color: var(--fg); font-size: 12px; font-weight: 600; transition: background 0.1s; }
    .toggle button[aria-pressed="true"] { background: var(--chip); color: var(--accent); }

    /* === Layout === */
    section { margin-top: 20px; }
    .grid { display:grid; gap: 12px; grid-template-columns: repeat(12, 1fr); }
    .card { border: 1px solid var(--border); background: var(--card); border-radius: 10px; padding: 14px 14px; }
    .card h2 { margin: 0 0 8px; font-size: 11px; color: var(--muted); font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; }
    .big { font-size: 28px; font-weight: 700; line-height: 1.1; }
    .big-accent { color: var(--accent); }
    .sub { margin-top: 4px; font-size: 12px; color: var(--muted); }
    .span3 { grid-column: span 3; }
    .span4 { grid-column: span 4; }
    .span6 { grid-column: span 6; }
    .span8 { grid-column: span 8; }
    .span12 { grid-column: span 12; }
    @media (max-width: 980px) { .span3,.span4,.span6,.span8 { grid-column: span 12; } }
    @media (min-width:600px) and (max-width:980px) { .span3 { grid-column: span 6; } .span4 { grid-column: span 6; } }
    .kicker { margin: 12px 0 2px; font-size: 13.5px; color: var(--fg); line-height: 1.65; opacity: 0.85; }
    .quiet { color: var(--muted); }
    .row { display:flex; gap: 10px; align-items: center; justify-content: space-between; flex-wrap: wrap; }
    .pill { display:inline-block; padding: 2px 8px; border-radius: 999px; background: var(--chip); border: 1px solid var(--v-gold-dim); font-size: 11px; color: var(--accent); font-weight: 700; vertical-align: middle; }
    .no-data { color: var(--muted); font-size: 12px; font-style: italic; padding: 8px 0; }
    .info-note { font-size: 11px; color: var(--muted); background: color-mix(in srgb, var(--accent) 6%, transparent); border: 1px solid var(--v-gold-dim); border-radius: 6px; padding: 6px 10px; margin-top: 8px; }

    /* === Bar lists === */
    .barlist { display:flex; flex-direction: column; gap: 8px; }
    .bar { display:flex; align-items:center; gap: 10px; }
    .bar label { width: 195px; font-size: 12px; color: var(--fg); overflow:hidden; text-overflow: ellipsis; white-space: nowrap; flex-shrink: 0; }
    .bar .track { flex: 1; height: 8px; border-radius: 999px; background: color-mix(in srgb, var(--accent) 8%, transparent); overflow:hidden; min-width: 50px; }
    .bar .fill { height: 100%; background: var(--accent); border-radius: 999px; transition: width 0.3s ease; }
    .bar .n { width: 68px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; flex-shrink: 0; }
    .bar.cyan .fill { background: var(--v-cyan); }
    .bar.green .fill { background: var(--v-green); }

    /* === Details / collapsible === */
    details { border: 1px solid var(--border); border-radius: 10px; background: var(--card); }
    summary { cursor: pointer; padding: 12px 16px; line-height: 1.4; list-style: none; display: flex; align-items: center; gap: 10px; user-select: none; }
    summary::-webkit-details-marker { display: none; }
    .s-arrow { display: inline-block; width: 16px; height: 16px; color: var(--muted); flex-shrink: 0; font-style: normal; transition: transform 0.15s; text-align: center; line-height: 16px; font-size: 10px; }
    details[open] .s-arrow { transform: rotate(90deg); }
    summary strong { font-size: 13px; font-weight: 600; }
    .detailsBody { padding: 0 16px 16px; }

    /* === Tables === */
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { text-align:left; padding: 8px 8px; border-bottom: 1px solid var(--border); vertical-align: top; }
    th { color: var(--muted); font-weight: 700; font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.05em; }
    tr:last-child td { border-bottom: none; }
    code { font-family: "Cascadia Code", Consolas, monospace; font-size: 11.5px; }

    /* === Calendar heatmap === */
    .heatWrap { overflow-x: auto; scrollbar-width: thin; }
    .heat { display: grid; grid-auto-flow: column; grid-auto-columns: 13px; gap: 3px; align-items: start; padding: 8px 6px 4px; }
    .heatCol { display:grid; grid-template-rows: repeat(7, 13px); gap: 3px; }
    .cell { width: 13px; height: 13px; border-radius: 3px; background: var(--good0); cursor: default; }
    .lvl1 { background: var(--good1); }
    .lvl2 { background: var(--good2); }
    .lvl3 { background: var(--good3); }
    .lvl4 { background: var(--good4); }
    .heatLegend { display:flex; gap: 8px; align-items:center; justify-content:flex-end; font-size: 11.5px; color: var(--muted); padding: 0 6px 8px; }
    .legendSwatch { display:flex; gap: 3px; align-items:center; }

    /* === Tooltip === */
    .tooltip { position: fixed; z-index: 50; pointer-events:none; background: var(--v-surface2); border: 1px solid var(--border); border-radius: 10px; padding: 10px 12px; max-width: 380px; box-shadow: 0 16px 48px rgba(0,0,0,.45); display:none; }
    .tooltip .t { font-size: 12px; color: var(--fg); font-weight: 700; }
    .tooltip .m { font-size: 12px; color: var(--muted); margin-top: 6px; white-space: pre-line; }

    /* === Split layout === */
    .split { display:flex; gap: 14px; flex-wrap: wrap; align-items: flex-start; }
    .split > * { flex: 1 1 300px; min-width: 0; }

    /* === Histogram === */
    .hist { display:flex; flex-direction:column; gap:5px; }
    .histRow { display:flex; gap:10px; align-items:center; }
    .histRow .lab { width: 90px; font-size:12px; color: var(--fg); flex-shrink:0; }
    .histRow .track { flex:1; height: 8px; border-radius:999px; background: color-mix(in srgb, var(--accent) 8%, transparent); overflow:hidden; }
    .histRow .fill { height:100%; background: var(--accent); border-radius: 999px; }
    .histRow .n { width: 50px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; flex-shrink:0; }

    /* === Box plot === */
    .boxlist { display:flex; flex-direction:column; gap:8px; }
    .boxRow { display:flex; gap:10px; align-items:center; }
    .boxRow .lab { width: 80px; font-size:12px; color: var(--fg); flex-shrink:0; }
    .boxRow .track { position:relative; flex:1; height: 14px; border-radius:999px; background: color-mix(in srgb, var(--accent) 8%, transparent); }
    .boxRow .iqr { position:absolute; top:3px; height:8px; border-radius: 6px; background: color-mix(in srgb, var(--accent) 40%, transparent); }
    .boxRow .med { position:absolute; top:1px; width:2px; height:12px; background: var(--accent); border-radius: 2px; }
    .boxRow .n { width: 60px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; flex-shrink:0; }

    /* === Micro bar chart (hour/dow) === */
    .microbar-wrap { display:flex; gap: 4px; align-items: flex-end; height: 70px; margin-top: 10px; }
    .microbar-col { display:flex; flex-direction:column; align-items:center; flex: 1; gap: 3px; min-width: 0; }
    .microbar-bar { width: 100%; background: var(--accent); border-radius: 3px 3px 0 0; min-height: 2px; }
    .microbar-label { font-size: 9px; color: var(--muted); text-align:center; white-space: nowrap; overflow: hidden; width: 100%; }

    /* === Agent section === */
    .agent-kpi { display: grid; gap: 10px; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); margin-top: 10px; }
    .agent-kpi-card { border: 1px solid color-mix(in srgb, var(--v-cyan) 30%, var(--border)); background: color-mix(in srgb, var(--v-cyan) 5%, var(--card)); border-radius: 8px; padding: 10px 12px; }
    .agent-kpi-card h3 { margin: 0 0 4px; font-size: 10px; font-weight: 700; color: var(--v-cyan); text-transform: uppercase; letter-spacing: 0.07em; }
    .agent-kpi-card .val { font-size: 22px; font-weight: 700; color: var(--fg); }

    /* === Project evidence cards === */
    .proj-card { border: 1px solid var(--border); border-radius: 8px; background: var(--card); }
    .proj-card + .proj-card { margin-top: 8px; }
    .proj-card summary strong { font-size: 13px; }
    .proj-meta { display: flex; gap: 8px; flex-wrap: wrap; font-size: 11px; margin-bottom: 10px; }
    .proj-meta span { background: var(--chip); border: 1px solid var(--v-gold-dim); border-radius: 4px; padding: 2px 7px; color: var(--accent); font-weight: 600; }
    .proj-recent li { font-size: 12px; color: var(--fg); line-height: 1.55; margin-bottom: 4px; word-break: break-word; }

    /* === Kind chips === */
    .kchip { display:inline-block; padding: 1px 6px; border-radius: 4px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; }
    .kchip-code-change { background: color-mix(in srgb, var(--v-green) 15%, transparent); color: var(--v-green); }
    .kchip-plan { background: color-mix(in srgb, var(--v-cyan) 15%, transparent); color: var(--v-cyan); }
    .kchip-verification { background: color-mix(in srgb, var(--v-gold) 15%, transparent); color: var(--v-gold); }
    .kchip-commands { background: color-mix(in srgb, var(--v-slate) 20%, transparent); color: var(--v-slate); }
    .kchip-handoff { background: color-mix(in srgb, var(--v-burgundy) 20%, transparent); color: var(--v-burgundy); }
    .kchip-general { background: color-mix(in srgb, var(--v-muted-color) 20%, transparent); color: var(--v-muted-color); }
  </style>
</head>
<body>
<main>
  <header>
    <div class="header-left">
      <div class="brand-badge">VaultWares</div>
      <div>
        <h1 id="title" data-i18n="title">Work Impact</h1>
        <div class="meta">
          <span id="subtitle" data-i18n="subtitle"></span>
          <span class="quiet"> &middot; </span>
          <span class="quiet"><span data-i18n="range">Range</span>: <span id="range"></span></span>
          <span class="quiet"> &middot; </span>
          <span class="quiet"><span data-i18n="generated">Generated</span>: <span id="generated"></span></span>
        </div>
      </div>
    </div>
    <div class="lang">
      <span class="quiet" data-i18n="langLabel">Language</span>
      <div class="toggle" role="group" aria-label="Language">
        <button id="lang-en" type="button" aria-pressed="false">EN</button>
        <button id="lang-qc" type="button" aria-pressed="false">QC</button>
      </div>
    </div>
  </header>

  <p class="kicker" id="intro" data-i18n="intro"></p>

  <!-- KPI row -->
  <section class="grid">
    <div class="card span3">
      <h2 data-i18n="metricEvents">Work entries</h2>
      <div class="big big-accent" id="m-events">0</div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricDays">Active days</h2>
      <div class="big" id="m-days">0</div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricProjects">Projects touched</h2>
      <div class="big" id="m-projects">0</div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricStreak">Current streak</h2>
      <div class="big" id="m-streak">0</div>
      <div class="sub" id="m-streak-sub"></div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricLongestStreak">Longest streak</h2>
      <div class="big" id="m-longest">0</div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricBusiestDay">Busiest day</h2>
      <div class="big" id="m-bday">-</div>
      <div class="sub" id="m-bday-sub"></div>
    </div>
    <div class="card span3">
      <h2 data-i18n="metricBusiestWeek">Busiest week</h2>
      <div class="big" id="m-bweek">-</div>
      <div class="sub" id="m-bweek-sub"></div>
    </div>
    <div class="card span3">
      <h2 data-i18n="commitStatSamples">Commits sampled</h2>
      <div class="big" id="m-commits">0</div>
      <div class="sub" id="m-commits-sub"></div>
    </div>
  </section>

  <!-- Calendar heatmap -->
  <section class="card">
    <div class="row">
      <div>
        <h2 style="margin:0;" data-i18n="calendarTitle">Work activity by day</h2>
        <div class="sub" data-i18n="calendarHint">Hover a square to see that day.</div>
      </div>
      <div class="heatLegend">
        <span data-i18n="less">Less</span>
        <span class="legendSwatch" aria-hidden="true">
          <span class="cell"></span>
          <span class="cell lvl1"></span>
          <span class="cell lvl2"></span>
          <span class="cell lvl3"></span>
          <span class="cell lvl4"></span>
        </span>
        <span data-i18n="more">More</span>
      </div>
    </div>
    <div class="heatWrap">
      <div id="heat" class="heat" aria-label="Calendar heatmap"></div>
    </div>
    <div class="tooltip" id="tip">
      <div class="t" id="tip-title"></div>
      <div class="m" id="tip-meta"></div>
    </div>
  </section>

  <!-- Monthly + Projects + Kinds + Commit size -->
  <section class="grid">
    <div class="card span6">
      <h2 data-i18n="monthlyTitle">Work recorded per month</h2>
      <div class="barlist" id="monthlyBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="projectsTitle">Top projects by activity</h2>
      <div class="barlist" id="projectBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="kindsTitle">What kind of work</h2>
      <div class="barlist" id="kindBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="commitSizeTitle">Commit size (clean churn lines)</h2>
      <div class="sub" data-i18n="commitSizeHint"></div>
      <div id="commitSizeContent" style="margin-top:10px;"></div>
    </div>
  </section>

  <!-- Tech volume + Files touched -->
  <section class="grid">
    <div class="card span6">
      <h2 data-i18n="techTitle">Technical volume (clean vs raw)</h2>
      <div class="sub" data-i18n="techHint"></div>
      <div id="techVolumeContent" style="margin-top: 8px;"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="filesTouchedTitle">Files touched per commit</h2>
      <div id="filesTouchedContent"></div>
      <div style="margin-top:14px;">
        <h2 data-i18n="concentrationTitle">Work concentration</h2>
        <div class="sub" data-i18n="concentrationHint"></div>
        <div class="barlist" id="concentrationBars" style="margin-top: 8px;"></div>
      </div>
    </div>
  </section>

  <!-- Highlights row: consistent | spread | strongest week | milestones | top projects -->
  <section class="grid">
    <div class="card span4">
      <h2 data-i18n="hlMostConsistentMonth">Most consistent month</h2>
      <div class="big" id="hl-consistent">-</div>
      <div class="sub" id="hl-consistent-sub"></div>
    </div>
    <div class="card span4">
      <h2 data-i18n="hlWidestProjectDay">Widest project spread</h2>
      <div class="big" id="hl-spread">-</div>
      <div class="sub" id="hl-spread-sub"></div>
    </div>
    <div class="card span4">
      <h2 data-i18n="hlStrongestWeek">Strongest week</h2>
      <div class="big" id="hl-week">-</div>
      <div class="sub" id="hl-week-sub"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="hlMilestones">Milestones</h2>
      <div class="barlist" id="hl-milestones" style="margin-top: 6px;"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="highlightsTitle">Top projects</h2>
      <div class="barlist" id="hl-top-projects" style="margin-top: 6px;"></div>
    </div>
  </section>

  <!-- Activity patterns: hour of day + day of week -->
  <section class="grid">
    <div class="card span6">
      <h2 data-i18n="activityTitle">When work happens &mdash; hour of day</h2>
      <div class="sub" data-i18n="activityHint"></div>
      <div class="microbar-wrap" id="hourChart"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="activityTitle">When work happens &mdash; day of week</h2>
      <div class="microbar-wrap" id="dowChart"></div>
    </div>
  </section>

  <!-- Agent data section -->
  <section class="card" id="agentSection" style="display:none;">
    <div class="row" style="margin-bottom:10px;">
      <div>
        <h2 style="margin:0;" data-i18n="agentTitle">Agent activity</h2>
        <div class="sub" data-i18n="agentHint"></div>
      </div>
      <span class="pill" id="agentPill">0 events</span>
    </div>
    <div class="agent-kpi" id="agentKpi"></div>
    <div class="grid" style="margin-top:12px;">
      <div class="card span6" style="padding:10px 12px;">
        <h2>Tools used</h2>
        <div class="barlist" id="agentTools"></div>
      </div>
      <div class="card span6" style="padding:10px 12px;">
        <h2>MCP servers &amp; actors</h2>
        <div class="barlist" id="agentMcp"></div>
        <div class="barlist" id="agentActors" style="margin-top:12px;"></div>
      </div>
    </div>
    <div style="margin-top:12px;">
      <h2>Agent activity by day</h2>
      <div class="barlist" id="agentDays"></div>
    </div>
  </section>

  <!-- Evidence by project (collapsible) -->
  <section>
    <h2 style="font-size:14px;font-weight:700;color:var(--fg);margin:0 0 10px;display:flex;align-items:center;gap:10px;">
      <span data-i18n="evidenceTitle">Activity by project</span>
      <span style="flex:1;height:1px;background:var(--border);"></span>
    </h2>
    <p class="sub" data-i18n="evidenceHint" style="margin:0 0 10px;"></p>
    <div id="projectCards"></div>
  </section>

  <script>
    const PAYLOAD = __PAYLOAD_JSON__;
    const I18N = __I18N_JSON__;

    (function(){
      const data = PAYLOAD.data;

      const clampInt = (v)=> Number.isFinite(v) ? Math.trunc(v) : 0;
      const fmtInt = (n)=> new Intl.NumberFormat(undefined).format(clampInt(n));
      const fmt1 = (n)=> new Intl.NumberFormat(undefined,{maximumFractionDigits:1}).format(n);
      const fmt2 = (n)=> new Intl.NumberFormat(undefined,{maximumFractionDigits:2}).format(n);
      const fmtSigned = (n)=> (n>=0?"+":"") + fmtInt(n);
      const esc = (s)=> String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/\'/g,"&#39;");

      const supported = Object.keys(I18N);
      let saved = null;
      try { saved = localStorage.getItem("workImpactLang"); } catch {}
      const browser = (navigator.language || "en").toLowerCase();
      let lang = (saved && supported.includes(saved)) ? saved : (browser.startsWith("fr") ? "qc" : "en");
      if (!supported.includes(lang)) lang = supported[0] || "en";

      const setLang = (next) => {
        lang = next;
        try { localStorage.setItem("workImpactLang", lang); } catch {}
        document.getElementById("lang-en").setAttribute("aria-pressed", String(lang==="en"));
        document.getElementById("lang-qc").setAttribute("aria-pressed", String(lang==="qc"));
        applyI18n(); renderAll();
      };
      const t = (key) => (I18N[lang] && I18N[lang][key]) ? I18N[lang][key] : key;

      function applyI18n(){
        document.querySelectorAll("[data-i18n]").forEach(el=>{
          const k = el.getAttribute("data-i18n");
          el.textContent = t(k);
        });
        document.title = t("title");
      }

      document.getElementById("lang-en").addEventListener("click", ()=> setLang("en"));
      document.getElementById("lang-qc").addEventListener("click", ()=> setLang("qc"));

      document.getElementById("generated").textContent = data.generatedAtLocal || "";
      document.getElementById("range").textContent = (data.range?.start || "") + " \u2192 " + (data.range?.end || "");

      function parseLocalDate(s){
        if(!s) return null;
        const d = new Date(s + "T00:00:00");
        return Number.isNaN(d.getTime()) ? null : d;
      }
      function dayKey(d){
        return d.getFullYear() + "-" + String(d.getMonth()+1).padStart(2,"0") + "-" + String(d.getDate()).padStart(2,"0");
      }
      function addDays(d, n){
        const out = new Date(d); out.setDate(out.getDate()+n); return out;
      }

      const daySeries = Array.isArray(data.series?.days) ? data.series.days : [];
      const activeDays = new Set(daySeries.map(d=>d.day));

      function computeStreaks(){
        if(activeDays.size === 0) return { current: 0, longest: 0 };
        const end = parseLocalDate(data.range?.end) || new Date();
        let cur = 0;
        for(let i=0;i<4000;i++){
          const k = dayKey(addDays(end, -i));
          if(activeDays.has(k)) cur++; else break;
        }
        const daysSorted = Array.from(activeDays).sort();
        let longest = 1, run = 1;
        for(let i=1;i<daysSorted.length;i++){
          const prev = parseLocalDate(daysSorted[i-1]);
          const now = parseLocalDate(daysSorted[i]);
          if(!prev || !now) continue;
          const diff = Math.round((now - prev) / (24*3600*1000));
          if(diff === 1){ run++; if(run > longest) longest = run; } else run = 1;
        }
        return { current: cur, longest };
      }

      function computeBusiest(){
        let busiestDay = null;
        for(const d of daySeries){
          if(!busiestDay || (d.entries||0) > (busiestDay.entries||0)) busiestDay = d;
        }
        const weekCounts = new Map();
        for(const d of daySeries){
          const dt = parseLocalDate(d.day);
          if(!dt) continue;
          const dayOfWeek = (dt.getDay()+6)%7;
          const monday = addDays(dt, -dayOfWeek);
          const wk = dayKey(monday);
          weekCounts.set(wk, (weekCounts.get(wk)||0) + (d.entries||0));
        }
        let busiestWeek = null;
        for(const [wk,count] of weekCounts){
          if(!busiestWeek || count > busiestWeek.count) busiestWeek = { wk, count };
        }
        return { busiestDay, busiestWeek };
      }

      function quantile(sorted, q){
        if(sorted.length === 0) return 0;
        const pos = (sorted.length - 1) * q;
        const base = Math.floor(pos);
        const rest = pos - base;
        if(sorted[base+1] === undefined) return sorted[base];
        return sorted[base] + rest * (sorted[base+1] - sorted[base]);
      }

      function histogramBuckets(values){
        const edges = [0, 10, 25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
        const bins = edges.map((lo, i) => ({ lo, hi: edges[i+1], count: 0 }));
        bins.push({ lo: edges[edges.length-1], hi: null, count: 0 });
        for(const v of values){
          const n = Math.max(0, Math.floor(v));
          let placed = false;
          for(const b of bins){
            if(b.hi === null){ b.count++; placed=true; break; }
            if(n >= b.lo && n < b.hi){ b.count++; placed=true; break; }
          }
          if(!placed) bins[bins.length-1].count++;
        }
        return bins;
      }

      function makeBar(label, count, max, container, colorClass=''){
        const row = document.createElement("div");
        row.className = "bar" + (colorClass ? " " + colorClass : "");
        const lab = document.createElement("label"); lab.title = label; lab.textContent = label;
        const track = document.createElement("div"); track.className = "track";
        const fill = document.createElement("div"); fill.className = "fill";
        fill.style.width = (max ? (count/max*100) : 0).toFixed(2) + "%";
        track.appendChild(fill);
        const n = document.createElement("div"); n.className = "n"; n.textContent = fmtInt(count);
        row.appendChild(lab); row.appendChild(track); row.appendChild(n);
        container.appendChild(row);
      }

      function makeBarFrac(label, value, max, container, suffix){
        const row = document.createElement("div"); row.className = "bar";
        const lab = document.createElement("label"); lab.title = label; lab.textContent = label;
        const track = document.createElement("div"); track.className = "track";
        const fill = document.createElement("div"); fill.className = "fill";
        fill.style.width = (max ? (value/max*100) : 0).toFixed(2) + "%";
        track.appendChild(fill);
        const n = document.createElement("div"); n.className = "n";
        n.textContent = fmt1(value) + (suffix ? " " + suffix : "");
        row.appendChild(lab); row.appendChild(track); row.appendChild(n);
        container.appendChild(row);
      }

      function renderHeatmap(){
        const heat = document.getElementById("heat");
        heat.innerHTML = "";
        const tip = document.getElementById("tip");
        const tipTitle = document.getElementById("tip-title");
        const tipMeta = document.getElementById("tip-meta");
        const start = parseLocalDate(data.range?.start);
        const end = parseLocalDate(data.range?.end);
        if(!start || !end) return;
        const startDow = start.getDay();
        const alignedStart = addDays(start, -startDow);
        const byDay = new Map(daySeries.map(d=>[d.day, d]));
        const daysTotal = Math.round((end - alignedStart)/(24*3600*1000)) + 1;
        const weeks = Math.ceil(daysTotal / 7);
        const counts = daySeries.map(d=>d.entries||0);
        const sorted = [...counts].sort((a,b)=>a-b);
        const q1 = quantile(sorted, 0.25);
        const q2 = quantile(sorted, 0.50);
        const q3 = quantile(sorted, 0.75);
        function level(c){ if(c<=0) return 0; if(c<=q1) return 1; if(c<=q2) return 2; if(c<=q3) return 3; return 4; }
        for(let w=0; w<weeks; w++){
          const col = document.createElement("div"); col.className = "heatCol";
          for(let r=0; r<7; r++){
            const dt = addDays(alignedStart, w*7 + r);
            const key = dayKey(dt);
            const cell = document.createElement("div");
            const rec = byDay.get(key);
            const c = rec ? (rec.entries||0) : 0;
            cell.className = "cell" + (c>0 ? (" lvl"+level(c)) : "");
            cell.setAttribute("aria-label", key + ": " + c);
            cell.addEventListener("mouseenter", (ev)=>{
              const dict = I18N[lang];
              const projects = rec?.projects || [];
              const kindsObj = rec?.kinds || {};
              const kindParts = Object.keys(kindsObj).sort().map(k=>{
                const lbl = dict.kindLabels?.[k] || k;
                return lbl + ": " + fmtInt(kindsObj[k]);
              });
              tipTitle.textContent = key + " \u00B7 " + fmtInt(c) + " " + dict.units.entries;
              tipMeta.textContent =
                (projects.length ? (dict.labelProjects + ": " + projects.join(", ")) : "") +
                (kindParts.length ? ("\\n" + kindParts.join("\\n")) : "");
              tip.style.display = "block";
              tip.style.left = (ev.clientX + 12) + "px";
              tip.style.top = (ev.clientY + 12) + "px";
            });
            cell.addEventListener("mouseleave", ()=>{ tip.style.display = "none"; });
            col.appendChild(cell);
          }
          heat.appendChild(col);
        }
      }

      function renderBars(){
        // Monthly
        const monthlyBars = document.getElementById("monthlyBars");
        monthlyBars.innerHTML = "";
        const months = Array.isArray(data.series?.months) ? data.series.months.slice(-18) : [];
        const mmax = Math.max(1, ...months.map(x=>x.count||0));
        months.forEach(x=> makeBar(String(x.month), clampInt(x.count||0), mmax, monthlyBars));

        // Kinds
        const kindBars = document.getElementById("kindBars");
        kindBars.innerHTML = "";
        const kinds = Array.isArray(data.series?.kinds) ? data.series.kinds : [];
        const kmax = Math.max(1, ...kinds.map(x=>x.count||0));
        kinds.forEach(x=>{
          const label = I18N[lang]?.kindLabels?.[x.kind] || x.kind;
          makeBar(label, clampInt(x.count||0), kmax, kindBars);
        });

        // Projects
        const projectBars = document.getElementById("projectBars");
        projectBars.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects.slice(0, 12) : [];
        const pmax = Math.max(1, ...projects.map(x=>x.entries||0));
        projects.forEach(x=> makeBar(String(x.project), clampInt(x.entries||0), pmax, projectBars));
      }

      function renderCommitStats(){
        const samples = Array.isArray(data.commitSamples) ? data.commitSamples : [];
        const values = samples.map(s=> clampInt(s.cleanChurnLines||0));
        const totalSamples = samples.length;
        const hasLineData = values.some(v => v > 0);

        document.getElementById("m-commits").textContent = fmtInt(totalSamples);
        document.getElementById("m-commits-sub").textContent = totalSamples
          ? fmtInt(totalSamples) + " " + I18N[lang].units.commits
          : "";

        const container = document.getElementById("commitSizeContent");
        container.innerHTML = "";

        if(totalSamples === 0){
          container.innerHTML = '<div class="no-data">' + esc(t("noCommitData")) + '</div>';
          return;
        }

        if(!hasLineData){
          // Show the commit count but explain line data isn't available
          const note = document.createElement("div");
          note.className = "info-note";
          const tmpl = t("commitLineDataUnavailable");
          note.textContent = tmpl.replace("{n}", fmtInt(totalSamples));
          container.appendChild(note);
          return;
        }

        const sorted = [...values].sort((a,b)=>a-b);
        const mean = sorted.reduce((a,b)=>a+b,0) / sorted.length;
        const median = quantile(sorted, 0.5);
        const bins = histogramBuckets(sorted);
        const modeBin = bins.reduce((best,b)=> (b.count > (best?.count||-1) ? b : best), null);
        const modeLabel = modeBin ? (modeBin.hi===null ? (modeBin.lo + "+") : (modeBin.lo + "\u2013" + (modeBin.hi-1))) : "-";
        const units = I18N[lang].units;

        container.innerHTML = '<div class="split"></div>';
        const split = container.querySelector('.split');

        // Left: stats + histogram
        const leftDiv = document.createElement("div");
        const statsGrid = document.createElement("div");
        statsGrid.className = "grid";
        statsGrid.innerHTML =
          '<div class="card span4" style="padding:10px;">' +
            '<h2 data-i18n="commitStatMean">' + t("commitStatMean") + '</h2>' +
            '<div class="big">' + fmt1(mean) + '<span style="font-size:14px;font-weight:400;opacity:0.6;"> ' + units.lines + '</span></div>' +
          '</div>' +
          '<div class="card span4" style="padding:10px;">' +
            '<h2 data-i18n="commitStatMedian">' + t("commitStatMedian") + '</h2>' +
            '<div class="big">' + fmt1(median) + '<span style="font-size:14px;font-weight:400;opacity:0.6;"> ' + units.lines + '</span></div>' +
          '</div>' +
          '<div class="card span4" style="padding:10px;">' +
            '<h2>' + t("commitStatMode") + '</h2>' +
            '<div class="big" style="font-size:18px;">' + modeLabel + '</div>' +
          '</div>';
        leftDiv.appendChild(statsGrid);

        const histCard = document.createElement("div");
        histCard.className = "card"; histCard.style.marginTop = "12px";
        histCard.innerHTML = '<h2>' + t("commitHistTitle") + '</h2>';
        const histEl = document.createElement("div"); histEl.className = "hist";
        const hmax = Math.max(1, ...bins.map(b=>b.count));
        bins.forEach(b=>{
          if(b.count === 0) return;
          const lab = (b.hi===null) ? (b.lo + "+") : (b.lo + "\u2013" + (b.hi-1));
          const row = document.createElement("div"); row.className = "histRow";
          row.innerHTML = '<div class="lab">' + lab + '</div><div class="track"><div class="fill" style="width:' + (b.count/hmax*100).toFixed(2) + '%"></div></div><div class="n">' + fmtInt(b.count) + '</div>';
          histEl.appendChild(row);
        });
        histCard.appendChild(histEl);
        leftDiv.appendChild(histCard);
        split.appendChild(leftDiv);

        // Right: box by month + outliers
        const rightDiv = document.createElement("div");
        const byMonth = new Map();
        samples.forEach(s=>{
          const m = String(s.month||"");
          if(!m) return;
          if(!byMonth.has(m)) byMonth.set(m, []);
          byMonth.get(m).push(clampInt(s.cleanChurnLines||0));
        });
        const boxMonths = Array.from(byMonth.keys()).sort().slice(-12);
        const globalMax = Math.max(1, quantile([...sorted], 0.98));
        const boxCard = document.createElement("div"); boxCard.className = "card";
        boxCard.innerHTML = '<h2>' + t("commitBoxTitle") + '</h2>';
        const boxEl = document.createElement("div"); boxEl.className = "boxlist";
        boxMonths.forEach(m=>{
          const vals = (byMonth.get(m)||[]).filter(v=>v>=0).sort((a,b)=>a-b);
          if(vals.length===0) return;
          const bq1 = quantile(vals, 0.25), bq2 = quantile(vals, 0.5), bq3 = quantile(vals, 0.75);
          const left = (bq1/globalMax)*100, width = ((bq3-bq1)/globalMax)*100, med = (bq2/globalMax)*100;
          const row = document.createElement("div"); row.className = "boxRow";
          row.innerHTML = '<div class="lab">' + m + '</div><div class="track"><div class="iqr" style="left:'+left.toFixed(2)+'%;width:'+Math.max(0.5,width).toFixed(2)+'%"></div><div class="med" style="left:'+med.toFixed(2)+'%"></div></div><div class="n">' + fmtInt(vals.length) + '</div>';
          boxEl.appendChild(row);
        });
        boxCard.appendChild(boxEl);
        rightDiv.appendChild(boxCard);

        // Outliers (top commits)
        const out = [...samples].sort((a,b)=> (b.cleanChurnLines||0) - (a.cleanChurnLines||0)).slice(0,5);
        const outCard = document.createElement("div"); outCard.className = "card"; outCard.style.marginTop = "12px";
        outCard.innerHTML = '<h2>' + t("commitOutliersTitle") + '</h2>';
        const outEl = document.createElement("div"); outEl.className = "barlist";
        const omax = Math.max(1, ...out.map(x=>x.cleanChurnLines||0));
        out.forEach(x=>{
          const label = (x.project ? String(x.project) : "?") + " \u00B7 " + String(x.commit||"").slice(0,10);
          makeBar(label, clampInt(x.cleanChurnLines||0), omax, outEl);
        });
        outCard.appendChild(outEl);
        rightDiv.appendChild(outCard);
        split.appendChild(rightDiv);
      }

      function renderTechVolume(){
        const container = document.getElementById("techVolumeContent");
        container.innerHTML = "";
        const raw = data.lineStats?.raw || {insertions:0,deletions:0,files:0};
        const clean = data.lineStats?.clean || {insertions:0,deletions:0,files:0};
        const excl = data.lineStats?.excluded || {insertions:0,deletions:0,files:0};
        const hasData = (raw.insertions||0) + (raw.deletions||0) + (clean.insertions||0) + (clean.deletions||0) > 0;

        if(!hasData){
          const note = document.createElement("div");
          note.className = "info-note";
          note.textContent = t("lineStatsUnavailable");
          container.appendChild(note);
          return;
        }

        const tableWrap = document.createElement("div"); tableWrap.style.overflow = "auto";
        const dict = I18N[lang];
        const addRow = (label, s) => {
          const adds = clampInt(s.insertions||0), dels = clampInt(s.deletions||0);
          const files = clampInt(s.files||0), churn = adds+dels, net = adds-dels;
          return '<tr><td>' + label + '</td><td>' + fmtInt(adds) + '</td><td>' + fmtInt(dels) + '</td><td>' + fmtInt(files) + '</td><td>' + fmtInt(churn) + '</td><td>' + fmtSigned(net) + '</td></tr>';
        };
        tableWrap.innerHTML = '<table><thead><tr><th>' + dict.statType + '</th><th>' + dict.statAdds + '</th><th>' + dict.statDels + '</th><th>' + dict.statFiles + '</th><th>' + dict.statChurn + '</th><th>' + dict.statNet + '</th></tr></thead><tbody>' +
          addRow(dict.labelClean, clean) + addRow(dict.labelRaw, raw) + addRow(dict.labelExcluded, excl) +
          '</tbody></table>';
        container.appendChild(tableWrap);
        const excludedChurn = clampInt(excl.insertions||0) + clampInt(excl.deletions||0);
        const sub = document.createElement("div"); sub.className = "sub"; sub.style.marginTop = "8px";
        sub.textContent = dict.statExcluded + ": " + fmtInt(excludedChurn);
        container.appendChild(sub);
      }

      function renderFilesTouched(){
        const container = document.getElementById("filesTouchedContent");
        container.innerHTML = "";
        const samples = Array.isArray(data.commitSamples) ? data.commitSamples : [];
        const files = samples.map(s=> clampInt(s.filesClean ?? s.filesTouched ?? 0));
        const hasData = files.some(v => v > 0);
        const totalSamples = files.length;

        if(totalSamples === 0){
          container.innerHTML = '<div class="no-data">' + esc(t("noCommitData")) + '</div>';
          return;
        }
        if(!hasData){
          const note = document.createElement("div");
          note.className = "info-note";
          const tmpl2 = t("fileDataUnavailable");
          note.textContent = tmpl2.replace("{n}", fmtInt(totalSamples));
          container.appendChild(note);
          return;
        }

        const sorted = [...files].filter(v=>v>=0).sort((a,b)=>a-b);
        const mean = sorted.reduce((a,b)=>a+b,0) / sorted.length;
        const median = quantile(sorted, 0.5);
        const p90 = quantile(sorted, 0.9);
        const max = Math.max(1, ...sorted);
        const units = I18N[lang].units;
        const el = document.createElement("div"); el.className = "barlist";
        makeBarFrac(t("commitStatMean"), mean, max, el, units.files);
        makeBarFrac(t("commitStatMedian"), median, max, el, units.files);
        makeBarFrac("P90", p90, max, el, units.files);
        container.appendChild(el);
      }

      function renderConcentration(){
        const el = document.getElementById("concentrationBars");
        el.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects : [];
        const total = projects.reduce((s,p)=> s + (p.entries||0), 0);
        if(total <= 0) return;
        const top = projects.slice(0,5);
        const maxShare = Math.max(1, ...top.map(p=> (p.entries||0)/total*100));
        top.forEach(p=>{
          const share = (p.entries||0) / total * 100;
          const label = String(p.project);
          const row = document.createElement("div"); row.className = "bar";
          const lab = document.createElement("label"); lab.title = label; lab.textContent = label;
          const track = document.createElement("div"); track.className = "track";
          const fill = document.createElement("div"); fill.className = "fill";
          fill.style.width = (maxShare ? (share/maxShare*100) : 0).toFixed(2) + "%";
          track.appendChild(fill);
          const n = document.createElement("div"); n.className = "n"; n.textContent = fmt1(share) + "%";
          row.appendChild(lab); row.appendChild(track); row.appendChild(n);
          el.appendChild(row);
        });
      }

      function renderHighlights(){
        const monthToDays = new Map();
        for(const d of daySeries){
          const m = String(d.day||"").slice(0,7);
          if(!m) continue;
          if(!monthToDays.has(m)) monthToDays.set(m, new Set());
          monthToDays.get(m).add(String(d.day));
        }
        let bestMonth = null;
        for(const [m,set] of monthToDays){
          if(!bestMonth || set.size > bestMonth.active) bestMonth = { m, active: set.size };
        }
        if(bestMonth){
          document.getElementById("hl-consistent").textContent = bestMonth.m;
          document.getElementById("hl-consistent-sub").textContent = fmtInt(bestMonth.active) + " " + I18N[lang].units.days;
        }

        let spread = null;
        for(const d of daySeries){
          const n = Array.isArray(d.projects) ? d.projects.length : 0;
          if(!spread || n > spread.n) spread = { day: d.day, n };
        }
        if(spread){
          document.getElementById("hl-spread").textContent = spread.day;
          document.getElementById("hl-spread-sub").textContent = fmtInt(spread.n) + " " + t("labelProjects").toLowerCase();
        }

        const { busiestWeek } = computeBusiest();
        if(busiestWeek){
          document.getElementById("hl-week").textContent = busiestWeek.wk;
          document.getElementById("hl-week-sub").textContent = fmtInt(busiestWeek.count||0) + " " + I18N[lang].units.entries;
        }

        // Milestones: each bar scaled to its own next milestone target
        const ms = document.getElementById("hl-milestones");
        ms.innerHTML = "";
        const milestones = [
          { label: I18N[lang].metricEvents, cur: clampInt(data.totals?.events||0), steps: [50,100,250,500,1000,2000,5000] },
          { label: I18N[lang].metricDays, cur: clampInt(data.totals?.activeDays||0), steps: [10,25,50,100,200,365] },
          { label: I18N[lang].metricProjects, cur: clampInt(data.totals?.projects||0), steps: [5,10,25,50,100] },
          { label: I18N[lang].commitStatSamples, cur: clampInt(Array.isArray(data.commitSamples)?data.commitSamples.length:0), steps: [25,50,100,250,500,1000,2000] },
        ];
        for(const m of milestones){
          const next = m.steps.find(s=>s>m.cur) || m.cur;  // use cur as max if all steps exceeded
          const pct = Math.min(100, next > 0 ? (m.cur/next*100) : 100);
          const row = document.createElement("div"); row.className = "bar";
          const lab = document.createElement("label"); lab.title = m.label; lab.textContent = m.label;
          const track = document.createElement("div"); track.className = "track";
          const fill = document.createElement("div"); fill.className = "fill";
          fill.style.width = pct.toFixed(2) + "%";
          track.appendChild(fill);
          const n = document.createElement("div"); n.className = "n"; n.textContent = fmtInt(m.cur) + " / " + fmtInt(next);
          row.appendChild(lab); row.appendChild(track); row.appendChild(n);
          ms.appendChild(row);
        }

        // Top projects
        const tp = document.getElementById("hl-top-projects");
        tp.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects.slice(0,5) : [];
        const pmax = Math.max(1, ...projects.map(x=>x.entries||0));
        projects.forEach(x=> makeBar(String(x.project), clampInt(x.entries||0), pmax, tp));
      }

      function renderTopMetrics(){
        document.getElementById("m-events").textContent = fmtInt(data.totals?.events||0);
        document.getElementById("m-days").textContent = fmtInt(data.totals?.activeDays||0);
        document.getElementById("m-projects").textContent = fmtInt(data.totals?.projects||0);
        const { current, longest } = computeStreaks();
        document.getElementById("m-streak").textContent = fmtInt(current);
        document.getElementById("m-longest").textContent = fmtInt(longest);
        document.getElementById("m-streak-sub").textContent = t("streakMax").replace("{n}", fmtInt(longest));
        const { busiestDay, busiestWeek } = computeBusiest();
        if(busiestDay){
          document.getElementById("m-bday").textContent = busiestDay.day;
          document.getElementById("m-bday-sub").textContent = fmtInt(busiestDay.entries||0) + " " + I18N[lang].units.entries;
        }
        if(busiestWeek){
          document.getElementById("m-bweek").textContent = busiestWeek.wk;
          document.getElementById("m-bweek-sub").textContent = fmtInt(busiestWeek.count||0) + " " + I18N[lang].units.entries;
        }
      }

      function renderMicroBar(containerId, items, labelKey, countKey){
        const el = document.getElementById(containerId);
        if(!el) return;
        el.innerHTML = "";
        const maxVal = Math.max(1, ...items.map(x => x[countKey]||0));
        const CHART_H = 56; // px of bar area
        items.forEach(item => {
          const col = document.createElement("div"); col.className = "microbar-col";
          const barH = Math.max(2, Math.round((item[countKey]||0) / maxVal * CHART_H));
          const bar = document.createElement("div"); bar.className = "microbar-bar";
          bar.style.height = barH + "px";
          const label = document.createElement("div"); label.className = "microbar-label";
          label.textContent = item[labelKey];
          label.title = item[labelKey] + ": " + fmtInt(item[countKey]||0);
          col.appendChild(bar); col.appendChild(label);
          el.appendChild(col);
        });
      }

      function renderActivityCharts(){
        const hourSeries = Array.isArray(data.hourSeries) ? data.hourSeries : [];
        const dowSeries = Array.isArray(data.dowSeries) ? data.dowSeries : [];
        if(hourSeries.length > 0){
          const items = hourSeries.map(h => ({ label: String(h.hour).padStart(2,'0'), count: h.count||0 }));
          renderMicroBar("hourChart", items, "label", "count");
        }
        if(dowSeries.length > 0){
          renderMicroBar("dowChart", dowSeries, "label", "count");
        }
      }

      function renderAgentSection(){
        const ag = data.agentData;
        if(!ag || ag.totalEvents === 0){
          document.getElementById("agentSection").style.display = "none";
          return;
        }
        document.getElementById("agentSection").style.display = "";
        document.getElementById("agentPill").textContent = fmtInt(ag.totalEvents) + " " + I18N[lang].units.entries;

        // KPI cards
        const kpiEl = document.getElementById("agentKpi");
        kpiEl.innerHTML = "";
        const kpis = [
          { label: t("agentEventsLabel"), val: fmtInt(ag.totalEvents) },
          { label: t("distinctActors"), val: fmtInt((ag.actors||[]).length) },
          { label: t("modelsUsed"), val: fmtInt((ag.models||[]).length) },
          { label: t("toolsUsed"), val: fmtInt((ag.tools||[]).length) },
        ];
        kpis.forEach(k => {
          const card = document.createElement("div"); card.className = "agent-kpi-card";
          card.innerHTML = '<h3>' + esc(k.label) + '</h3><div class="val">' + k.val + '</div>';
          kpiEl.appendChild(card);
        });

        // Tools
        const toolsEl = document.getElementById("agentTools");
        toolsEl.innerHTML = "";
        const tools = (ag.tools||[]).slice(0,12);
        const tmax = Math.max(1, ...tools.map(([,c])=>c));
        tools.forEach(([name, count]) => makeBar(String(name), count, tmax, toolsEl, 'cyan'));

        // MCP + actors
        const mcpEl = document.getElementById("agentMcp");
        mcpEl.innerHTML = "";
        if((ag.mcpServers||[]).length > 0){
          const mmax = Math.max(1, ...ag.mcpServers.map(([,c])=>c||0));
          ag.mcpServers.forEach(([name, count]) => makeBar("MCP: " + String(name), count, mmax, mcpEl, 'green'));
        } else {
          mcpEl.innerHTML = '<div class="no-data">' + esc(t("noMcpData")) + '</div>';
        }
        const actorsEl = document.getElementById("agentActors");
        actorsEl.innerHTML = "";
        const actorList = ag.actors||[];
        if(actorList.length > 0){
          const amax = Math.max(1, ...actorList.map(([,c])=>c||0));
          actorList.forEach(([name, count]) => makeBar(String(name), count, amax, actorsEl));
        }

        // Days
        const daysEl = document.getElementById("agentDays");
        daysEl.innerHTML = "";
        const days = ag.daySeries||[];
        if(days.length > 0){
          const dmax = Math.max(1, ...days.map(d=>d.count||0));
          days.forEach(d => {
            const label = d.day + " \u00B7 " + (d.actors||[]).join(", ");
            makeBar(label, d.count||0, dmax, daysEl);
          });
        } else {
          daysEl.innerHTML = '<div class="no-data">' + esc(t("noAgentDays")) + '</div>';
        }
      }

      function renderProjectCards(){
        const container = document.getElementById("projectCards");
        container.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects : [];
        projects.forEach(p => {
          const kinds = p.kinds || {};
          const kindChips = Object.entries(kinds).map(([k,v]) =>
            '<span class="kchip kchip-' + esc(k) + '">' + esc(I18N[lang]?.kindLabels?.[k] || k) + '\u00a0' + v + '</span>'
          ).join(' ');
          const recent = (p.recent||[]).slice(0,3);
          const recentHtml = recent.length
            ? '<ul class="proj-recent" style="margin:0;padding-left:18px;">' +
              recent.map(s => '<li>' + esc(String(s)) + '</li>').join('') +
              '</ul>'
            : '<div class="no-data">' + esc(t("noSummaries")) + '</div>';

          const details = document.createElement("details");
          details.className = "proj-card";
          details.innerHTML =
            '<summary>' +
              '<i class="s-arrow">\u25B6</i>' +
              '<strong><code>' + esc(String(p.project)) + '</code></strong>' +
              '<span class="pill" style="margin-left:auto;">' + fmtInt(p.entries||0) + '</span>' +
            '</summary>' +
            '<div class="detailsBody">' +
              '<div class="proj-meta">' +
                '<span>' + esc(t("colFirst")) + ': ' + esc(p.firstDay||"") + '</span>' +
                '<span>' + esc(t("colLast")) + ': ' + esc(p.lastDay||"") + '</span>' +
                kindChips +
              '</div>' +
              '<div>' + recentHtml + '</div>' +
            '</div>';
          container.appendChild(details);
        });
      }

      function renderAll(){
        renderTopMetrics();
        renderHeatmap();
        renderBars();
        renderCommitStats();
        renderTechVolume();
        renderFilesTouched();
        renderConcentration();
        renderHighlights();
        renderActivityCharts();
        renderAgentSection();
        renderProjectCards();
      }

      setLang(lang);
    })();
  </script>
</main>
</body>
</html>

'@

$content = $template.Replace('__PAYLOAD_JSON__', $payloadJson).Replace('__I18N_JSON__', $i18nJson)

Set-Content -LiteralPath $outHtmlPath -Value $content -Encoding utf8
try {
    Set-Content -LiteralPath $ParentHtmlPath -Value $content -Encoding utf8
}
catch {
    # Non-fatal (CI or restricted path)
}

Write-Output "Rendered work impact to:"
Write-Output "  $outHtmlPath"
Write-Output "  $ParentHtmlPath"

