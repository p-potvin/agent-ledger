// ── App — VaultWares Work Impact Stats Dashboard ─────────────────────────────

import { useState } from 'react'
import { getI18n, type Lang } from './lib/i18n'
import type { WorkImpactData } from './lib/types'

import Header           from './components/Header'
import KpiCard          from './components/KpiCard'
import HeatmapGrid      from './components/HeatmapGrid'
import BarList          from './components/BarList'
import CommitStats      from './components/CommitStats'
import TechVolumeTable  from './components/TechVolumeTable'
import FilesTouched     from './components/FilesTouched'
import ConcentrationBars from './components/ConcentrationBars'
import ProjectCard      from './components/ProjectCard'
import AgentSection     from './components/AgentSection'
import Highlights       from './components/Highlights'
import ActivityPatterns from './components/ActivityPatterns'

// ── Demo data ─────────────────────────────────────────────────────────────────
const DEMO_DATA: WorkImpactData = {
  generatedAt: '2025-08-15T14:30:00Z',
  rangeStart:  '2025-01-01',
  rangeEnd:    '2025-08-15',
  lang:        'en',

  totalEvents:      418,
  activeDays:       147,
  totalProjects:    24,
  streakCurrent:    5,
  streakLongest:    14,
  busiestDay:       '2025-07-11',
  busiestDayCount:  23,
  busiestWeek:      '2025-W28',
  busiestWeekCount: 87,
  totalCommits:     312,

  daySeries: (() => {
    const entries = []
    const start = new Date('2025-01-01')
    for (let i = 0; i < 227; i++) {
      const d = new Date(start)
      d.setDate(d.getDate() + i)
      const iso = d.toISOString().slice(0, 10)
      const r = Math.random()
      entries.push({ date: iso, count: r < 0.35 ? 0 : Math.floor(r * 20) })
    }
    return entries
  })(),

  byMonth: [
    { label: 'Jan', count: 38 },
    { label: 'Feb', count: 44 },
    { label: 'Mar', count: 62 },
    { label: 'Apr', count: 51 },
    { label: 'May', count: 71 },
    { label: 'Jun', count: 49 },
    { label: 'Jul', count: 87 },
    { label: 'Aug', count: 16 },
  ],

  byKind: [
    { label: 'code-change',  count: 183 },
    { label: 'commands',     count: 97  },
    { label: 'plan',         count: 64  },
    { label: 'verification', count: 41  },
    { label: 'handoff',      count: 22  },
    { label: 'general',      count: 11  },
  ],

  byProject: [
    { label: 'vaultwares-themes',  count: 91 },
    { label: 'agent-ledger',       count: 78 },
    { label: 'vaultwares-adk',     count: 62 },
    { label: 'omx-core',           count: 47 },
    { label: 'vault-ui',           count: 39 },
    { label: 'infrastructure',     count: 28 },
    { label: 'docs',               count: 21 },
    { label: 'experiments',        count: 17 },
    { label: 'scripts',            count: 14 },
    { label: 'other',              count: 21 },
  ],

  commitStats: {
    mean:    82,
    median:  38,
    mode:    12,
    samples: 312,
  },

  commitBuckets: [
    { edge: '1–10',    count: 88 },
    { edge: '11–25',   count: 71 },
    { edge: '26–50',   count: 54 },
    { edge: '51–100',  count: 49 },
    { edge: '101–250', count: 31 },
    { edge: '251–500', count: 14 },
    { edge: '500+',    count: 5  },
  ],

  monthBoxes: [
    { month: 'Jan', min: 2,  q1: 8,  median: 22,  q3: 45,  max: 112 },
    { month: 'Feb', min: 1,  q1: 10, median: 28,  q3: 58,  max: 203 },
    { month: 'Mar', min: 0,  q1: 7,  median: 33,  q3: 72,  max: 310 },
    { month: 'Apr', min: 3,  q1: 12, median: 30,  q3: 62,  max: 189 },
    { month: 'May', min: 1,  q1: 9,  median: 25,  q3: 55,  max: 244 },
    { month: 'Jun', min: 0,  q1: 11, median: 29,  q3: 67,  max: 415 },
    { month: 'Jul', min: 2,  q1: 15, median: 44,  q3: 91,  max: 872 },
    { month: 'Aug', min: 4,  q1: 18, median: 38,  q3: 80,  max: 196 },
  ],

  commitOutliers: [
    '2025-04-22: +1842 lines (vaultwares-themes: full design-token refactor)',
    '2025-07-03: +974 lines (omx-core: video pipeline rewrite)',
    '2025-06-18: +731 lines (agent-ledger: stats-app scaffold)',
  ],

  techVolume: {
    raw: {
      label:      'Raw',
      insertions: 48320,
      deletions:  21780,
      files:      1247,
      churn:      70100,
      net:        26540,
    },
    clean: {
      label:      'Clean',
      insertions: 31450,
      deletions:  14920,
      files:      876,
      churn:      46370,
      net:        16530,
    },
    excluded: {
      label:      'Excluded',
      insertions: 16870,
      deletions:  6860,
      files:      371,
      churn:      23730,
      net:        10010,
    },
  },

  filesTouched: {
    mean:   4.2,
    median: 3,
    p90:    12,
    max:    87,
  },

  concentration: [
    { label: 'vaultwares-themes', count: 22 },
    { label: 'agent-ledger',      count: 19 },
    { label: 'vaultwares-adk',    count: 15 },
    { label: 'omx-core',          count: 11 },
    { label: 'vault-ui',          count: 9  },
    { label: 'infrastructure',    count: 7  },
    { label: 'docs',              count: 5  },
    { label: 'scripts',           count: 3  },
    { label: 'experiments',       count: 4  },
    { label: 'other',             count: 5  },
  ],

  highlights: {
    mostConsistentMonth: 'July 2025',
    widestProjectDay:    '2025-06-14 (8 projects)',
    strongestWeek:       '2025-W28 (87 events)',
    milestones: [
      '418 total events recorded',
      '14-day longest streak',
      'First full multi-agent coordination (vaultwares-adk)',
      '48k+ insertions across all repos',
    ],
    topProjects: ['vaultwares-themes', 'agent-ledger', 'vaultwares-adk', 'omx-core'],
  },

  byHour: Array.from({ length: 24 }, (_, i) => ({
    label: String(i).padStart(2, '0'),
    count: i < 6 ? Math.floor(Math.random() * 3)
         : i < 9 ? Math.floor(Math.random() * 8)
         : i < 18 ? Math.floor(Math.random() * 35) + 5
         : Math.floor(Math.random() * 15),
  })),

  byDow: [
    { label: 'Mon', count: 72 },
    { label: 'Tue', count: 68 },
    { label: 'Wed', count: 81 },
    { label: 'Thu', count: 64 },
    { label: 'Fri', count: 55 },
    { label: 'Sat', count: 38 },
    { label: 'Sun', count: 40 },
  ],

  agentData: {
    totalEvents:    156,
    distinctActors: 3,
    modelsUsed:     4,
    toolsUsed:      18,
    topTools: [
      { label: 'replace_string_in_file', count: 312 },
      { label: 'read_file',              count: 271 },
      { label: 'grep_search',            count: 198 },
      { label: 'run_in_terminal',        count: 143 },
      { label: 'create_file',            count: 87  },
      { label: 'semantic_search',        count: 64  },
    ],
    topMcp: [
      { label: 'mcp_github_push_files',         count: 48 },
      { label: 'mcp_github_list_commits',        count: 41 },
      { label: 'mcp_github_create_pull_request', count: 27 },
      { label: 'mcp_azure_mcp_storage',          count: 19 },
      { label: 'mcp_apify_call-actor',           count: 12 },
    ],
    topActors: [
      { label: 'GitHub Copilot (Claude)', count: 98 },
      { label: 'Claude Code',             count: 42 },
      { label: 'GPT-4o (Copilot Chat)',   count: 16 },
    ],
    dayActivity: (() => {
      const days: { label: string; count: number }[] = []
      const start = new Date('2025-07-01')
      for (let i = 0; i < 45; i++) {
        const d = new Date(start)
        d.setDate(d.getDate() + i)
        days.push({ label: d.toISOString().slice(0, 10), count: Math.floor(Math.random() * 8) })
      }
      return days
    })(),
  },

  projects: [
    {
      name: 'vaultwares-themes',
      aliases: ['themes', 'vault-themes'],
      entries: 91,
      first: '2025-01-08',
      last: '2025-08-12',
      kinds: { 'code-change': 48, 'plan': 22, 'verification': 12, 'commands': 9 },
      recentSummaries: [
        'Added LED pulse keyframes to index.css.',
        'Rewrote VaultThemeManager to support dark/light variants.',
        'Exported qt_exporter.py integration for PySide6 apps.',
      ],
    },
    {
      name: 'agent-ledger',
      aliases: ['ledger'],
      entries: 78,
      first: '2025-01-15',
      last: '2025-08-15',
      kinds: { 'code-change': 31, 'commands': 28, 'plan': 12, 'handoff': 7 },
      recentSummaries: [
        'Scaffolded stats-app React/Vite app with Tailwind 4.',
        'Added BoxPlotList and HistogramChart components.',
        'Created deploy workflow targeting stats.vaultwares.ca.',
      ],
    },
    {
      name: 'vaultwares-adk',
      aliases: ['adk'],
      entries: 62,
      first: '2025-02-11',
      last: '2025-08-09',
      kinds: { 'code-change': 27, 'plan': 18, 'commands': 11, 'general': 6 },
      recentSummaries: [
        'Implemented multi-agent coordination via Redis pub/sub.',
        'Added extrovert_agent and cheddar_bob personas.',
        'Wired omni_agent to ADK dispatcher pipeline.',
      ],
    },
  ],
}

