import { useEffect, useState } from 'react';
import type { ChangeEvent, InputTrackerData, WorkImpactData } from './types';

const API_BASE = (import.meta.env.VITE_API_BASE || import.meta.env.VITE_PIPELINES_API_BASE || '').replace(/\/$/, '');

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, { headers: { Accept: 'application/json' } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return (await response.json()) as T;
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
    getJson<WorkImpactData>('/monitor/work-impact')
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
    getJson<{ events?: ChangeEvent[] } | ChangeEvent[]>('/monitor/changes')
      .then((payload) => {
        if (cancelled) return;
        const list = Array.isArray(payload) ? payload : payload.events || [];
        setEvents(list);
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
    getJson<InputTrackerData>('/monitor/input-tracker')
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
