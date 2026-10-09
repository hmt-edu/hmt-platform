import { useEffect, useState } from 'react';
import { getSupabase, getSupabaseConfig } from './supabase';

export type SystemInfo = {
  appName: string;
  schemaVersion: string;
  dbTime: string;
};

export type SystemStatus =
  | { state: 'not-configured'; detail: string }
  | { state: 'loading' }
  | { state: 'connected'; info: SystemInfo }
  | { state: 'error'; message: string };

function parseSystemInfo(data: unknown): SystemInfo | null {
  if (!data || typeof data !== 'object') return null;
  const record = data as Record<string, unknown>;
  const { app_name: appName, schema_version: schemaVersion, db_time: dbTime } = record;
  if (typeof appName !== 'string' || typeof schemaVersion !== 'string') return null;
  if (typeof dbTime !== 'string') return null;
  return { appName, schemaVersion, dbTime };
}

function initialStatus(): SystemStatus {
  const config = getSupabaseConfig();
  if (config.status === 'missing') {
    return { state: 'not-configured', detail: `Thiếu ${config.missing.join(', ')}` };
  }
  if (config.status === 'invalid') {
    return { state: 'not-configured', detail: config.reason };
  }
  return { state: 'loading' };
}

/** Gọi public.system_status() để kiểm tra kết nối cơ sở dữ liệu. */
export function useSystemStatus(): SystemStatus {
  const [status, setStatus] = useState<SystemStatus>(initialStatus);

  useEffect(() => {
    const client = getSupabase();
    if (!client) return;
    let cancelled = false;

    async function load(rpcClient: NonNullable<typeof client>) {
      try {
        const response = await rpcClient.rpc('system_status');
        if (cancelled) return;
        if (response.error) {
          setStatus({ state: 'error', message: response.error.message });
          return;
        }
        const data: unknown = response.data;
        const info = parseSystemInfo(data);
        setStatus(
          info
            ? { state: 'connected', info }
            : { state: 'error', message: 'Dữ liệu trả về không đúng định dạng' },
        );
      } catch (err: unknown) {
        if (cancelled) return;
        setStatus({ state: 'error', message: err instanceof Error ? err.message : String(err) });
      }
    }

    void load(client);
    return () => {
      cancelled = true;
    };
  }, []);

  return status;
}
