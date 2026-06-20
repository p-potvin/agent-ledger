#!/usr/bin/env node
// generate-data.mjs — produce stats-app/src/lib/data.json on every deploy.
//
// Sources (both read at deploy time on greencloud):
//   1. /monitor/work-impact — fresh event totals/series from vaultwares-api
//   2. /var/www/ledger.vaultwares.ca/data/work-impact-data.json — legacy
//      renderer output, supplies lineStats / commitSamples that the API
//      doesn't compute. Slightly behind the API on days but the derived
//      metrics (commit-size distribution, files-touched, techVolume) are
//      computed there with pathRegex exclusions already applied.
//
// Transforms:
//   - Cutoff date 2026-03-11 (VaultWares foundation). Earlier events in the
//     DB (early-2026 telemetry seeding) are dropped from every series.
//   - Project consolidation via project-aliases.json so renames don't
//     fracture the totals (e.g. vaultwares-pipelines → vaultwares-api).
//   - Known commit outliers (giant-diff rewrites) listed in COMMIT_OUTLIERS
//     are kept visible but excluded from commitStats math.
//
// Env (with sensible greencloud-vps defaults):
//   STATS_API_URL          default https://api.vaultwares.ca/monitor/work-impact
//   STATS_LEGACY_PATH      default /var/www/ledger.vaultwares.ca/data/work-impact-data.json
//   STATS_LEGACY_URL       fallback if the local file isn't present (e.g. dev)
//   STATS_ALIASES_PATH     default ../project-aliases.json (relative to stats-app/)
//   STATS_DATA_OUT         default src/lib/data.json
//   STATS_CUTOFF_DATE      default 2026-03-11

import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const API_URL = process.env.STATS_API_URL || "https://api.vaultwares.ca/monitor/work-impact";
const LEGACY_PATH = process.env.STATS_LEGACY_PATH || "/var/www/ledger.vaultwares.ca/data/work-impact-data.json";
const LEGACY_URL  = process.env.STATS_LEGACY_URL || "https://ledger.vaultwares.ca/data/work-impact-data.json";
const ALIASES_PATH = resolve(process.env.STATS_ALIASES_PATH || "../project-aliases.json");
const OUT_PATH = resolve(process.env.STATS_DATA_OUT || "src/lib/data.json");
const CUTOFF = process.env.STATS_CUTOFF_DATE || "2026-03-11";

// Giant single-commit rewrites that skew the commit-size distribution.
// Listed so users can see them but excluded from commitStats math.
const COMMIT_OUTLIERS = [
  { day: "2026-03-23", project: "windows-customizer", commit: "a1d4b42", cleanChurnLines: 29687, note: "Major refactoring"   },
  { day: "2026-04-14", project: "vaultwares-cli",     commit: "486f844", cleanChurnLines: 83144, note: "Massive CLI overhaul" },
  { day: "2026-04-26", project: "vault-flows",        commit: "37dfb53", cleanChurnLines: 45406, note: "Flow system migration"},
  { day: "2026-04-26", project: "vault-flows",        commit: "0998411", cleanChurnLines: 45406, note: "Parallel flow rewrite"},
];
// Any commit with more clean churn than this gets auto-flagged + excluded
// from commitStats so future mega-commits don't quietly poison the math.
// They still appear in the commitOutliers list so the reader sees them.
const AUTO_OUTLIER_THRESHOLD = 15000;

const log = (...a) => console.log("[generate-data]", ...a);
const die = (msg, err) => { console.error("[generate-data] FATAL:", msg, err ?? ""); process.exit(1); };

// ---------- Sources -----------------------------------------------------------

log("fetch api", API_URL);
const apiRes = await fetch(API_URL, { headers: { Accept: "application/json" } }).catch(e => die("api fetch failed", e));
if (!apiRes.ok) die(`api HTTP ${apiRes.status}`);
const apiPayload = await apiRes.json().catch(e => die("api response not JSON", e));
const api = apiPayload.data ?? apiPayload;
if (!api?.totals || !api?.series) die("api response missing data.totals/series", apiPayload);

