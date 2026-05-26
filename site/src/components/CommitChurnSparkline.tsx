import { useMemo } from 'react';
import type { CommitSample } from '../types';

export function CommitChurnSparkline({ samples }: { samples: CommitSample[] }) {
  const { dailyValues, avg7, max } = useMemo(() => {
    const byDay = new Map<string, number>();
    for (const s of samples) {
      const d = s.month ? undefined : undefined;
      const day = s.project ? '' : '';
      const churn = s.cleanChurnLines || 0;
      // Bucket by day from the commit data — use month as a proxy since day isn't always available
      const key = s.month || 'unknown';
      byDay.set(key, (byDay.get(key) || 0) + churn);
    }

    // If we don't have per-day data, aggregate by month
    const entries = Array.from(byDay.entries()).sort(([a], [b]) => a.localeCompare(b)).slice(-30);
    const values = entries.map(([, v]) => v);
    const max = Math.max(1, ...values);

    const last7 = values.slice(-7);
    const avg7 = last7.length > 0 ? Math.round(last7.reduce((a, b) => a + b, 0) / last7.length) : 0;

    return { dailyValues: values, avg7, max };
  }, [samples]);

  const W = 200;
  const H = 60;
  const PAD = 2;

  const points = dailyValues.map((v, i) => {
    const x = PAD + (i / Math.max(1, dailyValues.length - 1)) * (W - 2 * PAD);
    const y = H - PAD - (v / max) * (H - 2 * PAD);
    return `${x},${y}`;
  });

  const pathD = points.length > 1 ? `M${points.join(' L')}` : '';
  const len = dailyValues.length * 12;

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-1">
        Commit Churn
      </h2>
      <div className="flex items-baseline gap-1.5">
        <span className="text-[22px] font-bold tabular-nums text-[var(--fg)]">
          {new Intl.NumberFormat().format(avg7)}
        </span>
        <span className="text-[10px] text-[var(--muted)]">lines/period avg</span>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full flex-1 mt-1" preserveAspectRatio="none">
        {pathD && (
          <path
            d={pathD}
            fill="none"
            stroke="var(--v-gold)"
            strokeWidth={1.5}
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{
              strokeDasharray: len,
              strokeDashoffset: len,
              animation: 'draw-spark 600ms ease-out forwards',
            }}
          />
        )}
        <style>{`@keyframes draw-spark { to { stroke-dashoffset: 0; } }`}</style>
      </svg>
    </div>
  );
}
