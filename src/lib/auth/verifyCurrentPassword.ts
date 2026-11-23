import { getSupabaseConfig } from '../supabase';

/**
 * Kiểm mật khẩu hiện tại trước khi đổi (S8, RS-23-12, CHUNG-13): đăng nhập thử bằng mật khẩu đó qua Supabase Auth.
 * Gọi thẳng điểm cuối Auth bằng `fetch`, KHÔNG dùng client chính để không đụng phiên đang mở và không lưu phiên.
 * Đăng nhập thử thành công vẫn tạo một phiên bên Supabase: gọi logout phạm vi `local` bằng access_token vừa nhận để huỷ nó.
 * Mật khẩu chỉ nằm trong thân yêu cầu này, không lưu, không ghi log.
 * Kết quả: 'ok' (đúng), 'wrong' (sai mật khẩu), 'error' (không kiểm được: mạng, cấu hình, bị giới hạn lượt, captcha, tài khoản bị cấm...).
 * Chỉ mã lỗi `invalid_credentials` mới là sai mật khẩu; mọi mã khác không được nói là sai mật khẩu.
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
    if (res.ok) {
      await endProbeSession(res, cfg.config.url, cfg.config.publishableKey);
      return 'ok';
    }
    const body = (await res.json().catch(() => null)) as { error_code?: string } | null;
    return body?.error_code === 'invalid_credentials' ? 'wrong' : 'error';
  } catch {
    return 'error';
  }
}

/** Huỷ phiên do đăng nhập thử tạo ra (chỉ phiên đó, scope=local). Lỗi ở đây không ảnh hưởng kết quả kiểm. */
async function endProbeSession(res: Response, baseUrl: string, apikey: string): Promise<void> {
  try {
    const data = (await res.json().catch(() => null)) as { access_token?: string } | null;
    if (!data?.access_token) return;
    const url = new URL('auth/v1/logout?scope=local', baseUrl.replace(/\/?$/, '/'));
    await fetch(url, {
      method: 'POST',
      headers: { apikey, Authorization: `Bearer ${data.access_token}` },
    });
  } catch {
    /* bỏ qua: phiên thử tự hết hạn */
  }
}
