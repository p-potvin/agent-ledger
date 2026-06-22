export type KnownKind = 'code-change' | 'plan' | 'verification' | 'commands' | 'handoff' | 'general';

const KNOWN_KINDS = new Set<KnownKind>(['code-change', 'plan', 'verification', 'commands', 'handoff', 'general']);

export function parseKinds(kind?: string): string[] {
  if (!kind) return ['general'];
  return kind
    .split(/[,+|]/)
    .map((part) => part.trim())
    .filter(Boolean);
}

export function isKnownKind(kind: string): kind is KnownKind {
  return KNOWN_KINDS.has(kind as KnownKind);
}

export interface DaySeries {
  day: string;
  entries?: number;
  count?: number;
  projects?: string[];
  kinds?: Record<string, number>;
}

export interface ProjectSeries {
  project: string;
  entries?: number;
  firstDay?: string;
  lastDay?: string;
  kinds?: Record<string, number>;
  recent?: string[];
}

export interface CommitSample {
  day?: string;
  cleanChurnLines?: number;
}

export interface WorkImpactData {
  generatedAtLocal?: string;
  range?: { start?: string; end?: string };
  totals?: { events?: number; activeDays?: number; projects?: number };
  series?: {
    days?: DaySeries[];
    months?: { month: string; count: number }[];
    kinds?: { kind: string; count: number }[];
    projects?: ProjectSeries[];
  };
  commitSamples?: CommitSample[];
  hourSeries?: { hour: number; count: number }[];
  dowSeries?: { label: string; count: number }[];
  agentData?: {
    totalEvents?: number;
    models?: unknown;
    actors?: unknown;
    tools?: unknown;
    mcpServers?: unknown;
    daySeries?: { day: string; count: number }[];
  };
  data?: Partial<WorkImpactData>;
}

export interface ChangeEvent {
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
  git?: { repo?: string; branch?: string; head?: string };
  telemetry?: {
    flags?: Record<string, unknown>;
    metrics?: Record<string, unknown>;
  };
}

export interface InputTrackerData {
  source?: string;
  status?: 'online' | 'stale' | 'unavailable' | 'missing' | string;
  generated_at?: string;
  latest_received_at?: string | null;
  window_hours?: number;
  totals?: Record<string, number>;
  derived?: {
    wpm?: number;
    cpm?: number;
    correction_ratio?: number;
    click_to_travel_ratio?: number;
  };
  kpis?: {
    focus?: Record<string, number | string | null>;
    typing?: Record<string, number | string | null>;
    pointer?: Record<string, number | string | null>;
    rhythm?: Record<string, number | string | null>;
    reliability?: Record<string, number | string | null>;
  };
  key_latency_buckets?: { name: string; count: number }[];
  click_hotspots?: { name: string; count: number }[];
  focus_categories?: { name: string; count: number }[];
  focus_windows?: { name: string; category?: string; count: number }[];
  events?: Array<{
    event_id?: string;
    event_type?: string;
    timestamp?: string;
    metrics?: Record<string, unknown>;
    dimensions?: Record<string, unknown>;
  }>;
  privacy?: {
    raw_text?: boolean;
    clipboard_contents?: boolean;
    window_titles?: string;
  };
  message?: string;
}