let legacy = null;
try {
  legacy = JSON.parse(await readFile(LEGACY_PATH, "utf8"));
  log("read legacy file", LEGACY_PATH);
} catch {
  log("legacy file not found, trying URL", LEGACY_URL);
  try {
    const r = await fetch(LEGACY_URL);
    if (r.ok) legacy = await r.json();
  } catch { /* legacy stays null */ }
}
const legacyData = legacy?.data ?? null;

let aliasesRaw = null;
try { aliasesRaw = JSON.parse(await readFile(ALIASES_PATH, "utf8")); }
catch (e) { log("aliases file not readable, projects will not be consolidated", e?.message); }

// ---------- Project aliasing + fork exclusion --------------------------------

const aliasMap = new Map();
if (aliasesRaw?.projects) {
  for (const entry of aliasesRaw.projects) {
    if (!entry?.canonical) continue;
    aliasMap.set(entry.canonical.toLowerCase(), entry.canonical);
    for (const a of entry.aliases || []) aliasMap.set(String(a).toLowerCase(), entry.canonical);
  }
}
const canon = (name) => {
  if (!name) return "General Tasks";
  const hit = aliasMap.get(String(name).toLowerCase());
  return hit || name;
};
const forkSet = new Set((aliasesRaw?.forks || []).map(s => String(s).toLowerCase()));
const isOwn = (name) => !forkSet.has(String(name).toLowerCase());

// ---------- Cutoff + per-day filter, recompute totals ------------------------

const rawDays = (api.series.days || []).filter(d => d.day && d.day >= CUTOFF);
rawDays.sort((a, b) => a.day.localeCompare(b.day));

// Fill zero-event days between CUTOFF and the last seen date so streak math
// and the heatmap reflect actual gaps, not the API's sparse omit-zero output.
function eachDay(fromStr, toStr) {
  const out = [];
  const d = new Date(fromStr + "T00:00:00Z");
  const end = new Date(toStr + "T00:00:00Z");
  while (d <= end) {
    out.push(d.toISOString().slice(0, 10));
    d.setUTCDate(d.getUTCDate() + 1);
  }
  return out;
}
const lastSeen = rawDays.at(-1)?.day || CUTOFF;
const byDayCount = new Map(rawDays.map(d => [d.day, Number(d.entries ?? d.count ?? 0)]));
const daySeries = eachDay(CUTOFF, lastSeen).map(date => ({
  date,
  count: byDayCount.get(date) ?? 0,
}));

const totalEvents = daySeries.reduce((s, r) => s + r.count, 0);
const activeDays = daySeries.filter(r => r.count > 0).length;

// Per-day project set after aliasing → recompute distinct projects post-cutoff.
// Forks are excluded so external repos cloned for reference don't pad the count.
const projectsSet = new Set();
for (const d of rawDays) for (const p of d.projects || []) {
  const c = canon(p);
  if (isOwn(c)) projectsSet.add(c);
}
const totalProjects = projectsSet.size;

// ---------- byMonth — recompute from filtered daySeries (drop pre-cutoff) ---

const monthCounts = new Map();
for (const r of daySeries) {
  const m = r.date.slice(0, 7);
  monthCounts.set(m, (monthCounts.get(m) || 0) + r.count);
}
const byMonth = [...monthCounts.entries()]
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([label, count]) => ({ label, count }));

// ---------- byKind — keep as-is (kinds aren't time-filtered) -----------------

const byKind = (api.series.kinds || []).map(k => ({ label: k.kind, count: Number(k.count || 0) }));

// ---------- byProject — consolidate via aliases, sort desc -------------------

const projectCounts = new Map();
for (const p of api.series.projects || []) {
  const key = canon(p.project);
  if (!isOwn(key)) continue;
  projectCounts.set(key, (projectCounts.get(key) || 0) + Number(p.entries ?? p.count ?? 0));
}
const byProject = [...projectCounts.entries()]
  .sort(([, a], [, b]) => b - a)
  .map(([label, count]) => ({ label, count }));

// ---------- hour / dow -------------------------------------------------------

const byHour = (api.hourSeries || []).map(h => ({ label: String(h.hour).padStart(2, "0"), count: Number(h.count || 0) }));
const byDow  = (api.dowSeries  || []).map(r => ({ label: r.label, count: Number(r.count || 0) }));

