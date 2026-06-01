<#
.SYNOPSIS
    VaultWares Daily Dashboard Renderer
.DESCRIPTION
    Reads input-logs/*.json + history/**/*.json + events/**/*.json then bakes
    everything into a self-contained DAILY_DASHBOARD.html.
.PARAMETER LedgerRoot   Path to agent-ledger root. Defaults to parent of script dir.
.PARAMETER OutPath      Output HTML path. Defaults to <LedgerRoot>/DAILY_DASHBOARD.html.
.PARAMETER DaysBack     Days of history to include. Default 90.
#>
[CmdletBinding()]
param(
    [string]$LedgerRoot,
    [string]$OutPath,
    [int]   $DaysBack = 90
)
$ErrorActionPreference = "Stop"

if (-not $LedgerRoot) { $LedgerRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
if (-not $OutPath)    { $OutPath    = Join-Path $LedgerRoot "DAILY_DASHBOARD.html" }

$LogDir    = Join-Path $LedgerRoot "input-logs"
$HistDir   = Join-Path $LedgerRoot "history"
$EventsDir = Join-Path $LedgerRoot "events"

# ---------------------------------------------------------------------------
# 1. Load input-log files
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
# 2. Load ledger events from both history/ and events/
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

# ---------------------------------------------------------------------------
# 3. Serialise — use safe placeholder tokens, never inject into heredoc
# ---------------------------------------------------------------------------
$inputDaysJson = if ($inputDays.Count -eq 0)   { "[]" } else { $inputDays   | ConvertTo-Json -Depth 6 -Compress }
$ledgerJson    = if ($ledgerEvents.Count -eq 0) { "[]" } else { $ledgerEvents | ConvertTo-Json -Depth 3 -Compress }
$generatedAt   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")

# ---------------------------------------------------------------------------
# 4. HTML template  (single-quoted heredoc -- no $ expansion, "@ safe)
#    Placeholders:  __INPUT_DAYS__  __LEDGER_EVENTS__  __GENERATED_AT__
# ---------------------------------------------------------------------------
$html = @'
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
:root {
  --font-sans:"Inter","Segoe UI",ui-sans-serif,system-ui,sans-serif;
  --font-mono:"JetBrains Mono","Cascadia Code",Consolas,ui-monospace,monospace;
  --bg:#0e0c18; --surface:#161320; --surface2:#1c1826; --surface3:#231e30;
  --border:rgba(255,255,255,0.07);
  --fg:#d8d0f0; --muted:rgba(216,208,240,0.48); --dim:rgba(216,208,240,0.24);
  --gold:#b8882e; --gold-glow:rgba(184,136,46,0.28); --gold-dim:rgba(184,136,46,0.12);
  --amber:#c49840;
  --violet:#8a62c0; --violet-glow:rgba(138,98,192,0.28);
  --green:#4e9954;
  --red:#a84e5a;
  --orange:#a86840;
}
*,*::before,*::after{box-sizing:border-box}
body{margin:0;font-family:var(--font-sans);background:var(--bg);color:var(--fg);line-height:1.5;-webkit-font-smoothing:antialiased}
main{max-width:1200px;margin:0 auto;padding:24px 16px 80px}
a{color:var(--gold)} canvas{display:block}
header{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;padding-bottom:18px;border-bottom:1px solid var(--border);margin-bottom:4px}
.brand{display:flex;align-items:center;gap:10px}
.brand-badge{background:var(--gold-dim);border:1px solid var(--gold-glow);border-radius:6px;padding:3px 10px;font-size:10px;font-weight:800;color:var(--gold);letter-spacing:.1em;text-transform:uppercase}
h1{margin:0;font-size:22px;font-weight:800;letter-spacing:-.01em}
h1 span{color:var(--gold)}
.meta-row{color:var(--muted);font-size:12px;margin-top:2px}
.range-row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.range-row label{font-size:12px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.range-btn{appearance:none;border:1px solid var(--border);border-radius:6px;padding:6px 14px;background:var(--surface2);color:var(--muted);font-size:12px;font-weight:600;cursor:pointer;transition:all .15s;font-family:var(--font-sans)}
.range-btn:hover{border-color:var(--gold);color:var(--gold)}
.range-btn.active{background:var(--gold-dim);border-color:var(--gold);color:var(--gold)}
.custom-row{display:none;gap:8px;align-items:center;margin-top:6px}
.custom-row.visible{display:flex}
.custom-row input{appearance:none;border:1px solid var(--border);border-radius:6px;padding:5px 10px;background:var(--surface2);color:var(--fg);font-size:12px;font-family:var(--font-mono)}
.custom-row button{appearance:none;border:1px solid var(--gold-glow);border-radius:6px;padding:5px 12px;background:var(--gold-dim);color:var(--gold);font-size:12px;font-weight:700;cursor:pointer;font-family:var(--font-sans)}
section{margin-top:24px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(12,1fr)}
.span2{grid-column:span 2} .span3{grid-column:span 3} .span4{grid-column:span 4}
.span6{grid-column:span 6} .span8{grid-column:span 8} .span12{grid-column:span 12}
@media(max-width:900px){.span2,.span3,.span4,.span6,.span8{grid-column:span 6}}
@media(max-width:560px){.span2,.span3,.span4,.span6,.span8{grid-column:span 12}}
.card{border:1px solid var(--border);background:var(--surface);border-radius:12px;padding:16px}
.card-title{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 10px}
section > h2{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 10px}
.led-card{border-radius:12px;padding:16px 16px 14px;background:var(--surface2);border:1px solid var(--border);display:flex;flex-direction:column;gap:4px}
.led-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;animation:ledpulse 3s ease-in-out infinite}
@keyframes ledpulse{0%,100%{opacity:1}60%{opacity:.4}}
.led-header{display:flex;align-items:center;gap:7px}
.led-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}
.led-value{font-size:26px;font-weight:800;font-family:var(--font-mono);line-height:1.1;font-variant-numeric:tabular-nums}
.led-unit{font-size:11px;font-weight:600;opacity:.6;margin-left:2px}
.led-sub{font-size:11px;color:var(--muted);margin-top:2px}
.led-gold .led-dot{background:var(--gold);box-shadow:0 0 5px var(--gold)} .led-gold .led-value{color:var(--gold)}
.led-violet .led-dot{background:var(--violet);box-shadow:0 0 5px var(--violet)} .led-violet .led-value{color:var(--violet)}
.led-green .led-dot{background:var(--green);box-shadow:0 0 5px var(--green)} .led-green .led-value{color:var(--green)}
.led-amber .led-dot{background:var(--amber);box-shadow:0 0 5px var(--amber)} .led-amber .led-value{color:var(--amber)}
.led-orange .led-dot{background:var(--orange);box-shadow:0 0 5px var(--orange)} .led-orange .led-value{color:var(--orange)}
.led-red .led-dot{background:var(--red);box-shadow:0 0 5px var(--red)} .led-red .led-value{color:var(--red)}
.chart-wrap{position:relative;width:100%;height:240px}
.heatWrap{overflow-x:auto;scrollbar-width:thin}
.heat{display:grid;grid-auto-flow:column;grid-auto-columns:13px;gap:3px;align-items:start;padding:6px 4px 4px}
.heatCol{display:grid;grid-template-rows:repeat(7,13px);gap:3px}
.cell{width:13px;height:13px;border-radius:3px;background:rgba(255,255,255,.05);cursor:default;transition:transform .1s}
.cell:hover{transform:scale(1.4)}
.lvl1{background:rgba(138,98,192,.25)} .lvl2{background:rgba(138,98,192,.48)}
.lvl3{background:rgba(138,98,192,.72)} .lvl4{background:var(--violet)}
.heatLegend{display:flex;gap:8px;align-items:center;justify-content:flex-end;font-size:11px;color:var(--muted);padding:0 4px 4px}
.legendSwatch{display:flex;gap:3px;align-items:center}
.heatMonths{display:flex;gap:3px;padding:0 4px;font-size:9px;color:var(--dim);overflow-x:auto;scrollbar-width:none}
.heatMonthLabel{min-width:13px;text-align:center}
.focus-timeline{position:relative;height:44px;background:var(--surface2);border-radius:8px;overflow:hidden;margin-top:8px}
.focus-block{position:absolute;top:8px;height:28px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;font-family:var(--font-mono);color:rgba(0,0,0,.7);cursor:default}
.focus-axis{display:flex;justify-content:space-between;padding:0 2px;margin-top:4px}
.focus-axis span{font-size:9px;color:var(--dim);font-family:var(--font-mono)}
.focus-empty{text-align:center;color:var(--muted);font-size:12px;padding:14px 0;font-style:italic}
.score-ring-wrap{display:flex;flex-direction:column;align-items:center;gap:6px;padding:8px 0}
.score-label{font-size:11px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.score-ring{position:relative;width:110px;height:110px}
.score-ring svg{transform:rotate(-90deg)}
.score-inner{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.score-num{font-size:28px;font-weight:800;font-family:var(--font-mono);color:var(--violet)}
.score-max{font-size:10px;color:var(--muted)}
.score-title{font-size:12px;font-weight:700;color:var(--violet)}
.fun-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px;margin-top:8px}
.fun-card{background:var(--surface2);border:1px solid var(--border);border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:4px}
.fun-icon{font-size:13px;font-weight:700;color:var(--muted);font-family:var(--font-mono)}
.fun-stat{font-size:18px;font-weight:800;font-family:var(--font-mono);color:var(--fg)}
.fun-desc{font-size:11px;color:var(--muted)}
.barlist{display:flex;flex-direction:column;gap:7px}
.bar-row{display:flex;align-items:center;gap:10px}
.bar-label{width:160px;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex-shrink:0;color:var(--fg)}
.bar-track{flex:1;height:8px;border-radius:999px;background:rgba(255,255,255,.05);overflow:hidden;min-width:40px}
.bar-fill{height:100%;border-radius:999px}
.bar-n{width:54px;text-align:right;font-size:12px;color:var(--muted);font-family:var(--font-mono);flex-shrink:0}
#tooltip{position:fixed;z-index:99;pointer-events:none;background:var(--surface3);border:1px solid var(--border);border-radius:10px;padding:10px 13px;max-width:280px;box-shadow:0 16px 48px rgba(0,0,0,.55);display:none}
#tooltip .tt{font-size:12px;font-weight:700;color:var(--fg)}
#tooltip .tm{font-size:12px;color:var(--muted);margin-top:5px;white-space:pre-line}
.nodata{color:var(--muted);font-size:12px;font-style:italic;padding:12px 0;text-align:center}
.tag{display:inline-block;padding:1px 7px;border-radius:999px;font-size:10px;font-weight:700;border:1px solid}
.tag-violet{background:var(--surface3);border-color:rgba(138,98,192,.3);color:var(--violet)}
.tag-gold{background:var(--gold-dim);border-color:var(--gold-glow);color:var(--gold)}
</style>
</head>
<body>
<main>

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
      <span style="color:var(--muted);font-size:12px">to</span>
      <input type="date" id="customTo">
      <button onclick="applyCustom()">Apply</button>
    </div>
  </div>
</header>

<section>
  <div class="grid" id="ledStrip">
    <div class="led-card led-gold span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Keystrokes</div></div>
      <div class="led-value" id="v-keys">--</div>
      <div class="led-sub" id="s-keys"></div>
    </div>
    <div class="led-card led-violet span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Mouse Travel</div></div>
      <div class="led-value" id="v-mouse">--<span class="led-unit">m</span></div>
      <div class="led-sub" id="s-mouse"></div>
    </div>
    <div class="led-card led-green span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Saves</div></div>
      <div class="led-value" id="v-saves">--</div>
      <div class="led-sub" id="s-saves"></div>
    </div>
    <div class="led-card led-amber span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Copies</div></div>
      <div class="led-value" id="v-copies">--</div>
      <div class="led-sub" id="s-copies"></div>
    </div>
    <div class="led-card led-orange span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Chars Typed</div></div>
      <div class="led-value" id="v-chars">--</div>
      <div class="led-sub" id="s-chars"></div>
    </div>
    <div class="led-card led-red span2">
      <div class="led-header"><div class="led-dot"></div><div class="led-label">Pastes</div></div>
      <div class="led-value" id="v-pastes">--</div>
      <div class="led-sub" id="s-pastes"></div>
    </div>
  </div>
</section>

<section>
  <h2 id="hourlyTitle">Hourly Activity</h2>
  <div class="card span12"><div class="chart-wrap"><canvas id="hourlyChart"></canvas></div></div>
</section>

<section>
  <div class="grid">
    <div class="card span9">
      <div class="card-title">Activity Heatmap (90 days)</div>
      <div class="heatMonths" id="heatMonths"></div>
      <div class="heatWrap"><div class="heat" id="heatGrid"></div></div>
      <div class="heatLegend">
        <span>Less</span>
        <div class="legendSwatch">
          <div class="cell"></div><div class="cell lvl1"></div>
          <div class="cell lvl2"></div><div class="cell lvl3"></div><div class="cell lvl4"></div>
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

<section>
  <div class="card span12">
    <div class="card-title">Focus Blocks -- Today <span class="tag tag-violet" style="margin-left:6px">&gt;= 1 hr uninterrupted</span></div>
    <div class="focus-timeline" id="focusTimeline"></div>
    <div class="focus-axis"><span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>23:59</span></div>
  </div>
</section>

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

<section>
  <div class="card span12">
    <div class="card-title">Project Context Switches per Day <span class="tag tag-gold" style="margin-left:6px">Agent ledger</span></div>
    <div class="chart-wrap" style="height:160px"><canvas id="switchChart"></canvas></div>
  </div>
</section>

<section>
  <h2>Fun Stats</h2>
  <div class="fun-grid" id="funFacts"></div>
</section>

<div id="tooltip"><div class="tt" id="tt-title"></div><div class="tm" id="tt-body"></div></div>

<script>
const INPUT_DAYS    = __INPUT_DAYS__;
const LEDGER_EVENTS = __LEDGER_EVENTS__;
const GENERATED_AT  = "__GENERATED_AT__";
</script>

<script>
/* utils */
const fmt    = n => (n == null || isNaN(n)) ? '--' : Number(n).toLocaleString();
const fmtDec = (n,d=1) => (n == null || isNaN(n)) ? '--' : Number(n).toLocaleString(undefined,{maximumFractionDigits:d});
function dateStr(d){ return d.toISOString().slice(0,10); }
function parseDateStr(s){ const [y,m,d]=s.split('-'); return new Date(y,m-1,d); }
const TT = document.getElementById('tooltip');
function showTip(e,title,body){ document.getElementById('tt-title').textContent=title; document.getElementById('tt-body').textContent=body; TT.style.display='block'; moveTip(e); }
function moveTip(e){ TT.style.left=Math.min(e.clientX+14,innerWidth-290)+'px'; TT.style.top=Math.max(e.clientY-10,4)+'px'; }
function hideTip(){ TT.style.display='none'; }
const dayMap = {};
for(const d of INPUT_DAYS) dayMap[d.date] = d;

/* range */
let activeRange = 30;
let customFrom, customTo;
function rangeWindow(){
  const today = new Date(); today.setHours(23,59,59,999);
  if(activeRange===0){ return { from: customFrom||today, to: customTo||today }; }
  const from = new Date(today); from.setDate(from.getDate()-(activeRange-1)); from.setHours(0,0,0,0);
  return { from, to: today };
}
function daysInRange(r){
  const out=[]; const cur=new Date(r.from); cur.setHours(0,0,0,0);
  while(cur<=r.to){ out.push(dateStr(cur)); cur.setDate(cur.getDate()+1); }
  return out;
}

/* aggregates */
function sumField(days,field){ let t=0; for(const d of days){ const row=dayMap[d]; if(!row) continue; for(const h of row.hourly) t+=(h[field]||0); } return t; }
function hourlyAvg(days,field){
  const tots=new Array(24).fill(0), cnts=new Array(24).fill(0);
  for(const d of days){ const row=dayMap[d]; if(!row) continue; for(const h of row.hourly){ tots[h.hour]+=(h[field]||0); cnts[h.hour]++; } }
  return tots.map((v,i)=>cnts[i]?v/cnts[i]:0);
}
function hourlySum(day,field){ const row=dayMap[day]; if(!row) return new Array(24).fill(0); const out=new Array(24).fill(0); for(const h of row.hourly) out[h.hour]=(h[field]||0); return out; }
function dailyTotals(days,field){ return days.map(d=>{ const row=dayMap[d]; return row?row.hourly.reduce((s,h)=>s+(h[field]||0),0):0; }); }
function ledgerInRange(range){ const f=dateStr(range.from).slice(0,10),t=dateStr(range.to).slice(0,10); return LEDGER_EVENTS.filter(e=>e.date>=f&&e.date<=t); }
function countBy(arr,key){ const m={}; for(const x of arr){ const v=x[key]||'unknown'; m[v]=(m[v]||0)+1; } return m; }
function countByKinds(arr){ const m={}; for(const x of arr){ const kinds=(x.kind||'general').split(','); for(const k of kinds){ const v=k.trim()||'general'; m[v]=(m[v]||0)+1; } } return m; }

/* Chart.js defaults */
Chart.defaults.color='rgba(216,208,240,0.48)';
Chart.defaults.borderColor='rgba(255,255,255,0.07)';
Chart.defaults.font.family='"Inter","Segoe UI",sans-serif';
Chart.defaults.font.size=11;
const DONUT_COLORS=['#b8882e','#8a62c0','#4e9954','#c49840','#a86840','#a84e5a','#9a7428','#6a4aa0','#3a7840','#8a5830'];
function makeChart(id,cfg){ return new Chart(document.getElementById(id).getContext('2d'),cfg); }

const barOpts={responsive:true,maintainAspectRatio:false,
  plugins:{legend:{display:false}},
  scales:{x:{grid:{color:'rgba(255,255,255,0.04)'}},y:{grid:{color:'rgba(255,255,255,0.04)'},beginAtZero:true}}};

let hourlyC,trendC,rhythmC,modelC,kindsC,switchC;
function initCharts(){
  hourlyC = makeChart('hourlyChart',{type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:[],borderRadius:4,borderSkipped:false}]},options:{...barOpts,plugins:{...barOpts.plugins,tooltip:{callbacks:{label:c=>' '+fmt(c.parsed.y)+' keystrokes'}}}}});
  trendC  = makeChart('trendChart', {type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:'rgba(184,136,46,0.55)',borderRadius:3,borderSkipped:false}]},options:{...barOpts,plugins:{...barOpts.plugins,tooltip:{callbacks:{label:c=>fmt(c.parsed.y)+' keystrokes'}}}}});
  rhythmC = makeChart('rhythmChart',{type:'bar',data:{labels:Array.from({length:24},(_,i)=>i+'h'),datasets:[{data:[],backgroundColor:'rgba(138,98,192,0.55)',borderRadius:3,borderSkipped:false}]},options:{...barOpts,plugins:{...barOpts.plugins,tooltip:{callbacks:{label:c=>fmtDec(c.parsed.y)+' avg'}}}}});
  modelC  = makeChart('modelChart', {type:'doughnut',data:{labels:[],datasets:[{data:[],backgroundColor:DONUT_COLORS,borderWidth:0,hoverOffset:8}]},options:{responsive:true,maintainAspectRatio:false,cutout:'62%',plugins:{legend:{position:'bottom',labels:{boxWidth:10,padding:10,font:{size:10}}}}}});
  kindsC  = makeChart('kindsChart', {type:'doughnut',data:{labels:[],datasets:[{data:[],backgroundColor:DONUT_COLORS,borderWidth:0,hoverOffset:8}]},options:{responsive:true,maintainAspectRatio:false,cutout:'62%',plugins:{legend:{position:'bottom',labels:{boxWidth:10,padding:10,font:{size:10}}}}}});
  switchC = makeChart('switchChart',{type:'bar',data:{labels:[],datasets:[{data:[],backgroundColor:'rgba(184,136,46,0.5)',borderRadius:3,borderSkipped:false}]},options:{...barOpts,plugins:{...barOpts.plugins,tooltip:{callbacks:{label:c=>c.parsed.y+' switches'}}}}});
}

