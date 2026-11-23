import { describe, expect, it } from 'vitest';
import {
  checkPassword,
  clientIp,
  decideLogin,
  isEmailActionRejected,
  isInternalStudentEmail,
  MAX_LOGIN_LENGTH,
  isWarmPing,
  LOGIN_MESSAGES,
  normalizeLogin,
  toAuthEmail,
} from './login-rules.ts';

const policy = { minLength: 8, requireLetterDigit: true };

describe('đăng nhập bằng mã học sinh', () => {
  it('mã HS (viết thường, có khoảng trắng) đổi thành email nội bộ', () => {
    expect(toAuthEmail(' hs000123 ')).toBe('hs000123@hocsinh.hoamatoan.edu.vn');
  });
  it('email nhân viên giữ nguyên, viết thường', () => {
    expect(toAuthEmail('Sale.CS5@Example.com')).toBe('sale.cs5@example.com');
    expect(normalizeLogin('HS000123')).toBe('HS000123');
  });
  it('nhận ra địa chỉ nội bộ của học sinh để không gửi thư', () => {
    expect(isInternalStudentEmail('HS000123@HOCSINH.hoamatoan.edu.vn')).toBe(true);
    expect(isInternalStudentEmail('phuhuynh@example.com')).toBe(false);
    expect(isInternalStudentEmail('x@hocsinh.hoamatoan.edu.vn.evil.com')).toBe(false);
  });
});

describe('đăng nhập bằng mã phụ huynh (QT-17, CHUNG-23)', () => {
  it('mã PH (viết thường, có khoảng trắng) đổi thành email nội bộ riêng của phụ huynh', () => {
    expect(toAuthEmail(' ph000212 ')).toBe('ph000212@phuhuynh.hoamatoan.edu.vn');
    expect(normalizeLogin('ph000212')).toBe('PH000212');
  });
  it('địa chỉ nội bộ của phụ huynh cũng không gửi thư', () => {
    expect(isInternalStudentEmail('ph000212@phuhuynh.hoamatoan.edu.vn')).toBe(true);
    expect(isInternalStudentEmail('x@phuhuynh.hoamatoan.edu.vn.evil.com')).toBe(false);
  });
  it('email thường bắt đầu bằng ph nhưng không phải mã PH thì giữ nguyên', () => {
    expect(toAuthEmail('Phong@Example.com')).toBe('phong@example.com');
  });
});

describe('chính sách mật khẩu (tham số Cài đặt)', () => {
  it('đủ 8 ký tự, có chữ và số: đạt; không bắt chữ hoa', () => {
    expect(checkPassword('abcdef12', policy)).toBeNull();
  });
  it('ngắn hơn tối thiểu: bị chặn', () => {
    expect(checkPassword('abc12', policy)).toMatch(/ít nhất 8/);
  });
  it('thiếu số hoặc thiếu chữ: bị chặn', () => {
    expect(checkPassword('abcdefgh', policy)).toMatch(/chữ và số/);
    expect(checkPassword('12345678', policy)).toMatch(/chữ và số/);
  });
  it('chữ có dấu tiếng Việt vẫn tính là chữ', () => {
    expect(checkPassword('đườngđi9', policy)).toBeNull();
  });
});

describe('IP thật của người dùng', () => {
  const h = (m: Record<string, string>) => ({ get: (k: string) => m[k] ?? null });
  it('ưu tiên cf-connecting-ip', () => {
    expect(clientIp(h({ 'cf-connecting-ip': '1.2.3.4', 'x-forwarded-for': '9.9.9.9' }))).toBe('1.2.3.4');
  });
  it('không có thì lấy phần tử đầu x-forwarded-for', () => {
    expect(clientIp(h({ 'x-forwarded-for': '5.6.7.8, 10.0.0.1' }))).toBe('5.6.7.8');
  });
  it('không có gì: null', () => {
    expect(clientIp(h({}))).toBeNull();
  });
});

