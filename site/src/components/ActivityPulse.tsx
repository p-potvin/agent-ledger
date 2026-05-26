import { useMemo } from 'react';
import { Led } from './Led';
import type { DaySeries } from '../types';

const KIND_COLORS: Record<string, { stroke: string; label: string; status: 'online' | 'relay' | 'sync' | 'warning' | 'alert' }> = {
  'code-change': { stroke: 'var(--v-gold)', label: 'Built', status: 'warning' },
  plan: { stroke: 'var(--v-violet)', label: 'Plan', status: 'sync' },
  verification: { stroke: 'var(--v-green)', label: 'Verify', status: 'online' },
  commands: { stroke: 'var(--v-slate)', label: 'Ops', status: 'relay' },
  handoff: { stroke: 'var(--v-burgundy)', label: 'Handoff', status: 'alert' },
  general: { stroke: 'var(--v-muted-color)', label: 'Other', status: 'relay' },
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

export function ActivityPulse({ days }: { days: DaySeries[] }) {
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
          Activity Pulse
        </h2>
        <div className="flex gap-2 flex-wrap">
          {KINDS.map((k) => (
            <span key={k} className="flex items-center gap-1 text-[9px] text-[var(--muted)]">
              <Led status={KIND_COLORS[k].status} size={5} pulse={false} />
              {KIND_COLORS[k].label}
            </span>
          ))}
        </div>
      </div>

      <svg viewBox={`0 0 ${W} ${H}`} className="w-full flex-1" preserveAspectRatio="none">
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

      <div className="flex gap-2 mt-2 justify-between">
        {KINDS.map((k) => (
          <div key={k} className="text-center">
            <div className="text-[13px] font-bold tabular-nums" style={{ color: KIND_COLORS[k].stroke }}>
              {totals[k]}
            </div>
            <div className="text-[8px] text-[var(--muted)] uppercase">{KIND_COLORS[k].label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
