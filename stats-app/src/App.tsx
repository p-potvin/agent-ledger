// ── App — VaultWares Work Impact Stats Dashboard ─────────────────────────────

import { useState } from 'react'
import { getI18n, type Lang } from './lib/i18n'
import type { WorkImpactData } from './lib/types'
import data from './lib/data'

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
  const [lang, setLang] = useState<Lang>(data.lang)
  const t = getI18n(lang)
  const d = data

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