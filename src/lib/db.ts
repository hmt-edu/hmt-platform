// Gọi hàm cơ sở dữ liệu (schema app) và Edge Function; lỗi nghiệp vụ có mã HMT_* và câu tiếng Việt hiện thẳng.
import type { SupabaseClient } from '@supabase/supabase-js';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from './auth/authContext';
import { readIntSetting } from './auth/api';
import { getSupabaseConfig } from './supabase';

export class HmtError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export const FORBIDDEN_CODE = 'HMT_KHONG_CO_QUYEN';
const GENERIC = 'Có lỗi xảy ra, thử lại sau. Nếu vẫn lỗi, báo quản trị viên.';

type DbError = { message: string; hint?: string | null; code?: string };

/** Đổi lỗi Supabase thành HmtError: lỗi nghiệp vụ giữ câu tiếng Việt, lỗi khác dùng câu chung. */
export function toHmtError(error: DbError): HmtError {
  if (error.hint?.startsWith('HMT_')) return new HmtError(error.hint, error.message);
  // 42501: cơ sở dữ liệu từ chối vì thiếu quyền.
  if (error.code === '42501')
    return new HmtError(FORBIDDEN_CODE, 'Bạn không có quyền làm việc này.');
  return new HmtError('HMT_LOI', GENERIC);
}

export async function rpc<T>(
  supabase: SupabaseClient,
  fn: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = (await supabase.schema('app').rpc(fn, args)) as {
    data: unknown;
    error: DbError | null;
  };
  if (error) throw toHmtError(error);
  return data as T;
}

/** Gọi Edge Function bằng phiên của người đang đăng nhập. */
export async function callFunction<T>(
  supabase: SupabaseClient,
  name: string,
  body: Record<string, unknown>,
): Promise<T> {
  const config = getSupabaseConfig();
  const { data } = await supabase.auth.getSession();
  if (config.status !== 'ok' || !data.session) throw new HmtError('HMT_LOI', GENERIC);
  let response: Response;
  try {
    response = await fetch(`${config.config.url}/functions/v1/${name}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: config.config.publishableKey,
        Authorization: `Bearer ${data.session.access_token}`,
      },
      body: JSON.stringify(body),
    });
  } catch {
    throw new HmtError('HMT_MANG', 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
  }
  const payload = (await response.json().catch(() => ({}))) as {
    error?: { code?: string; message?: string };
  };
  if (!response.ok) {
    throw new HmtError(payload.error?.code ?? 'HMT_LOI', payload.error?.message ?? GENERIC);
  }
  return payload as T;
}

/** Client đã đăng nhập; ném lỗi nếu gọi ngoài khung (không xảy ra trong các cổng). */
export function useDb(): SupabaseClient {
  const { supabase } = useAuth();
  if (!supabase) throw new Error('Chưa cấu hình kết nối.');
  return supabase;
}

/** Tham số số nguyên trong Cài đặt (vd list_page_size). Chưa tải xong thì trả null. */
export function useIntSetting(key: string): number | null {
  const supabase = useDb();
  const query = useQuery({
    queryKey: ['setting-int', key],
    queryFn: () => readIntSetting(supabase, key),
    staleTime: Infinity,
  });
  return query.data ?? null;
}

type QueryResult = { data: unknown; error: DbError | null; count?: number | null };

/** Chạy một truy vấn đọc bảng; trả các dòng (đã ép kiểu) và tổng số dòng nếu truy vấn có đếm. */
export async function fetchRows<T>(
  query: PromiseLike<QueryResult>,
): Promise<{ rows: T[]; total: number }> {
  const { data, error, count } = await query;
  if (error) throw toHmtError(error);
  const rows = (Array.isArray(data) ? data : data === null ? [] : [data]) as T[];
  return { rows, total: count ?? rows.length };
}
