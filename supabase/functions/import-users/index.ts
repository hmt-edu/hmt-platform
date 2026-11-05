// Edge Function nạp Người dùng (T4b; chỉ ADMIN đã xác thực hai bước). Khoá secret chỉ nằm trong secrets của Supabase.
// Luồng: (1) kiểm từng dòng bằng hàm DB app.import_users_resolve (không tạo gì); (2) nếu commit = true: tạo người dùng Auth với
// mật khẩu tạm ngẫu nhiên, tạo tài khoản (app.import_user_create), gắn quản lý trực tiếp, khoá người nghỉ, ghi nhật ký nạp.
// QUYỀN RIÊNG TƯ: không ghi (console) họ tên, email, tên đăng nhập, mật khẩu; kết quả trả về trình duyệt chỉ có số dòng và chữ cái
// đầu của tên. Mật khẩu tạm CHỈ trả một lần trong lần nạp thật cho Admin tải file; không lưu ở máy chủ, không gửi email.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { corsHeaders, fail, HTTP, json, publishableKey, secretKey } from '../_shared/http.ts';
import { generateTempPassword } from '../_shared/temp-password.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
// Cấm đăng nhập ở Supabase Auth khi khoá: thời hạn rất dài (khoá đến khi Admin mở), như admin-users.
const BAN_FOREVER = '876000h';

type ResolvedRow = {
  row: number;
  label: string;
  initial: string | null;
  status: 'HOP_LE' | 'TRUNG' | 'LOI';
  code: string | null;
  message: string | null;
  warnings: string[];
  resolved?: {
    username: string;
    email: string;
    display_name: string;
    branch_code: string;
    role: string;
    raw_branches: string;
    multi_branch: boolean;
    locked: boolean;
    manager_username: string | null;
  };
};

function noStore(res: Response): Response {
  res.headers.set('Cache-Control', 'no-store');
  return res;
}

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

  let body: { rows?: unknown; commit?: unknown; fileName?: unknown };
  try {
    body = await req.json();
  } catch {
    return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
  }
  if (!Array.isArray(body.rows)) return fail(req, HTTP.BAD_REQUEST, 'HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nạp.');
  const commit = body.commit === true;
  const fileName = typeof body.fileName === 'string' ? body.fileName : null;

  const rpcFail = (error: { message: string; hint?: string }) =>
    fail(req, HTTP.BAD_REQUEST, error.hint?.startsWith('HMT_') ? error.hint : 'HMT_LOI', error.message);

  // Bước 1: kiểm từng dòng (không tạo gì).
  const { data: checked, error: checkError } = await asCaller.rpc('import_users_resolve', { p_rows: body.rows });
  if (checkError) return rpcFail(checkError);
  const rows = (checked as { rows: ResolvedRow[] }).rows;

  // Kết quả trả về trình duyệt: bỏ cột `resolved` (có email, tên đăng nhập).
  const publicRows = () =>
    rows.map(({ resolved: _omit, ...rest }) => rest);
  const counts = () => ({
    total: rows.length,
    imported: rows.filter((r) => r.status === 'HOP_LE').length,
    duplicates: rows.filter((r) => r.status === 'TRUNG').length,
    errors: rows.filter((r) => r.status === 'LOI').length,
  });

  if (!commit) {
    return noStore(json(req, HTTP.OK, { mode: 'XEM_TRUOC', kind: 'NGUOI_DUNG', ...counts(), rows: publicRows() }));
  }

  // Bước 2: nạp thật.
  const [{ data: lengthSetting }, { data: minLength }] = await Promise.all([
    asCaller.rpc('get_setting_int', { p_key: 'import_temp_password_length' }),
    asCaller.rpc('get_setting_int', { p_key: 'password_min_length' }),
  ]);
  const passwordLength = Math.max(Number(lengthSetting), Number(minLength));
  const random = (buffer: Uint8Array) => crypto.getRandomValues(buffer);

  const created: { row: ResolvedRow; userId: string; password: string }[] = [];
  for (const row of rows) {
    if (row.status !== 'HOP_LE' || !row.resolved) continue;
    const password = generateTempPassword(passwordLength, random);
    // Tài khoản tạo ở trạng thái đã xác nhận: không gửi thư xác nhận.
    const { data: authUser, error: createError } = await admin.auth.admin.createUser({
      email: row.resolved.email,
      password,
      email_confirm: true,
    });
    if (createError || !authUser.user) {
      row.status = 'LOI';
      row.message = 'Không tạo được tài khoản đăng nhập (email có thể đã dùng ở hệ thống đăng nhập).';
      continue;
    }
    const { error } = await asCaller.rpc('import_user_create', { p_user_id: authUser.user.id, p_resolved: row.resolved });
    if (error) {
      // Lỗi nghiệp vụ thì gỡ người dùng Auth vừa tạo (chưa có dữ liệu gì gắn vào).
      await admin.auth.admin.deleteUser(authUser.user.id);
      row.status = 'LOI';
      row.message = error.hint?.startsWith('HMT_') ? error.message : 'Không tạo được tài khoản (lỗi hệ thống).';
      continue;
    }
    created.push({ row, userId: authUser.user.id, password });
  }

  // Gắn quản lý trực tiếp sau khi tạo hết (quản lý đứng sau người được quản lý cũng gắn được).
  for (const item of created) {
    const manager = item.row.resolved?.manager_username;
    if (!manager) continue;
    const { error } = await asCaller.rpc('import_user_set_manager', { p_user_id: item.userId, p_manager_username: manager });
    if (error) item.row.warnings = [...item.row.warnings, 'Chưa gắn được quản lý trực tiếp: ' + error.message];
  }
  // Khoá người nghỉ phép, đã nghỉ (sau khi gắn quản lý) và cấm đăng nhập ở Auth.
  for (const item of created) {
    if (!item.row.resolved?.locked) continue;
    const { error } = await asCaller.rpc('import_user_lock', { p_user_id: item.userId });
    if (error) {
      item.row.warnings = [...item.row.warnings, 'Chưa khoá được tài khoản người nghỉ: ' + error.message];
      continue;
    }
    await admin.auth.admin.updateUserById(item.userId, { ban_duration: BAN_FOREVER });
  }

  const final = counts();
  const { error: finishError } = await asCaller.rpc('import_users_finish', {
    p_file_name: fileName,
    p_total: final.total,
    p_imported: created.length,
    p_duplicates: final.duplicates,
    p_errors: final.errors,
    p_pending: created
      .filter((c) => c.row.resolved?.multi_branch)
      .map((c) => ({ user_id: c.userId, raw_branches: c.row.resolved?.raw_branches })),
  });
  if (finishError) return rpcFail(finishError);

  // Mật khẩu tạm trả MỘT LẦN về trình duyệt Admin để tải file giao người dùng; không lưu, không ghi nhật ký.
  const passwords = created.map((c) => ({ username: c.row.resolved?.username, password: c.password }));
  return noStore(
    json(req, HTTP.OK, {
      mode: 'NHAP',
      kind: 'NGUOI_DUNG',
      total: final.total,
      imported: created.length,
      duplicates: final.duplicates,
      errors: final.errors,
      rows: publicRows().map((r) => (r.status === 'HOP_LE' ? { ...r, message: null } : r)),
      passwords,
    }),
  );
});
