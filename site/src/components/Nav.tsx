import { NavLink } from 'react-router-dom';
import { Led } from './Led';
import { IconActivity, IconList } from '../icons';
import { IconChevronRight } from '../icons';

export function Nav() {
  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `px-3 py-1.5 rounded-full text-sm font-semibold transition-colors flex items-center gap-1.5 ${
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
          <IconChevronRight width={14} height={14} className="text-[var(--v-gold-dim)]" />
          <h1 className="text-lg font-bold m-0 flex items-center gap-2">
            Agent Ledger
            <Led status="online" size={6} />
          </h1>
        </div>
        <nav className="flex items-center gap-2 ml-auto">
          <NavLink to="/work-impact" className={linkClass}>
            <IconActivity width={14} height={14} />
            Work Impact
          </NavLink>
          <NavLink to="/changes" className={linkClass}>
            <IconList width={14} height={14} />
            Changes
          </NavLink>
        </nav>
      </div>
    </header>
  );
}