function render(){
  const range=rangeWindow(), days=daysInRange(range), today=dateStr(new Date());
  document.getElementById('genTime').textContent = GENERATED_AT.replace('T',' ');
  document.getElementById('dataRange').textContent = days.length===1?days[0]:days[0]+' to '+days[days.length-1];

  const totKeys=sumField(days,'keystrokes'), totMouse=sumField(days,'mouse_distance_m');
  const totSaves=sumField(days,'saves'), totCopies=sumField(days,'copies');
  const totChars=sumField(days,'chars_typed'), totPastes=sumField(days,'pastes');
  const totPastedChars=sumField(days,'chars_pasted');
  const activeDays=Math.max(days.filter(d=>dayMap[d]).length,1);

  document.getElementById('v-keys').innerHTML=fmt(totKeys);
  document.getElementById('s-keys').textContent=activeDays>1?'~'+fmt(Math.round(totKeys/activeDays))+' / day':'';
  document.getElementById('v-mouse').innerHTML=fmtDec(totMouse)+'<span class="led-unit">m</span>';
  document.getElementById('s-mouse').textContent=totMouse>=1000?fmtDec(totMouse/1000,2)+' km total':'';
  document.getElementById('v-saves').innerHTML=fmt(totSaves);
  document.getElementById('s-saves').textContent=activeDays>1?'~'+fmtDec(totSaves/activeDays,1)+' / day':'';
  document.getElementById('v-copies').innerHTML=fmt(totCopies);
  document.getElementById('s-copies').textContent=totPastes?totPastes+' pastes':'';
  document.getElementById('v-chars').innerHTML=fmt(totChars);
  document.getElementById('s-chars').textContent=totChars?'~'+fmt(Math.round(totChars/5))+' words':'';
  document.getElementById('v-pastes').innerHTML=fmt(totPastes);
  document.getElementById('s-pastes').textContent=totPastedChars?fmt(totPastedChars)+' chars':'';

  /* hourly chart */
  let hLabels,hData;
  if(days.length===1){
    hLabels=Array.from({length:24},(_,i)=>i+'h'); hData=hourlySum(days[0],'keystrokes');
    document.getElementById('hourlyTitle').textContent='Hourly Activity -- '+days[0];
  } else {
    hLabels=Array.from({length:24},(_,i)=>i+'h'); hData=hourlyAvg(days,'keystrokes');
    document.getElementById('hourlyTitle').textContent='Avg Hourly Activity -- '+days.length+' days';
  }
  const maxH=Math.max(...hData,1);
  const hColors=hData.map(v=>{ const r=v/maxH; return r>.75?'rgba(184,136,46,0.9)':r>.5?'rgba(184,136,46,0.65)':r>.25?'rgba(184,136,46,0.42)':'rgba(184,136,46,0.2)'; });
  hourlyC.data.labels=hLabels; hourlyC.data.datasets[0].data=hData; hourlyC.data.datasets[0].backgroundColor=hColors; hourlyC.update();

  /* trend */
  const tLabels=days.length>60?days.filter((_,i)=>i%2===0):days;
  trendC.data.labels=tLabels; trendC.data.datasets[0].data=dailyTotals(days,'keystrokes').filter((_,i)=>days.length<=60||i%2===0); trendC.update();

  /* rhythm */
  rhythmC.data.datasets[0].data=hourlyAvg(days,'keystrokes'); rhythmC.update();

  buildHeatmap();
  buildScore(today);
  buildFocus(today);

  const events=ledgerInRange(range);
  buildDonut(modelC,countBy(events,'model'));
  buildDonut(kindsC,countByKinds(events));
  buildProjectsBar(events);
  buildSwitchChart(days,events);
  buildFun(totKeys,totMouse,totSaves,totCopies,totChars,totPastes,totPastedChars,activeDays);
}

