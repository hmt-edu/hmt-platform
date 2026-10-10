// Edge Function đăng nhập (chốt 10/10/2026): nhận email hoặc mã HS + mật khẩu + mã Turnstile,
// kiểm khoá/khoá tạm, gọi Supabase Auth (chuyển IP thật qua Sb-Forwarded-For để giới hạn tốc độ
// theo IP vẫn đúng), ghi sự kiện đăng nhập, trả phiên về trình duyệt.
// Sai tên, sai mật khẩu, tài khoản không có, bị khoá: cùng một câu trả lời (decideLogin); lý do thật
// chỉ ghi ở app.login_event.
// KHÔNG BAO GIỜ in mật khẩu hay nội dung yêu cầu ra log.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { corsHeaders, fail, HTTP, json, secretKey } from '../_shared/http.ts';
import { type AuthAttempt, clientIp, decideLogin, LOGIN_MESSAGES, type LoginRecord, toAuthEmail } from '../_shared/login-rules.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';

const OUTCOME_STATUS = {
  SAI: HTTP.UNAUTHORIZED,
  KHOA_TAM: HTTP.TOO_MANY_REQUESTS,
  CAPTCHA: HTTP.BAD_REQUEST,
  QUA_NHIEU: HTTP.TOO_MANY_REQUESTS,
  LOI: HTTP.BAD_GATEWAY,
} as const;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, HTTP.METHOD_NOT_ALLOWED, 'HMT_SAI_PHUONG_THUC', 'Chỉ nhận POST.');

  let body: { login?: unknown; password?: unknown; captchaToken?: unknown };
  try {
    body = await req.json();
  } catch {
    return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
  }
  const login = typeof body.login === 'string' ? body.login : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const captchaToken = typeof body.captchaToken === 'string' ? body.captchaToken : undefined;
  if (!login.trim() || !password) {
    return fail(req, HTTP.BAD_REQUEST, 'HMT_THIEU_THONG_TIN', 'Nhập tên đăng nhập và mật khẩu.');
  }

  const email = toAuthEmail(login);
  const ip = clientIp(req.headers);
  const userAgent = req.headers.get('user-agent') ?? '';
  const key = secretKey();
  const db = createClient(SUPABASE_URL, key, { db: { schema: 'app' }, auth: { persistSession: false } });
  const record = (result: LoginRecord) =>
    db.rpc('login_record', { p_login_name: email, p_result: result, p_ip: ip ?? '', p_user_agent: userAgent });

  const { data: precheck, error: preError } = await db.rpc('login_precheck', { p_login_name: email });
  if (preError) {
    console.error('login_precheck lỗi', preError.code);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI_HE_THONG', 'Hệ thống đang lỗi, thử lại sau.');
  }

  // Luật: đang khoá tạm thì không gọi Supabase Auth. Tài khoản bị khoá vẫn gọi (để thời gian trả lời
  // giống người sai mật khẩu), nhưng không bao giờ trả phiên.
  let auth: AuthAttempt | null = null;
  let session: Record<string, unknown> = {};
  if (precheck !== 'KHOA_TAM') {
    // Sb-Forwarded-For chỉ được nhận khi gọi bằng khoá sb_secret_.
    const headers: Record<string, string> = { apikey: key, 'Content-Type': 'application/json' };
    if (ip && key.startsWith('sb_secret_')) headers['Sb-Forwarded-For'] = ip;
    const authResponse = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ email, password, gotrue_meta_security: { captcha_token: captchaToken } }),
    });
    session = (await authResponse.json().catch(() => ({}))) as Record<string, unknown>;
    auth = {
      ok: authResponse.ok,
      status: authResponse.status,
      errorCode: authResponse.ok ? '' : String(session.error_code ?? session.code ?? ''),
    };
  }

  const { outcome, record: reason } = decideLogin(String(precheck), auth);
  if (reason) await record(reason);
  if (outcome === 'THANH_CONG') return json(req, HTTP.OK, { session });
  if (outcome === 'LOI') console.error('Supabase Auth trả lỗi', auth?.status, auth?.errorCode);
  const { code, message } = LOGIN_MESSAGES[outcome];
  return fail(req, OUTCOME_STATUS[outcome], code, message);
});
