// B-23-17: tiêu đề bảo mật của Cloudflare Pages (public/_headers) phải còn đủ; sửa file thì bài này nhắc đối chiếu.
import { describe, expect, it } from 'vitest';
import text from '../public/_headers?raw';
// Bỏ dòng chú thích để không khớp nhầm chữ trong lời giải thích.
const lines = text
  .split('\n')
  .filter((l) => !l.trim().startsWith('#'))
  .join('\n');

describe('public/_headers (B-23-17)', () => {
  it('bật thật: chống nhúng khung, đoán kiểu tệp, Referrer-Policy, HSTS', () => {
    expect(lines).toContain('X-Frame-Options: DENY');
    expect(lines).toContain('X-Content-Type-Options: nosniff');
    expect(lines).toContain('Referrer-Policy: strict-origin-when-cross-origin');
    expect(lines).toMatch(/Strict-Transport-Security: max-age=\d{7,}/);
  });
  it('CSP có chế độ báo cáo với các nguồn thật: Supabase, Turnstile; chống nhúng khung', () => {
    const csp = lines.split('\n').find((l) => l.includes('Content-Security-Policy-Report-Only'));
    expect(csp).toBeDefined();
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain('https://*.supabase.co');
    expect(csp).toContain('https://challenges.cloudflare.com');
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain("object-src 'none'");
  });
  it('giữ bộ nhớ đệm lâu cho /assets/*', () => {
    expect(lines).toContain('Cache-Control: public, max-age=31536000, immutable');
  });
});
