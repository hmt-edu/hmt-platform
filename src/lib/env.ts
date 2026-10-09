// Đọc và kiểm tra biến môi trường của giao diện.
// Chỉ đọc ba biến công khai; không bao giờ đọc khoá bí mật ở trình duyệt.

export const APP_ENVS = ['local', 'preview', 'staging', 'production'] as const;
export type AppEnv = (typeof APP_ENVS)[number];

const APP_ENV_LABELS: Record<AppEnv, string> = {
  local: 'Local',
  preview: 'Xem trước',
  staging: 'Thử nghiệm',
  production: 'Chạy thật',
};

export const UNKNOWN_ENV_LABEL = 'Không rõ';

export function parseAppEnv(value: string | undefined): AppEnv | null {
  const normalized = value?.trim().toLowerCase();
  return APP_ENVS.find((env) => env === normalized) ?? null;
}

export function getAppEnvLabel(value: string | undefined): string {
  const env = parseAppEnv(value);
  return env ? APP_ENV_LABELS[env] : UNKNOWN_ENV_LABEL;
}

export type RawEnv = {
  VITE_SUPABASE_URL?: string | undefined;
  VITE_SUPABASE_PUBLISHABLE_KEY?: string | undefined;
  VITE_APP_ENV?: string | undefined;
};

export type SupabaseConfig = {
  url: string;
  publishableKey: string;
};

export type SupabaseConfigResult =
  | { status: 'ok'; config: SupabaseConfig }
  | { status: 'missing'; missing: string[] }
  | { status: 'invalid'; reason: string };

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function decodeJwtRole(token: string): string | null {
  const parts = token.split('.');
  const payload = parts.length === 3 ? parts[1] : undefined;
  if (!payload) return null;
  try {
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    const parsed: unknown = JSON.parse(json);
    if (parsed && typeof parsed === 'object' && 'role' in parsed) {
      const role = parsed.role;
      return typeof role === 'string' ? role : null;
    }
    return null;
  } catch {
    return null;
  }
}

/** Khoá bí mật (secret / service_role) không bao giờ được dùng ở trình duyệt. */
export function isSecretKey(key: string): boolean {
  return key.startsWith('sb_secret_') || decodeJwtRole(key) === 'service_role';
}

export function readSupabaseConfig(raw: RawEnv): SupabaseConfigResult {
  const url = raw.VITE_SUPABASE_URL?.trim() ?? '';
  const publishableKey = raw.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ?? '';

  const missing: string[] = [];
  if (!url) missing.push('VITE_SUPABASE_URL');
  if (!publishableKey) missing.push('VITE_SUPABASE_PUBLISHABLE_KEY');
  if (missing.length > 0) return { status: 'missing', missing };

  if (!isHttpUrl(url)) {
    return { status: 'invalid', reason: 'VITE_SUPABASE_URL không phải địa chỉ http(s) hợp lệ' };
  }
  if (isSecretKey(publishableKey)) {
    return {
      status: 'invalid',
      reason: 'VITE_SUPABASE_PUBLISHABLE_KEY đang là khoá bí mật; chỉ dùng khoá công khai',
    };
  }
  return { status: 'ok', config: { url, publishableKey } };
}

/** Biến môi trường hiện tại (đọc lúc gọi để kiểm thử thay được). */
export function currentRawEnv(): RawEnv {
  return {
    VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL,
    VITE_SUPABASE_PUBLISHABLE_KEY: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
    VITE_APP_ENV: import.meta.env.VITE_APP_ENV,
  };
}
