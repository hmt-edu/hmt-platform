/** Mã thử của Cloudflare Turnstile, khớp khoá bí mật thử (luôn qua) dùng ở local/CI. */
export const TEST_CAPTCHA_TOKEN = 'XXXX.DUMMY.TOKEN.XXXX';

/** Site key Turnstile thật (thử nghiệm, chạy thật); không đặt thì dùng mã thử. */
export function turnstileSiteKey(): string | null {
  const key = import.meta.env.VITE_TURNSTILE_SITE_KEY?.trim();
  return key ? key : null;
}