function buildHeatmap(){
  const grid=document.getElementById('heatGrid'), mths=document.getElementById('heatMonths');
  grid.innerHTML=''; mths.innerHTML='';
  const today=new Date(); today.setHours(0,0,0,0);
  const start=new Date(today); start.setDate(start.getDate()-89);
  while(start.getDay()!==0) start.setDate(start.getDate()-1);
  const allK={};
  for(const d of INPUT_DAYS){ allK[d.date]=d.hourly.reduce((s,h)=>s+(h.keystrokes||0),0); }
  // Also use ledger event counts as proxy when no input data
  const ledgerByDay=countBy(LEDGER_EVENTS,'date');
  const maxK=Math.max(...Object.values(allK),1);
  const maxL=Math.max(...Object.values(ledgerByDay),1);
  let col=null, prevMonth=-1, colIndex=0;
  const cur=new Date(start);
  while(cur<=today){
    if(col===null||cur.getDay()===0){ col=document.createElement('div'); col.className='heatCol'; grid.appendChild(col);
      if(cur.getMonth()!==prevMonth){ const s=document.createElement('div'); s.className='heatMonthLabel'; s.textContent=cur.toLocaleString('default',{month:'short'}); mths.appendChild(s); prevMonth=cur.getMonth(); } else { const s=document.createElement('div'); s.className='heatMonthLabel'; mths.appendChild(s); }
      colIndex++; }
    const ds=dateStr(cur);
    const hasInput=allK[ds]!=null;
    const ratio=hasInput?(allK[ds]||0)/maxK:(ledgerByDay[ds]||0)/maxL*0.5;
    const cell=document.createElement('div');
    cell.className='cell'+(ratio>.75?' lvl4':ratio>.4?' lvl3':ratio>.15?' lvl2':ratio>.02?' lvl1':'');
    const tip=hasInput?(allK[ds]?fmt(allK[ds])+' keystrokes':'No input data'):(ledgerByDay[ds]?ledgerByDay[ds]+' ledger entries':'No data');
    cell.addEventListener('mouseenter',e=>showTip(e,ds,tip));
    cell.addEventListener('mousemove',moveTip); cell.addEventListener('mouseleave',hideTip);
    col.appendChild(cell);
    cur.setDate(cur.getDate()+1);
  }
}

