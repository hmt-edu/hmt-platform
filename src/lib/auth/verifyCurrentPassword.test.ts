import { afterEach, describe, expect, it, vi } from 'vitest';

vi.mock('../supabase', () => ({
  getSupabaseConfig: () => ({
    status: 'ok',
    config: { url: 'https://x.supabase.co', publishableKey: 'sb_publishable_test' },
  }),
}));

import { verifyCurrentPassword } from './verifyCurrentPassword';

function stub(res: Partial<Response> | Error) {
  const fn = vi.fn(() =>
    res instanceof Error ? Promise.reject(res) : Promise.resolve(res as Response),
  );
  vi.stubGlobal('fetch', fn);
  return fn;
}

describe('Đổi mật khẩu hỏi mật khẩu cũ (S8): kiểm mật khẩu hiện tại', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('đúng mật khẩu thì ok, gọi điểm cuối đăng nhập bằng mật khẩu, không dùng phiên', async () => {
    const fn = stub({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ access_token: 'tok' }),
    });
    expect(await verifyCurrentPassword('a@b.vn', 'Mk12345678')).toBe('ok');
    const [url, init] = fn.mock.calls[0] as unknown as [URL, RequestInit];
    expect(String(url)).toBe('https://x.supabase.co/auth/v1/token?grant_type=password');
    expect(init.headers).toEqual({
      'Content-Type': 'application/json',
      apikey: 'sb_publishable_test',
    });
  });

  it('đúng mật khẩu thì huỷ phiên thử bằng logout scope=local với access_token vừa nhận', async () => {
    const fn = stub({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ access_token: 'tok' }),
    });
    await verifyCurrentPassword('a@b.vn', 'Mk12345678');
    const [url, init] = fn.mock.calls[1] as unknown as [URL, RequestInit];
    expect(String(url)).toBe('https://x.supabase.co/auth/v1/logout?scope=local');
    expect(init.headers).toMatchObject({ Authorization: 'Bearer tok' });
  });

  it('sai mật khẩu (invalid_credentials) thì wrong', async () => {
    stub({
      ok: false,
      status: 400,
      json: () => Promise.resolve({ error_code: 'invalid_credentials' }),
    });
    expect(await verifyCurrentPassword('a@b.vn', 'sai')).toBe('wrong');
  });

  it('mã lỗi khác (captcha_failed, bị cấm...) thì error, không nói sai mật khẩu', async () => {
    stub({ ok: false, status: 400, json: () => Promise.resolve({ error_code: 'captcha_failed' }) });
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
    stub({ ok: false, status: 400, json: () => Promise.resolve({ error_code: 'user_banned' }) });
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
  });

  it('bị giới hạn lượt (429) hoặc lỗi mạng thì error, không coi là đúng', async () => {
    stub({ ok: false, status: 429 });
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
    stub(new Error('mạng'));
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
  });
});