// ---------- Streaks ----------------------------------------------------------

function streaks(series) {
  let cur = 0, longest = 0;
  for (const r of series) {
    if (r.count > 0) { cur += 1; if (cur > longest) longest = cur; }
    else cur = 0;
  }
  let current = 0;
  for (let i = series.length - 1; i >= 0; i--) {
    if (series[i].count > 0) current += 1; else break;
  }
  return { current, longest };
}
const { current: streakCurrent, longest: streakLongest } = streaks(daySeries);

// ---------- Busiest day / week -----------------------------------------------

const busiestDayEntry = daySeries.reduce((best, r) => (r.count > (best?.count ?? -1) ? r : best), null);
const busiestDay = busiestDayEntry?.date ?? "";
const busiestDayCount = busiestDayEntry?.count ?? 0;

function isoWeek(dateStr) {
  const d = new Date(dateStr + "T00:00:00Z");
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
// ISO week label "2026-W17" → Monday Apr 20, 2026 → human range "Apr 20-26"
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function isoWeekToRange(weekStr) {
  const m = /^(\d{4})-W(\d{2})$/.exec(weekStr);
  if (!m) return weekStr;
  const year = +m[1], week = +m[2];
  // ISO week 1 = the week containing the first Thursday. Equivalently, the
  // Monday of week 1 is Jan 4 of that year, rolled back to its Monday.
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const jan4Day = jan4.getUTCDay() || 7;            // 1..7 (Mon..Sun)
  const week1Monday = new Date(jan4);
  week1Monday.setUTCDate(jan4.getUTCDate() - jan4Day + 1);
  const start = new Date(week1Monday);
  start.setUTCDate(week1Monday.getUTCDate() + (week - 1) * 7);
  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + 6);
  const sm = start.getUTCMonth(), em = end.getUTCMonth();
  if (sm === em) return `${MONTH_NAMES[sm]} ${start.getUTCDate()}-${end.getUTCDate()}`;
  return `${MONTH_NAMES[sm]} ${start.getUTCDate()} - ${MONTH_NAMES[em]} ${end.getUTCDate()}`;
}
const weekCounts = new Map();
for (const r of daySeries) {
  const w = isoWeek(r.date);
  weekCounts.set(w, (weekCounts.get(w) || 0) + r.count);
}
let busiestWeekIso = "", busiestWeekCount = 0;
for (const [w, c] of weekCounts) if (c > busiestWeekCount) { busiestWeekIso = w; busiestWeekCount = c; }
const busiestWeek = busiestWeekIso ? isoWeekToRange(busiestWeekIso) : "";

// ---------- commitStats / commitBuckets / monthBoxes from legacy samples -----

const namedOutlierKeys = new Set(COMMIT_OUTLIERS.map(o => o.commit));

const allSamples = legacyData?.commitSamples ?? [];
// Auto-flag any future commit above AUTO_OUTLIER_THRESHOLD so a fresh
// mega-rewrite doesn't quietly skew the mean before someone notices.
const autoOutliers = allSamples
  .filter(s =>
    !namedOutlierKeys.has(s.commit) &&
    (s.day ?? "") >= CUTOFF &&
    Number(s.cleanChurnLines || 0) > AUTO_OUTLIER_THRESHOLD,
  );
const allOutlierKeys = new Set([...namedOutlierKeys, ...autoOutliers.map(s => s.commit)]);
const goodSamples = allSamples.filter(s => !allOutlierKeys.has(s.commit) && (s.day ?? "") >= CUTOFF);

function quantile(sorted, q) {
  if (sorted.length === 0) return 0;
  const idx = q * (sorted.length - 1);
  const lo = Math.floor(idx), hi = Math.ceil(idx);
  return lo === hi ? sorted[lo] : sorted[lo] + (idx - lo) * (sorted[hi] - sorted[lo]);
}
function modeOf(values) {
  const counts = new Map();
  for (const v of values) counts.set(v, (counts.get(v) || 0) + 1);
  let mode = 0, best = 0;
  for (const [v, c] of counts) if (c > best) { mode = v; best = c; }
  return mode;
}

