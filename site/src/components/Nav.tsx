import { NavLink } from 'react-router-dom';

export function Nav() {
  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `px-3 py-1.5 rounded-full text-sm font-semibold transition-colors ${
      isActive
        ? 'bg-[var(--chip)] text-[var(--accent)] border border-[var(--v-gold-dim)]'
        : 'text-[var(--muted)] hover:text-[var(--fg)]'
    }`;

  return (
    <header className="border-b border-[var(--border)] bg-[var(--v-surface)]">
      <div className="max-w-[1140px] mx-auto px-4 py-3 flex items-center gap-4">
        <div className="flex items-center gap-3">
          <img
            src="/vaultwares-logo.svg"
            alt="VaultWares"
            className="h-6 flex-shrink-0"
          />
          <span className="text-[var(--v-gold-dim)] select-none">/</span>
          <h1 className="text-lg font-bold m-0">Agent Ledger</h1>
        </div>
        <nav className="flex items-center gap-2 ml-auto">
          <NavLink to="/work-impact" className={linkClass}>
            Work Impact
          </NavLink>
          <NavLink to="/changes" className={linkClass}>
            Changes
          </NavLink>
        </nav>
      </div>
    </header>
  );
}
