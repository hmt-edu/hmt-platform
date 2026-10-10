// Kiểm mã Turnstile (chống máy tự động) ngay trong Edge Function login (thuần TypeScript, fetch truyền vào
// để Vitest kiểm được).
// Vì sao không để Supabase Auth kiểm: Edge Function gọi Supabase Auth bằng khoá secret (để chuyển IP thật),
// mà Supabase Auth bỏ qua Turnstile với lời gọi bằng khoá secret. Phát hiện trên thử nghiệm 10/10/2026.

export const TURNSTILE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

/** OK: qua. SAI: mã thiếu, sai, hết hạn, đã dùng. CHUA_CAU_HINH: thiếu khoá bí mật (từ chối, không bỏ qua). LOI: không gọi được Cloudflare. */
export type CaptchaResult = 'OK' | 'SAI' | 'CHUA_CAU_HINH' | 'LOI';

type Fetcher = (url: string, init: { method: string; body: URLSearchParams }) => Promise<{ ok: boolean; json(): Promise<unknown> }>;

export async function verifyCaptcha(
  token: string | undefined,
  options: { secret: string | undefined; ip: string | null; fetcher: Fetcher },
): Promise<CaptchaResult> {
  // Luật: chưa cấu hình khoá thì từ chối đăng nhập (không lặng lẽ bỏ qua bước chống máy).
  if (!options.secret) return 'CHUA_CAU_HINH';
  // Luật: không có mã thì từ chối, không cần hỏi Cloudflare.
  if (!token) return 'SAI';
  const body = new URLSearchParams({ secret: options.secret, response: token });
  if (options.ip) body.set('remoteip', options.ip);
  try {
    const response = await options.fetcher(TURNSTILE_VERIFY_URL, { method: 'POST', body });
    if (!response.ok) return 'LOI';
    const result = (await response.json()) as { success?: unknown };
    return result.success === true ? 'OK' : 'SAI';
  } catch {
    return 'LOI';
  }
}
