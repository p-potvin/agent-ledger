// ── Header — page masthead with wordmark, title, meta, lang toggle ───────────

import VaultWordmark from './VaultWordmark'
import LedDot from './LedDot'
import type { I18nStrings, Lang } from '../lib/i18n'

interface HeaderProps {
  t: I18nStrings
  lang: Lang
  onToggleLang: () => void
  generatedAt: string
  rangeStart: string
  rangeEnd: string
}

export default function Header({ t, lang, onToggleLang, generatedAt, rangeStart, rangeEnd }: HeaderProps) {
  return (
    <header className="bg-vault-surface border-b border-vault-border px-6 py-4">
      <div className="max-w-[1400px] mx-auto flex flex-col gap-3">
        {/* Top row: wordmark + lang toggle */}
        <div className="flex items-center justify-between gap-4">
          <VaultWordmark height={32} />
          <button
            onClick={onToggleLang}
            className="text-[12px] font-bold uppercase tracking-wide text-vault-gold bg-vault-gold-muted border border-vault-gold-dim hover:bg-vault-gold-dim transition-colors px-3 py-1 rounded-full cursor-pointer"
            aria-label={`Switch language to ${t.langLabel}`}
          >
            {t.langLabel}
          </button>
        </div>

        {/* Title row */}
        <div className="flex items-center gap-3">
          <LedDot variant="cyan" />
          <h1 className="text-[22px] font-bold text-vault-fg leading-none">
            {t.title}
            <span className="text-[14px] font-normal text-vault-muted ml-3">{t.subtitle}</span>
          </h1>
        </div>

        {/* Meta row */}
        <div className="flex flex-wrap gap-x-5 gap-y-1 text-[12px] text-vault-muted">
          <span>
            <span className="text-vault-slate">{t.generated}:</span>{' '}
            <span className="font-mono">{generatedAt}</span>
          </span>
          {rangeStart && rangeEnd && (
            <span>
              <span className="text-vault-slate">{t.range}:</span>{' '}
              <span className="font-mono">{rangeStart}</span>
              {' – '}
              <span className="font-mono">{rangeEnd}</span>
            </span>
          )}
          {lang === 'qc' && (
            <span className="italic opacity-70">{t.intro}</span>
          )}
        </div>
      </div>
    </header>
  )
}
