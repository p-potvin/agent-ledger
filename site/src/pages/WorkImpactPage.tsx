import { useMemo, useRef, useState } from 'react';
import { Card } from '../components/Card';
import { LangToggle } from '../components/LangToggle';
import { Led } from '../components/Led';
import { ActivityPulse } from '../components/ActivityPulse';
import { TopProjectsVelocity } from '../components/TopProjectsVelocity';
import { CommitChurnSparkline } from '../components/CommitChurnSparkline';
import { Activity24 } from '../components/Activity24';
import { useWorkImpactData } from '../useData';
import { I18N, useLang, type Lang } from '../i18n';
import { IconCalendar, IconActivity, IconBarChart, IconFolder } from '../icons';
import { IconChevronRight, IconFileText } from '../icons';
import { IconGitCommit } from '../icons';
import type { DaySeries, ProjectSeries } from '../types';

/* ---- helpers ---- */
const fmtInt = (n: number) =>
  Number.isFinite(n) ? new Intl.NumberFormat().format(Math.trunc(n)) : '0';
const fmt1 = (n: number) =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 }).format(n);

function parseLocalDate(s: string | undefined) {
  if (!s) return null;
  const d = new Date(s + 'T00:00:00');
  return Number.isNaN(d.getTime()) ? null : d;
}
function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function addDays(d: Date, n: number) {
  const out = new Date(d);
  out.setDate(out.getDate() + n);
  return out;
}
function quantile(sorted: number[], q: number) {
  if (sorted.length === 0) return 0;
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  return sorted[base + 1] === undefined
    ? sorted[base]
    : sorted[base] + rest * (sorted[base + 1] - sorted[base]);
}

/* ---- sub-components ---- */

function KpiCard({
  label,
  value,
  sub,
  accent,
}: {
  label: string;
  value: string;
  sub?: string;
  accent?: boolean;
}) {
  return (
    <Card className="col-span-3 max-md:col-span-12 max-lg:col-span-6">
      <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-2">
        {label}
      </h2>
      <div
        className={`text-[28px] font-bold leading-tight ${accent ? 'text-[var(--accent)]' : ''}`}
      >
        {value}
      </div>
      {sub && (
        <div className="mt-1 text-xs text-[var(--muted)]">{sub}</div>
      )}
    </Card>
  );
}

function BarRow({
  label,
  count,
  max,
}: {
  label: string;
  count: number;
  max: number;
}) {
  const pct = max ? ((count / max) * 100).toFixed(2) : '0';
  return (
    <div className="flex items-center gap-2.5">
      <label
        className="w-48 text-xs text-[var(--fg)] truncate flex-shrink-0"
        title={label}
      >
        {label}
      </label>
      <div className="flex-1 h-2 rounded-full bg-[color-mix(in_srgb,var(--accent)_8%,transparent)] overflow-hidden min-w-[50px]">
        <div
          className="h-full rounded-full bg-[var(--accent)] transition-[width] duration-300"
          style={{ width: `${pct}%` }}
        />
      </div>
      <div className="w-16 text-right tabular-nums text-[var(--muted)] text-xs flex-shrink-0">
        {fmtInt(count)}
      </div>
    </div>
  );
}

