import { createContext, createElement, useContext, useMemo, useState, type ReactNode } from 'react';

export const I18N = {
  en: {
    title: 'Work Impact',
    subtitle: 'A plain-language view of the work recorded in your agent ledger.',
    generated: 'Generated',
    generatedSuffix: '(local time)',
    range: 'Range',
    langLabel: 'Language',
    intro:
      'This report helps non-technical readers understand effort: how often you worked, how widely you spread across projects, and how the pace evolved.',
    metricEvents: 'Work entries',
    metricDays: 'Active days',
    metricProjects: 'Projects touched',
    metricStreak: 'Current streak',
    metricLongestStreak: 'Longest streak',
    metricBusiestDay: 'Busiest day',
    metricBusiestWeek: 'Busiest week',
    metricAvgPerActiveDay: 'Avg entries / active day',
    weekdayRhythmTitle: 'Activity by weekday',
    agentModelsTitle: 'AI model usage',
    agentActorsTitle: 'Distinct actors',
    agentToolsTitle: 'Tools used',
    agentMcpTitle: 'MCP servers',
    agentByDayTitle: 'Agent activity by day',
    calendarTitle: 'Work activity by day',
    calendarHint: 'Hover a square to see that day.',
    less: 'Less',
    more: 'More',
    monthlyTitle: 'Work recorded per month',
    kindsTitle: 'What kind of work',
    projectsTitle: 'Top projects by activity',
    commitSizeTitle: 'Commit size (clean churn lines)',
    commitStatMean: 'Mean',
    commitStatMedian: 'Median',
    commitStatMode: 'Mode',
    commitStatSamples: 'Commits sampled',
    evidenceTitle: 'Activity by project',
    evidenceHint: 'Expand any project to see its recent activity entries.',
    colFirst: 'First',
    colLast: 'Last',
    noCommitData: 'No commit data yet.',
    noSummaries: 'No summaries.',
    labelProjects: 'Projects',
    labelKinds: 'Kinds',
    kindLabels: {
      'code-change': 'Built / changed',
      plan: 'Planning',
      verification: 'Verification',
      commands: 'Operations',
      handoff: 'Handoffs',
      general: 'Other',
    } as Record<string, string>,
    labels: {
      max: 'Max',
    },
    units: {
      days: 'days',
      entries: 'entries',
      commits: 'commits',
      lines: 'lines',
      files: 'files',
    },
    changesTitle: 'Agent Ledger',
    changesSubtitle:
      'Generated from agent-ledger/events. Open a row to see commands, files, and details.',
    noEvents: 'No agent activity has been recorded yet.',
    generalTasks: 'General Tasks',
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

    errors: {
      loading: 'Loading…',
      failedToLoad: 'Failed to load data',
    },

    widgets: {
      commitChurnTitle: 'Commit churn',
      commitChurnUnit: 'lines',
      commitChurnAvg7: '7-day avg',
      commitChurnViewDow: 'By weekday',
      commitChurnViewTimeline: 'Timeline',
      commitChurnHint: 'Hover for exact values.',
      activity24Title: '24h activity',
      activity24Peak: 'Peak',
      activity24Hint: 'Hover a spike to see the hour.',
      activityPulseTitle: 'Activity pulse',
      activityPulseHint: 'Hover the chart to see values for a day.',
    },
  },
  qc: {
    title: 'Impact du travail',
    subtitle:
      'Une vue simple du travail enregistré dans ton agent ledger.',
    generated: 'Généré',
    generatedSuffix: '(heure locale)',
    range: 'Période',
    langLabel: 'Langue',
    intro:
      "Ce rapport aide des gens non-tech à comprendre l’effort : à quelle fréquence tu as travaillé, sur combien de projets, et comment le rythme a évolué.",
    metricEvents: 'Entrées de travail',
    metricDays: 'Jours actifs',
    metricProjects: 'Projets touchés',
    metricStreak: 'Série en cours',
    metricLongestStreak: 'Plus longue série',
    metricBusiestDay: 'Jour le plus actif',
    metricBusiestWeek: 'Semaine la plus active',
    metricAvgPerActiveDay: 'Moyenne entrées / jour actif',
    weekdayRhythmTitle: 'Activité par jour de semaine',
    agentModelsTitle: 'Utilisation des modèles IA',
    agentActorsTitle: 'Acteurs distincts',
    agentToolsTitle: 'Outils utilisés',
    agentMcpTitle: 'Serveurs MCP',
    agentByDayTitle: 'Activité des agents par jour',
    calendarTitle: 'Activité de travail par jour',
    calendarHint: 'Survole un carré pour voir la journée.',
    less: 'Moins',
    more: 'Plus',
    monthlyTitle: 'Travail enregistré par mois',
    kindsTitle: 'Type de travail',
    projectsTitle: 'Projets les plus actifs',
    commitSizeTitle: 'Taille des commits (churn propre)',
    commitStatMean: 'Moyenne',
    commitStatMedian: 'Médiane',
    commitStatMode: 'Mode',
    commitStatSamples: 'Commits mesurés',
    evidenceTitle: 'Activité par projet',
    evidenceHint:
      'Dépliez un projet pour voir ses entrées récentes.',
    colFirst: 'Premier',
    colLast: 'Dernier',
    noCommitData: 'Pas encore de commits.',
    noSummaries: 'Aucun résumé.',
    labelProjects: 'Projets',
    labelKinds: 'Types',
    kindLabels: {
      'code-change': 'Construit / modifié',
      plan: 'Planification',
      verification: 'Vérification',
      commands: 'Opérations',
      handoff: 'Passations',
      general: 'Autre',
    } as Record<string, string>,
    labels: {
      max: 'Max',
    },
    units: {
      days: 'jours',
      entries: 'entrées',
      commits: 'commits',
      lines: 'lignes',
      files: 'fichiers',
    },
    changesTitle: 'Agent Ledger',
    changesSubtitle:
      'Généré depuis agent-ledger/events. Ouvre une ligne pour voir les détails.',
    noEvents: "Aucune activité d’agent n’a été enregistrée.",
    generalTasks: 'Tâches générales',
    changesLabels: {
      kind: 'Type',
      actor: 'Auteur',
      agentHeader: 'Entête agent',
      telemetry: 'Télémétrie',
      flags: 'Indicateurs',
      metrics: 'Métriques',
      summary: 'Résumé',
      commands: 'Commandes',
      files: 'Fichiers',
      plan: 'Plan',
      git: 'Git',
    },

    errors: {
      loading: 'Chargement…',
      failedToLoad: 'Impossible de charger les données',
    },

    widgets: {
      commitChurnTitle: 'Changements dans les commits',
      commitChurnUnit: 'lignes',
      commitChurnAvg7: 'Moyenne 7 jours',
      commitChurnViewDow: 'Par jour de semaine',
      commitChurnViewTimeline: 'Ligne du temps',
      commitChurnHint: 'Survole pour voir les chiffres exacts.',
      activity24Title: 'Activité sur 24h',
      activity24Peak: 'Pic',
      activity24Hint: 'Survole une barre pour voir l’heure.',
      activityPulseTitle: 'Pouls d’activité',
      activityPulseHint: 'Survole le graphe pour voir les valeurs du jour.',
    },
  },
} as const;

