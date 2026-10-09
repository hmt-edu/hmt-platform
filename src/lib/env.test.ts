import { describe, expect, it } from 'vitest';
import { getAppEnvLabel, isSecretKey, parseAppEnv, readSupabaseConfig } from './env';

function fakeJwt(payload: object): string {
  const encode = (value: object) => btoa(JSON.stringify(value)).replace(/=+$/, '');
  return `${encode({ alg: 'HS256' })}.${encode(payload)}.signature`;
}

describe('getAppEnvLabel', () => {
  it.each([
    ['local', 'Local'],
    ['preview', 'Xem trước'],
    ['staging', 'Thử nghiệm'],
    ['production', 'Chạy thật'],
    [' Staging ', 'Thử nghiệm'],
  ])('%s → %s', (value, label) => {
    expect(getAppEnvLabel(value)).toBe(label);
  });

  it.each([undefined, '', 'prod', 'dev'])('giá trị lạ (%s) → Không rõ', (value) => {
    expect(getAppEnvLabel(value)).toBe('Không rõ');
    expect(parseAppEnv(value)).toBeNull();
  });
});

describe('readSupabaseConfig', () => {
  it('báo thiếu khi chưa có biến', () => {
    expect(readSupabaseConfig({})).toEqual({
      status: 'missing',
      missing: ['VITE_SUPABASE_URL', 'VITE_SUPABASE_PUBLISHABLE_KEY'],
    });
  });

  it('chấp nhận URL và khoá công khai', () => {
    expect(
      readSupabaseConfig({
        VITE_SUPABASE_URL: 'http://127.0.0.1:54321',
        VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_abc',
      }),
    ).toEqual({
      status: 'ok',
      config: { url: 'http://127.0.0.1:54321', publishableKey: 'sb_publishable_abc' },
    });
  });

  it('từ chối URL không hợp lệ', () => {
    const result = readSupabaseConfig({
      VITE_SUPABASE_URL: 'not a url',
      VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_abc',
    });
    expect(result.status).toBe('invalid');
  });

  it('từ chối khoá bí mật', () => {
    for (const key of ['sb_secret_abc', fakeJwt({ role: 'service_role' })]) {
      expect(isSecretKey(key)).toBe(true);
      const result = readSupabaseConfig({
        VITE_SUPABASE_URL: 'https://example.supabase.co',
        VITE_SUPABASE_PUBLISHABLE_KEY: key,
      });
      expect(result.status).toBe('invalid');
    }
  });

  it('khoá anon dạng JWT cũ vẫn hợp lệ', () => {
    expect(isSecretKey(fakeJwt({ role: 'anon' }))).toBe(false);
  });
});