// ── Section wrapper ───────────────────────────────────────────────────────────
function Section({ title, hint, children }: {
  title: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <section className="bg-vault-surface border border-vault-border rounded-[10px] p-5 flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h2 className="text-[13px] font-bold uppercase tracking-[0.06em] text-vault-fg">{title}</h2>
        {hint && <p className="text-[12px] text-vault-muted">{hint}</p>}
      </div>
      {children}
    </section>
  )
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  const [lang, setLang] = useState<Lang>(DEMO_DATA.lang)
  const t = getI18n(lang)
  const d = DEMO_DATA

  return (
    <div className="min-h-screen bg-vault-bg text-vault-fg font-sans">
      <Header
        t={t}
        lang={lang}
        onToggleLang={() => setLang(l => l === 'en' ? 'qc' : 'en')}
        generatedAt={d.generatedAt}
        rangeStart={d.rangeStart}
        rangeEnd={d.rangeEnd}
      />

      <main className="max-w-[1400px] mx-auto px-6 py-8 flex flex-col gap-6">

        {/* KPI grid */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
          <KpiCard label={t.metricEvents}  value={d.totalEvents}  variant="accent" />
          <KpiCard label={t.metricDays}    value={d.activeDays}   />
          <KpiCard label={t.metricProjects} value={d.totalProjects} />
          <KpiCard label={t.metricStreak}  value={d.streakCurrent} variant="green"
            sub={t.streakMax(d.streakLongest)} />
          <KpiCard label={t.metricCommits} value={d.totalCommits} />
        </div>

        {/* Busiest day / week KPIs */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <KpiCard label={t.metricBusiestDay}  value={`${d.busiestDay} (${d.busiestDayCount})`} />
          <KpiCard label={t.metricBusiestWeek} value={`${d.busiestWeek} (${d.busiestWeekCount})`} />
        </div>

        {/* Activity calendar */}
        <Section title={t.calendarTitle} hint={t.calendarHint}>
          <HeatmapGrid daySeries={d.daySeries} t={t} />
        </Section>

        {/* Bar list trio */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Section title={t.monthlyTitle}>
            <BarList items={d.byMonth} color="cyan" />
          </Section>
          <Section title={t.kindsTitle}>
            <BarList items={d.byKind} color="violet" />
          </Section>
          <Section title={t.projectsTitle}>
            <BarList items={d.byProject.slice(0, 8)} color="gold" />
          </Section>
        </div>

        {/* Commit size distribution */}
        <Section title={t.commitSizeTitle} hint={t.commitSizeHint}>
          <CommitStats
            commitStats={d.commitStats}
            commitBuckets={d.commitBuckets}
            monthBoxes={d.monthBoxes}
            commitOutliers={d.commitOutliers}
            t={t}
          />
        </Section>

        {/* Line changes by scope */}
        <Section title={t.techTitle} hint={t.techHint}>
          <TechVolumeTable techVolume={d.techVolume} t={t} />
        </Section>

        {/* Files touched */}
        <Section title={t.filesTouchedTitle}>
          <FilesTouched filesTouched={d.filesTouched} t={t} />
        </Section>

        {/* Work concentration */}
        <Section title={t.concentrationTitle} hint={t.concentrationHint}>
          <ConcentrationBars concentration={d.concentration} t={t} />
        </Section>

        {/* Activity patterns */}
        <Section title={t.activityTitle} hint={t.activityHint}>
          <ActivityPatterns byHour={d.byHour} byDow={d.byDow} t={t} />
        </Section>

        {/* Project evidence table */}
        {d.projects && d.projects.length > 0 && (
          <Section title={t.evidenceTitle} hint={t.evidenceHint}>
            <div className="flex flex-col gap-[3px]">
              {d.projects.map(p => (
                <ProjectCard key={p.name} project={p} t={t} />
              ))}
            </div>
          </Section>
        )}

        {/* AI agent activity */}
        <Section title={t.agentTitle} hint={t.agentHint}>
          <AgentSection agent={d.agentData} t={t} />
        </Section>

        {/* Highlights */}
        {d.highlights && (
          <Section title={t.highlightsTitle} hint={t.highlightsHint}>
            <Highlights highlights={d.highlights} t={t} />
          </Section>
        )}

      </main>
    </div>
  )
}