function buildScore(today){
  const row=dayMap[today];
  if(!row){ document.getElementById('scoreNum').textContent='--'; document.getElementById('scoreTitle').textContent='No data'; return; }
  const hourlyK=row.hourly.map(h=>h.keystrokes||0);
  const totalK=hourlyK.reduce((a,b)=>a+b,0);
  let maxBlock=0,cur=0;
  for(const k of hourlyK){ if(k>30){cur++;if(cur>maxBlock)maxBlock=cur;}else cur=0; }
  const score=Math.min(100,Math.round(Math.min(40,maxBlock*8)+Math.min(30,Math.floor(totalK/100))+Math.min(15,Math.floor((row.hourly.reduce((s,h)=>s+(h.saves||0),0)/Math.max(totalK,1))*3000))+Math.max(0,15-(new Set(LEDGER_EVENTS.filter(e=>e.date===today).map(e=>e.project)).size-1)*3)));
  document.getElementById('scoreNum').textContent=score;
  document.getElementById('scoreArc').style.strokeDashoffset=289*(1-score/100);
  const t=score>=80?'Elite':score>=60?'Strong':score>=40?'Solid':score>=20?'Warming up':'Quiet day';
  document.getElementById('scoreTitle').textContent=t;
  document.getElementById('scoreDesc').textContent={Elite:'Peak focus. You were in the zone.',Strong:'Great session. Sustained effort.',Solid:'Good work. Some strong blocks.','Warming up':'Light day. Plenty left in the tank.','Quiet day':'Rest is productive too.'}[t];
}

