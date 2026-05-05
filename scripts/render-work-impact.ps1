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
            kindsTitle = 'What kind of work it was'
            projectsTitle = 'Projects with the most activity'
            projectsNote = 'Raw repo names are shown.'
            commitSizeTitle = 'Commit size (clean churn lines)'
            commitSizeHint = 'Commit size is computed from the commits referenced by backfill events. Clean churn lines = clean additions + clean deletions.'
            commitStatMean = 'Mean'
            commitStatMedian = 'Median'
            commitStatMode = 'Mode (bucket)'
            commitStatSamples = 'Commits measured'
            commitHistTitle = 'Distribution'
            commitBoxTitle = 'By month (quartiles)'
            commitOutliersTitle = 'Largest commits'
            techTitle = 'Technical volume (clean vs raw)'
            techHint = 'Line counts are only one imperfect proxy for effort.'
            statType = 'Metric'
            statAdds = 'Additions'
            statDels = 'Deletions'
            statFiles = 'Files'
            statChurn = 'Churn (adds + dels)'
            statNet = 'Net (adds - dels)'
            statExcluded = 'Excluded churn'
            filesTouchedTitle = 'Files touched per commit'
            concentrationTitle = 'Work concentration'
            concentrationHint = 'Shows how much of your recorded activity is concentrated in the top projects.'
            highlightsTitle = 'Highlights'
            highlightsHint = 'A few personal milestones and peaks from the selected range.'
            hlMostConsistentMonth = 'Most consistent month'
            hlWidestProjectDay = 'Widest project spread day'
            hlStrongestWeek = 'Strongest week'
            hlMilestones = 'Milestones'
            labelProjects = 'Projects'
            labelKinds = 'Kinds'
            labelClean = 'Clean'
            labelRaw = 'Raw'
            labelExcluded = 'Excluded'
            evidenceTitle = 'Evidence by project'
            evidenceHint = 'Use this for review before sharing.'
            colProject = 'Project'
            colEntries = 'Entries'
            colFirst = 'First'
            colLast = 'Last'
            colExamples = 'Examples'
            kindLabels = [ordered]@{
                'code-change' = 'Built or changed things'
                'plan' = 'Planning'
                'verification' = 'Checked the work'
                'commands' = 'Operations run'
                'handoff' = 'Handovers'
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
            subtitle = "Une vue simple du travail enregistre dans ton agent ledger."
            generated = 'Genere'
            range = 'Periode'
            langLabel = 'Langue'
            intro = "Ce rapport aide des gens non-tech a comprendre l'effort: a quelle frequence tu as travaille, sur combien de projets, et comment le rythme a evolue."
            metricEvents = 'Entrees de travail'
            metricDays = 'Jours actifs'
            metricProjects = 'Projets touches'
            metricStreak = 'Serie en cours'
            metricLongestStreak = 'Plus longue serie'
            metricBusiestDay = 'Jour le plus actif'
            metricBusiestWeek = 'Semaine la plus active'
            calendarTitle = 'Activite de travail par jour'
            calendarHint = "Survole un carre pour voir la journee."
            less = 'Moins'
            more = 'Plus'
            monthlyTitle = 'Travail enregistre par mois'
            kindsTitle = "Type de travail"
            projectsTitle = 'Projets les plus actifs'
            projectsNote = 'Les noms bruts des repos sont affiches.'
            commitSizeTitle = 'Taille des commits (churn propre)'
            commitSizeHint = "La taille des commits est calculee a partir des commits references par des evenements de backfill. Churn propre = ajouts propres + suppressions propres."
            commitStatMean = 'Moyenne'
            commitStatMedian = 'Mediane'
            commitStatMode = 'Mode (tranche)'
            commitStatSamples = 'Commits mesures'
            commitHistTitle = 'Distribution'
            commitBoxTitle = 'Par mois (quartiles)'
            commitOutliersTitle = 'Plus gros commits'
            techTitle = 'Volume technique (propre vs brut)'
            techHint = "Le nombre de lignes est juste un indice (pas une mesure parfaite)."
            statType = 'Metrique'
            statAdds = 'Ajouts'
            statDels = 'Suppressions'
            statFiles = 'Fichiers'
            statChurn = 'Churn (ajouts + suppr)'
            statNet = 'Net (ajouts - suppr)'
            statExcluded = 'Churn exclu'
            filesTouchedTitle = 'Fichiers touches par commit'
            concentrationTitle = 'Concentration du travail'
            concentrationHint = "Montre a quel point l'activite est concentree dans les projets les plus actifs."
            highlightsTitle = 'Faits saillants'
            highlightsHint = 'Quelques pointes et jalons personnels pour la periode.'
            hlMostConsistentMonth = 'Mois le plus constant'
            hlWidestProjectDay = 'Jour avec le plus de projets'
            hlStrongestWeek = 'Semaine la plus forte'
            hlMilestones = 'Jalons'
            labelProjects = 'Projets'
            labelKinds = 'Types'
            labelClean = 'Propre'
            labelRaw = 'Brut'
            labelExcluded = 'Exclu'
            evidenceTitle = 'Preuves par projet'
            evidenceHint = 'Utile pour verifier avant de partager.'
            colProject = 'Projet'
            colEntries = 'Entrees'
            colFirst = 'Premier'
            colLast = 'Dernier'
            colExamples = 'Exemples'
            kindLabels = [ordered]@{
                'code-change' = 'Construit ou modifie'
                'plan' = 'Planification'
                'verification' = 'Verification'
                'commands' = 'Operations lancees'
                'handoff' = 'Passations'
                'general' = 'Autre'
            }
            units = [ordered]@{
                days = 'jours'
                entries = 'entrees'
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
    :root {
      color-scheme: light dark;
      --bg: Canvas;
      --fg: CanvasText;
      --muted: color-mix(in srgb, CanvasText 62%, transparent);
      --border: color-mix(in srgb, CanvasText 16%, transparent);
      --card: color-mix(in srgb, Canvas 94%, CanvasText 6%);
      --chip: color-mix(in srgb, CanvasText 11%, transparent);
      --accent: #1f6feb;
      --good0: color-mix(in srgb, CanvasText 10%, transparent);
      --good1: #0e4429;
      --good2: #006d32;
      --good3: #26a641;
      --good4: #39d353;
    }
    @media (prefers-color-scheme: light) {
      :root {
        --good0: #ebedf0;
        --good1: #9be9a8;
        --good2: #40c463;
        --good3: #30a14e;
        --good4: #216e39;
      }
    }
    body { margin: 0; font-family: "Segoe UI", system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--fg); }
    main { max-width: 1120px; margin: 0 auto; padding: 28px 18px 64px; }
    header { display:flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }
    h1 { font-size: 24px; margin: 0; letter-spacing: 0; }
    .meta { margin: 8px 0 0; color: var(--muted); font-size: 13px; }
    .lang { display:flex; gap: 8px; align-items: center; }
    .toggle { display:inline-flex; border: 1px solid var(--border); border-radius: 999px; overflow:hidden; }
    .toggle button { appearance:none; border:0; padding: 8px 10px; cursor:pointer; background: transparent; color: var(--fg); font-size: 13px; }
    .toggle button[aria-pressed="true"] { background: var(--chip); }
    section { margin-top: 22px; }
    .grid { display:grid; gap: 12px; grid-template-columns: repeat(12, 1fr); }
    .card { border: 1px solid var(--border); background: var(--card); border-radius: 8px; padding: 12px 12px; }
    .card h2 { margin: 0 0 8px; font-size: 14px; color: var(--muted); font-weight: 600; }
    .big { font-size: 22px; font-weight: 700; }
    .sub { margin-top: 4px; font-size: 12px; color: var(--muted); }
    .span3 { grid-column: span 3; }
    .span4 { grid-column: span 4; }
    .span6 { grid-column: span 6; }
    .span12 { grid-column: span 12; }
    @media (max-width: 980px) { .span3, .span4, .span6 { grid-column: span 12; } }
    .kicker { margin: 10px 0 0; font-size: 14px; color: var(--fg); }
    .quiet { color: var(--muted); }
    .row { display:flex; gap: 10px; align-items: center; justify-content: space-between; flex-wrap: wrap; }
    .barlist { display:flex; flex-direction: column; gap: 8px; }
    .bar { display:flex; align-items:center; gap: 10px; }
    .bar label { width: 220px; font-size: 12px; color: var(--fg); overflow:hidden; text-overflow: ellipsis; white-space: nowrap; }
    .bar .track { flex: 1; height: 10px; border-radius: 999px; background: color-mix(in srgb, CanvasText 10%, transparent); overflow:hidden; }
    .bar .fill { height: 100%; background: var(--accent); }
    .bar .n { width: 80px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; }
    details { border: 1px solid var(--border); border-radius: 8px; background: var(--card); }
    summary { cursor: pointer; padding: 12px 14px; line-height: 1.35; }
    summary strong { font-size: 13px; }
    .detailsBody { padding: 0 14px 14px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { text-align:left; padding: 8px 6px; border-bottom: 1px solid var(--border); vertical-align: top; }
    th { color: var(--muted); font-weight: 600; }
    code { font-family: Consolas, monospace; font-size: 12px; }
    .pill { display:inline-block; padding: 2px 8px; border-radius: 999px; background: var(--chip); font-size: 12px; color: var(--fg); }
    .heatWrap { overflow-x: auto; }
    .heat { display: grid; grid-auto-flow: column; grid-auto-columns: 12px; gap: 3px; align-items: start; padding: 8px 6px 2px; }
    .heatCol { display:grid; grid-template-rows: repeat(7, 12px); gap: 3px; }
    .cell { width: 12px; height: 12px; border-radius: 3px; background: var(--good0); border: 1px solid color-mix(in srgb, CanvasText 10%, transparent); cursor: default; }
    .lvl1 { background: var(--good1); border-color: transparent; }
    .lvl2 { background: var(--good2); border-color: transparent; }
    .lvl3 { background: var(--good3); border-color: transparent; }
    .lvl4 { background: var(--good4); border-color: transparent; }
    .heatLegend { display:flex; gap: 8px; align-items:center; justify-content:flex-end; font-size: 12px; color: var(--muted); padding: 0 6px 10px; }
    .legendSwatch { display:flex; gap: 3px; align-items:center; }
    .tooltip { position: fixed; z-index: 50; pointer-events:none; background: color-mix(in srgb, Canvas 90%, CanvasText 10%); border: 1px solid var(--border); border-radius: 8px; padding: 10px 10px; max-width: 360px; box-shadow: 0 10px 30px rgba(0,0,0,.25); display:none; }
    .tooltip .t { font-size: 12px; color: var(--fg); }
    .tooltip .m { font-size: 12px; color: var(--muted); margin-top: 6px; white-space: pre-line; }
    .split { display:flex; gap: 14px; flex-wrap: wrap; align-items: flex-start; }
    .split > * { flex: 1 1 360px; }
    .hist { display:flex; flex-direction:column; gap:6px; }
    .histRow { display:flex; gap:10px; align-items:center; }
    .histRow .lab { width: 140px; font-size:12px; color: var(--fg); }
    .histRow .track { flex:1; height: 10px; border-radius:999px; background: color-mix(in srgb, CanvasText 10%, transparent); overflow:hidden; }
    .histRow .fill { height:100%; background: var(--accent); }
    .histRow .n { width: 80px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; }
    .boxlist { display:flex; flex-direction:column; gap:8px; }
    .boxRow { display:flex; gap:10px; align-items:center; }
    .boxRow .lab { width: 90px; font-size:12px; color: var(--fg); }
    .boxRow .track { position:relative; flex:1; height: 14px; border-radius:999px; background: color-mix(in srgb, CanvasText 10%, transparent); }
    .boxRow .iqr { position:absolute; top:3px; height:8px; border-radius: 6px; background: color-mix(in srgb, var(--accent) 45%, transparent); }
    .boxRow .med { position:absolute; top:1px; width:2px; height:12px; background: var(--accent); }
    .boxRow .n { width: 80px; text-align:right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 12px; }
  </style>
</head>
<body>
<main>
  <header>
    <div>
      <h1 id="title" data-i18n="title">Work Impact</h1>
      <div class="meta">
        <span id="subtitle" data-i18n="subtitle"></span>
        <span class="quiet"> · </span>
        <span class="quiet"><span data-i18n="range">Range</span>: <span id="range"></span></span>
        <span class="quiet"> · </span>
        <span class="quiet"><span data-i18n="generated">Generated</span>: <span id="generated"></span></span>
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

  <section class="grid">
    <div class="card span3">
      <h2 data-i18n="metricEvents">Work entries</h2>
      <div class="big" id="m-events">0</div>
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
      <h2 data-i18n="commitStatSamples">Commits measured</h2>
      <div class="big" id="m-commits">0</div>
      <div class="sub" id="m-commits-sub"></div>
    </div>
  </section>

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

  <section class="grid">
    <div class="card span6">
      <h2 data-i18n="monthlyTitle">Work recorded per month</h2>
      <div class="barlist" id="monthlyBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="projectsTitle">Projects with the most activity</h2>
      <div class="sub" data-i18n="projectsNote"></div>
      <div class="barlist" id="projectBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="kindsTitle">What kind of work it was</h2>
      <div class="barlist" id="kindBars"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="commitSizeTitle">Commit size</h2>
      <div class="sub" data-i18n="commitSizeHint"></div>
      <div class="split" style="margin-top:10px;">
        <div>
          <div class="grid">
            <div class="card span4" style="padding:10px;">
              <h2 data-i18n="commitStatMean">Mean</h2>
              <div class="big" id="c-mean">-</div>
            </div>
            <div class="card span4" style="padding:10px;">
              <h2 data-i18n="commitStatMedian">Median</h2>
              <div class="big" id="c-median">-</div>
            </div>
            <div class="card span4" style="padding:10px;">
              <h2 data-i18n="commitStatMode">Mode</h2>
              <div class="big" id="c-mode">-</div>
            </div>
          </div>
          <div class="card" style="margin-top:12px;">
            <h2 data-i18n="commitHistTitle">Distribution</h2>
            <div class="hist" id="commitHist"></div>
          </div>
        </div>
        <div>
          <div class="card">
            <h2 data-i18n="commitBoxTitle">By month</h2>
            <div class="boxlist" id="commitBox"></div>
          </div>
          <div class="card" style="margin-top:12px;">
            <h2 data-i18n="commitOutliersTitle">Largest commits</h2>
            <div class="barlist" id="commitOutliers"></div>
          </div>
        </div>
      </div>
    </div>
  </section>

  <section class="grid">
    <div class="card span6">
      <h2 data-i18n="techTitle">Technical volume (clean vs raw)</h2>
      <div class="sub" data-i18n="techHint"></div>
      <div style="overflow:auto; margin-top: 8px;">
        <table>
          <thead>
            <tr>
              <th data-i18n="statType">Metric</th>
              <th data-i18n="statAdds">Additions</th>
              <th data-i18n="statDels">Deletions</th>
              <th data-i18n="statFiles">Files</th>
              <th data-i18n="statChurn">Churn</th>
              <th data-i18n="statNet">Net</th>
            </tr>
          </thead>
          <tbody id="lineRows"></tbody>
        </table>
      </div>
      <div class="sub" style="margin-top:10px;">
        <span data-i18n="statExcluded">Excluded churn</span>: <span id="excludedChurn">0</span>
      </div>
    </div>
    <div class="card span6">
      <h2 data-i18n="filesTouchedTitle">Files touched per commit</h2>
      <div class="barlist" id="filesTouched"></div>
      <div style="margin-top:14px;">
        <h2 data-i18n="concentrationTitle">Work concentration</h2>
        <div class="sub" data-i18n="concentrationHint"></div>
        <div class="barlist" id="concentrationBars" style="margin-top: 10px;"></div>
      </div>
    </div>
  </section>

  <section class="grid">
    <div class="card span4">
      <h2 data-i18n="hlMostConsistentMonth">Most consistent month</h2>
      <div class="big" id="hl-consistent">-</div>
      <div class="sub" id="hl-consistent-sub"></div>
    </div>
    <div class="card span4">
      <h2 data-i18n="hlWidestProjectDay">Widest project spread day</h2>
      <div class="big" id="hl-spread">-</div>
      <div class="sub" id="hl-spread-sub"></div>
    </div>
    <div class="card span4">
      <h2 data-i18n="hlMilestones">Milestones</h2>
      <div class="sub" data-i18n="highlightsHint"></div>
      <div class="barlist" id="hl-milestones" style="margin-top: 10px;"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="hlStrongestWeek">Strongest week</h2>
      <div class="big" id="hl-week">-</div>
      <div class="sub" id="hl-week-sub"></div>
    </div>
    <div class="card span6">
      <h2 data-i18n="highlightsTitle">Highlights</h2>
      <div class="sub" data-i18n="highlightsHint"></div>
      <div class="barlist" id="hl-top-projects" style="margin-top: 10px;"></div>
    </div>
  </section>

  <section class="card">
    <h2 data-i18n="evidenceTitle">Evidence by project</h2>
    <div class="sub" data-i18n="evidenceHint"></div>
    <div style="overflow:auto; margin-top: 8px;">
      <table>
        <thead>
          <tr>
            <th data-i18n="colProject">Project</th>
            <th data-i18n="colEntries">Entries</th>
            <th data-i18n="colFirst">First</th>
            <th data-i18n="colLast">Last</th>
            <th data-i18n="colExamples">Examples</th>
          </tr>
        </thead>
        <tbody id="projectTable"></tbody>
      </table>
    </div>
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
      const fmtSigned = (n)=> (n>=0? "+" : "") + fmtInt(n);

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
        applyI18n();
        renderAll();
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

      // header meta
      document.getElementById("generated").textContent = data.generatedAtLocal || "";
      document.getElementById("range").textContent = (data.range?.start || "") + " → " + (data.range?.end || "");

      function parseLocalDate(s){
        // "YYYY-MM-DD" -> local Date
        if(!s) return null;
        const d = new Date(s + "T00:00:00");
        return Number.isNaN(d.getTime()) ? null : d;
      }
      function dayKey(d){
        const y = d.getFullYear();
        const m = String(d.getMonth()+1).padStart(2,"0");
        const da = String(d.getDate()).padStart(2,"0");
        return y + "-" + m + "-" + da;
      }
      function addDays(d, n){
        const out = new Date(d);
        out.setDate(out.getDate()+n);
        return out;
      }

      // Metrics
      const daySeries = Array.isArray(data.series?.days) ? data.series.days : [];
      const activeDays = new Set(daySeries.map(d=>d.day));

      function computeStreaks(){
        if(activeDays.size === 0) return { current: 0, longest: 0 };
        const end = parseLocalDate(data.range?.end) || new Date();
        // current streak: walk back from end date
        let cur = 0;
        for(let i=0;i<4000;i++){
          const k = dayKey(addDays(end, -i));
          if(activeDays.has(k)) cur++;
          else break;
        }
        // longest streak: scan all active days in sorted order
        const daysSorted = Array.from(activeDays).sort();
        let longest = 1;
        let run = 1;
        for(let i=1;i<daysSorted.length;i++){
          const prev = parseLocalDate(daysSorted[i-1]);
          const now = parseLocalDate(daysSorted[i]);
          if(!prev || !now) continue;
          const diff = Math.round((now - prev) / (24*3600*1000));
          if(diff === 1){
            run++;
            if(run > longest) longest = run;
          } else {
            run = 1;
          }
        }
        return { current: cur, longest };
      }

      function computeBusiest(){
        let busiestDay = null;
        for(const d of daySeries){
          if(!busiestDay || (d.entries||0) > (busiestDay.entries||0)) busiestDay = d;
        }
        // week: Monday-start buckets based on local date
        const weekCounts = new Map();
        for(const d of daySeries){
          const dt = parseLocalDate(d.day);
          if(!dt) continue;
          const dayOfWeek = (dt.getDay()+6)%7; // 0=Mon
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
        const bins = [];
        for(let i=0;i<edges.length;i++){
          const lo = edges[i];
          const hi = edges[i+1];
          bins.push({ lo, hi, count: 0 });
        }
        bins.push({ lo: edges[edges.length-1], hi: null, count: 0 });
        for(const v of values){
          const n = Math.max(0, Math.floor(v));
          let placed = false;
          for(const b of bins){
            if(b.hi === null){
              b.count++;
              placed = true;
              break;
            }
            if(n >= b.lo && n < b.hi){
              b.count++;
              placed = true;
              break;
            }
          }
          if(!placed) bins[bins.length-1].count++;
        }
        return bins;
      }

      function makeBar(label, count, max, container){
        const row = document.createElement("div"); row.className = "bar";
        const lab = document.createElement("label"); lab.title = label; lab.textContent = label;
        const track = document.createElement("div"); track.className = "track";
        const fill = document.createElement("div"); fill.className = "fill";
        fill.style.width = (max ? (count/max*100) : 0).toFixed(2) + "%";
        track.appendChild(fill);
        const n = document.createElement("div"); n.className = "n"; n.textContent = fmtInt(count);
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

        // align to Sunday like GitHub
        const startDow = start.getDay();
        const alignedStart = addDays(start, -startDow);

        const byDay = new Map(daySeries.map(d=>[d.day, d]));
        const daysTotal = Math.round((end - alignedStart)/(24*3600*1000)) + 1;
        const weeks = Math.ceil(daysTotal / 7);

        const counts = daySeries.map(d=>d.entries||0);
        const max = Math.max(1, ...counts);
        const q1 = quantile([...counts].sort((a,b)=>a-b), 0.25);
        const q2 = quantile([...counts].sort((a,b)=>a-b), 0.50);
        const q3 = quantile([...counts].sort((a,b)=>a-b), 0.75);

        function level(c){
          if(c <= 0) return 0;
          if(c <= q1) return 1;
          if(c <= q2) return 2;
          if(c <= q3) return 3;
          return 4;
        }

        for(let w=0; w<weeks; w++){
          const col = document.createElement("div");
          col.className = "heatCol";
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
              tipTitle.textContent = key + " · " + fmtInt(c) + " " + dict.units.entries;
              tipMeta.textContent =
                (projects.length ? (dict.labelProjects + ": " + projects.join(", ")) : "") +
                (kindParts.length ? ("\\n" + kindParts.join("\\n")) : "");
              tip.style.display = "block";
              const x = ev.clientX + 12;
              const y = ev.clientY + 12;
              tip.style.left = x + "px";
              tip.style.top = y + "px";
            });
            cell.addEventListener("mouseleave", ()=>{ tip.style.display = "none"; });
            col.appendChild(cell);
          }
          heat.appendChild(col);
        }
      }

      function renderBars(){
        // monthly
        const monthlyBars = document.getElementById("monthlyBars");
        monthlyBars.innerHTML = "";
        const months = Array.isArray(data.series?.months) ? data.series.months.slice(-18) : [];
        const mmax = Math.max(1, ...months.map(x=>x.count||0));
        months.forEach(x=> makeBar(String(x.month), clampInt(x.count||0), mmax, monthlyBars));

        // kinds
        const kindBars = document.getElementById("kindBars");
        kindBars.innerHTML = "";
        const kinds = Array.isArray(data.series?.kinds) ? data.series.kinds : [];
        const kmax = Math.max(1, ...kinds.map(x=>x.count||0));
        kinds.forEach(x=>{
          const label = I18N[lang]?.kindLabels?.[x.kind] || x.kind;
          makeBar(label, clampInt(x.count||0), kmax, kindBars);
        });

        // projects
        const projectBars = document.getElementById("projectBars");
        projectBars.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects.slice(0, 12) : [];
        const pmax = Math.max(1, ...projects.map(x=>x.entries||0));
        projects.forEach(x=> makeBar(String(x.project), clampInt(x.entries||0), pmax, projectBars));
      }

      function renderProjectTable(){
        const pt = document.getElementById("projectTable");
        pt.innerHTML = "";
        const projects = Array.isArray(data.series?.projects) ? data.series.projects : [];
        projects.forEach(p=>{
          const tr = document.createElement("tr");
          const ex = (p.recent||[]).map(s=>"• " + s).join("\\n");
          tr.innerHTML = `<td><code>${String(p.project)}</code></td><td>${fmtInt(p.entries||0)}</td><td>${p.firstDay||""}</td><td>${p.lastDay||""}</td><td><pre style="margin:0;white-space:pre-wrap;font-family:inherit">${ex}</pre></td>`;
          pt.appendChild(tr);
        });
      }

      function renderLineStats(){
        const rows = document.getElementById("lineRows");
        rows.innerHTML = "";
        const raw = data.lineStats?.raw || {insertions:0,deletions:0,files:0};
        const clean = data.lineStats?.clean || {insertions:0,deletions:0,files:0};
        const excl = data.lineStats?.excluded || {insertions:0,deletions:0,files:0};

        const addRow = (label, s) => {
          const adds = clampInt(s.insertions||0);
          const dels = clampInt(s.deletions||0);
          const files = clampInt(s.files||0);
          const churn = adds + dels;
          const net = adds - dels;
          const tr = document.createElement("tr");
          tr.innerHTML = `<td>${label}</td><td>${fmtInt(adds)}</td><td>${fmtInt(dels)}</td><td>${fmtInt(files)}</td><td>${fmtInt(churn)}</td><td>${fmtSigned(net)}</td>`;
          rows.appendChild(tr);
        };

        const dict = I18N[lang];
        addRow(dict.labelClean, clean);
        addRow(dict.labelRaw, raw);
        addRow(dict.labelExcluded, excl);

        const excludedChurn = clampInt(excl.insertions||0) + clampInt(excl.deletions||0);
        document.getElementById("excludedChurn").textContent = fmtInt(excludedChurn);
      }

      function renderCommitStats(){
        const samples = Array.isArray(data.commitSamples) ? data.commitSamples : [];
        const values = samples.map(s=> clampInt(s.cleanChurnLines||0)).filter(n=>n>=0);
        document.getElementById("m-commits").textContent = fmtInt(values.length);
        document.getElementById("m-commits-sub").textContent = values.length ? (fmtInt(values.length) + " " + I18N[lang].units.commits) : "";

        if(values.length === 0){
          document.getElementById("c-mean").textContent = "-";
          document.getElementById("c-median").textContent = "-";
          document.getElementById("c-mode").textContent = "-";
          document.getElementById("commitHist").innerHTML = "";
          document.getElementById("commitBox").innerHTML = "";
          document.getElementById("commitOutliers").innerHTML = "";
          return;
        }

        const sorted = [...values].sort((a,b)=>a-b);
        const mean = sorted.reduce((a,b)=>a+b,0) / sorted.length;
        const median = quantile(sorted, 0.5);
        const bins = histogramBuckets(sorted);
        const modeBin = bins.reduce((best,b)=> (b.count > (best?.count||-1) ? b : best), null);
        const modeLabel = modeBin ? (modeBin.hi===null ? (modeBin.lo + "+") : (modeBin.lo + "–" + (modeBin.hi-1))) : "-";

        document.getElementById("c-mean").textContent = fmt1(mean) + " " + I18N[lang].units.lines;
        document.getElementById("c-median").textContent = fmt1(median) + " " + I18N[lang].units.lines;
        document.getElementById("c-mode").textContent = modeLabel + " " + I18N[lang].units.lines;

        // histogram
        const hist = document.getElementById("commitHist");
        hist.innerHTML = "";
        const hmax = Math.max(1, ...bins.map(b=>b.count));
        bins.forEach(b=>{
          const lab = (b.hi===null) ? (b.lo + "+") : (b.lo + "–" + (b.hi-1));
          const row = document.createElement("div"); row.className = "histRow";
          row.innerHTML = `<div class="lab">${lab}</div><div class="track"><div class="fill" style="width:${(b.count/hmax*100).toFixed(2)}%"></div></div><div class="n">${fmtInt(b.count)}</div>`;
          hist.appendChild(row);
        });

        // box by month
        const byMonth = new Map();
        samples.forEach(s=>{
          const m = String(s.month||"");
          if(!m) return;
          if(!byMonth.has(m)) byMonth.set(m, []);
          byMonth.get(m).push(clampInt(s.cleanChurnLines||0));
        });
        const months = Array.from(byMonth.keys()).sort().slice(-12);
        const all = sorted;
        const globalMax = Math.max(1, quantile(all, 0.98)); // dampen outliers in scale
        const box = document.getElementById("commitBox");
        box.innerHTML = "";
        months.forEach(m=>{
          const vals = (byMonth.get(m)||[]).filter(v=>v>=0).sort((a,b)=>a-b);
          if(vals.length===0) return;
          const q1 = quantile(vals, 0.25);
          const q2 = quantile(vals, 0.5);
          const q3 = quantile(vals, 0.75);
          const left = (q1/globalMax)*100;
          const width = ((q3-q1)/globalMax)*100;
          const med = (q2/globalMax)*100;
          const row = document.createElement("div"); row.className = "boxRow";
          const n = vals.length;
          row.innerHTML = `<div class="lab">${m}</div><div class="track"><div class="iqr" style="left:${left.toFixed(2)}%;width:${Math.max(0.5,width).toFixed(2)}%"></div><div class="med" style="left:${med.toFixed(2)}%"></div></div><div class="n">${fmtInt(n)}</div>`;
          box.appendChild(row);
        });

        // outliers: top 5 commits by clean churn
        const out = [...samples].sort((a,b)=> (b.cleanChurnLines||0) - (a.cleanChurnLines||0)).slice(0,5);
        const outEl = document.getElementById("commitOutliers");
        outEl.innerHTML = "";
        const omax = Math.max(1, ...out.map(x=>x.cleanChurnLines||0));
        out.forEach(x=>{
          const label = (x.project ? String(x.project) : "Project") + " · " + String(x.commit||"").slice(0,12);
          makeBar(label, clampInt(x.cleanChurnLines||0), omax, outEl);
        });
      }

      function renderFilesTouched(){
        const el = document.getElementById("filesTouched");
        el.innerHTML = "";
        const samples = Array.isArray(data.commitSamples) ? data.commitSamples : [];
        const files = samples.map(s=> clampInt(s.filesClean ?? s.filesTouched ?? 0)).filter(n=>n>=0);
        if(files.length === 0){
          el.innerHTML = `<div class="quiet">${lang==="qc" ? "Aucune donnee de commit pour l'instant." : "No commit data yet."}</div>`;
          return;
        }
        const sorted = [...files].sort((a,b)=>a-b);
        const mean = sorted.reduce((a,b)=>a+b,0) / sorted.length;
        const median = quantile(sorted, 0.5);
        const p90 = quantile(sorted, 0.9);
        const max = Math.max(1, ...sorted);
        makeBar(lang==="qc" ? "Moyenne" : "Mean", Number(mean.toFixed(2)), max, el);
        makeBar(lang==="qc" ? "Mediane" : "Median", Number(median.toFixed(2)), max, el);
        makeBar(lang==="qc" ? "P90" : "P90", Number(p90.toFixed(2)), max, el);
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
          const n = document.createElement("div"); n.className = "n"; n.textContent = fmt2(share) + "%";
          row.appendChild(lab); row.appendChild(track); row.appendChild(n);
          el.appendChild(row);
        });
      }

      function renderHighlights(){
        // Most consistent month = month with most active days
        const monthToDays = new Map();
        for(const d of daySeries){
          const m = String(d.day||"").slice(0,7);
          if(!m) continue;
          if(!monthToDays.has(m)) monthToDays.set(m, new Set());
          monthToDays.get(m).add(String(d.day));
        }
        let bestMonth = null;
        for(const [m,set] of monthToDays){
          const active = set.size;
          if(!bestMonth || active > bestMonth.active) bestMonth = { m, active };
        }
        if(bestMonth){
          document.getElementById("hl-consistent").textContent = bestMonth.m;
          document.getElementById("hl-consistent-sub").textContent =
            fmtInt(bestMonth.active) + " " + I18N[lang].units.days;
        }

        // Widest project spread day
        let spread = null;
        for(const d of daySeries){
          const n = Array.isArray(d.projects) ? d.projects.length : 0;
          if(!spread || n > spread.n) spread = { day: d.day, n };
        }
        if(spread){
          document.getElementById("hl-spread").textContent = spread.day;
          document.getElementById("hl-spread-sub").textContent =
            fmtInt(spread.n) + " " + (lang==="qc" ? I18N[lang].labelProjects.toLowerCase() : "projects");
        }

        // Strongest week (entries)
        const { busiestWeek } = computeBusiest();
        if(busiestWeek){
          document.getElementById("hl-week").textContent = busiestWeek.wk;
          document.getElementById("hl-week-sub").textContent =
            fmtInt(busiestWeek.count||0) + " " + I18N[lang].units.entries;
        }

        // Milestones
        const ms = document.getElementById("hl-milestones");
        ms.innerHTML = "";
        const milestones = [
          { key: "entries", label: I18N[lang].metricEvents, cur: clampInt(data.totals?.events||0), steps: [50,100,250,500,1000,2000,5000] },
          { key: "days", label: I18N[lang].metricDays, cur: clampInt(data.totals?.activeDays||0), steps: [5,10,25,50,100,200,365] },
          { key: "projects", label: I18N[lang].metricProjects, cur: clampInt(data.totals?.projects||0), steps: [3,5,10,25,50,100] },
          { key: "commits", label: I18N[lang].commitStatSamples, cur: clampInt((Array.isArray(data.commitSamples)?data.commitSamples.length:0)), steps: [10,25,50,100,250,500] },
        ];
        const maxNext = (m) => (m.steps.find(s=>s>m.cur) || (m.steps[m.steps.length-1] || Math.max(1,m.cur)));
        const mmax = Math.max(1, ...milestones.map(m=>maxNext(m)));
        for(const m of milestones){
          const next = maxNext(m);
          const row = document.createElement("div"); row.className = "bar";
          const lab = document.createElement("label"); lab.title = m.label; lab.textContent = m.label;
          const track = document.createElement("div"); track.className = "track";
          const fill = document.createElement("div"); fill.className = "fill";
          fill.style.width = (next ? Math.min(100, (m.cur/next*100)) : 0).toFixed(2) + "%";
          track.appendChild(fill);
          const n = document.createElement("div"); n.className = "n"; n.textContent = fmtInt(m.cur) + "/" + fmtInt(next);
          row.appendChild(lab); row.appendChild(track); row.appendChild(n);
          ms.appendChild(row);
        }

        // Top projects list (for the personal "what I touched most")
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
        document.getElementById("m-streak-sub").textContent = lang==="qc"
          ? ("Max: " + fmtInt(longest) + " jours")
          : ("Max: " + fmtInt(longest) + " days");

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

      function renderAll(){
        renderTopMetrics();
        renderHeatmap();
        renderBars();
        renderCommitStats();
        renderLineStats();
        renderFilesTouched();
        renderConcentration();
        renderHighlights();
        renderProjectTable();
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

