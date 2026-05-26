interface LangToggleProps {
  lang: string;
  onChangeLang: (lang: string) => void;
}

export function LangToggle({ lang, onChangeLang }: LangToggleProps) {
  return (
    <div className="flex items-center gap-2 flex-shrink-0">
      <span className="text-[var(--muted)] text-xs">Language</span>
      <div className="inline-flex border border-[var(--border)] rounded-full overflow-hidden">
        <button
          onClick={() => onChangeLang('en')}
          aria-pressed={lang === 'en'}
          className={`appearance-none border-0 px-3 py-1.5 cursor-pointer text-xs font-semibold transition-colors ${
            lang === 'en'
              ? 'bg-[var(--chip)] text-[var(--accent)]'
              : 'bg-transparent text-[var(--fg)]'
          }`}
        >
          EN
        </button>
        <button
          onClick={() => onChangeLang('qc')}
          aria-pressed={lang === 'qc'}
          className={`appearance-none border-0 px-3 py-1.5 cursor-pointer text-xs font-semibold transition-colors ${
            lang === 'qc'
              ? 'bg-[var(--chip)] text-[var(--accent)]'
              : 'bg-transparent text-[var(--fg)]'
          }`}
        >
          QC
        </button>
      </div>
    </div>
  );
}
