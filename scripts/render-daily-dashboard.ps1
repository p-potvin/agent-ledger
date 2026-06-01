<#
.SYNOPSIS
    VaultWares Daily Dashboard Renderer

.DESCRIPTION
    Reads agent-ledger/input-logs/*.json (input tracker data) and
    agent-ledger/history/**/*.json (ledger events) then bakes everything
    into a self-contained DAILY_DASHBOARD.html with the full VaultWares
    console theme: LED stat cards, hourly activity bars, heatmap, focus
    blocks, AI model breakdown, fun stats, and more.

.PARAMETER LedgerRoot
    Path to the agent-ledger repo root. Defaults to the parent of this script's directory.

.PARAMETER OutPath
    Where to write the HTML file. Defaults to <LedgerRoot>/DAILY_DASHBOARD.html.

.PARAMETER DaysBack
    How many days of input-log data to pre-load into the HTML. Default 90.
#>
[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$OutPath,
    [int]   $DaysBack = 90
)

$ErrorActionPreference = "Stop"

if (-not $LedgerRoot) {
    $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
}
if (-not $OutPath) {
    $OutPath = Join-Path $LedgerRoot "DAILY_DASHBOARD.html"
}

$LogDir      = Join-Path $LedgerRoot "input-logs"
$HistoryDir  = Join-Path $LedgerRoot "history"
$EventsDir   = Join-Path $LedgerRoot "events"

# ---------------------------------------------------------------------------
# 1. Load input-log files
# ---------------------------------------------------------------------------

$inputDays = [System.Collections.Generic.List[object]]::new()

if (Test-Path $LogDir) {
    $cutoff = (Get-Date).AddDays(-$DaysBack).Date
    Get-ChildItem -Path $LogDir -Filter "*.json" -File |
        Sort-Object Name |
        Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}$' } |
        ForEach-Object {
            try {
                $dt = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
                if ($dt -ge $cutoff) {
                    $obj = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                    $inputDays.Add($obj)
                }
            } catch { }
        }
}

# ---------------------------------------------------------------------------
# 2. Load ledger events (slim: date, project, kind, model, actor)
# ---------------------------------------------------------------------------

$ledgerEvents = [System.Collections.Generic.List[object]]::new()
$seenIds      = [System.Collections.Generic.HashSet[string]]::new()

