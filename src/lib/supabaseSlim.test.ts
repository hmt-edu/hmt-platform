import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildSlimClient } from './supabase';

const KEY = 'sb_publishable_test_khoa_cong_khai';

describe('client mỏng (A10): giữ cách gắn tiêu đề và khoá lưu phiên của supabase-js', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    window.localStorage.clear();
  });

  it('chưa đăng nhập: truy vấn gửi khoá công khai ở apikey và Authorization, đúng địa chỉ rest/v1', async () => {
    const fetchMock = vi.fn(() =>
      Promise.resolve(
        new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } }),
      ),
    );
    vi.stubGlobal('fetch', fetchMock);
    const client = buildSlimClient('https://abcd.supabase.co', KEY);
    await client.schema('app').from('holiday').select('id');
    const call = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(String(call[0])).toContain('https://abcd.supabase.co/rest/v1/holiday');
    const headers = new Headers(call[1].headers);
    expect(headers.get('apikey')).toBe(KEY);
    expect(headers.get('Authorization')).toBe(`Bearer ${KEY}`);
    expect(headers.get('Accept-Profile')).toBe('app');
  });

  it('rpc gọi đúng hàm, có cả hàm lẫn lược đồ', async () => {
    const fetchMock = vi.fn(() =>
      Promise.resolve(
        new Response('1', { status: 200, headers: { 'content-type': 'application/json' } }),
      ),
    );
    vi.stubGlobal('fetch', fetchMock);
    const client = buildSlimClient('https://abcd.supabase.co', KEY);
    await client.schema('app').rpc('get_setting_int', { p_key: 'x' });
    const call = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(String(call[0])).toBe('https://abcd.supabase.co/rest/v1/rpc/get_setting_int');
    expect(call[1].method).toBe('POST');
  });

  it('có phiên đã lưu (cùng khoá sb-<mã dự án>-auth-token): truy vấn mang mã phiên', async () => {
    const future = Math.floor(Date.now() / 1000) + 3600; // allow-number: một giờ nữa tính bằng giây
    window.localStorage.setItem(
      'sb-abcd-auth-token',
      JSON.stringify({
        access_token: 'tok-phien',
        refresh_token: 'r',
        expires_at: future,
        expires_in: 3600,
        token_type: 'bearer',
        user: { id: 'u1' },
      }),
    );
    const fetchMock = vi.fn(() =>
      Promise.resolve(
        new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } }),
      ),
    );
    vi.stubGlobal('fetch', fetchMock);
    const client = buildSlimClient('https://abcd.supabase.co', KEY);
    await client.from('holiday').select('id');
    const call = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(new Headers(call[1].headers).get('Authorization')).toBe('Bearer tok-phien');
  });

  it('có đủ phần giao diện dùng: auth (đăng nhập, hai bước), from, schema, rpc', () => {
    const client = buildSlimClient('https://abcd.supabase.co', KEY);
    expect(typeof client.auth.getSession).toBe('function');
    expect(typeof client.auth.mfa.enroll).toBe('function');
    expect(typeof client.auth.onAuthStateChange).toBe('function');
    expect(typeof client.from).toBe('function');
    expect(typeof client.schema).toBe('function');
    expect(typeof client.rpc).toBe('function');
  });
});