function buildFocus(today){
  const tl=document.getElementById('focusTimeline'); tl.innerHTML='';
  const row=dayMap[today];
  if(!row){tl.innerHTML='<div class="focus-empty">No input data for today yet.</div>';return;}
  const hourlyK=row.hourly.map(h=>h.keystrokes||0);
  const COLORS=['#b8882e','#8a62c0','#4e9954','#c49840','#a86840'];
  let blocks=[],s=-1;
  for(let h=0;h<24;h++){if(hourlyK[h]>30){if(s===-1)s=h;}else{if(s!==-1){blocks.push({start:s,end:h});s=-1;}}}
  if(s!==-1) blocks.push({start:s,end:24});
  blocks=blocks.filter(b=>b.end-b.start>=1);
  if(!blocks.length){tl.innerHTML='<div class="focus-empty">No focus blocks yet today.</div>';return;}
  blocks.forEach((b,i)=>{
    const div=document.createElement('div'); div.className='focus-block';
    div.style.cssText='left:'+(b.start/24*100).toFixed(1)+'%;width:'+((b.end-b.start)/24*100).toFixed(1)+'%;background:'+COLORS[i%COLORS.length]+';';
    div.textContent=(b.end-b.start)+'h';
    div.title=b.start+':00 - '+b.end+':00 ('+(b.end-b.start)+'h)';
    tl.appendChild(div);
  });
}

