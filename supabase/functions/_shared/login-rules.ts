// Luật đăng nhập dùng chung (thuần TypeScript, không phụ thuộc Deno để Vitest kiểm được).
// Spec: docs/spec/03 mục "Đăng nhập"; chốt 10/10/2026.

/** Tên miền email nội bộ cho học sinh: không nhận thư, hệ thống không bao giờ gửi thư tới đây. */
export const STUDENT_EMAIL_DOMAIN = 'hocsinh.hoamatoan.edu.vn';

const STUDENT_CODE_PATTERN = /^HS\d+$/;

/** Chuẩn hoá tên đăng nhập: bỏ khoảng trắng; mã HS viết hoa; email viết thường. */
export function normalizeLogin(raw: string): string {
  const value = raw.trim();
  if (STUDENT_CODE_PATTERN.test(value.toUpperCase())) {
    return value.toUpperCase();
  }
  return value.toLowerCase();
}

/** Mã HS → email nội bộ (HS000123 → hs000123@hocsinh.hoamatoan.edu.vn); email giữ nguyên. */
export function toAuthEmail(login: string): string {
  const value = normalizeLogin(login);
  if (STUDENT_CODE_PATTERN.test(value)) {
    return `${value.toLowerCase()}@${STUDENT_EMAIL_DOMAIN}`;
  }
  return value;
}

/** Địa chỉ nội bộ của học sinh: tuyệt đối không gửi thư. */
export function isInternalStudentEmail(email: string): boolean {
  return email.trim().toLowerCase().endsWith(`@${STUDENT_EMAIL_DOMAIN}`);
}

/**
 * Loại thư Auth bị từ chối ở hook gửi thư (R-HT-12, Soát E6): chỉ Admin sửa email người dùng (bằng API quản trị, không cần thư xác nhận).
 * Nhân viên tự đổi email qua Auth sẽ lệch tên đăng nhập, mất khoá tạm theo tài khoản và dấu trong nhật ký đăng nhập.
 */
export function isEmailActionRejected(actionType: string): boolean {
  return actionType === 'email_change' || actionType === 'email_change_current' || actionType === 'email_change_new';
}

/** Độ dài tối đa tên đăng nhập nhận vào (Soát E5): không ghi chuỗi dài vào nhật ký đăng nhập. */
export const MAX_LOGIN_LENGTH = 254; // allow-number: độ dài tối đa một địa chỉ email theo RFC 5321

export interface PasswordPolicy {
  minLength: number;
  requireLetterDigit: boolean;
}

/** Kiểm mật khẩu theo tham số Cài đặt. Trả về câu lỗi tiếng Việt, hoặc null nếu đạt. */
export function checkPassword(password: string, policy: PasswordPolicy): string | null {
  if (password.length < policy.minLength) {
    return `Mật khẩu phải có ít nhất ${policy.minLength} ký tự.`;
  }
  if (policy.requireLetterDigit && !(/\p{L}/u.test(password) && /\d/.test(password))) {
    return 'Mật khẩu phải có cả chữ và số.';
  }
  return null;
}

/**
 * IP thật của người dùng. Ưu tiên cf-connecting-ip (do hạ tầng Supabase/Cloudflare đặt, người dùng
 * không giả được); sau đó phần tử đầu của x-forwarded-for.
 */
