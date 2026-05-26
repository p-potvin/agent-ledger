import { useMemo } from 'react';
import type { ProjectSeries } from '../types';

export function TopProjectsVelocity({
  projects,
  onScrollTo,
}: {
  projects: ProjectSeries[];
  onScrollTo?: (project: string) => void;
}) {
  const top5 = useMemo(() => {
    return projects.slice(0, 5);
  }, [projects]);

  const max = Math.max(1, ...top5.map((p) => p.entries || 0));

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3">
        Top Projects (30d)
      </h2>
      <div className="flex flex-col gap-2.5 flex-1 justify-center">
        {top5.map((p, i) => {
          const pct = ((p.entries || 0) / max) * 100;
          return (
            <button
              key={p.project}
              className="flex items-center gap-2 w-full text-left bg-transparent border-0 p-0 cursor-pointer group"
              onClick={() => onScrollTo?.(p.project)}
            >
              <span className="w-24 text-[11px] text-[var(--fg)] truncate flex-shrink-0 group-hover:text-[var(--accent)]" title={p.project}>
                {p.project}
              </span>
              <span className="flex-1 h-2 rounded-full bg-[color-mix(in_srgb,var(--accent)_8%,transparent)] overflow-hidden">
                <span
                  className="block h-full rounded-full bg-[var(--accent)]"
                  style={{
                    width: `${pct}%`,
                    transition: `width 600ms ease-out ${i * 80}ms`,
                    boxShadow: '0 0 6px var(--v-gold-muted)',
                  }}
                />
              </span>
              <span className="w-8 text-right text-[11px] tabular-nums text-[var(--muted)] flex-shrink-0">
                {p.entries || 0}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
