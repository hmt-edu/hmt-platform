// Edge Function quản trị tài khoản (chỉ ADMIN đã xác thực hai bước): tạo tài khoản, đổi vai trò,
// đổi cơ sở, khoá/mở khoá, đặt lại mật khẩu, đặt tên đăng nhập, sửa email. Khoá secret chỉ nằm trong secrets của Supabase.
// Kiểm quyền: gọi hàm DB bằng chính token của người gọi (app.assert_account_admin).
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { corsHeaders, fail, HTTP, json, publishableKey, secretKey } from '../_shared/http.ts';
import { checkPassword, toAuthEmail } from '../_shared/login-rules.ts';
import { generateTempPassword } from '../_shared/temp-password.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
// Cấm đăng nhập ở Supabase Auth khi khoá: thời hạn rất dài (khoá đến khi Admin mở).
const BAN_FOREVER = '876000h';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, HTTP.METHOD_NOT_ALLOWED, 'HMT_SAI_PHUONG_THUC', 'Chỉ nhận POST.');
  const authorization = req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return fail(req, HTTP.UNAUTHORIZED, 'HMT_CHUA_DANG_NHAP', 'Chưa đăng nhập.');

  const asCaller = createClient(SUPABASE_URL, publishableKey(), {
    db: { schema: 'app' },
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(SUPABASE_URL, secretKey(), { auth: { persistSession: false } });

  const { error: notAdmin } = await asCaller.rpc('assert_account_admin');
  if (notAdmin) return fail(req, HTTP.FORBIDDEN, 'HMT_KHONG_CO_QUYEN', notAdmin.message);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
  }
  const action = String(body.action ?? '');
  const userId = typeof body.userId === 'string' ? body.userId : '';

  const passwordProblem = async (password: string) => {
    const [{ data: minLength }, { data: requireLetterDigit }] = await Promise.all([
      asCaller.rpc('get_setting_int', { p_key: 'password_min_length' }),
      asCaller.rpc('get_setting_bool', { p_key: 'password_require_letter_digit' }),
    ]);
    return checkPassword(password, { minLength: Number(minLength), requireLetterDigit: Boolean(requireLetterDigit) });
  };
  // Mật khẩu tạm ngẫu nhiên (cùng độ dài, chính sách như lúc nạp người dùng); trả MỘT lần cho Admin, không lưu, không ghi nhật ký.
  const makeTempPassword = async () => {
    const [{ data: lengthSetting }, { data: minLength }] = await Promise.all([
      asCaller.rpc('get_setting_int', { p_key: 'import_temp_password_length' }),
      asCaller.rpc('get_setting_int', { p_key: 'password_min_length' }),
    ]);
    return generateTempPassword(Math.max(Number(lengthSetting), Number(minLength)), (buffer) => crypto.getRandomValues(buffer));
  };
  const rpcFail = (error: { message: string; hint?: string }) =>
    fail(req, HTTP.BAD_REQUEST, error.hint?.startsWith('HMT_') ? error.hint : 'HMT_LOI', error.message);

  switch (action) {
    case 'create': {
      const isStudent = body.kind === 'student';
      const studentCode = typeof body.studentCode === 'string' ? body.studentCode.trim().toUpperCase() : null;
      const loginEmail = isStudent ? toAuthEmail(studentCode ?? '') : String(body.email ?? '').trim().toLowerCase();
      // Không gửi sẵn mật khẩu thì máy chủ sinh mật khẩu tạm và trả một lần (form Tạo người dùng QT-03).
      let password = String(body.password ?? '');
      const generated = password === '';
      if (generated) password = await makeTempPassword();
      if (!loginEmail || (isStudent && !studentCode)) return fail(req, HTTP.BAD_REQUEST, 'HMT_THIEU_THONG_TIN', 'Thiếu email hoặc mã học sinh.');
      const problem = await passwordProblem(password);
      if (problem) return fail(req, HTTP.BAD_REQUEST, 'HMT_MAT_KHAU_YEU', problem);

      // Tài khoản tạo ở trạng thái đã xác nhận: không gửi thư xác nhận (học sinh không có email thật).
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: loginEmail,
        password,
        email_confirm: true,
      });
      if (createError || !created.user) {
        return fail(req, HTTP.BAD_REQUEST, 'HMT_TAO_TAI_KHOAN_LOI', createError?.message ?? 'Không tạo được tài khoản.');
      }
      const { error } = await asCaller.rpc('admin_create_account', {
        p_user_id: created.user.id,
        p_display_name: String(body.displayName ?? ''),
        p_login_name: loginEmail,
        p_branch_code: String(body.branchCode ?? ''),
        p_roles: Array.isArray(body.roles) ? body.roles : [],
        p_staff_code: typeof body.staffCode === 'string' ? body.staffCode : null,
        p_staff_kind: typeof body.staffKind === 'string' ? body.staffKind : null,
        p_student_code: studentCode,
        p_username: typeof body.username === 'string' && body.username.trim() !== '' ? body.username : null,
      });
      if (error) {
        // Khai báo HMT lỗi thì gỡ tài khoản Auth vừa tạo (chưa có dữ liệu gì gắn vào).
        await admin.auth.admin.deleteUser(created.user.id);
        return rpcFail(error);
      }
      const response = json(req, HTTP.OK, generated ? { userId: created.user.id, password } : { userId: created.user.id });
      response.headers.set('Cache-Control', 'no-store');
      return response;
    }
    case 'set_username': {
      // Đặt tên đăng nhập MỘT lần cho tài khoản chưa có (ví dụ Admin tạo bằng Bootstrap admin). Đã có thì DB chặn.
      const { error } = await asCaller.rpc('admin_set_username', { p_user_id: userId, p_username: String(body.username ?? '') });
      return error ? rpcFail(error) : json(req, HTTP.OK, { ok: true });
    }
    case 'set_email': {
      // Sửa email (R-HT-12): DB kiểm luật (chỉ Admin, người khác, không trùng) -> đổi ở Supabase Auth -> DB áp dụng, thu hồi phiên, ghi nhật ký.
      // Áp dụng ở DB trượt thì trả email cũ cho Auth để hai bên không lệch.
      const newEmail = String(body.email ?? '').trim().toLowerCase();
      const { data: oldEmail, error: checkError } = await asCaller.rpc('admin_change_email_check', { p_user_id: userId, p_new_email: newEmail });
      if (checkError) return rpcFail(checkError);
      const { error: authError } = await admin.auth.admin.updateUserById(userId, { email: newEmail, email_confirm: true });
      if (authError) return fail(req, HTTP.BAD_REQUEST, 'HMT_LOI', authError.message);
      const { error } = await asCaller.rpc('admin_change_email_apply', { p_user_id: userId, p_new_email: newEmail });
      if (error) {
        await admin.auth.admin.updateUserById(userId, { email: String(oldEmail), email_confirm: true });
        return rpcFail(error);
      }
      return json(req, HTTP.OK, { ok: true });
    }
    case 'set_roles': {
      const { error } = await asCaller.rpc('admin_set_roles', { p_user_id: userId, p_roles: body.roles });
      return error ? rpcFail(error) : json(req, HTTP.OK, { ok: true });
    }
    case 'set_branch': {
      const { error } = await asCaller.rpc('admin_set_branch', { p_user_id: userId, p_branch_code: body.branchCode });
      return error ? rpcFail(error) : json(req, HTTP.OK, { ok: true });
    }
    case 'lock':
    case 'unlock': {
      const locked = action === 'lock';
      const { error } = await asCaller.rpc('admin_set_locked', { p_user_id: userId, p_locked: locked, p_reason: body.reason ?? null });
      if (error) return rpcFail(error);
      const { error: banError } = await admin.auth.admin.updateUserById(userId, { ban_duration: locked ? BAN_FOREVER : 'none' });
      if (banError) return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI_HE_THONG', 'Đã khoá trong HMT nhưng chưa cấm được ở Supabase Auth; thử lại.');
      return json(req, HTTP.OK, { ok: true });
    }
    case 'reset_password': {
      // Không gửi sẵn mật khẩu thì máy chủ sinh mật khẩu tạm ngẫu nhiên (cùng độ dài, chính sách như lúc nạp người dùng) và trả MỘT lần
      // cho Admin; không lưu, không ghi nhật ký. Có gửi `password` thì kiểm theo chính sách như trước.
      let password = String(body.password ?? '');
      let generated = false;
      if (password === '') {
        password = await makeTempPassword();
        generated = true;
      }
      const problem = await passwordProblem(password);
      if (problem) return fail(req, HTTP.BAD_REQUEST, 'HMT_MAT_KHAU_YEU', problem);
      // Soát E2: kiểm người dùng đích tồn tại TRƯỚC khi đổi mật khẩu ở Auth (đổi rồi mới thấy không có đích thì mật khẩu đã đổi mà không đánh dấu bắt đổi lại).
      const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
      if (targetError || !target?.user) return fail(req, HTTP.NOT_FOUND, 'HMT_KHONG_TIM_THAY', 'Không tìm thấy người dùng.');
      const { error: authError } = await admin.auth.admin.updateUserById(userId, { password });
      if (authError) return fail(req, HTTP.BAD_REQUEST, 'HMT_LOI', authError.message);
      const { error } = await asCaller.rpc('admin_mark_password_reset', { p_user_id: userId });
      if (error) return rpcFail(error);
      const response = json(req, HTTP.OK, generated ? { ok: true, password } : { ok: true });
      response.headers.set('Cache-Control', 'no-store');
      return response;
    }
    default:
      return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Không có thao tác này.');
  }
});
