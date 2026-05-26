import { useMemo } from 'react';
import { Led } from './Led';

const COLORS = [
  'var(--good0)',
  'var(--good1)',
  'var(--good2)',
  'var(--good3)',
  'var(--good4)',
];

export function Activity24({ hourSeries }: { hourSeries: { hour: number; count: number }[] }) {
  const { segments, peak, maxCount } = useMemo(() => {
    const counts = new Array(24).fill(0);
    for (const h of hourSeries) {
      counts[h.hour] = h.count || 0;
    }
    const maxCount = Math.max(1, ...counts);
    let peak = 0;
    for (let i = 0; i < 24; i++) {
      if (counts[i] > counts[peak]) peak = i;
    }

    const sorted = [...counts].filter((c) => c > 0).sort((a, b) => a - b);
    const q = [0.25, 0.5, 0.75].map((p) => {
      const pos = (sorted.length - 1) * p;
      const lo = Math.floor(pos);
      const hi = Math.ceil(pos);
      return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
    });

    const segments = counts.map((c) => {
      let level = 0;
      if (c > 0) {
        if (c <= q[0]) level = 1;
        else if (c <= q[1]) level = 2;
        else if (c <= q[2]) level = 3;
        else level = 4;
      }
      return { count: c, level, ratio: c / maxCount };
    });

    return { segments, peak, maxCount };
  }, [hourSeries]);

  const CX = 60;
  const CY = 60;
  const R_MIN = 20;
  const R_MAX = 52;

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between mb-1">
        <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0">
          24h Activity
        </h2>
        <Led status="sync" size={5} />
      </div>

      <div className="flex-1 flex items-center justify-center relative">
        <svg viewBox="0 0 120 120" className="w-full max-w-[160px]">
          {segments.map((seg, i) => {
            const angle = ((i - 6) / 24) * Math.PI * 2;
            const r = R_MIN + seg.ratio * (R_MAX - R_MIN);
            const x1 = CX + Math.cos(angle) * R_MIN;
            const y1 = CY + Math.sin(angle) * R_MIN;
            const x2 = CX + Math.cos(angle) * r;
            const y2 = CY + Math.sin(angle) * r;

            return (
              <line
                key={i}
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke={COLORS[seg.level]}
                strokeWidth={3.5}
                strokeLinecap="round"
                style={{
                  opacity: 0,
                  animation: `radial-in 600ms ease-out ${i * 25}ms forwards`,
                }}
              />
            );
          })}
          <style>{`@keyframes radial-in { from { opacity:0; } to { opacity:1; } }`}</style>
        </svg>
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="text-center">
            <div className="text-[10px] text-[var(--muted)] uppercase">Peak</div>
            <div className="text-[15px] font-bold tabular-nums text-[var(--fg)]">
              {String(peak).padStart(2, '0')}:00
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