export type Lang = keyof typeof I18N;

export function useLang(): [Lang, (l: Lang) => void] {
  const stored =
    typeof localStorage !== 'undefined'
      ? (localStorage.getItem('ledgerLang') as Lang | null)
      : null;
  const browser =
    typeof navigator !== 'undefined' ? navigator.language : 'en';
  const initial: Lang =
    stored && stored in I18N
      ? stored
      : browser.startsWith('fr')
        ? 'qc'
        : 'en';

  const [lang, setLangState] = useState<Lang>(initial);

  const setLang = (l: Lang) => {
    setLangState(l);
    try {
      localStorage.setItem('ledgerLang', l);
    } catch {
      // localStorage unavailable
    }
  };

  return [lang, setLang];
}

type LangContextValue = { lang: Lang; setLang: (l: Lang) => void };

const LangContext = createContext<LangContextValue | null>(null);

export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useLang();
  const value = useMemo(() => ({ lang, setLang }), [lang, setLang]);
  return createElement(LangContext.Provider, { value }, children);
}

export function useLangState(): [Lang, (l: Lang) => void] {
  const ctx = useContext(LangContext);
  if (!ctx) {
    throw new Error('useLangState must be used inside <LangProvider>');
  }
  return [ctx.lang, ctx.setLang];
}
