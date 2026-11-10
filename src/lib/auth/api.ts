// Gọi Edge Function đăng nhập và các hàm DB liên quan đăng nhập.
import type { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseConfig } from '../supabase';

export type LoginError = { code: string; message: string };

/** Đăng nhập qua Edge Function login (ghi sự kiện, khoá tạm); trả phiên rồi gắn vào client. */
export async function loginWithPassword(
  supabase: SupabaseClient,
  login: string,
  password: string,
  captchaToken: string,
): Promise<LoginError | null> {
  const config = getSupabaseConfig();
  if (config.status !== 'ok')
    return { code: 'HMT_CHUA_CAU_HINH', message: 'Ứng dụng chưa cấu hình kết nối.' };
  let response: Response;
  try {
    response = await fetch(`${config.config.url}/functions/v1/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: config.config.publishableKey },
      body: JSON.stringify({ login, password, captchaToken }),
    });
  } catch {
    return { code: 'HMT_MANG', message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.' };
  }
  const body = (await response.json().catch(() => ({}))) as {
    session?: { access_token: string; refresh_token: string };
    error?: LoginError;
  };
  if (!response.ok || !body.session) {
    return body.error ?? { code: 'HMT_LOI', message: 'Không đăng nhập được, thử lại sau.' };
  }
  const { error } = await supabase.auth.setSession({
    access_token: body.session.access_token,
    refresh_token: body.session.refresh_token,
  });
  return error ? { code: 'HMT_LOI', message: 'Không lưu được phiên đăng nhập.' } : null;
}

/** Đọc tham số Cài đặt dạng số nguyên (giá trị chung). */
export async function readIntSetting(
  supabase: SupabaseClient,
  key: string,
): Promise<number | null> {
  const { data, error } = (await supabase.schema('app').rpc('get_setting_int', { p_key: key })) as {
    data: unknown;
    error: unknown;
  };
  return error || data === null ? null : Number(data);
}

/** Đọc tham số Cài đặt dạng số có phần thập phân (vd hạn mức Ưu đãi linh hoạt, giá trị chung). */
export async function readNumberSetting(
  supabase: SupabaseClient,
  key: string,
): Promise<number | null> {
  const { data, error } = (await supabase
    .schema('app')
    .rpc('get_setting_numeric', { p_key: key })) as { data: unknown; error: unknown };
  return error || data === null ? null : Number(data);
}

export async function readBoolSetting(
  supabase: SupabaseClient,
  key: string,
): Promise<boolean | null> {
  const { data, error } = (await supabase
    .schema('app')
    .rpc('get_setting_bool', { p_key: key })) as {
    data: unknown;
    error: unknown;
  };
  return error || data === null ? null : Boolean(data);
}
