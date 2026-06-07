import { Card } from '../components/Card';
import { LangToggle } from '../components/LangToggle';
import { useInputTrackerData } from '../useData';
import { I18N, useLangState, type Lang } from '../i18n';
import { IconActivity, IconBarChart, IconClock, IconDatabase, IconPieChart, IconZap } from '../icons';

const fmtInt = (n: number | undefined) =>
  new Intl.NumberFormat().format(Math.trunc(Number.isFinite(n || 0) ? n || 0 : 0));
const fmt1 = (n: number | undefined) =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 }).format(Number.isFinite(n || 0) ? n || 0 : 0);
const fmtPct = (n: number | undefined) =>
  new Intl.NumberFormat(undefined, { style: 'percent', maximumFractionDigits: 1 }).format(Number.isFinite(n || 0) ? n || 0 : 0);

function MetricCard({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <Card className="col-span-3 max-lg:col-span-6 max-md:col-span-12">
      <div className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider">{label}</div>
      <div className="mt-2 text-[28px] leading-tight font-bold text-[var(--fg)]">{value}</div>
      {sub ? <div className="mt-1 text-xs text-[var(--muted)]">{sub}</div> : null}
    </Card>
  );
}

function BarRows({ rows, empty }: { rows?: { name: string; count: number }[]; empty: string }) {
  const max = Math.max(1, ...(rows || []).map((row) => row.count || 0));
  if (!rows || rows.length === 0) {
    return <div className="text-xs text-[var(--muted)] italic">{empty}</div>;
  }
  return (
    <div className="space-y-2">
      {rows.slice(0, 10).map((row) => (
        <div key={row.name} className="grid grid-cols-[minmax(84px,150px)_1fr_60px] items-center gap-2">
          <div className="text-xs text-[var(--fg)] truncate" title={row.name}>{row.name}</div>
          <div className="h-2 rounded-full bg-[color-mix(in_srgb,var(--accent)_8%,transparent)] overflow-hidden">
            <div
              className="h-full rounded-full bg-[var(--accent)]"
              style={{ width: `${Math.max(2, ((row.count || 0) / max) * 100)}%` }}
            />
          </div>
          <div className="text-xs text-right tabular-nums text-[var(--muted)]">{fmtInt(row.count)}</div>
        </div>
      ))}
    </div>
  );
}

function StatusLed({ status }: { status?: string }) {
  const color =
    status === 'online'
      ? 'var(--v-green)'
      : status === 'stale'
        ? 'var(--v-gold)'
        : 'var(--v-burgundy)';
  return (
    <span
      className="inline-block w-2.5 h-2.5 rounded-full"
      style={{ backgroundColor: color, boxShadow: `0 0 14px ${color}` }}
    />
  );
}

function RecentEvents({ events, lang }: { events: NonNullable<ReturnType<typeof useInputTrackerData>['data']>['events']; lang: Lang }) {
  const dict = I18N[lang];
  if (!events || events.length === 0) {
    return <div className="text-xs text-[var(--muted)] italic">{dict.noEvents}</div>;
  }
  return (
    <div className="space-y-2">
      {events.slice(0, 8).map((event) => (
        <div key={event.event_id} className="rounded-lg border border-[var(--border)] bg-[var(--card)] px-3 py-2">
          <div className="flex items-center gap-2 text-xs">
            <IconClock width={13} height={13} className="text-[var(--muted)]" />
            <span className="text-[var(--fg)]">{event.timestamp || '-'}</span>
            <span className="ml-auto text-[var(--muted)]">{event.event_type}</span>
          </div>
          <div className="mt-1 text-[11px] text-[var(--muted)]">
            keys={String(event.metrics?.keystrokes || 0)} clicks={String(event.metrics?.clicks || 0)} focus={String(event.dimensions?.focus_category || 'unknown')}
          </div>
        </div>
      ))}
    </div>
  );
}

