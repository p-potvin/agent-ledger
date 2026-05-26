import { useMemo, useRef, useState } from 'react';
import type { CommitSample } from '../types';
import { I18N, type Lang } from '../i18n';

type TipState = { x: number; y: number; title: string; meta: string } | null;

function parseDay(day: string | undefined) {
  if (!day) return null;
  const d = new Date(`${day}T00:00:00`);
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

function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export function CommitChurnSparkline({ samples, lang }: { samples: CommitSample[]; lang: Lang }) {
  const dict = I18N[lang];
  const tipRef = useRef<HTMLDivElement>(null);
  const [tip, setTip] = useState<TipState>(null);
  const [view, setView] = useState<'dow' | 'timeline'>('dow');

  const { days, dailyTotals, dailyMax, avg7, dow, dowMax, rangeLabel } = useMemo(() => {
    const byDay = new Map<string, number>();
    for (const s of samples) {
      const d = parseDay(s.day);
      if (!d) continue;
      const key = dayKey(d);
      byDay.set(key, (byDay.get(key) || 0) + (s.cleanChurnLines || 0));
    }

    const dayKeys = Array.from(byDay.keys()).sort((a, b) => a.localeCompare(b));
    const lastKey = dayKeys.length ? dayKeys[dayKeys.length - 1] : undefined;
    const last = lastKey ? parseDay(lastKey) : null;
    const end = last || new Date();
    const start = addDays(end, -27);

    const days: string[] = [];
    const totals: number[] = [];
    for (let i = 0; i < 28; i++) {
      const d = addDays(start, i);
      const k = dayKey(d);
      days.push(k);
      totals.push(byDay.get(k) || 0);
    }

    const dailyMax = Math.max(1, ...totals);
    const avg7Slice = totals.slice(-7);
    const avg7 = avg7Slice.length ? Math.round(avg7Slice.reduce((a, b) => a + b, 0) / avg7Slice.length) : 0;

    // Monday..Sunday buckets
    const dowTotals = new Array(7).fill(0);
    for (let i = 0; i < days.length; i++) {
      const d = parseDay(days[i]);
      if (!d) continue;
      // JS: 0=Sun..6=Sat. We want 0=Mon..6=Sun.
      const js = d.getDay();
      const idx = js === 0 ? 6 : js - 1;
      dowTotals[idx] += totals[i];
    }
    const dowMax = Math.max(1, ...dowTotals);

    const rangeLabel = `${days[0]} → ${days.length ? days[days.length - 1] : days[0]}`;
    return { days, dailyTotals: totals, dailyMax, avg7, dow: dowTotals, dowMax, rangeLabel };
  }, [samples]);

  const W = 280;
  const H = 92;
  const PADX = 6;
  const PADY = 8;

  const weekdayLabels = useMemo(() => {
    return lang === 'qc'
      ? ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }, [lang]);

  const bars = useMemo(() => {
    const values = view === 'dow' ? dow : dailyTotals;
    const max = view === 'dow' ? dowMax : dailyMax;
    const count = values.length;
    const innerW = W - PADX * 2;
    const innerH = H - PADY * 2;
    const barW = innerW / Math.max(1, count);
    return values.map((v, i) => {
      const h = (v / max) * innerH;
      const x = PADX + i * barW + Math.max(1, barW * 0.16);
      const w = Math.max(2, barW * 0.68);
      const y = PADY + (innerH - h);
      return { i, v, x, y, w, h };
    });
  }, [dailyMax, dailyTotals, dow, dowMax, view]);

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-1">
        {dict.widgets.commitChurnTitle}
      </h2>
      <div className="flex items-baseline gap-1.5">
        <span className="text-[22px] font-bold tabular-nums text-[var(--fg)]">
          {new Intl.NumberFormat().format(avg7)}
        </span>
        <span className="text-[10px] text-[var(--muted)]">
          {dict.widgets.commitChurnAvg7} ({dict.widgets.commitChurnUnit})
        </span>
      </div>
      <div className="mt-2 flex items-center justify-between gap-2">
        <div className="text-[10px] text-[var(--muted)]">{rangeLabel}</div>
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => setView('dow')}
            className={`px-2 py-1 rounded-md border text-[10px] font-bold uppercase tracking-wider ${
              view === 'dow'
                ? 'border-[color-mix(in_srgb,var(--accent)_45%,transparent)] bg-[var(--chip)] text-[var(--fg)]'
                : 'border-[var(--border)] text-[var(--muted)] hover:text-[var(--fg)]'
            }`}
          >
            {dict.widgets.commitChurnViewDow}
          </button>
          <button
            type="button"
            onClick={() => setView('timeline')}
            className={`px-2 py-1 rounded-md border text-[10px] font-bold uppercase tracking-wider ${
              view === 'timeline'
                ? 'border-[color-mix(in_srgb,var(--accent)_45%,transparent)] bg-[var(--chip)] text-[var(--fg)]'
                : 'border-[var(--border)] text-[var(--muted)] hover:text-[var(--fg)]'
            }`}
          >
            {dict.widgets.commitChurnViewTimeline}
          </button>
        </div>
      </div>

      <div className="relative flex-1 mt-2">
        <svg
          viewBox={`0 0 ${W} ${H}`}
          className="w-full h-full"
          onMouseLeave={() => setTip(null)}
          onMouseMove={(e) => {
            const el = e.currentTarget;
            const rect = el.getBoundingClientRect();
            const x = clamp(e.clientX - rect.left, 0, rect.width);
            const idx = clamp(
              Math.round((x / rect.width) * (bars.length - 1)),
              0,
              bars.length - 1,
            );

            const b = bars[idx];
            const title =
              view === 'dow'
                ? weekdayLabels[idx] || ''
                : days[idx] || '';
            const meta = `${new Intl.NumberFormat().format(b.v)} ${dict.widgets.commitChurnUnit}`;

            setTip({ x: e.clientX, y: e.clientY, title, meta });
          }}
        >
          {bars.map((b) => (
            <rect
              key={b.i}
              x={b.x}
              y={b.y}
              width={b.w}
              height={Math.max(1, b.h)}
              rx={2.5}
              fill="var(--v-gold)"
              opacity={0.9}
            />
          ))}
          {/* x-axis labels */}
          {view === 'dow' ? (
            weekdayLabels.map((label, i) => (
              <text
                key={label}
                x={PADX + (i + 0.5) * ((W - PADX * 2) / 7)}
                y={H - 2}
                textAnchor="middle"
                fontSize={9}
                fill="var(--muted)"
              >
                {label}
              </text>
            ))
          ) : (
            <>
              <text x={PADX} y={H - 2} textAnchor="start" fontSize={9} fill="var(--muted)">
                {days[0]}
              </text>
              <text x={W - PADX} y={H - 2} textAnchor="end" fontSize={9} fill="var(--muted)">
                {days.length ? days[days.length - 1] : ''}
              </text>
            </>
          )}
        </svg>

        <div className="text-[10px] text-[var(--muted)] mt-1">{dict.widgets.commitChurnHint}</div>

        {tip ? (
          <div
            ref={tipRef}
            className="fixed z-50 pointer-events-none"
            style={{ left: tip.x + 12, top: tip.y + 12 }}
          >
            <div className="rounded-lg border border-[var(--border)] bg-[var(--card)] px-2.5 py-2 shadow-lg">
              <div className="text-[10px] font-bold text-[var(--fg)]">{tip.title}</div>
              <div className="text-[10px] text-[var(--muted)]">{tip.meta}</div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
