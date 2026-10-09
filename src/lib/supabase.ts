import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { currentRawEnv, readSupabaseConfig, type SupabaseConfigResult } from './env';

let cachedClient: SupabaseClient | null = null;

export function getSupabaseConfig(): SupabaseConfigResult {
  return readSupabaseConfig(currentRawEnv());
}

/** Trả về client Supabase dùng khoá công khai, hoặc null nếu chưa cấu hình đúng. */
export function getSupabase(): SupabaseClient | null {
  const result = getSupabaseConfig();
  if (result.status !== 'ok') return null;
  cachedClient ??= createClient(result.config.url, result.config.publishableKey);
  return cachedClient;
}
