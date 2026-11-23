import { getSupabaseConfig } from '../supabase';

/**
 * Kiểm mật khẩu hiện tại trước khi đổi (S8, RS-23-12, CHUNG-13): đăng nhập thử bằng mật khẩu đó qua Supabase Auth.
 * Gọi thẳng điểm cuối Auth bằng `fetch`, KHÔNG dùng client chính để không tạo phiên mới, không đụng phiên đang mở.
 * Mật khẩu chỉ nằm trong thân yêu cầu này, không lưu, không ghi log.
 * Kết quả: 'ok' (đúng), 'wrong' (sai mật khẩu), 'error' (không kiểm được: mạng, cấu hình, bị giới hạn lượt).
 */
export async function verifyCurrentPassword(
  email: string,
  password: string,
): Promise<'ok' | 'wrong' | 'error'> {
  const cfg = getSupabaseConfig();
  if (cfg.status !== 'ok') return 'error';
  try {
    const url = new URL('auth/v1/token?grant_type=password', cfg.config.url.replace(/\/?$/, '/'));
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: cfg.config.publishableKey },
      body: JSON.stringify({ email, password }),
    });
    if (res.ok) return 'ok';
    if (res.status === 400) return 'wrong'; // allow-number: mã HTTP chuẩn «yêu cầu sai» (invalid_credentials)
    return 'error';
  } catch {
    return 'error';
  }
}