export function clientIp(headers: { get(name: string): string | null }): string | null {
  const cf = headers.get('cf-connecting-ip');
  if (cf) return cf.trim();
  const forwarded = headers.get('x-forwarded-for');
  if (forwarded) {
    const first = forwarded.split(',')[0]?.trim();
    if (first) return first;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Câu trả lời khi đăng nhập không được (góp ý 10/10/2026): sai tên, sai mật khẩu, tài khoản không có,
// tài khoản bị khoá đều trả cùng một câu; khoá tạm trả câu riêng nhưng tên không có tài khoản cũng bị
// khoá tạm như tên có (app.login_precheck). Lý do thật chỉ ghi ở app.login_event.
// ---------------------------------------------------------------------------

/** Kết quả ghi vào app.login_event (lý do thật). */
export type LoginRecord = 'THANH_CONG' | 'SAI_MAT_KHAU' | 'TAI_KHOAN_KHOA' | 'KHOA_TAM' | 'LOI';

/** Câu trả lời cho trình duyệt (không lộ tài khoản có tồn tại hay bị khoá không). */
export type LoginOutcome = 'THANH_CONG' | 'SAI' | 'KHOA_TAM' | 'CAPTCHA' | 'QUA_NHIEU' | 'LOI';

export const LOGIN_MESSAGES: Record<Exclude<LoginOutcome, 'THANH_CONG'>, { code: string; message: string }> = {
  SAI: { code: 'HMT_SAI_DANG_NHAP', message: 'Tên đăng nhập hoặc mật khẩu không đúng.' },
  KHOA_TAM: { code: 'HMT_DANG_NHAP_TAM_CHAN', message: 'Đăng nhập tạm thời bị chặn, thử lại sau.' },
  CAPTCHA: { code: 'HMT_CAPTCHA', message: 'Chưa qua bước xác minh chống máy tự động. Tải lại trang rồi thử lại.' },
  QUA_NHIEU: { code: 'HMT_QUA_NHIEU_YEU_CAU', message: 'Quá nhiều lần thử từ máy này. Thử lại sau ít phút.' },
  LOI: { code: 'HMT_LOI_HE_THONG', message: 'Không đăng nhập được lúc này, thử lại sau.' },
};

/** Kết quả gọi Supabase Auth (bỏ qua khi khoá tạm). */
export interface AuthAttempt {
  ok: boolean;
  status: number;
  errorCode: string;
}

const AUTH_FORBIDDEN = 403; // allow-number: mã HTTP hook Supabase trả khi từ chối cấp token
const AUTH_TOO_MANY = 429; // allow-number: mã HTTP Supabase Auth trả khi giới hạn tốc độ

/**
 * Quyết định câu trả lời và lý do ghi nhật ký.
 * precheck: kết quả app.login_precheck ('OK' | 'TAI_KHOAN_KHOA' | 'KHOA_TAM').
 * auth: kết quả gọi Supabase Auth; null khi không gọi (khoá tạm).
 * record null: không ghi (lỗi trước bước kiểm mật khẩu: captcha, giới hạn tốc độ theo IP).
 */
export function decideLogin(precheck: string, auth: AuthAttempt | null): { outcome: LoginOutcome; record: LoginRecord | null } {
  if (precheck === 'KHOA_TAM' || !auth) return { outcome: 'KHOA_TAM', record: 'KHOA_TAM' };
  if (auth.errorCode.startsWith('captcha')) return { outcome: 'CAPTCHA', record: null };
  if (auth.status === AUTH_TOO_MANY) return { outcome: 'QUA_NHIEU', record: null };
  // Tài khoản bị khoá: không bao giờ trả phiên, kể cả khi Auth nhận mật khẩu.
  if (precheck === 'TAI_KHOAN_KHOA') return { outcome: 'SAI', record: 'TAI_KHOAN_KHOA' };
  if (auth.ok) return { outcome: 'THANH_CONG', record: 'THANH_CONG' };
  if (auth.errorCode === 'invalid_credentials') return { outcome: 'SAI', record: 'SAI_MAT_KHAU' };
  // Bị khoá giữa chừng: hook từ chối cấp token, hoặc Auth báo người dùng bị cấm.
  if (auth.status === AUTH_FORBIDDEN || auth.errorCode === 'user_banned') return { outcome: 'SAI', record: 'TAI_KHOAN_KHOA' };
  return { outcome: 'LOI', record: 'LOI' };
}

/**
 * Yêu cầu «hâm nóng» (A9, Chat duyệt 18/11): GET ?ping=1 chỉ để giữ Function không ngủ nên lần đăng nhập thật không gặp khởi động lạnh.
 * Đường này KHÔNG đọc thân yêu cầu, KHÔNG gọi Turnstile, KHÔNG chạm DB, KHÔNG ghi nhật ký, không nhận dữ liệu nào.
 */
export function isWarmPing(method: string, url: string): boolean {
  if (method !== 'GET') return false;
  try {
    return new URL(url).searchParams.get('ping') === '1';
  } catch {
    return false;
  }
}
