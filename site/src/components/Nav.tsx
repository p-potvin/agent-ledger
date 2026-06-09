import { NavLink } from 'react-router-dom';
import { IconActivity, IconDatabase, IconList } from '../icons';
import { IconChevronRight } from '../icons';
import { I18N, useLangState } from '../i18n';

export function Nav() {
  const [lang] = useLangState();
  const dict = I18N[lang];
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
            {dict.siteTitle}
          </h1>
        </div>
        <nav className="flex items-center gap-2 ml-auto">
          <NavLink to="/work-impact" className={linkClass}>
            <IconActivity width={14} height={14} />
            {dict.title}
          </NavLink>
          <NavLink to="/changes" className={linkClass}>
            <IconList width={14} height={14} />
            {dict.changesTitle}
          </NavLink>
          <NavLink to="/input-tracker" className={linkClass}>
            <IconDatabase width={14} height={14} />
            {dict.inputTrackerNav}
          </NavLink>
        </nav>
      </div>
    </header>
  );
}
