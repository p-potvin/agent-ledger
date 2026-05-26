export const VW_KIND_ENUM = ['plan','commands','code-change','verification','handoff','general'] as const;
export type Kind = typeof VW_KIND_ENUM[number];

export function parseKinds(value: string | undefined): string[] {
  if (!value) return ['general'];
  const parts = value.split(',').map(s => s.trim()).filter(Boolean);
  return parts.length ? parts : ['general'];
}

export function isKnownKind(k: string): k is Kind {
  return (VW_KIND_ENUM as readonly string[]).includes(k);
}

/** Shape of work-impact-data.json (matches work-impact.state.json .data) */
export interface WorkImpactData {
  generatedAtLocal?: string;
  range?: { start: string; end: string };
  totals?: {
    events: number;
    activeDays: number;
    projects: number;
  };
  series?: {
    days: DaySeries[];
    months: { month: string; count: number }[];
    kinds: { kind: string; count: number }[];
    projects: ProjectSeries[];
  };
  commitSamples?: CommitSample[];
  lineStats?: {
    raw: LineStat;
    clean: LineStat;
    excluded: LineStat;
  };
  hourSeries?: { hour: number; count: number }[];
  dowSeries?: { label: string; count: number }[];
  agentData?: AgentData;
}

export interface DaySeries {
  day: string;
  entries: number;
  projects?: string[];
  kinds?: Record<string, number>;
}

export interface ProjectSeries {
  project: string;
  entries: number;
  firstDay?: string;
  lastDay?: string;
  kinds?: Record<string, number>;
  recent?: string[];
}

export interface CommitSample {
  project?: string;
  commit?: string;
  month?: string;
  cleanChurnLines?: number;
  filesTouched?: number;
  filesClean?: number;
}

export interface LineStat {
  insertions: number;
  deletions: number;
  files: number;
}

export interface AgentData {
  totalEvents: number;
  actors?: [string, number][];
  models?: [string, number][];
  tools?: [string, number][];
  mcpServers?: [string, number][];
  daySeries?: { day: string; count: number; actors?: string[] }[];
}

/** Shape of changes-data.json */
export interface ChangesEvent {
  createdAt?: string;
  createdAtLocal?: string;
  project?: string;
  kind?: string;
  summary?: string;
  actor?: string;
  agentHeader?: string;
  commands?: string[];
  files?: string[];
  planPath?: string;
  git?: {
    repo?: string;
    branch?: string;
    head?: string;
  };
  telemetry?: {
    flags?: Record<string, unknown>;
    metrics?: Record<string, unknown>;
  };
}