describe('đăng nhập không được: không lộ tài khoản có tồn tại hay bị khoá', () => {
  const wrong = { ok: false, status: 400, errorCode: 'invalid_credentials' };
  const okAuth = { ok: true, status: 200, errorCode: '' };

  it('sai mật khẩu và tài khoản không có: cùng câu "Tên đăng nhập hoặc mật khẩu không đúng"', () => {
    // Tài khoản không có: precheck trả OK, Auth trả invalid_credentials (DB ghi KHONG_CO_TAI_KHOAN).
    expect(decideLogin('OK', wrong)).toEqual({ outcome: 'SAI', record: 'SAI_MAT_KHAU' });
    expect(LOGIN_MESSAGES.SAI.message).toBe('Tên đăng nhập hoặc mật khẩu không đúng.');
  });
  it('tài khoản bị khoá: cùng câu như sai mật khẩu, lý do thật chỉ ghi nhật ký', () => {
    expect(decideLogin('TAI_KHOAN_KHOA', wrong)).toEqual({ outcome: 'SAI', record: 'TAI_KHOAN_KHOA' });
  });
  it('tài khoản bị khoá nhập đúng mật khẩu: vẫn không trả phiên', () => {
    expect(decideLogin('TAI_KHOAN_KHOA', okAuth)).toEqual({ outcome: 'SAI', record: 'TAI_KHOAN_KHOA' });
  });
  it('bị khoá giữa chừng (hook từ chối, Auth cấm): cùng câu như sai mật khẩu', () => {
    expect(decideLogin('OK', { ok: false, status: 403, errorCode: '' }).outcome).toBe('SAI');
    expect(decideLogin('OK', { ok: false, status: 400, errorCode: 'user_banned' })).toEqual({ outcome: 'SAI', record: 'TAI_KHOAN_KHOA' });
  });
  it('khoá tạm: câu "Đăng nhập tạm thời bị chặn, thử lại sau", không gọi Auth', () => {
    expect(decideLogin('KHOA_TAM', null)).toEqual({ outcome: 'KHOA_TAM', record: 'KHOA_TAM' });
    expect(LOGIN_MESSAGES.KHOA_TAM.message).toBe('Đăng nhập tạm thời bị chặn, thử lại sau.');
  });
  it('các câu trả lời không nhắc tới tài khoản tồn tại hay bị khoá', () => {
    for (const { message } of Object.values(LOGIN_MESSAGES)) {
      expect(message).not.toMatch(/khoá|không tồn tại|không có tài khoản/i);
    }
  });
  it('đúng mật khẩu, tài khoản dùng được: trả phiên', () => {
    expect(decideLogin('OK', okAuth)).toEqual({ outcome: 'THANH_CONG', record: 'THANH_CONG' });
  });
  it('lỗi captcha, giới hạn tốc độ theo IP: không ghi là sai mật khẩu', () => {
    expect(decideLogin('OK', { ok: false, status: 400, errorCode: 'captcha_failed' })).toEqual({ outcome: 'CAPTCHA', record: null });
    expect(decideLogin('OK', { ok: false, status: 429, errorCode: 'over_request_rate_limit' })).toEqual({ outcome: 'QUA_NHIEU', record: null });
  });
});

describe('yêu cầu hâm nóng (A9)', () => {
  it('chỉ GET có ?ping=1', () => {
    expect(isWarmPing('GET', 'https://x.supabase.co/functions/v1/login?ping=1')).toBe(true);
    expect(isWarmPing('GET', 'https://x.supabase.co/functions/v1/login')).toBe(false);
    expect(isWarmPing('GET', 'https://x.supabase.co/functions/v1/login?ping=0')).toBe(false);
    expect(isWarmPing('POST', 'https://x.supabase.co/functions/v1/login?ping=1')).toBe(false);
  });
  it('địa chỉ hỏng thì không phải ping', () => {
    expect(isWarmPing('GET', 'khong-phai-dia-chi')).toBe(false);
  });
});

describe('R-HT-12: không gửi thư đổi email (Soát E6)', () => {
  it('từ chối mọi loại thư đổi email', () => {
    expect(isEmailActionRejected('email_change')).toBe(true);
    expect(isEmailActionRejected('email_change_current')).toBe(true);
    expect(isEmailActionRejected('email_change_new')).toBe(true);
  });
  it('vẫn cho các loại thư khác (đặt lại mật khẩu, mời, xác minh)', () => {
    for (const type of ['recovery', 'magiclink', 'signup', 'invite', 'reauthentication', '']) {
      expect(isEmailActionRejected(type)).toBe(false);
    }
  });
});

describe('E5: trần độ dài tên đăng nhập', () => {
  it('là độ dài tối đa một địa chỉ email', () => {
    expect(MAX_LOGIN_LENGTH).toBeGreaterThan(100);
  });
});
