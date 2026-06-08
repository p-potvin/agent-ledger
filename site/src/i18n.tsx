import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';

export type Lang = 'en' | 'qc';

const base = {
  title: 'Work Impact',
  subtitle: 'Agent-ledger activity through vaultwares-api',
  intro: 'A compact operational view of recorded agent work, command evidence, verification, and project activity.',
  changesTitle: 'Agent Ledger',
  changesSubtitle: 'Recent ledger entries served from the vaultwares-api database.',
  inputTrackerTitle: 'Input Tracker',
  inputTrackerSubtitle: 'Privacy-safe local input telemetry, batched through vaultwares-pipelines.',
  inputTrackerNav: 'Input',
  range: 'Range',
  generated: 'Generated',
  generatedSuffix: '',
  calendarTitle: 'Activity calendar',
  calendarHint: 'Daily ledger entry density',
  less: 'Less',
  more: 'More',
  labelProjects: 'Projects',
  colFirst: 'First',
  colLast: 'Last',
  noSummaries: 'No summaries',
  monthlyTitle: 'Monthly activity',
  projectsTitle: 'Projects',
  kindsTitle: 'Kinds',
  commitSizeTitle: 'Commit size',
  noCommitData: 'No commit data',
  commitStatMean: 'Mean',
  commitStatMedian: 'Median',
  commitStatSamples: 'Samples',
  metricEvents: 'Events',
  metricDays: 'Active days',
  metricProjects: 'Projects',
  metricStreak: 'Current streak',
  metricLongestStreak: 'Longest streak',
  metricBusiestDay: 'Busiest day',
  metricBusiestWeek: 'Busiest week',
  metricAvgPerActiveDay: 'Avg per active day',
  weekdayRhythmTitle: 'Weekday rhythm',
  agentModelsTitle: 'Models',
  agentActorsTitle: 'Actors',
  agentToolsTitle: 'Tools',
  agentMcpTitle: 'MCP servers',
  agentByDayTitle: 'Agent activity by day',
  evidenceTitle: 'Project evidence',
  evidenceHint: 'Expandable summaries from ledger events.',
  generalTasks: 'General Tasks',
  noEvents: 'No events',
  labels: { max: 'Max' },
  units: { entries: 'entries', days: 'days', lines: 'lines' },
  errors: { loading: 'Loading...', failedToLoad: 'Failed to load' },
  kindLabels: {
    'code-change': 'Code',
    plan: 'Plan',
    verification: 'Verify',
    commands: 'Commands',
    handoff: 'Handoff',
    general: 'General',
  } as Record<string, string>,
  changesLabels: {
    kind: 'Kind',
    actor: 'Actor',
    agentHeader: 'Agent header',
    telemetry: 'Telemetry',
    flags: 'Flags',
    metrics: 'Metrics',
    summary: 'Summary',
    commands: 'Commands',
    files: 'Files',
    plan: 'Plan',
    git: 'Git',
  },
  widgets: {
    activityPulseTitle: 'Activity pulse',
    activityPulseHint: 'Last 60 days by kind',
    activity24Title: '24h rhythm',
    activity24Peak: 'Peak',
    activity24Hint: 'Hourly activity distribution',
    commitChurnTitle: 'Commit churn',
    commitChurnAvg7: '7-day avg',
    commitChurnUnit: 'lines',
    commitChurnViewDow: 'DOW',
    commitChurnViewTimeline: 'Timeline',
    commitChurnHint: 'Clean churn samples',
  },
  input: {
    status: 'Status',
    latest: 'Latest receipt',
    wpm: 'WPM',
    cpm: 'CPM',
    correction: 'Correction ratio',
    clickTravel: 'Click/travel',
    keyBursts: 'Typing bursts',
    mouse: 'Pointer activity',
    focus: 'Focus categories',
    latency: 'Key latency buckets',
    hotspots: 'Click hotspots',
    cadence: 'Command cadence',
    offline: 'Tracker is stale or offline',
    privacy: 'Privacy defaults: no raw text, no clipboard contents, redacted or hashed window titles.',
  },
};

export const I18N = {
  en: base,
  qc: {
    ...base,
    title: 'Impact du travail',
    subtitle: 'Activite agent-ledger via vaultwares-api',
    changesTitle: 'Registre Agent',
    changesSubtitle: 'Entrees recentes servies par la base vaultwares-api.',
    inputTrackerTitle: 'Traceur Input',
    inputTrackerSubtitle: 'Telemetrie locale privee, envoyee par lots a vaultwares-pipelines.',
    inputTrackerNav: 'Input',
    generated: 'Genere',
    noEvents: 'Aucun evenement',
    errors: { loading: 'Chargement...', failedToLoad: 'Chargement echoue' },
    labels: { max: 'Max' },
    input: {
      ...base.input,
      status: 'Etat',
      latest: 'Derniere reception',
      correction: 'Ratio corrections',
      focus: 'Categories de focus',
      offline: 'Traceur stale ou hors ligne',
    },
  },
};

const LangContext = createContext<[Lang, (lang: Lang) => void] | null>(null);

export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>('en');
  const value = useMemo<[Lang, (lang: Lang) => void]>(() => [lang, setLang], [lang]);
  return <LangContext.Provider value={value}>{children}</LangContext.Provider>;
}

export function useLangState() {
  const value = useContext(LangContext);
  if (!value) return ['en', () => undefined] as [Lang, (lang: Lang) => void];
  return value;
}