function Import-LedgerDir {
    param([string]$Dir, [datetime]$Cutoff)
    if (-not (Test-Path $Dir)) { return }
    Get-ChildItem -Path $Dir -Filter "*.json" -Recurse -File |
        Sort-Object Name |
        ForEach-Object {
            try {
                $raw = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $dt  = [datetime]::Parse($raw.createdAt)
                $id  = if ($raw.id) { $raw.id } else { $_.BaseName }
                if ($dt.Date -ge $Cutoff -and $seenIds.Add($id)) {
                    $ledgerEvents.Add([pscustomobject]@{
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
Import-LedgerDir -Dir $HistoryDir -Cutoff $cutoff
Import-LedgerDir -Dir $EventsDir  -Cutoff $cutoff

# ---------------------------------------------------------------------------
# 3. Serialise to JSON for injection into HTML
# ---------------------------------------------------------------------------

$inputDaysJson  = $inputDays  | ConvertTo-Json -Depth 6 -Compress
$ledgerJson     = $ledgerEvents | ConvertTo-Json -Depth 3 -Compress
$generatedAt    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")

if ($inputDays.Count -eq 0)  { $inputDaysJson  = "[]" }
if ($ledgerEvents.Count -eq 0){ $ledgerJson    = "[]" }

# ---------------------------------------------------------------------------
# 4. HTML template
# ---------------------------------------------------------------------------

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Daily Dashboard -- VaultWares</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap">
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
<style>
/* ===== VaultWares Console Design Tokens ===== */
:root {
  --font-sans: "Inter","Segoe UI",ui-sans-serif,system-ui,sans-serif;
  --font-mono: "JetBrains Mono","Cascadia Code",Consolas,ui-monospace,monospace;
  --bg:        #0e0c18;
  --surface:   #161320;
  --surface2:  #1c1826;
  --surface3:  #231e30;
  --border:    rgba(255,255,255,0.07);
  --fg:        #d8d0f0;
  --muted:     rgba(216,208,240,0.48);
  --dim:       rgba(216,208,240,0.24);
  --gold:      #b8882e;
  --gold-glow: rgba(184,136,46,0.28);
  --gold-dim:  rgba(184,136,46,0.12);
  --amber:     #c49840;
  --amber-glow:rgba(196,152,64,0.22);
  --violet:    #8a62c0;
  --violet-glow:rgba(138,98,192,0.28);
  --green:     #4e9954;
  --green-glow:rgba(78,153,84,0.28);
  --red:       #a84e5a;
  --red-glow:  rgba(168,78,90,0.28);
  --orange:    #a86840;
  --orange-glow:rgba(168,104,64,0.28);
}

/* ===== Reset ===== */
*,*::before,*::after{box-sizing:border-box}
body{margin:0;font-family:var(--font-sans);background:var(--bg);color:var(--fg);line-height:1.5;-webkit-font-smoothing:antialiased;min-height:100vh}
main{max-width:1200px;margin:0 auto;padding:24px 16px 80px}
a{color:var(--gold)}
canvas{display:block}

/* ===== Header ===== */
header{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;padding-bottom:18px;border-bottom:1px solid var(--border);margin-bottom:4px}
.brand{display:flex;align-items:center;gap:10px}
.brand-badge{background:var(--gold-dim);border:1px solid var(--gold-glow);border-radius:6px;padding:3px 10px;font-size:10px;font-weight:800;color:var(--gold);letter-spacing:.1em;text-transform:uppercase}
h1{margin:0;font-size:22px;font-weight:800;letter-spacing:-.01em}
h1 span{color:var(--gold)}
.meta-row{color:var(--muted);font-size:12px;margin-top:2px}

/* ===== Range Picker ===== */
.range-row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.range-row label{font-size:12px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.range-btn{appearance:none;border:1px solid var(--border);border-radius:6px;padding:6px 14px;background:var(--surface2);color:var(--muted);font-size:12px;font-weight:600;cursor:pointer;transition:all .15s;font-family:var(--font-sans)}
.range-btn:hover{border-color:var(--gold);color:var(--gold)}
.range-btn.active{background:var(--gold-dim);border-color:var(--gold);color:var(--gold)}
.custom-row{display:flex;gap:8px;align-items:center;margin-top:6px;display:none}
.custom-row.visible{display:flex}
.custom-row input{appearance:none;border:1px solid var(--border);border-radius:6px;padding:5px 10px;background:var(--surface2);color:var(--fg);font-size:12px;font-family:var(--font-mono)}
.custom-row button{appearance:none;border:1px solid var(--gold-glow);border-radius:6px;padding:5px 12px;background:var(--gold-dim);color:var(--gold);font-size:12px;font-weight:700;cursor:pointer;font-family:var(--font-sans)}

/* ===== Grid ===== */
section{margin-top:24px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(12,1fr)}
.span2{grid-column:span 2}
.span3{grid-column:span 3}
.span4{grid-column:span 4}
.span6{grid-column:span 6}
.span8{grid-column:span 8}
.span12{grid-column:span 12}
@media(max-width:900px){.span2,.span3,.span4,.span6,.span8{grid-column:span 6}}
@media(max-width:560px){.span2,.span3,.span4,.span6,.span8{grid-column:span 12}}

/* ===== Cards ===== */
.card{border:1px solid var(--border);background:var(--surface);border-radius:12px;padding:16px;position:relative}
.card-title{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 10px}
.big-num{font-size:32px;font-weight:800;line-height:1;font-variant-numeric:tabular-nums;font-family:var(--font-mono)}
.big-sub{font-size:11px;color:var(--muted);margin-top:4px}
section > h2{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 10px}

/* ===== LED Stat Cards ===== */
.led-card{border-radius:12px;padding:16px 16px 14px;background:var(--surface2);border:1px solid var(--border);display:flex;flex-direction:column;gap:4px}
.led-card .led-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;animation:ledpulse 3s ease-in-out infinite}
@keyframes ledpulse{0%,100%{opacity:1}60%{opacity:.4}}
.led-header{display:flex;align-items:center;gap:7px}
.led-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}
.led-value{font-size:26px;font-weight:800;font-family:var(--font-mono);line-height:1.1;font-variant-numeric:tabular-nums}
.led-unit{font-size:11px;font-weight:600;opacity:.6;margin-left:2px}
.led-sub{font-size:11px;color:var(--muted);margin-top:2px}

.led-gold .led-dot{background:var(--gold);box-shadow:0 0 5px var(--gold)}
.led-gold .led-value{color:var(--gold)}

.led-violet .led-dot{background:var(--violet);box-shadow:0 0 5px var(--violet)}
.led-violet .led-value{color:var(--violet)}

.led-green .led-dot{background:var(--green);box-shadow:0 0 5px var(--green)}
.led-green .led-value{color:var(--green)}

.led-amber .led-dot{background:var(--amber);box-shadow:0 0 5px var(--amber)}
.led-amber .led-value{color:var(--amber)}

.led-orange .led-dot{background:var(--orange);box-shadow:0 0 5px var(--orange)}
.led-orange .led-value{color:var(--orange)}

.led-red .led-dot{background:var(--red);box-shadow:0 0 5px var(--red)}
.led-red .led-value{color:var(--red)}

/* ===== Hourly Chart ===== */
.chart-wrap{position:relative;width:100%;height:240px}

/* ===== Heatmap ===== */
.heatWrap{overflow-x:auto;scrollbar-width:thin}
.heat{display:grid;grid-auto-flow:column;grid-auto-columns:13px;gap:3px;align-items:start;padding:6px 4px 4px}
.heatCol{display:grid;grid-template-rows:repeat(7,13px);gap:3px}
.cell{width:13px;height:13px;border-radius:3px;background:rgba(255,255,255,.05);cursor:default;transition:transform .1s}
.cell:hover{transform:scale(1.4)}
.lvl1{background:rgba(138,98,192,.25)}
.lvl2{background:rgba(138,98,192,.48)}
.lvl3{background:rgba(138,98,192,.72)}
.lvl4{background:var(--violet)}
.heatLegend{display:flex;gap:8px;align-items:center;justify-content:flex-end;font-size:11px;color:var(--muted);padding:0 4px 4px}
.legendSwatch{display:flex;gap:3px;align-items:center}
.heatMonths{display:flex;gap:3px;padding:0 4px;font-size:9px;color:var(--dim);overflow-x:auto;scrollbar-width:none}
.heatMonthLabel{min-width:13px;text-align:center}

/* ===== Focus Blocks ===== */
.focus-timeline{position:relative;height:44px;background:var(--surface2);border-radius:8px;overflow:hidden;margin-top:8px}
.focus-block{position:absolute;top:8px;height:28px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;font-family:var(--font-mono);color:rgba(0,0,0,.7);cursor:default;transition:filter .15s}
.focus-block:hover{filter:brightness(1.15)}
.focus-axis{display:flex;justify-content:space-between;padding:0 2px;margin-top:4px}
.focus-axis span{font-size:9px;color:var(--dim);font-family:var(--font-mono)}
.focus-empty{text-align:center;color:var(--muted);font-size:12px;padding:14px 0;font-style:italic}

/* ===== Deep Work Score ===== */
.score-ring-wrap{display:flex;flex-direction:column;align-items:center;gap:6px;padding:8px 0}
.score-label{font-size:11px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.score-ring{position:relative;width:110px;height:110px}
.score-ring svg{transform:rotate(-90deg)}
.score-inner{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.score-num{font-size:28px;font-weight:800;font-family:var(--font-mono);color:var(--violet)}
.score-max{font-size:10px;color:var(--muted)}
.score-title{font-size:12px;font-weight:700;color:var(--violet)}

/* ===== Fun Facts ===== */
.fun-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin-top:8px}
.fun-card{background:var(--surface2);border:1px solid var(--border);border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:4px}
.fun-emoji{font-size:22px;line-height:1}
.fun-stat{font-size:16px;font-weight:800;font-family:var(--font-mono);color:var(--fg)}
.fun-desc{font-size:11px;color:var(--muted)}

/* ===== Bar list ===== */
.barlist{display:flex;flex-direction:column;gap:7px}
.bar-row{display:flex;align-items:center;gap:10px}
.bar-label{width:160px;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex-shrink:0;color:var(--fg)}
.bar-track{flex:1;height:8px;border-radius:999px;background:rgba(255,255,255,.05);overflow:hidden;min-width:40px}
.bar-fill{height:100%;border-radius:999px}
.bar-n{width:54px;text-align:right;font-size:12px;color:var(--muted);font-family:var(--font-mono);flex-shrink:0}

/* ===== Tooltip ===== */
#tooltip{position:fixed;z-index:99;pointer-events:none;background:var(--surface3);border:1px solid var(--border);border-radius:10px;padding:10px 13px;max-width:280px;box-shadow:0 16px 48px rgba(0,0,0,.55);display:none}
#tooltip .tt{font-size:12px;font-weight:700;color:var(--fg)}
#tooltip .tm{font-size:12px;color:var(--muted);margin-top:5px;white-space:pre-line}

/* ===== No-data ===== */
.nodata{color:var(--muted);font-size:12px;font-style:italic;padding:12px 0;text-align:center}

/* ===== Misc ===== */
.sep{border:none;border-top:1px solid var(--border);margin:0}
.tag{display:inline-block;padding:1px 7px;border-radius:999px;font-size:10px;font-weight:700;border:1px solid}
.tag-violet{background:var(--surface3);border-color:rgba(138,98,192,.3);color:var(--violet)}
.tag-gold{background:var(--gold-dim);border-color:var(--gold-glow);color:var(--gold)}
</style>
</head>
<body>
<main>

<!-- ===== Header ===== -->
<header>
  <div class="brand">
    <div class="brand-badge">VaultWares</div>
    <div>
      <h1>Daily <span>Dashboard</span></h1>
      <div class="meta-row">Generated <span id="genTime"></span> &nbsp;&middot;&nbsp; <span id="dataRange"></span></div>
    </div>
  </div>
  <div>
    <div class="range-row">
      <label>Range</label>
      <button class="range-btn" data-range="1">Today</button>
      <button class="range-btn" data-range="7">7 days</button>
      <button class="range-btn active" data-range="30">30 days</button>
      <button class="range-btn" data-range="90">90 days</button>
      <button class="range-btn" data-range="custom">Custom</button>
    </div>
    <div class="custom-row" id="customRow">
      <input type="date" id="customFrom">
      <span style="color:var(--muted);font-size:12px">-></span>
      <input type="date" id="customTo">
      <button onclick="applyCustom()">Apply</button>
    </div>
  </div>
</header>

<!-- ===== LED Stat Strip ===== -->
<section>
  <div class="grid" id="ledStrip">
    <div class="led-card led-gold span2" id="card-keys">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Keystrokes</div></div>
      <div class="led-value" id="v-keys">--</div>
      <div class="led-sub" id="s-keys"></div>
    </div>
    <div class="led-card led-violet span2" id="card-mouse">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Mouse Travel</div></div>
      <div class="led-value" id="v-mouse">--<span class="led-unit">m</span></div>
      <div class="led-sub" id="s-mouse"></div>
    </div>
    <div class="led-card led-green span2" id="card-saves">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Saves</div></div>
      <div class="led-value" id="v-saves">--</div>
      <div class="led-sub" id="s-saves"></div>
    </div>
    <div class="led-card led-amber span2" id="card-copies">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Copies</div></div>
      <div class="led-value" id="v-copies">--</div>
      <div class="led-sub" id="s-copies"></div>
    </div>
    <div class="led-card led-orange span2" id="card-chars">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Chars Typed</div></div>
      <div class="led-value" id="v-chars">--</div>
      <div class="led-sub" id="s-chars"></div>
    </div>
    <div class="led-card led-red span2" id="card-pastes">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Pastes</div></div>
      <div class="led-value" id="v-pastes">--</div>
      <div class="led-sub" id="s-pastes"></div>
    </div>
  </div>
</section>

<!-- ===== Hourly Activity ===== -->
<section>
  <h2 id="hourlyTitle">Hourly Activity -- Today</h2>
  <div class="card span12">
    <div class="chart-wrap"><canvas id="hourlyChart"></canvas></div>
  </div>
</section>

<!-- ===== Heatmap + Deep Work Score ===== -->
<section>
  <div class="grid">
    <div class="card span9">
      <div class="card-title">Activity Heatmap</div>
      <div class="heatMonths" id="heatMonths"></div>
      <div class="heatWrap"><div class="heat" id="heatGrid"></div></div>
      <div class="heatLegend">
        <span>Less</span>
        <div class="legendSwatch">
          <div class="cell"></div><div class="cell lvl1"></div>
          <div class="cell lvl2"></div><div class="cell lvl3"></div>
          <div class="cell lvl4"></div>
        </div>
        <span>More</span>
      </div>
    </div>
    <div class="card span3" style="display:flex;flex-direction:column;align-items:center;justify-content:center">
      <div class="score-ring-wrap">
        <div class="score-label">Deep Work Score</div>
        <div class="score-ring">
          <svg width="110" height="110" viewBox="0 0 110 110">
            <circle cx="55" cy="55" r="46" fill="none" stroke="rgba(138,98,192,0.12)" stroke-width="10"/>
            <circle id="scoreArc" cx="55" cy="55" r="46" fill="none" stroke="var(--violet)" stroke-width="10"
              stroke-linecap="round" stroke-dasharray="289" stroke-dashoffset="289"
              style="transition:stroke-dashoffset 1s ease"/>
          </svg>
          <div class="score-inner">
            <div class="score-num" id="scoreNum">--</div>
            <div class="score-max">/100</div>
          </div>
        </div>
        <div class="score-title" id="scoreTitle">--</div>
        <div style="font-size:11px;color:var(--muted);text-align:center;max-width:140px" id="scoreDesc"></div>
      </div>
    </div>
  </div>
</section>

<!-- ===== Daily Trend + Focus Blocks ===== -->
<section>
  <div class="grid">
    <div class="card span6">
      <div class="card-title">Daily Keystroke Trend</div>
      <div class="chart-wrap" style="height:180px"><canvas id="trendChart"></canvas></div>
    </div>
    <div class="card span6">
      <div class="card-title">Time-of-Day Rhythm (avg keystrokes/hr)</div>
      <div class="chart-wrap" style="height:180px"><canvas id="rhythmChart"></canvas></div>
    </div>
  </div>
</section>

<!-- ===== Focus Blocks ===== -->
<section>
  <div class="card span12">
    <div class="card-title">Focus Blocks -- Today <span class="tag tag-cyan" style="margin-left:6px">>= 30 min uninterrupted</span></div>
    <div class="focus-timeline" id="focusTimeline"></div>
    <div class="focus-axis">
      <span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>23:59</span>
    </div>
  </div>
</section>

<!-- ===== AI Model Breakdown + Projects + Kinds ===== -->
<section>
  <div class="grid">
    <div class="card span4">
      <div class="card-title">AI Model Usage</div>
      <div class="chart-wrap" style="height:200px"><canvas id="modelChart"></canvas></div>
    </div>
    <div class="card span4">
      <div class="card-title">Work Kinds</div>
      <div class="chart-wrap" style="height:200px"><canvas id="kindsChart"></canvas></div>
    </div>
    <div class="card span4">
      <div class="card-title">Top Projects</div>
      <div id="projectsBar" class="barlist" style="margin-top:4px"></div>
    </div>
  </div>
</section>

<!-- ===== Context Switching ===== -->
<section>
  <div class="card span12">
    <div class="card-title">Project Context Switches per Day <span class="tag tag-violet" style="margin-left:6px">From agent ledger</span></div>
    <div class="chart-wrap" style="height:160px"><canvas id="switchChart"></canvas></div>
  </div>
</section>

<!-- ===== Fun Facts ===== -->
<section>
  <h2>Fun Facts</h2>
  <div class="fun-grid" id="funFacts"></div>
</section>

<!-- Tooltip -->
<div id="tooltip"><div class="tt" id="tt-title"></div><div class="tm" id="tt-body"></div></div>

<!-- ===== Data ===== -->
<script>
const INPUT_DAYS    = $inputDaysJson;
const LEDGER_EVENTS = $ledgerJson;
const GENERATED_AT  = "$generatedAt";
</script>

<script>
/* ============================================================
   Utilities
   ============================================================ */
const fmt = n => n == null ? '--' : Number(n).toLocaleString();
const fmtDec = (n,d=1) => n == null ? '--' : Number(n).toLocaleString(undefined,{maximumFractionDigits:d});

function dateStr(d){ return d.toISOString().slice(0,10); }
function parseDateStr(s){ const [y,m,d]=s.split('-'); return new Date(y,m-1,d); }

/* tooltip */
const TT = document.getElementById('tooltip');
function showTip(e,title,body){
  document.getElementById('tt-title').textContent = title;
  document.getElementById('tt-body').textContent  = body;
  TT.style.display='block';
  moveTip(e);
}
function moveTip(e){
  const x=e.clientX+14, y=e.clientY-10;
  TT.style.left = Math.min(x, innerWidth-290)+'px';
  TT.style.top  = Math.max(y, 4)+'px';
}
function hideTip(){ TT.style.display='none'; }

/* Build a date lookup from INPUT_DAYS */
const dayMap = {};
for(const d of INPUT_DAYS) dayMap[d.date] = d;

/* ============================================================
   Range state
   ============================================================ */
let activeRange = 30; // days; 0 = custom
let customFrom, customTo;

function rangeWindow(){
  const today = new Date(); today.setHours(23,59,59,999);
  let from;
  if(activeRange === 0){
    from = customFrom || today;
    return { from, to: customTo || today };
  }
  from = new Date(today);
  from.setDate(from.getDate() - (activeRange - 1));
  from.setHours(0,0,0,0);
  return { from, to: today };
}

function daysInRange(r){
  const out = [];
  const cur = new Date(r.from); cur.setHours(0,0,0,0);
  const end = new Date(r.to);   end.setHours(23,59,59,999);
  while(cur <= end){
    out.push(dateStr(cur));
    cur.setDate(cur.getDate()+1);
  }
  return out;
}

/* ============================================================
   Aggregate helpers
   ============================================================ */
function sumField(days, field){
  let t=0; for(const d of days){ const row=dayMap[d]; if(!row) continue; for(const h of row.hourly) t+=h[field]||0; } return t;
}
function hourlyAvg(days, field){
  const totals = new Array(24).fill(0);
  const counts  = new Array(24).fill(0);
  for(const d of days){
    const row = dayMap[d]; if(!row) continue;
    for(const h of row.hourly){ totals[h.hour]+=(h[field]||0); counts[h.hour]++; }
  }
  return totals.map((v,i)=>counts[i]?v/counts[i]:0);
}
function hourlySum(day, field){
  const row = dayMap[day]; if(!row) return new Array(24).fill(0);
  const out = new Array(24).fill(0);
  for(const h of row.hourly) out[h.hour] = h[field]||0;
  return out;
}
function dailyTotals(days, field){
  return days.map(d=>{ const row=dayMap[d]; if(!row) return 0; return row.hourly.reduce((s,h)=>s+(h[field]||0),0); });
}

/* ============================================================
   Ledger helpers
   ============================================================ */
function ledgerInRange(range){
  const from = dateStr(range.from).slice(0,10);
  const to   = dateStr(range.to).slice(0,10);
  return LEDGER_EVENTS.filter(e=>e.date>=from && e.date<=to);
}
function countBy(arr, key){
  const m={};
  for(const x of arr){ const v=x[key]||'unknown'; m[v]=(m[v]||0)+1; }
  return m;
}

/* ============================================================
   Chart.js defaults
   ============================================================ */
Chart.defaults.color = 'rgba(237,230,255,0.55)';
Chart.defaults.borderColor = 'rgba(255,255,255,0.07)';
Chart.defaults.font.family = '"Inter","Segoe UI",sans-serif';
Chart.defaults.font.size = 11;

const DONUT_COLORS = [
  '#b8882e','#8a62c0','#4e9954','#c49840','#a86840','#a84e5a',
  '#9a7428','#6a4aa0','#3a7840','#8a5830'
];

function makeChart(id, cfg){ return new Chart(document.getElementById(id).getContext('2d'), cfg); }

/* ============================================================
   Chart instances
   ============================================================ */
let hourlyChartInst, trendChartInst, rhythmChartInst, modelChartInst, kindsChartInst, switchChartInst;

function initCharts(){
  const barOpts = { responsive:true, maintainAspectRatio:false,
    plugins:{ legend:{ display:false }, tooltip:{ enabled:true } },
    scales:{ x:{ grid:{ color:'rgba(255,255,255,0.04)' } }, y:{ grid:{ color:'rgba(255,255,255,0.04)' }, beginAtZero:true } }
  };

  hourlyChartInst = makeChart('hourlyChart', {
    type:'bar',
    data:{ labels:[], datasets:[{ data:[], backgroundColor:[], borderRadius:4, borderSkipped:false }] },
    options:{ ...barOpts, plugins:{ ...barOpts.plugins, tooltip:{
      callbacks:{ label: ctx => ` ${fmt(ctx.parsed.y)} keystrokes` }
    }}}
  });

  trendChartInst = makeChart('trendChart', {
    type:'bar',
    data:{ labels:[], datasets:[{ data:[], backgroundColor:'rgba(184,136,46,0.55)', borderRadius:3, borderSkipped:false }] },
    options:{ ...barOpts, plugins:{ ...barOpts.plugins,
      tooltip:{ callbacks:{ label: ctx=>`${fmt(ctx.parsed.y)} keystrokes` } }
    }}
  });

  rhythmChartInst = makeChart('rhythmChart', {
    type:'bar',
    data:{ labels: Array.from({length:24},(_,i)=>i+'h'), datasets:[{
      data:[], backgroundColor:'rgba(138,98,192,0.55)', borderRadius:3, borderSkipped:false
    }]},
    options:{ ...barOpts, plugins:{ ...barOpts.plugins,
      tooltip:{ callbacks:{ label:ctx=>`${fmtDec(ctx.parsed.y)} avg keystrokes` } }
    }}
  });

  modelChartInst = makeChart('modelChart', {
    type:'doughnut',
    data:{ labels:[], datasets:[{ data:[], backgroundColor:DONUT_COLORS, borderWidth:0, hoverOffset:8 }] },
    options:{ responsive:true, maintainAspectRatio:false, cutout:'62%',
      plugins:{ legend:{ position:'bottom', labels:{ boxWidth:10, padding:10, font:{size:10} } } }
    }
  });

  kindsChartInst = makeChart('kindsChart', {
    type:'doughnut',
    data:{ labels:[], datasets:[{ data:[], backgroundColor:DONUT_COLORS, borderWidth:0, hoverOffset:8 }] },
    options:{ responsive:true, maintainAspectRatio:false, cutout:'62%',
      plugins:{ legend:{ position:'bottom', labels:{ boxWidth:10, padding:10, font:{size:10} } } }
    }
  });

  switchChartInst = makeChart('switchChart', {
    type:'bar',
    data:{ labels:[], datasets:[{ data:[], backgroundColor:'rgba(184,136,46,0.5)', borderRadius:3, borderSkipped:false }] },
    options:{ ...barOpts, plugins:{ ...barOpts.plugins,
      tooltip:{ callbacks:{ label:ctx=>`${ctx.parsed.y} project switch${ctx.parsed.y===1?'':'es'}` } }
    }}
  });
}

/* ============================================================
   Render all
   ============================================================ */
function render(){
  const range = rangeWindow();
  const days  = daysInRange(range);
  const today = dateStr(new Date());

  /* ---- header ---- */
  document.getElementById('genTime').textContent = GENERATED_AT.replace('T',' ');
  document.getElementById('dataRange').textContent =
    days.length===1 ? days[0] : days[0] + ' -> ' + days[days.length-1];

  /* ---- totals ---- */
  const totKeys   = sumField(days,'keystrokes');
  const totMouse  = sumField(days,'mouse_distance_m');
  const totSaves  = sumField(days,'saves');
  const totCopies = sumField(days,'copies');
  const totChars  = sumField(days,'chars_typed');
  const totPastes = sumField(days,'pastes');
  const totPastedChars = sumField(days,'chars_pasted');

  const activeDays = days.filter(d=>dayMap[d]).length || 1;

  document.getElementById('v-keys').innerHTML   = fmt(totKeys);
  document.getElementById('s-keys').textContent = activeDays>1 ? `~${fmt(Math.round(totKeys/activeDays))} / day` : '';
  document.getElementById('v-mouse').innerHTML  = fmtDec(totMouse)+'<span class="led-unit">m</span>';
  document.getElementById('s-mouse').textContent = totMouse>1000 ? fmtDec(totMouse/1000,2)+' km total' : '';
  document.getElementById('v-saves').innerHTML  = fmt(totSaves);
  document.getElementById('s-saves').textContent = activeDays>1 ? `~${fmtDec(totSaves/activeDays,1)} / day` : '';
  document.getElementById('v-copies').innerHTML = fmt(totCopies);
  document.getElementById('s-copies').textContent = totPastes ? totPastes+' pastes' : '';
  document.getElementById('v-chars').innerHTML  = fmt(totChars);
  document.getElementById('s-chars').textContent = totChars ? '~'+fmt(Math.round(totChars/5))+' words' : '';
  document.getElementById('v-pastes').innerHTML = fmt(totPastes);
  document.getElementById('s-pastes').textContent = totPastedChars ? fmt(totPastedChars)+' chars pasted' : '';

  /* ---- hourly chart ---- */
  let hourlyLabels, hourlyData, hourlyColors;
  if(days.length===1){
    hourlyLabels = Array.from({length:24},(_,i)=>i+'h');
    hourlyData   = hourlySum(days[0],'keystrokes');
    document.getElementById('hourlyTitle').textContent = 'Hourly Activity -- '+days[0];
  } else {
    hourlyLabels = Array.from({length:24},(_,i)=>i+'h');
    hourlyData   = hourlyAvg(days,'keystrokes');
    document.getElementById('hourlyTitle').textContent = 'Average Hourly Activity (keystrokes/hr) -- '+days.length+' days';
  }
  const maxH = Math.max(...hourlyData,1);
  hourlyColors = hourlyData.map(v=>{
    const ratio = v/maxH;
    if(ratio>.75) return 'rgba(184,136,46,0.9)';
    if(ratio>.5)  return 'rgba(184,136,46,0.65)';
    if(ratio>.25) return 'rgba(184,136,46,0.42)';
    return 'rgba(184,136,46,0.2)';
  });
  hourlyChartInst.data.labels   = hourlyLabels;
  hourlyChartInst.data.datasets[0].data = hourlyData;
  hourlyChartInst.data.datasets[0].backgroundColor = hourlyColors;
  hourlyChartInst.update();

  /* ---- trend chart ---- */
  trendChartInst.data.labels   = days.length>60 ? days.filter((_,i)=>i%2===0) : days;
  trendChartInst.data.datasets[0].data = dailyTotals(days,'keystrokes').filter((_,i)=>days.length<=60||i%2===0);
  trendChartInst.update();

  /* ---- rhythm (avg by hour-of-day across range) ---- */
  rhythmChartInst.data.datasets[0].data = hourlyAvg(days,'keystrokes');
  rhythmChartInst.update();

  /* ---- heatmap ---- */
  buildHeatmap(days);

  /* ---- deep work score ---- */
  buildScore(days, today);

  /* ---- focus blocks ---- */
  buildFocus(today);

  /* ---- ledger charts ---- */
  const events = ledgerInRange(range);
  buildDonut(modelChartInst, countBy(events,'model'));
  buildDonut(kindsChartInst, countBy(events,'kind'));
  buildProjectsBar(events, range);
  buildSwitchChart(days, events);

  /* ---- fun facts ---- */
  buildFun(totKeys, totMouse, totSaves, totCopies, totChars, totPastes, totPastedChars, activeDays);
}

/* ============================================================
   Heatmap
   ============================================================ */
function buildHeatmap(highlightDays){
  const grid = document.getElementById('heatGrid');
  const mths = document.getElementById('heatMonths');
  grid.innerHTML = ''; mths.innerHTML='';

  // Always show 90 days ending today
  const today = new Date(); today.setHours(0,0,0,0);
  const start = new Date(today); start.setDate(start.getDate()-89);
  // Pad to start of week (Sunday)
  while(start.getDay()!==0) start.setDate(start.getDate()-1);

  const allKeys = {};
  for(const d of INPUT_DAYS){
    const total = d.hourly.reduce((s,h)=>s+(h.keystrokes||0),0);
    allKeys[d.date] = total;
  }
  const maxK = Math.max(...Object.values(allKeys),1);

  let col = null, prevMonth = -1;
  const monthLabels=[];
  let colIndex=0;

  const cur = new Date(start);
  while(cur <= today){
    if(col===null || cur.getDay()===0){
      col = document.createElement('div');
      col.className='heatCol';
      grid.appendChild(col);
      if(cur.getMonth()!==prevMonth){ monthLabels.push({col:colIndex,label:cur.toLocaleString('default',{month:'short'})}); prevMonth=cur.getMonth(); }
      colIndex++;
    }
    if(cur < today || dateStr(cur)===dateStr(today)){
      const k = allKeys[dateStr(cur)]||0;
      const ratio = k/maxK;
      const cell = document.createElement('div');
      cell.className='cell'+(ratio>.75?' lvl4':ratio>.4?' lvl3':ratio>.15?' lvl2':ratio>.02?' lvl1':'');
      const ds=dateStr(cur);
      cell.addEventListener('mouseenter',e=>showTip(e,ds,k?`${fmt(k)} keystrokes`:'No data'));
      cell.addEventListener('mousemove',moveTip);
      cell.addEventListener('mouseleave',hideTip);
      col.appendChild(cell);
    } else {
      const ph=document.createElement('div'); ph.style.width='13px'; ph.style.height='13px'; col.appendChild(ph);
    }
    cur.setDate(cur.getDate()+1);
  }

  // Month labels
  for(const ml of monthLabels){
    const span=document.createElement('div');
    span.className='heatMonthLabel';
    span.style.gridColumn=(ml.col+1)+'';
    span.textContent=ml.label;
    mths.appendChild(span);
  }
}

/* ============================================================
   Deep Work Score (today only)
   ============================================================ */
function buildScore(days, today){
  const row = dayMap[today];
  if(!row){ document.getElementById('scoreNum').textContent='--'; document.getElementById('scoreTitle').textContent='No data'; return; }

  // Score heuristics (0-100):
  // 1. Long focus blocks (hours with >50 keys back-to-back) -> up to 40pts
  // 2. Total keystrokes today -> up to 30pts
  // 3. Low context switching (ledger) -> up to 15pts
  // 4. Saves ratio (saves/keystrokes) -> up to 15pts

  const hourlyK = row.hourly.map(h=>h.keystrokes||0);
  const totalK  = hourlyK.reduce((a,b)=>a+b,0);

  // Focus: count consecutive busy hours (>30 keys)
  let maxBlock=0, cur=0;
  for(const k of hourlyK){ if(k>30){ cur++; if(cur>maxBlock) maxBlock=cur; } else cur=0; }
  const focusPts = Math.min(40, maxBlock*8);

  // Volume
  const volPts = Math.min(30, Math.floor(totalK/100));

  // Saves ratio (good: >1 save per 200 keystrokes)
  const saves = row.hourly.reduce((s,h)=>s+(h.saves||0),0);
  const saveRatio = totalK>0 ? saves/totalK : 0;
  const savePts = Math.min(15, Math.floor(saveRatio*3000));

  // Context switching from ledger today
  const todayEvents = LEDGER_EVENTS.filter(e=>e.date===today);
  const projects    = new Set(todayEvents.map(e=>e.project));
  const switchPts   = Math.max(0,15 - (projects.size-1)*3);

  const score = Math.min(100, Math.round(focusPts+volPts+savePts+switchPts));
  const CIRCUMFERENCE = 2*Math.PI*46;

  document.getElementById('scoreNum').textContent = score;
  document.getElementById('scoreArc').style.strokeDashoffset = CIRCUMFERENCE*(1-score/100);
  const titles = score>=80?'Elite':score>=60?'Strong':score>=40?'Solid':score>=20?'Warming up':'Quiet day';
  const descs  = {
    'Elite':   'Peak focus. You were in the zone.',
    'Strong':  'Great session. Sustained effort.',
    'Solid':   'Good work. Some strong blocks.',
    'Warming up': 'Light day. Plenty left in the tank.',
    'Quiet day':  'Rest is productive too.'
  };
  document.getElementById('scoreTitle').textContent = titles;
  document.getElementById('scoreDesc').textContent  = descs[titles];
}

/* ============================================================
   Focus Blocks (today)
   ============================================================ */
function buildFocus(today){
  const tl = document.getElementById('focusTimeline');
  tl.innerHTML='';
  const row = dayMap[today];
  if(!row){ tl.innerHTML='<div class="focus-empty">No input data for today yet.</div>'; return; }

  const hourlyK = row.hourly.map(h=>h.keystrokes||0);
  const TOTAL_MINS = 24*60;
  const BLOCK_COLORS = ['#b8882e','#8a62c0','#4e9954','#c49840','#a86840'];
  let colorIdx=0;

  // Find blocks of consecutive active hours (threshold: >30 keys)
  let blocks=[], start=-1;
  for(let h=0;h<24;h++){
    if(hourlyK[h]>30){ if(start===-1)start=h; }
    else { if(start!==-1){ blocks.push({start,end:h}); start=-1; } }
  }
  if(start!==-1) blocks.push({start,end:24});

  // Filter to >=1 hour (>=30min is >=1 block-hour here)
  blocks = blocks.filter(b=>b.end-b.start>=1);

  if(!blocks.length){ tl.innerHTML='<div class="focus-empty">No focus blocks detected yet today.</div>'; return; }

  for(const b of blocks){
    const leftPct  = (b.start/24)*100;
    const widthPct = ((b.end-b.start)/24)*100;
    const color    = BLOCK_COLORS[colorIdx++%BLOCK_COLORS.length];
    const dur      = b.end-b.start;
    const div=document.createElement('div');
    div.className='focus-block';
    div.style.cssText=`left:${leftPct}%;width:${widthPct}%;background:${color};`;
    div.textContent = dur+'h';
    div.title = `${b.start}:00 - ${b.end}:00 (${dur}h focus block)`;
    tl.appendChild(div);
  }
}

/* ============================================================
   Donut helper
   ============================================================ */
function buildDonut(chart, counts){
  const entries = Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,10);
  chart.data.labels   = entries.map(e=>e[0]);
  chart.data.datasets[0].data = entries.map(e=>e[1]);
  chart.update();
}

/* ============================================================
   Projects bar list
   ============================================================ */
function buildProjectsBar(events, range){
  const el = document.getElementById('projectsBar');
  const counts = countBy(events,'project');
  const entries = Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,8);
  if(!entries.length){ el.innerHTML='<div class="nodata">No ledger data in range</div>'; return; }
  const max = entries[0][1];
  el.innerHTML = entries.map(([p,n])=>`
    <div class="bar-row">
      <div class="bar-label" title="${p}">${p}</div>
      <div class="bar-track"><div class="bar-fill" style="width:${(n/max*100).toFixed(1)}%;background:var(--gold)"></div></div>
      <div class="bar-n">${n}</div>
    </div>`).join('');
}

/* ============================================================
   Context switching chart
   ============================================================ */
function buildSwitchChart(days, events){
  const byDate={};
  for(const e of events){ if(!byDate[e.date]) byDate[e.date]=new Set(); byDate[e.date].add(e.project); }
  const labels = days.length>60 ? days.filter((_,i)=>i%2===0) : days;
  const data   = labels.map(d=>{ const s=byDate[d]; return s ? Math.max(0,s.size-1) : 0; });
  switchChartInst.data.labels   = labels;
  switchChartInst.data.datasets[0].data = data;
  switchChartInst.update();
}

/* ============================================================
   Fun Facts
   ============================================================ */
function buildFun(keys, mouseM, saves, copies, chars, pastes, pastedChars, activeDays){
  const facts=[];
  // Pages typed (avg page ~250 words, avg word ~5 chars)
  if(chars>0){
    const words = Math.round(chars/5);
    const pages = (words/250).toFixed(1);
    facts.push({e:'[pg]',s:pages+' pages',d:'of text typed (250 words/page)'});
  }
  // Mouse distance
  if(mouseM>0){
    if(mouseM>=1000) facts.push({e:'[map]',s:fmtDec(mouseM/1000,2)+' km',d:'mouse travel distance'});
    else              facts.push({e:'[mouse]',s:fmtDec(mouseM)+' m',d:'mouse travel distance'});
    // Marathons? 42.195km
    const marathons=(mouseM/1000/42.195);
    if(marathons>0.01) facts.push({e:'[run]',s:fmtDec(marathons,3)+'x',d:'a marathon in mouse movement'});
  }
  // Saves
  if(saves>0) facts.push({e:'[save]',s:fmt(saves),d:'times you saved your work'});
  // Copy-paste ratio
  if(copies>0&&pastes>0){
    const ratio=(copies/pastes).toFixed(2);
    facts.push({e:'[clip]',s:ratio+'x',d:'copy-to-paste ratio'});
  }
  // Words per minute estimate (assuming 8h active time)
  if(chars>0&&activeDays>0){
    const activeMinutes = activeDays*8*60;
    const wpm = ((chars/5)/activeMinutes).toFixed(1);
    facts.push({e:'[kbd]',s:wpm+' WPM',d:'estimated typing speed (8h active/day)'});
  }
  // Keystrokes
  if(keys>1000){
    const novels = (keys/500000).toFixed(4);
    facts.push({e:'[book]',s:novels+'x',d:'a novel worth of keystrokes (500k chars)'});
  }
  // Pasted chars
  if(pastedChars>0){
    facts.push({e:'[in]',s:fmt(pastedChars),d:'characters pasted from clipboard'});
  }
  // Saves per hour
  if(saves>0&&keys>0){
    const savePer1k=(saves/keys*1000).toFixed(2);
    facts.push({e:'[loop]',s:savePer1k,d:'saves per 1,000 keystrokes'});
  }

  const el=document.getElementById('funFacts');
  if(!facts.length){ el.innerHTML='<div class="nodata">Run the input tracker for a while to unlock fun facts.</div>'; return; }
  el.innerHTML=facts.map(f=>`
    <div class="fun-card">
      <div class="fun-emoji">${f.e}</div>
      <div class="fun-stat">${f.s}</div>
      <div class="fun-desc">${f.d}</div>
    </div>`).join('');
}

/* ============================================================
   Range buttons
   ============================================================ */
document.querySelectorAll('.range-btn').forEach(btn=>{
  btn.addEventListener('click',()=>{
    document.querySelectorAll('.range-btn').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active');
    const r=btn.dataset.range;
    document.getElementById('customRow').classList.toggle('visible', r==='custom');
    if(r!=='custom'){ activeRange=parseInt(r); render(); }
  });
});

function applyCustom(){
  const f=document.getElementById('customFrom').value;
  const t=document.getElementById('customTo').value;
  if(!f||!t) return;
  activeRange=0;
  customFrom=parseDateStr(f);
  customTo=parseDateStr(t); customTo.setHours(23,59,59,999);
  render();
}

/* ============================================================
   Boot
   ============================================================ */
initCharts();
render();
</script>
</body>
</html>
"@

# Write output
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutPath, $html, $utf8NoBom)

Write-Host "Dashboard rendered -> $OutPath" -ForegroundColor Cyan
Write-Host "  Input days loaded : $($inputDays.Count)"  -ForegroundColor Green
Write-Host "  Ledger events     : $($ledgerEvents.Count)" -ForegroundColor Green