function buildDonut(chart,counts){
  const e=Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,10);
  chart.data.labels=e.map(x=>x[0]); chart.data.datasets[0].data=e.map(x=>x[1]); chart.update();
}

function buildProjectsBar(events){
  const el=document.getElementById('projectsBar');
  const counts=countBy(events,'project');
  const entries=Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,8);
  if(!entries.length){el.innerHTML='<div class="nodata">No ledger data in range</div>';return;}
  const max=entries[0][1];
  el.innerHTML=entries.map(function(entry){
    var p=entry[0],n=entry[1];
    return '<div class="bar-row"><div class="bar-label" title="'+p+'">'+p+'</div><div class="bar-track"><div class="bar-fill" style="width:'+(n/max*100).toFixed(1)+'%;background:var(--gold)"></div></div><div class="bar-n">'+n+'</div></div>';
  }).join('');
}

function buildSwitchChart(days,events){
  const byDate={};
  for(const e of events){if(!byDate[e.date])byDate[e.date]=new Set();byDate[e.date].add(e.project);}
  const labels=days.length>60?days.filter((_,i)=>i%2===0):days;
  switchC.data.labels=labels; switchC.data.datasets[0].data=labels.map(d=>byDate[d]?Math.max(0,byDate[d].size-1):0); switchC.update();
}

