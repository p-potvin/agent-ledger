import { useEffect, useState } from 'react';
import type { ChangeEvent, InputTrackerData, WorkImpactData } from './types';

const API_BASE = (import.meta.env.VITE_PIPELINES_API_BASE || '').replace(/\/$/, '');

async function getJson<T>(paths: string[]): Promise<T> {
  let lastError: unknown;
  for (const path of paths) {
    try {
      const response = await fetch(`${API_BASE}${path}`, { headers: { Accept: 'application/json' } });
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
      return (await response.json()) as T;
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error('request failed');
}

function unwrapWorkImpact(payload: WorkImpactData): WorkImpactData {
  if (payload.data && !payload.series) {
    return { ...payload.data, generatedAtLocal: payload.generatedAtLocal } as WorkImpactData;
  }
  return payload;
}

export function useWorkImpactData() {
  const [data, setData] = useState<WorkImpactData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    let cancelled = false;
    getJson<WorkImpactData>(['/monitor/work-impact', '/data/work-impact-data.json'])
      .then((payload) => {
        if (!cancelled) setData(unwrapWorkImpact(payload));
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || String(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  return { data, loading, error };
}

export function useChangesData() {
  const [events, setEvents] = useState<ChangeEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    let cancelled = false;
    getJson<{ events?: ChangeEvent[] }>(['/monitor/changes', '/data/changes-data.json'])
      .then((payload) => {
        if (!cancelled) setEvents(payload.events || []);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || String(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  return { events, loading, error };
}

export function useInputTrackerData() {
  const [data, setData] = useState<InputTrackerData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    let cancelled = false;
    getJson<InputTrackerData>(['/monitor/input-tracker'])
      .then((payload) => {
        if (!cancelled) setData(payload);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || String(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  return { data, loading, error };
}
