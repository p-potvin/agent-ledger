#!/usr/bin/env node
// generate-data.mjs — fetch /monitor/work-impact from vaultwares-api,
// transform the nested API shape into the flat shape stats-app expects,
// and write to src/lib/data.json so the next vite build bundles fresh data.
//
// Run from the stats-app/ directory (deploy.sh chdirs there before build):
//   node scripts/generate-data.mjs
//
// Env (with sensible greencloud-vps defaults):
//   STATS_API_URL  default https://api.vaultwares.ca/monitor/work-impact
//   STATS_DATA_OUT default src/lib/data.json

import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const API_URL = process.env.STATS_API_URL || "https://api.vaultwares.ca/monitor/work-impact";
const OUT_PATH = resolve(process.env.STATS_DATA_OUT || "src/lib/data.json");

const log = (...a) => console.log("[generate-data]", ...a);
const die = (msg, err) => { console.error("[generate-data] FATAL:", msg, err ?? ""); process.exit(1); };

log("fetch", API_URL);
const res = await fetch(API_URL, { headers: { Accept: "application/json" } }).catch(e => die("fetch failed", e));
if (!res.ok) die(`HTTP ${res.status} ${res.statusText}`);
const payload = await res.json().catch(e => die("response is not JSON", e));

const d = payload.data ?? payload;
if (!d || !d.totals || !d.series) die("response missing data.totals / data.series", payload);

// --- Derived metrics that the API doesn't compute ---------------------------

const days = (d.series.days || []).slice().sort((a, b) => a.day.localeCompare(b.day));
const daySeries = days.map(r => ({ date: r.day, count: Number(r.entries ?? r.count ?? 0) }));

// Streaks count consecutive days where count > 0; "current" is the streak
// ending at the LATEST date in the range (not strictly "today" — the API
// trims to the last day with activity).
function streaks(series) {
  let cur = 0, longest = 0, runEnd = -1;
  for (let i = 0; i < series.length; i++) {
    if (series[i].count > 0) {
      cur += 1;
      if (cur > longest) longest = cur;
      runEnd = i;
    } else {
      cur = 0;
    }
  }
  const current = runEnd === series.length - 1 ? cur || streakBack(series) : 0;
  return { current, longest };
}
function streakBack(series) {
  let n = 0;
  for (let i = series.length - 1; i >= 0; i--) {
    if (series[i].count > 0) n += 1; else break;
  }
  return n;
}
const { current: streakCurrent, longest: streakLongest } = streaks(daySeries);

const busiestDayEntry = daySeries.reduce((best, r) => (r.count > (best?.count ?? -1) ? r : best), null);
const busiestDay = busiestDayEntry?.date ?? "";
const busiestDayCount = busiestDayEntry?.count ?? 0;

// ISO week (YYYY-Www) from a YYYY-MM-DD date.
function isoWeek(dateStr) {
  const d = new Date(dateStr + "T00:00:00Z");
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
const weekCounts = new Map();
for (const r of daySeries) {
  const w = isoWeek(r.date);
  weekCounts.set(w, (weekCounts.get(w) || 0) + r.count);
}
let busiestWeek = "", busiestWeekCount = 0;
for (const [w, c] of weekCounts) if (c > busiestWeekCount) { busiestWeek = w; busiestWeekCount = c; }

// --- BarList shapes (label, count) ------------------------------------------

const byMonth   = (d.series.months   || []).map(m => ({ label: m.month, count: Number(m.count || 0) }));
const byKind    = (d.series.kinds    || []).map(k => ({ label: k.kind,  count: Number(k.count || 0) }));
const byProject = (d.series.projects || []).map(p => ({ label: p.project, count: Number(p.entries ?? p.count ?? 0) }));

const byHour = (d.hourSeries || []).map(h => ({ label: String(h.hour).padStart(2, "0"), count: Number(h.count || 0) }));
const byDow  = (d.dowSeries  || []).map(r => ({ label: r.label, count: Number(r.count || 0) }));

// --- agentData ---------------------------------------------------------------

const a = d.agentData || {};
const agentData = {
  totalEvents:    Number(a.totalEvents ?? d.totals.events ?? 0),
  distinctActors: Array.isArray(a.actors) ? a.actors.length : 0,
  modelsUsed:     Array.isArray(a.models) ? a.models.length : 0,
  toolsUsed:      Array.isArray(a.tools)  ? a.tools.length  : 0,
  topTools:    (a.tools     || []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  topMcp:      (a.mcpServers|| []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  topActors:   (a.actors    || []).slice(0, 10).map(t => ({ label: t.name, count: Number(t.count || 0) })),
  dayActivity: (a.daySeries || []).map(r => ({ label: r.day, count: Number(r.count || 0) })),
};

// --- Projects detail (best-effort from series.projects) ---------------------

const projects = (d.series.projects || []).slice(0, 50).map(p => ({
  name: p.project,
  aliases: [],
  entries: Number(p.entries ?? p.count ?? 0),
  first: p.firstDay || "",
  last:  p.lastDay  || "",
  kinds: p.kinds || {},
  recentSummaries: Array.isArray(p.recent) ? p.recent.slice(0, 5) : [],
}));

// --- Final payload matching stats-app/src/lib/types.ts WorkImpactData -------

const out = {
  generatedAt: payload.generated_at || new Date().toISOString(),
  rangeStart:  d.range?.start || "",
  rangeEnd:    d.range?.end   || "",
  lang: "en",

  totalEvents:     Number(d.totals.events     || 0),
  activeDays:      Number(d.totals.activeDays || 0),
  totalProjects:   Number(d.totals.projects   || 0),
  streakCurrent,
  streakLongest,
  busiestDay,
  busiestDayCount,
  busiestWeek,
  busiestWeekCount,
  totalCommits:    Number(d.totals.commitEventsWithStats ?? d.totals.events ?? 0),

  daySeries,
  byMonth,
  byKind,
  byProject,

  byHour,
  byDow,

  agentData,
  projects,
};

await writeFile(OUT_PATH, JSON.stringify(out, null, 2) + "\n", "utf8");
log("wrote", OUT_PATH, `(${out.totalEvents} events, ${out.activeDays} active days, range ${out.rangeStart} → ${out.rangeEnd})`);
