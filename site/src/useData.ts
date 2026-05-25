import { useState, useEffect } from 'react';
import type { WorkImpactData, ChangesEvent } from './types';

export function useWorkImpactData() {
  const [data, setData] = useState<WorkImpactData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/data/work-impact-data.json')
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((json) => {
        // The JSON is the full state payload; .data holds the dashboard data
        setData(json.data ?? json);
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, []);

  return { data, loading, error };
}

export type AliasMap = Record<string, string[]>;

export function useAliasData() {
  const [aliases, setAliases] = useState<AliasMap>({});

  useEffect(() => {
    fetch('/data/project-aliases.json')
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((json) => setAliases(json ?? {}))
      .catch(() => {
        // Alias data is optional — fail silently
      });
  }, []);

  return aliases;
}

export function useChangesData() {
  const [events, setEvents] = useState<ChangesEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/data/changes-data.json')
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((json) => {
        setEvents(Array.isArray(json) ? json : []);
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, []);

  return { events, loading, error };
}