function buildFun(keys,mouseM,saves,copies,chars,pastes,pastedChars,activeDays){
  const facts=[];
  if(chars>0){ const words=Math.round(chars/5); facts.push({i:'[pg]',s:(words/250).toFixed(1)+' pages',d:'of text typed'}); }
  if(mouseM>0){ facts.push({i:'[mv]',s:mouseM>=1000?fmtDec(mouseM/1000,2)+' km':fmtDec(mouseM)+' m',d:'mouse travel distance'}); }
  if(mouseM>=1000){ facts.push({i:'[run]',s:fmtDec(mouseM/1000/42.195,3)+'x',d:'a marathon in mouse movement'}); }
  if(saves>0) facts.push({i:'[sv]',s:fmt(saves),d:'times you saved your work'});
  if(copies>0&&pastes>0) facts.push({i:'[cp]',s:(copies/pastes).toFixed(2)+'x',d:'copy-to-paste ratio'});
  if(chars>0) facts.push({i:'[wpm]',s:((chars/5)/(activeDays*8*60)).toFixed(1)+' WPM',d:'est. typing speed (8h active/day)'});
  if(keys>1000) facts.push({i:'[kbd]',s:(keys/500000).toFixed(4)+'x',d:'a novel worth of keystrokes'});
  if(pastedChars>0) facts.push({i:'[in]',s:fmt(pastedChars),d:'characters pasted from clipboard'});
  if(saves>0&&keys>0) facts.push({i:'[/k]',s:(saves/keys*1000).toFixed(2),d:'saves per 1,000 keystrokes'});
  const el=document.getElementById('funFacts');
  if(!facts.length){el.innerHTML='<div class="nodata">Start the input tracker to unlock fun stats.</div>';return;}
  el.innerHTML=facts.map(function(f){
    return '<div class="fun-card"><div class="fun-icon">'+f.i+'</div><div class="fun-stat">'+f.s+'</div><div class="fun-desc">'+f.d+'</div></div>';
  }).join('');
}