const cleanChurns = goodSamples.map(s => Number(s.cleanChurnLines || 0)).sort((a, b) => a - b);
const commitStats = goodSamples.length
  ? {
      mean:    Math.round(cleanChurns.reduce((a, b) => a + b, 0) / cleanChurns.length),
      median:  Math.round(quantile(cleanChurns, 0.5)),
      mode:    modeOf(cleanChurns),
      samples: goodSamples.length,
    }
  : { mean: 0, median: 0, mode: 0, samples: 0 };

// Log-ish histogram buckets matching the legacy UI (powers of ~2)
const BUCKET_EDGES = [0, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
const commitBuckets = BUCKET_EDGES.map((edge, i) => {
  const upper = BUCKET_EDGES[i + 1] ?? Infinity;
  const count = cleanChurns.filter(v => v >= edge && v < upper).length;
  return { edge: edge.toString(), count };
});

// Per-month box plot from clean churn
const samplesByMonth = new Map();
for (const s of goodSamples) {
  const m = (s.month || (s.day ?? "").slice(0, 7));
  if (!m) continue;
  if (!samplesByMonth.has(m)) samplesByMonth.set(m, []);
  samplesByMonth.get(m).push(Number(s.cleanChurnLines || 0));
}
const monthBoxes = [...samplesByMonth.entries()]
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([month, arr]) => {
    arr.sort((a, b) => a - b);
    return {
      month,
      min:    arr[0] ?? 0,
      q1:     Math.round(quantile(arr, 0.25)),
      median: Math.round(quantile(arr, 0.5)),
      q3:     Math.round(quantile(arr, 0.75)),
      max:    arr[arr.length - 1] ?? 0,
    };
  });

// Named outliers (curated narrative) + auto-detected mega-commits since.
const commitOutliersList = [
  ...COMMIT_OUTLIERS.map(o =>
    `${o.day}: ${o.project} - +${o.cleanChurnLines.toLocaleString()} lines (${o.commit}) - ${o.note}`,
  ),
  ...autoOutliers
    .sort((a, b) => Number(b.cleanChurnLines || 0) - Number(a.cleanChurnLines || 0))
    .map(s =>
      `${s.day}: ${s.project} - +${Number(s.cleanChurnLines || 0).toLocaleString()} lines (${s.commit}) - auto-detected (> ${AUTO_OUTLIER_THRESHOLD.toLocaleString()} clean lines)`,
    ),
];

// ---------- techVolume — straight from legacy lineStats ----------------------

const lsRaw      = legacyData?.lineStats?.raw      || { files: 0, insertions: 0, deletions: 0 };
const lsClean    = legacyData?.lineStats?.clean    || { files: 0, insertions: 0, deletions: 0 };
const lsExcluded = legacyData?.lineStats?.excluded || { files: 0, insertions: 0, deletions: 0 };
const techRow = (label, x) => ({
  label,
  insertions: x.insertions || 0,
  deletions:  x.deletions  || 0,
  files:      x.files      || 0,
  churn:     (x.insertions || 0) + (x.deletions || 0),
  net:       (x.insertions || 0) - (x.deletions || 0),
});
const techVolume = {
  raw:      techRow("Raw",      lsRaw),
  clean:    techRow("Clean",    lsClean),
  excluded: techRow("Excluded", lsExcluded),
};

// ---------- filesTouched per commit (mean/median/p90/max) -------------------

const filesPer = goodSamples.map(s => Number(s.filesClean ?? s.filesTouched ?? 0)).sort((a, b) => a - b);
const filesTouched = filesPer.length
  ? {
      mean:   +(filesPer.reduce((a, b) => a + b, 0) / filesPer.length).toFixed(1),
      median: Math.round(quantile(filesPer, 0.5)),
      p90:    Math.round(quantile(filesPer, 0.9)),
      max:    filesPer[filesPer.length - 1],
    }
  : { mean: 0, median: 0, p90: 0, max: 0 };

// ---------- concentration: top-5 project share -------------------------------

const top5 = byProject.slice(0, 5);
const top5Sum = top5.reduce((s, p) => s + p.count, 0);
const concentration = top5.map(p => ({
  label: p.label,
  count: Math.round((p.count / (top5Sum || 1)) * 100),
}));

