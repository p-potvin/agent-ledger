import { useState } from 'react';

export const I18N = {
  en: {
    title: 'Work Impact',
    subtitle: 'A plain-language view of the work recorded in your agent ledger.',
    generated: 'Generated',
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
  },
  qc: {
    title: 'Impact du travail',
    subtitle:
      'Une vue simple du travail enregistré dans ton agent ledger.',
    generated: 'Généré',
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
