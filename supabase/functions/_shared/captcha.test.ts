import { describe, expect, it, vi } from 'vitest';
import { TURNSTILE_VERIFY_URL, verifyCaptcha } from './captcha.ts';

const reply = (success: boolean) => vi.fn(async () => ({ ok: true, json: async () => ({ success }) }));

describe('Edge Function login tự kiểm mã Turnstile', () => {
  it('mã giả bị Cloudflare từ chối: không cho kiểm mật khẩu', async () => {
    expect(await verifyCaptcha('gia', { secret: 's', ip: '1.2.3.4', fetcher: reply(false) })).toBe('SAI');
  });
  it('mã đúng: qua, gửi kèm IP thật của người dùng', async () => {
    const fetcher = reply(true);
    expect(await verifyCaptcha('ma-that', { secret: 's', ip: '1.2.3.4', fetcher })).toBe('OK');
    const [url, init] = fetcher.mock.calls[0] as unknown as [string, { body: URLSearchParams }];
    expect(url).toBe(TURNSTILE_VERIFY_URL);
    expect(init.body.get('remoteip')).toBe('1.2.3.4');
    expect(init.body.get('response')).toBe('ma-that');
  });
  it('không có mã: từ chối, không gọi Cloudflare', async () => {
    const fetcher = reply(true);
    expect(await verifyCaptcha(undefined, { secret: 's', ip: null, fetcher })).toBe('SAI');
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('chưa cấu hình khoá bí mật: từ chối (không lặng lẽ bỏ qua)', async () => {
    expect(await verifyCaptcha('ma', { secret: '', ip: null, fetcher: reply(true) })).toBe('CHUA_CAU_HINH');
  });
  it('không gọi được Cloudflare: từ chối', async () => {
    const fetcher = vi.fn(async () => {
      throw new Error('mạng lỗi');
    });
    expect(await verifyCaptcha('ma', { secret: 's', ip: null, fetcher })).toBe('LOI');
  });
});
