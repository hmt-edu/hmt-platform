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
    const fn = stub({ ok: true, status: 200 });
    expect(await verifyCurrentPassword('a@b.vn', 'Mk12345678')).toBe('ok');
    const [url, init] = fn.mock.calls[0] as unknown as [URL, RequestInit];
    expect(String(url)).toBe('https://x.supabase.co/auth/v1/token?grant_type=password');
    expect(init.headers).toEqual({
      'Content-Type': 'application/json',
      apikey: 'sb_publishable_test',
    });
  });

  it('sai mật khẩu (400) thì wrong', async () => {
    stub({ ok: false, status: 400 });
    expect(await verifyCurrentPassword('a@b.vn', 'sai')).toBe('wrong');
  });

  it('bị giới hạn lượt (429) hoặc lỗi mạng thì error, không coi là đúng', async () => {
    stub({ ok: false, status: 429 });
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
    stub(new Error('mạng'));
    expect(await verifyCurrentPassword('a@b.vn', 'x')).toBe('error');
  });
});