export function InputTrackerPage() {
  const { data, loading, error } = useInputTrackerData();
  const [lang, setLang] = useLangState();
  const dict = I18N[lang];
  const input = dict.input;
  const totals = data?.totals || {};
  const derived = data?.derived || {};
  const stale = !data || data.status !== 'online';

  if (loading) {
    return <div className="text-center py-20 text-[var(--muted)]">{dict.errors.loading}</div>;
  }

  return (
    <>
      <div className="flex items-center justify-between flex-wrap gap-3 pb-4 border-b border-[var(--border)] mb-1">
        <div>
          <h1 className="text-xl font-bold m-0 flex items-center gap-2">
            <IconActivity width={18} height={18} className="text-[var(--accent)]" />
            {dict.inputTrackerTitle}
          </h1>
          <p className="m-0 mt-1 text-[var(--muted)] text-[13px]">{dict.inputTrackerSubtitle}</p>
        </div>
        <LangToggle lang={lang} onChangeLang={(value) => setLang(value as Lang)} />
      </div>

      {error ? (
        <Card className="mt-5 border-[color-mix(in_srgb,var(--v-burgundy)_60%,var(--border))]">
          <div className="flex items-center gap-2 text-[var(--v-burgundy)] font-semibold">
            <StatusLed status="unavailable" />
            {dict.errors.failedToLoad}: {error}
          </div>
        </Card>
      ) : null}

      {stale ? (
        <Card className="mt-5">
          <div className="flex items-center gap-2 text-sm">
            <StatusLed status={data?.status} />
            <strong>{input.offline}</strong>
            <span className="text-[var(--muted)]">{data?.message}</span>
          </div>
        </Card>
      ) : null}

      <section className="grid grid-cols-12 gap-3 mt-5">
        <MetricCard label={input.status} value={data?.status || 'unavailable'} sub={data?.source || 'vaultwares-pipelines'} />
        <MetricCard label={input.latest} value={data?.latest_received_at ? new Date(data.latest_received_at).toLocaleTimeString() : '-'} sub={`${data?.window_hours || 24}h window`} />
        <MetricCard label={input.wpm} value={fmt1(derived.wpm)} sub={input.keyBursts} />
        <MetricCard label={input.cpm} value={fmt1(derived.cpm)} sub={`${fmtInt(totals.chars_typed)} chars`} />
        <MetricCard label={input.correction} value={fmtPct(derived.correction_ratio)} sub={`${fmtInt(totals.backspaces)} backspaces`} />
        <MetricCard label={input.clickTravel} value={fmt1(derived.click_to_travel_ratio)} sub={`${fmtInt(totals.clicks)} clicks / ${fmt1(totals.mouse_distance_m)}m`} />
        <MetricCard label="Shortcuts" value={fmtInt(totals.shortcut_count)} sub={`${fmtInt(totals.saves)} saves · ${fmtInt(totals.undo_redo)} undo/redo`} />
        <MetricCard label="Pauses" value={fmtInt(totals.micro_pauses)} sub={`${fmtInt(totals.rest_blocks)} rest blocks`} />
      </section>

      <section className="grid grid-cols-12 gap-3 mt-5">
        <Card className="col-span-4 max-lg:col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3 flex items-center gap-1.5">
            <IconZap width={13} height={13} />
            {input.latency}
          </h2>
          <BarRows rows={data?.key_latency_buckets} empty="No latency samples" />
        </Card>
        <Card className="col-span-4 max-lg:col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3 flex items-center gap-1.5">
            <IconPieChart width={13} height={13} />
            {input.focus}
          </h2>
          <BarRows rows={data?.focus_categories} empty="No focus samples" />
        </Card>
        <Card className="col-span-4 max-lg:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3 flex items-center gap-1.5">
            <IconBarChart width={13} height={13} />
            {input.hotspots}
          </h2>
          <BarRows rows={data?.click_hotspots} empty="No click samples" />
        </Card>
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3">
            {input.mouse}
          </h2>
          <div className="grid grid-cols-3 gap-2">
            <MetricCard label="Clicks" value={fmtInt(totals.clicks)} />
            <MetricCard label="Scroll" value={fmtInt(totals.scroll_ticks)} />
            <MetricCard label="Travel" value={`${fmt1(totals.mouse_distance_m)}m`} />
          </div>
        </Card>
        <Card className="col-span-6 max-md:col-span-12">
          <h2 className="text-[11px] text-[var(--muted)] font-bold uppercase tracking-wider m-0 mb-3 flex items-center gap-1.5">
            <IconDatabase width={13} height={13} />
            {input.cadence}
          </h2>
          <RecentEvents events={data?.events} lang={lang} />
        </Card>
      </section>

      <p className="mt-5 text-xs text-[var(--muted)]">{input.privacy}</p>
    </>
  );
}
