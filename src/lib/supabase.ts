import { GoTrueClient } from '@supabase/auth-js';
import { PostgrestClient } from '@supabase/postgrest-js';
import type { SupabaseClient } from '@supabase/supabase-js';
import { currentRawEnv, readSupabaseConfig, type SupabaseConfigResult } from './env';

let cachedClient: SupabaseClient | null = null;

export function getSupabaseConfig(): SupabaseConfigResult {
  return readSupabaseConfig(currentRawEnv());
}

/**
 * Client mỏng (A10, Chat duyệt 18/11): chỉ có đăng nhập (`auth`) và truy vấn bảng, hàm (`from`, `rpc`, `schema`) như giao diện đang dùng.
 * `createClient` của supabase-js luôn kéo cả realtime, storage, functions (~80 KB thô, ~25 KB nén) mà giao diện không dùng; ở đây dựng trực tiếp
 * từ auth-js và postgrest-js, GIỮ NGUYÊN cách lưu phiên (cùng khoá lưu `sb-<mã dự án>-auth-token`, tự làm mới, đọc phiên từ địa chỉ khi đặt lại mật khẩu)
 * và cách gắn tiêu đề (khoá công khai ở `apikey`; `Authorization` là mã phiên, chưa đăng nhập thì là khoá công khai) như supabase-js.
 * Kiểu trả về vẫn là SupabaseClient để mọi nơi dùng không đổi; gọi tới `storage`, `functions`, `channel` sẽ lỗi (không có trong gói), đã kiểm không nơi nào dùng.
 */
export function buildSlimClient(url: string, publishableKey: string): SupabaseClient {
  const base = new URL(url);
  const auth = new GoTrueClient({
    url: new URL('auth/v1', base).href,
    headers: { Authorization: `Bearer ${publishableKey}`, apikey: publishableKey },
    storageKey: `sb-${base.hostname.split('.')[0]}-auth-token`,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    flowType: 'implicit',
  });
  const authedFetch: typeof fetch = async (input, init) => {
    const { data } = await auth.getSession();
    const headers = new Headers(init?.headers);
    if (!headers.has('apikey')) headers.set('apikey', publishableKey);
    if (!headers.has('Authorization')) {
      headers.set('Authorization', `Bearer ${data.session?.access_token ?? publishableKey}`);
    }
    return fetch(input, { ...init, headers });
  };
  const rest = new PostgrestClient(new URL('rest/v1', base).href, {
    schema: 'public',
    fetch: authedFetch,
  });
  const client = {
    auth,
    from: (relation: string) => rest.from(relation),
    schema: (schema: string) => rest.schema(schema),
    rpc: (fn: string, args?: object, options?: object) => rest.rpc(fn, args, options),
  };
  return client as unknown as SupabaseClient;
}

/** Trả về client Supabase dùng khoá công khai, hoặc null nếu chưa cấu hình đúng. */
export function getSupabase(): SupabaseClient | null {
  const result = getSupabaseConfig();
  if (result.status !== 'ok') return null;
  cachedClient ??= buildSlimClient(result.config.url, result.config.publishableKey);
  return cachedClient;
}
