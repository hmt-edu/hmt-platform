// Trả lời HTTP dùng chung cho Edge Function: CORS theo danh sách nguồn được phép, JSON tiếng Việt.
import { isOriginAllowed } from './cors-rules.ts';

function originAllowed(origin: string): boolean {
  return isOriginAllowed(origin, {
    allowedOrigins: (Deno.env.get('HMT_ALLOWED_ORIGINS') ?? '').split(',').map((s) => s.trim()).filter(Boolean),
    allowStagingPreviews: Deno.env.get('HMT_ALLOW_STAGING_PREVIEWS') === 'true',
  });
}

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('origin') ?? '';
  return {
    ...(originAllowed(origin) ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : {}),
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

export function json(req: Request, status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/** Lỗi nghiệp vụ: { code: HMT_*, message: câu tiếng Việt }. */
export function fail(req: Request, status: number, code: string, message: string): Response {
  return json(req, status, { error: { code, message } });
}

/** Khoá secret của project (Supabase cấp sẵn cho Edge Function; ưu tiên khoá sb_secret_ do anh Trường đặt). */
export function secretKey(): string {
  const key = Deno.env.get('HMT_SECRET_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!key) throw new Error('Thiếu khoá secret cho Edge Function.');
  return key;
}

export function publishableKey(): string {
  const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!key) throw new Error('Thiếu publishable key cho Edge Function.');
  return key;
}

/** Mã trạng thái HTTP chuẩn (không phải số nghiệp vụ). */
export const HTTP = {
  OK: 200, // allow-number: mã HTTP chuẩn
  BAD_REQUEST: 400, // allow-number: mã HTTP chuẩn
  UNAUTHORIZED: 401, // allow-number: mã HTTP chuẩn
  FORBIDDEN: 403, // allow-number: mã HTTP chuẩn
  METHOD_NOT_ALLOWED: 405, // allow-number: mã HTTP chuẩn
  TOO_MANY_REQUESTS: 429, // allow-number: mã HTTP chuẩn
  SERVER_ERROR: 500, // allow-number: mã HTTP chuẩn
  BAD_GATEWAY: 502, // allow-number: mã HTTP chuẩn
  UNAVAILABLE: 503, // allow-number: mã HTTP chuẩn
} as const;