// ---------- highlights -------------------------------------------------------

const mostConsistentMonth = byMonth.length
  ? byMonth.reduce((best, m) => (m.count > (best?.count ?? -1) ? m : best)).label
  : "";
const widestProjectDay = rawDays.length
  ? rawDays.reduce((best, d) => (((d.projects || []).length) > ((best?.projects || []).length) ? d : best), null)?.day || ""
  : "";
const highlights = {
  mostConsistentMonth,
  widestProjectDay,
  strongestWeek: busiestWeek,
  milestones: [],
  topProjects: byProject.slice(0, 5).map(p => p.label),
};

// ---------- agentData --------------------------------------------------------

const a = api.agentData || {};
const agentData = {
  totalEvents:    Number(a.totalEvents ?? totalEvents),
  distinctActors: Array.isArray(a.actors) ? a.actors.length : 0,
  modelsUsed:     Array.isArray(a.models) ? a.models.length : 0,
  toolsUsed:      Array.isArray(a.tools)  ? a.tools.length  : 0,
  topTools:    (a.tools     || []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  topMcp:      (a.mcpServers|| []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  topActors:   (a.actors    || []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  dayActivity: (a.daySeries || []).filter(r => (r.day ?? "") >= CUTOFF).map(r => ({ label: r.day, count: Number(r.count || 0) })),
};

// ---------- Projects detail (best-effort, aliased) --------------------------

const projectsAgg = new Map();
for (const p of api.series.projects || []) {
  const name = canon(p.project);
  if (!isOwn(name)) continue;
  const entries = Number(p.entries ?? p.count ?? 0);
  const existing = projectsAgg.get(name);
  if (!existing) {
    projectsAgg.set(name, {
      name,
      aliases: Array.isArray(p.aliases) ? p.aliases : (p.project !== name ? [p.project] : []),
      entries,
      first: p.firstDay || "",
      last:  p.lastDay  || "",
      kinds: { ...(p.kinds || {}) },
      recentSummaries: Array.isArray(p.recent) ? p.recent.slice(0, 5) : [],
    });
  } else {
    existing.entries += entries;
    if (p.project !== name && !existing.aliases.includes(p.project)) existing.aliases.push(p.project);
    if (p.firstDay && (!existing.first || p.firstDay < existing.first)) existing.first = p.firstDay;
    if (p.lastDay  && (!existing.last  || p.lastDay  > existing.last))  existing.last  = p.lastDay;
    for (const [k, v] of Object.entries(p.kinds || {})) existing.kinds[k] = (existing.kinds[k] || 0) + v;
    for (const s of (p.recent || []).slice(0, 5 - existing.recentSummaries.length)) existing.recentSummaries.push(s);
  }
}
const projects = [...projectsAgg.values()]
  .sort((a, b) => b.entries - a.entries)
  .slice(0, 50);

// ---------- Final payload ----------------------------------------------------

const out = {
  generatedAt: apiPayload.generated_at || new Date().toISOString(),
  rangeStart:  CUTOFF,
  rangeEnd:    daySeries.at(-1)?.date || CUTOFF,
  lang: "en",

  totalEvents,
  activeDays,
  totalProjects,
  streakCurrent,
  streakLongest,
  busiestDay,
  busiestDayCount,
  busiestWeek,
  busiestWeekCount,
  totalCommits: Number(legacyData?.totals?.uniqueCommitsRecomputed ?? legacyData?.totals?.commitEventsWithStats ?? api.totals.commitEventsWithStats ?? api.totals.events ?? 0),

  daySeries,
  byMonth,
  byKind,
  byProject,

  commitStats,
  commitBuckets,
  monthBoxes,
  commitOutliers: commitOutliersList,

  techVolume,
  filesTouched,
  concentration,
  highlights,

  byHour,
  byDow,

  agentData,
  projects,
};

await writeFile(OUT_PATH, JSON.stringify(out, null, 2) + "\n", "utf8");
log("wrote", OUT_PATH,
  `(${out.totalEvents} events, ${out.activeDays} active days, ${out.totalProjects} projects, range ${out.rangeStart} → ${out.rangeEnd})`);