document.querySelectorAll('.range-btn').forEach(function(btn){
  btn.addEventListener('click',function(){
    document.querySelectorAll('.range-btn').forEach(function(b){b.classList.remove('active');});
    btn.classList.add('active');
    const r=btn.dataset.range;
    document.getElementById('customRow').classList.toggle('visible',r==='custom');
    if(r!=='custom'){ activeRange=parseInt(r); render(); }
  });
});
function applyCustom(){
  const f=document.getElementById('customFrom').value, t=document.getElementById('customTo').value;
  if(!f||!t) return;
  activeRange=0; customFrom=parseDateStr(f); customTo=parseDateStr(t); customTo.setHours(23,59,59,999); render();
}

initCharts();
render();
</script>
</body>
</html>
'@

# ---------------------------------------------------------------------------
# 5. Inject data via safe string replacement (never inside heredoc)
# ---------------------------------------------------------------------------
$html = $html.Replace('__INPUT_DAYS__',    $inputDaysJson)
$html = $html.Replace('__LEDGER_EVENTS__', $ledgerJson)
$html = $html.Replace('__GENERATED_AT__',  $generatedAt)

# ---------------------------------------------------------------------------
# 6. Write UTF-8 without BOM
# ---------------------------------------------------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutPath, $html, $utf8NoBom)

Write-Host "Dashboard rendered -> $OutPath"
Write-Host "  Input days loaded : $($inputDays.Count)"
Write-Host "  Ledger events     : $($ledgerEvents.Count)"