function Heatmap({
  daySeries,
  rangeStart,
  rangeEnd,
  lang,
}: {
  daySeries: DaySeries[];
  rangeStart?: string;
  rangeEnd?: string;
  lang: Lang;
}) {
  const tipRef = useRef<HTMLDivElement>(null);
  const [tip, setTip] = useState<{
    x: number;
    y: number;
    title: string;
    meta: string;
  } | null>(null);

  const { weeks, byDay, levelFn } = useMemo(() => {
    const start = parseLocalDate(rangeStart);
    const end = parseLocalDate(rangeEnd);
    if (!start || !end) return { weeks: 0, byDay: new Map(), levelFn: () => 0 };
    const alignedStart = addDays(start, -start.getDay());
    const daysTotal =
      Math.round((end.getTime() - alignedStart.getTime()) / (24 * 3600 * 1000)) + 1;
    const byDay = new Map(daySeries.map((d) => [d.day, d]));
    const counts = daySeries.map((d) => d.entries || 0);
    const max = Math.max(1, ...counts);
    const levelFn = (c: number) => {
      if (c <= 0) return 0;
      const ratio = Math.log10(c + 1) / Math.log10(max + 1);
      if (ratio < 0.25) return 1;
      if (ratio < 0.50) return 2;
      if (ratio < 0.75) return 3;
      return 4;
    };
    return {
      weeks: Math.ceil(daysTotal / 7),
      byDay,
      levelFn,
      alignedStart,
    };
  }, [daySeries, rangeStart, rangeEnd]);

  const alignedStart = useMemo(() => {
    const start = parseLocalDate(rangeStart);
    return start ? addDays(start, -start.getDay()) : null;
  }, [rangeStart]);

  const lvlColors = [
    'bg-[var(--good0)]',
    'bg-[var(--good1)]',
    'bg-[var(--good2)]',
    'bg-[var(--good3)]',
    'bg-[var(--good4)]',
  ];

  const dict = I18N[lang];

  return (
    <div className="relative">
      <div className="overflow-x-auto" style={{ scrollbarWidth: 'thin' }}>
        <div
          className="grid gap-[3px] p-2 items-start"
          style={{
            gridAutoFlow: 'column',
            gridAutoColumns: '13px',
          }}
        >
          {alignedStart &&
            Array.from({ length: weeks }, (_, w) => (
              <div
                key={w}
                className="grid gap-[3px]"
                style={{ gridTemplateRows: 'repeat(7, 13px)' }}
              >
                {Array.from({ length: 7 }, (_, r) => {
                  const dt = addDays(alignedStart, w * 7 + r);
                  const key = dayKey(dt);
                  const rec = byDay.get(key);
                  const c = rec ? rec.entries || 0 : 0;
                  const lvl = levelFn(c);
                  return (
                    <div
                      key={r}
                      className={`w-[13px] h-[13px] rounded-[3px] cursor-default ${lvlColors[lvl]}`}
                      aria-label={`${key}: ${c}`}
                      onMouseEnter={(ev) => {
                        const projects = rec?.projects || [];
                        const kindsObj = rec?.kinds || {};
                        const kindParts = Object.keys(kindsObj)
                          .sort()
                          .map(
                            (k) =>
                              `${dict.kindLabels[k] || k}: ${fmtInt(kindsObj[k])}`,
                          );
                        setTip({
                          x: ev.clientX + 12,
                          y: ev.clientY + 12,
                          title: `${key} · ${fmtInt(c)} ${dict.units.entries}`,
                          meta:
                            (projects.length
                              ? `${dict.labelProjects}: ${projects.join(', ')}`
                              : '') +
                            (kindParts.length
                              ? '\n' + kindParts.join('\n')
                              : ''),
                        });
                      }}
                      onMouseLeave={() => setTip(null)}
                    />
                  );
                })}
              </div>
            ))}
        </div>
      </div>
      {tip && (
        <div
          ref={tipRef}
          className="fixed z-50 pointer-events-none bg-[var(--v-surface2)] border border-[var(--border)] rounded-xl p-2.5 px-3 max-w-[380px] shadow-[0_16px_48px_rgba(0,0,0,0.45)]"
          style={{ left: tip.x, top: tip.y }}
        >
          <div className="text-xs font-bold text-[var(--fg)]">{tip.title}</div>
          {tip.meta && (
            <div className="text-xs text-[var(--muted)] mt-1.5 whitespace-pre-line">
              {tip.meta}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function ProjectCard({
  p,
  lang,
}: {
  p: ProjectSeries;
  lang: Lang;
}) {
  const [open, setOpen] = useState(false);
  const dict = I18N[lang];
  const kinds = p.kinds || {};
  const recent = (p.recent || []).slice(0, 3);

  return (
    <details
      className="border border-[var(--border)] rounded-lg bg-[var(--card)] mb-2"
      data-project={p.project}
      open={open}
      onToggle={(e) => setOpen((e.target as HTMLDetailsElement).open)}
    >
      <summary className="cursor-pointer px-4 py-3 flex items-center gap-2.5 select-none list-none [&::-webkit-details-marker]:hidden">
        <IconChevronRight
          width={12}
          height={12}
          className={`text-[var(--muted)] transition-transform flex-shrink-0 ${open ? 'rotate-90' : ''}`}
        />
        <span className="flex items-center gap-2 min-w-0">
          <strong className="text-[13px] font-semibold">
            <code>{p.project}</code>
          </strong>
        </span>
        <span className="ml-auto inline-block px-2 py-0.5 rounded-full bg-[var(--chip)] border border-[var(--v-gold-dim)] text-[11px] text-[var(--accent)] font-bold flex-shrink-0">
          {fmtInt(p.entries || 0)}
        </span>
      </summary>
      <div className="px-4 pb-4">
        <div className="flex gap-2 flex-wrap text-[11px] mb-2.5">
          <span className="bg-[var(--chip)] border border-[var(--v-gold-dim)] rounded px-1.5 py-0.5 text-[var(--accent)] font-semibold">
            {dict.colFirst}: {p.firstDay || ''}
          </span>
          <span className="bg-[var(--chip)] border border-[var(--v-gold-dim)] rounded px-1.5 py-0.5 text-[var(--accent)] font-semibold">
            {dict.colLast}: {p.lastDay || ''}
          </span>
          {Object.entries(kinds).map(([k, v]) => (
            <span
              key={k}
              className={`inline-block px-1.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-tight
                ${k === 'code-change' ? 'bg-[color-mix(in_srgb,var(--v-green)_15%,transparent)] text-[var(--v-green)]' : ''}
                ${k === 'plan' ? 'bg-[color-mix(in_srgb,var(--v-violet)_15%,transparent)] text-[var(--v-violet)]' : ''}
                ${k === 'verification' ? 'bg-[color-mix(in_srgb,var(--v-gold)_15%,transparent)] text-[var(--v-gold)]' : ''}
                ${k === 'commands' ? 'bg-[color-mix(in_srgb,var(--v-slate)_20%,transparent)] text-[var(--v-slate)]' : ''}
                ${k === 'handoff' ? 'bg-[color-mix(in_srgb,var(--v-burgundy)_20%,transparent)] text-[var(--v-burgundy)]' : ''}
                ${k === 'general' ? 'bg-[color-mix(in_srgb,var(--v-muted-color)_20%,transparent)] text-[var(--v-muted-color)]' : ''}
              `}
            >
              {dict.kindLabels[k] || k}&nbsp;{v}
            </span>
          ))}
        </div>
        {recent.length > 0 ? (
          <ul className="m-0 pl-4 list-disc">
            {recent.map((s, i) => (
              <li
                key={i}
                className="text-xs text-[var(--fg)] leading-relaxed mb-1 break-words"
              >
                {s}
              </li>
            ))}
          </ul>
        ) : (
          <div className="text-[var(--muted)] text-xs italic">
            {dict.noSummaries}
          </div>
        )}
      </div>
    </details>
  );
}

/* ---- main page ---- */

export function WorkImpactPage() {
  const { data, loading, error } = useWorkImpactData();
  const [lang, setLang] = useLang();
  const dict = I18N[lang];

  const streaks = useMemo(() => {
    if (!data?.series?.days) return { current: 0, longest: 0 };
    const activeDays = new Set(data.series.days.map((d) => d.day));
    if (activeDays.size === 0) return { current: 0, longest: 0 };
    const end = parseLocalDate(data.range?.end) || new Date();
    let cur = 0;
    for (let i = 0; i < 4000; i++) {
      if (activeDays.has(dayKey(addDays(end, -i)))) cur++;
      else break;
    }
    const daysSorted = Array.from(activeDays).sort();
    let longest = 1,
      run = 1;
    for (let i = 1; i < daysSorted.length; i++) {
      const prev = parseLocalDate(daysSorted[i - 1]);
      const now = parseLocalDate(daysSorted[i]);
      if (!prev || !now) continue;
      const diff = Math.round(
        (now.getTime() - prev.getTime()) / (24 * 3600 * 1000),
      );
      if (diff === 1) {
        run++;
        if (run > longest) longest = run;
      } else run = 1;
    }
    return { current: cur, longest };
  }, [data]);

  const busiest = useMemo(() => {
    const daySeries = data?.series?.days || [];
    let bDay: DaySeries | null = null;
    for (const d of daySeries) {
      if (!bDay || (d.entries || 0) > (bDay.entries || 0)) bDay = d;
    }
    const weekCounts = new Map<string, number>();
    for (const d of daySeries) {
      const dt = parseLocalDate(d.day);
      if (!dt) continue;
      const dayOfWeek = (dt.getDay() + 6) % 7;
      const monday = addDays(dt, -dayOfWeek);
      const wk = dayKey(monday);
      weekCounts.set(wk, (weekCounts.get(wk) || 0) + (d.entries || 0));
    }
    let bWeek: { wk: string; count: number } | null = null;
    for (const [wk, count] of weekCounts) {
      if (!bWeek || count > bWeek.count) bWeek = { wk, count };
    }
    return { bDay, bWeek };
  }, [data]);

  if (loading) {
    return (
      <div className="text-center py-20 text-[var(--muted)]">Loading...</div>
    );
  }
  if (error || !data) {
    return (
      <div className="text-center py-20 text-[var(--v-burgundy)]">
        Failed to load data: {error || 'empty'}
      </div>
    );
  }

  const months = (data.series?.months || []).slice(-18);
  const kinds = data.series?.kinds || [];
  const projects = data.series?.projects || [];
  const commitSamples = data.commitSamples || [];
  const mmax = Math.max(1, ...months.map((x) => x.count || 0));
  const kmax = Math.max(1, ...kinds.map((x) => x.count || 0));
  const pmax = Math.max(1, ...projects.slice(0, 12).map((x) => x.entries || 0));

  return (
    <>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3 pb-4 border-b border-[var(--border)] mb-1">
        <div>
          <h1 className="text-xl font-bold m-0">{dict.title}</h1>
          <div className="mt-1 text-[var(--muted)] text-[13px]">
            {dict.subtitle}
            <span className="opacity-50"> &middot; </span>
            <span className="opacity-50">
              {dict.range}: {data.range?.start || ''} &rarr;{' '}
              {data.range?.end || ''}
            </span>
            <span className="opacity-50"> &middot; </span>
            <span className="opacity-50">
              {dict.generated}: {data.generatedAtLocal || ''}
            </span>
          </div>
        </div>
        <LangToggle lang={lang} onChangeLang={(l) => setLang(l as Lang)} />
      </div>

      <p className="text-[13.5px] text-[var(--fg)] opacity-85 leading-relaxed mt-3 mb-0">
        {dict.intro}
      </p>

      {/* KPI row */}
      <section className="grid grid-cols-12 gap-3 mt-5">
        <KpiCard
          label={dict.metricEvents}
          value={fmtInt(data.totals?.events || 0)}
          accent
        />
        <KpiCard
          label={dict.metricDays}
          value={fmtInt(data.totals?.activeDays || 0)}
        />
        <KpiCard
          label={dict.metricProjects}
          value={fmtInt(data.totals?.projects || 0)}
        />
        <KpiCard
          label={dict.metricStreak}
          value={fmtInt(streaks.current)}
          sub={`Max: ${fmtInt(streaks.longest)} ${dict.units.days}`}
        />
        <KpiCard
          label={dict.metricLongestStreak}
          value={fmtInt(streaks.longest)}
        />
        <KpiCard
          label={dict.metricBusiestDay}
          value={busiest.bDay?.day || '-'}
          sub={
            busiest.bDay
              ? `${fmtInt(busiest.bDay.entries || 0)} ${dict.units.entries}`
              : undefined
          }
        />
        <KpiCard
          label={dict.metricBusiestWeek}
          value={busiest.bWeek?.wk || '-'}
          sub={
            busiest.bWeek
              ? `${fmtInt(busiest.bWeek.count)} ${dict.units.entries}`
              : undefined
          }
        />
        <KpiCard
          label={dict.commitStatSamples}
          value={fmtInt(commitSamples.length)}
          sub={`${fmtInt(commitSamples.length)} ${dict.units.commits}`}
        />
      </section>

      {/* Heatmap + chart widgets */}
      <section className="grid grid-cols-12 gap-3 mt-5">
        <Card className="col-span-8 max-md:col-span-12">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-2">
              <IconCalendar width={14} height={14} className="text-[var(--muted)]" />
              <div>
                <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0">
                  {dict.calendarTitle}
                </h2>
                <div className="text-xs text-[var(--muted)]">
                  {dict.calendarHint}
                </div>
              </div>
            </div>
            <div className="flex gap-2 items-center text-[11.5px] text-[var(--muted)]">
              <span>{dict.less}</span>
              <span className="flex gap-[3px] items-center">
                <span className="w-[13px] h-[13px] rounded-[3px] bg-[var(--good0)]" />
                <span className="w-[13px] h-[13px] rounded-[3px] bg-[var(--good1)]" />
                <span className="w-[13px] h-[13px] rounded-[3px] bg-[var(--good2)]" />
                <span className="w-[13px] h-[13px] rounded-[3px] bg-[var(--good3)]" />
                <span className="w-[13px] h-[13px] rounded-[3px] bg-[var(--good4)]" />
              </span>
              <span>{dict.more}</span>
            </div>
          </div>
          <Heatmap
            daySeries={data.series?.days || []}
            rangeStart={data.range?.start}
            rangeEnd={data.range?.end}
            lang={lang}
          />
        </Card>
        <Card className="col-span-4 max-md:col-span-12">
          <ActivityPulse days={data.series?.days || []} />
        </Card>
        <Card className="col-span-4 max-md:col-span-12">
          <TopProjectsVelocity
            projects={projects}
            onScrollTo={(name) => {
              const el = document.querySelector(`[data-project="${name}"]`);
              el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }}
          />
        </Card>
        <Card className="col-span-4 max-md:col-span-12">
          <CommitChurnSparkline samples={commitSamples} />
        </Card>
        <Card className="col-span-4 max-md:col-span-12">
          <Activity24 hourSeries={data.hourSeries || []} />
        </Card>
      </section>

      {/* Monthly + Projects + Kinds */}
      <section className="grid grid-cols-12 gap-3 mt-5">
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-2 flex items-center gap-1.5">
            <IconBarChart width={13} height={13} />
            {dict.monthlyTitle}
          </h2>
          <div className="flex flex-col gap-2">
            {months.map((x) => (
              <BarRow
                key={x.month}
                label={x.month}
                count={x.count || 0}
                max={mmax}
              />
            ))}
          </div>
        </Card>
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-2 flex items-center gap-1.5">
            <IconFolder width={13} height={13} />
            {dict.projectsTitle}
          </h2>
          <div className="flex flex-col gap-2">
            {projects.slice(0, 12).map((x) => (
              <BarRow
                key={x.project}
                label={x.project}
                count={x.entries || 0}
                max={pmax}
              />
            ))}
          </div>
        </Card>
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-2">
            {dict.kindsTitle}
          </h2>
          <div className="flex flex-col gap-2">
            {kinds.map((x) => (
              <BarRow
                key={x.kind}
                label={dict.kindLabels[x.kind] || x.kind}
                count={x.count || 0}
                max={kmax}
              />
            ))}
          </div>
        </Card>
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-2">
            {dict.commitSizeTitle}
          </h2>
          {commitSamples.length === 0 ? (
            <div className="text-[var(--muted)] text-xs italic py-2">
              {dict.noCommitData}
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-2 mt-2">
              {(() => {
                const values = commitSamples.map(
                  (s) => Math.trunc(s.cleanChurnLines || 0),
                );
                const sorted = [...values].sort((a, b) => a - b);
                const mean =
                  sorted.reduce((a, b) => a + b, 0) / sorted.length;
                const median = quantile(sorted, 0.5);
                return (
                  <>
                    <div className="border border-[var(--border)] rounded-lg p-2.5 bg-[var(--card)]">
                      <div className="text-[10px] text-[var(--muted)] font-bold uppercase">
                        {dict.commitStatMean}
                      </div>
                      <div className="text-xl font-bold">
                        {fmt1(mean)}
                        <span className="text-sm font-normal opacity-60">
                          {' '}
                          {dict.units.lines}
                        </span>
                      </div>
                    </div>
                    <div className="border border-[var(--border)] rounded-lg p-2.5 bg-[var(--card)]">
                      <div className="text-[10px] text-[var(--muted)] font-bold uppercase">
                        {dict.commitStatMedian}
                      </div>
                      <div className="text-xl font-bold">
                        {fmt1(median)}
                        <span className="text-sm font-normal opacity-60">
                          {' '}
                          {dict.units.lines}
                        </span>
                      </div>
                    </div>
                    <div className="border border-[var(--border)] rounded-lg p-2.5 bg-[var(--card)]">
                      <div className="text-[10px] text-[var(--muted)] font-bold uppercase">
                        {dict.commitStatSamples}
                      </div>
                      <div className="text-xl font-bold">
                        {fmtInt(commitSamples.length)}
                      </div>
                    </div>
                  </>
                );
              })()}
            </div>
          )}
        </Card>
      </section>

      {/* Project evidence cards */}
      <section className="mt-5">
        <h2 className="text-sm font-bold text-[var(--fg)] m-0 mb-2.5 flex items-center gap-2.5">
          <Led status="relay" size={6} />
          <IconFolder width={14} height={14} className="text-[var(--muted)]" />
          <span>{dict.evidenceTitle}</span>
          <span className="flex-1 h-px bg-[var(--border)]" />
        </h2>
        <p className="text-xs text-[var(--muted)] m-0 mb-2.5">
          {dict.evidenceHint}
        </p>
        {projects.map((p) => (
          <ProjectCard key={p.project} p={p} lang={lang} />
        ))}
      </section>
    </>
  );
}
