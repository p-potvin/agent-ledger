import { useMemo, useState } from 'react';
import type { DaySeries } from '../types';
import { I18N, type Lang } from '../i18n';

const KIND_COLORS: Record<string, { stroke: string }> = {
  'code-change': { stroke: 'var(--v-gold)' },
  plan: { stroke: 'var(--v-violet)' },
  verification: { stroke: 'var(--v-green)' },
  commands: { stroke: 'var(--v-slate)' },
  handoff: { stroke: 'var(--v-burgundy)' },
  general: { stroke: 'var(--v-muted-color)' },
};

const KINDS = Object.keys(KIND_COLORS);

function catmullRom(points: [number, number][], tension = 0.5): string {
  if (points.length < 2) return '';
  const d: string[] = [`M${points[0][0]},${points[0][1]}`];
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[Math.max(i - 1, 0)];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[Math.min(i + 2, points.length - 1)];
    const cp1x = p1[0] + (p2[0] - p0[0]) / (6 * tension);
    const cp1y = p1[1] + (p2[1] - p0[1]) / (6 * tension);
    const cp2x = p2[0] - (p3[0] - p1[0]) / (6 * tension);
    const cp2y = p2[1] - (p3[1] - p1[1]) / (6 * tension);
    d.push(`C${cp1x},${cp1y} ${cp2x},${cp2y} ${p2[0]},${p2[1]}`);
  }
  return d.join(' ');
}

type TipState = { x: number; y: number; title: string; meta: string } | null;

function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export function ActivityPulse({ days, lang }: { days: DaySeries[]; lang: Lang }) {
  const dict = I18N[lang];
  const [tip, setTip] = useState<TipState>(null);
  const last60 = useMemo(() => days.slice(-60), [days]);

  const { lines, totals, maxVal } = useMemo(() => {
    const totals: Record<string, number> = {};
    KINDS.forEach((k) => (totals[k] = 0));

    const byKind: Record<string, number[]> = {};
    KINDS.forEach((k) => (byKind[k] = []));

    for (const d of last60) {
      const kinds = d.kinds || {};
      for (const k of KINDS) {
        const v = kinds[k] || 0;
        byKind[k].push(v);
        totals[k] += v;
      }
    }

    let maxVal = 1;
    for (const k of KINDS) {
      for (const v of byKind[k]) {
        if (v > maxVal) maxVal = v;
      }
    }

    return { lines: byKind, totals, maxVal };
  }, [last60]);

  const W = 280;
  const H = 100;
  const PAD = 4;

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between mb-2">
        <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0">
          {dict.widgets.activityPulseTitle}
        </h2>
        <div className="flex gap-2 flex-wrap">
          {KINDS.map((k) => (
            <span key={k} className="flex items-center gap-1 text-[9px] text-[var(--muted)]">
              <span
                className="inline-block w-[10px] h-[10px] rounded-full"
                style={{ backgroundColor: KIND_COLORS[k].stroke, boxShadow: `0 0 10px ${KIND_COLORS[k].stroke}` }}
              />
              {dict.kindLabels[k] || k}
            </span>
          ))}
        </div>
      </div>

      <div className="relative flex-1">
        <svg
          viewBox={`0 0 ${W} ${H}`}
          className="w-full h-full"
          preserveAspectRatio="none"
          onMouseLeave={() => setTip(null)}
          onMouseMove={(e) => {
            const rect = e.currentTarget.getBoundingClientRect();
            const x = clamp(e.clientX - rect.left, 0, rect.width);
            const idx = clamp(
              Math.round((x / rect.width) * (last60.length - 1)),
              0,
              Math.max(0, last60.length - 1),
            );
            const day = last60[idx]?.day || '';
            const kinds = last60[idx]?.kinds || {};

            const parts = KINDS.map((k) => {
              const label = dict.kindLabels[k] || k;
              const v = kinds[k] || 0;
              return `${label}: ${new Intl.NumberFormat().format(v)}`;
            });

            setTip({ x: e.clientX, y: e.clientY, title: day, meta: parts.join(' · ') });
          }}
        >
        {KINDS.map((k) => {
          const pts: [number, number][] = lines[k].map((v, i) => [
            PAD + (i / Math.max(1, lines[k].length - 1)) * (W - 2 * PAD),
            H - PAD - (v / maxVal) * (H - 2 * PAD),
          ]);
          const path = catmullRom(pts);
          if (!path) return null;
          const len = last60.length * 10;
          return (
            <path
              key={k}
              d={path}
              fill="none"
              stroke={KIND_COLORS[k].stroke}
              strokeWidth={1.5}
              strokeLinecap="round"
              style={{
                strokeDasharray: len,
                strokeDashoffset: len,
                animation: `draw-line 800ms ease-out forwards`,
              }}
            />
          );
        })}
        <style>{`@keyframes draw-line { to { stroke-dashoffset: 0; } }`}</style>
      </svg>
        {tip ? (
          <div className="fixed z-50 pointer-events-none" style={{ left: tip.x + 12, top: tip.y + 12 }}>
            <div className="rounded-lg border border-[var(--border)] bg-[var(--card)] px-2.5 py-2 shadow-lg max-w-[380px]">
              <div className="text-[10px] font-bold text-[var(--fg)]">{tip.title}</div>
              <div className="text-[10px] text-[var(--muted)] leading-relaxed">{tip.meta}</div>
            </div>
          </div>
        ) : null}
      </div>

      <div className="text-[10px] text-[var(--muted)] mt-1">{dict.widgets.activityPulseHint}</div>

      <div className="flex gap-2 mt-2 justify-between">
        {KINDS.map((k) => (
          <div key={k} className="text-center">
            <div className="text-[13px] font-bold tabular-nums" style={{ color: KIND_COLORS[k].stroke }}>
              {totals[k]}
            </div>
            <div className="text-[8px] text-[var(--muted)] uppercase">{dict.kindLabels[k] || k}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
