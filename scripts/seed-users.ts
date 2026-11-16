// Tạo tài khoản giả cho local, CI và hmt-staging (KHÔNG BAO GIỜ chạy trên bản chạy thật).
// Mỗi vai trò ít nhất một tài khoản, nhân viên ở CS1 và CS5. Chạy lại nhiều lần không nhân đôi.
// Biến môi trường: API_URL, SECRET_KEY (khoá secret của project), DB_URL, SEED_PASSWORD.
// Mật khẩu giả không nằm trong repo: đọc từ SEED_PASSWORD (local: .env.local; staging: GitHub secret).
// SEED_ASSIGN_MANAGERS=1 (chỉ bước triển khai staging đặt): gán sẵn Quản lý trực tiếp (R-HT-06) cho Sale, CSKH giả = Trưởng cơ sở cùng cơ sở, CHỈ khi
// đang để trống (không ghi đè quản lý đã gán tay ở màn Người dùng). Local, CI không đặt biến này vì bài Playwright cần Sale chưa có quản lý.
import pg from 'pg';

export const SEED_DOMAIN = 'thu.hoamatoan.invalid';

export type SeedUser = {
  key: string;
  name: string;
  branch: string;
  roles: string[];
  locked?: boolean;
  student?: boolean;
};

/** Danh sách tài khoản giả: key = phần trước @ (học sinh: mã HS). */
export const SEED_USERS: SeedUser[] = [
  { key: 'admin.cs1', name: 'Quản trị (giả)', branch: 'CS1', roles: ['ADMIN'] },
  // Admin thứ hai cho bài Playwright màn Người dùng (tránh tranh thiết bị hai bước của admin.cs1 với bài đăng nhập).
  { key: 'quantri.cs5', name: 'Quản trị CS5 (giả)', branch: 'CS5', roles: ['ADMIN'] },
  { key: 'truongcs.cs1', name: 'Trưởng CS1 (giả)', branch: 'CS1', roles: ['BRANCH_MANAGER'] },
  { key: 'truongcs.cs5', name: 'Trưởng CS5 (giả)', branch: 'CS5', roles: ['BRANCH_MANAGER'] },
  { key: 'sale.cs1', name: 'Sale CS1 (giả)', branch: 'CS1', roles: ['SALES'] },
  { key: 'sale.cs5', name: 'Sale CS5 (giả)', branch: 'CS5', roles: ['SALES'] },
  { key: 'cskh.cs1', name: 'CSKH CS1 (giả)', branch: 'CS1', roles: ['CSKH'] },
  { key: 'cskh.cs5', name: 'CSKH CS5 (giả)', branch: 'CS5', roles: ['CSKH'] },
  { key: 'ketoan', name: 'Kế toán (giả)', branch: 'CS1', roles: ['ACCOUNTANT'] },
  // Hai tài khoản riêng cho bài Kế toán duyệt phiếu thu (hai bước thiết lập ngay trong bài; không dùng chung với file bài khác để khỏi tranh thiết bị).
  { key: 'ketoan.cs5', name: 'Kế toán CS5 (giả)', branch: 'CS5', roles: ['ACCOUNTANT'] },
  // Kế toán thứ hai CS5 riêng cho bài đường học sinh mới (T4): hai file bài không dùng chung một tài khoản hai bước (tránh tranh thiết bị).
  { key: 'ketoan2.cs5', name: 'Kế toán thứ hai CS5 (giả)', branch: 'CS5', roles: ['ACCOUNTANT'] },
  { key: 'quantri.cs1', name: 'Quản trị CS1 (giả)', branch: 'CS1', roles: ['ADMIN'] },
  { key: 'gv.cs5', name: 'Giáo viên CS5 (giả)', branch: 'CS5', roles: ['TEACHER'] },
  // Giáo viên thứ hai: giáo viên của buổi "người khác" ở bài Playwright (buổi phải có giáo viên đủ vai trò, F5).
  { key: 'gv2.cs5', name: 'Giáo viên thứ hai CS5 (giả)', branch: 'CS5', roles: ['TEACHER'] },
  { key: 'tg.cs5', name: 'Trợ giảng CS5 (giả)', branch: 'CS5', roles: ['TA'] },
  {
    key: 'kiem.cs5',
    name: 'Trưởng kiêm Sale CS5 (giả)',
    branch: 'CS5',
    roles: ['BRANCH_MANAGER', 'SALES'],
  },
  { key: 'khoa.cs5', name: 'Đã nghỉ việc (giả)', branch: 'CS5', roles: ['SALES'], locked: true },
  { key: 'HS900001', name: 'Học sinh (giả)', branch: 'CS5', roles: ['STUDENT'], student: true },
];

/** Quản lý trực tiếp mặc định của Sale, CSKH giả (người → quản lý), theo cơ sở. Dùng khi SEED_ASSIGN_MANAGERS=1. */
export const SEED_MANAGERS: Record<string, string> = {
  'sale.cs1': 'truongcs.cs1',
  'cskh.cs1': 'truongcs.cs1',
  'sale.cs5': 'truongcs.cs5',
  'cskh.cs5': 'truongcs.cs5',
};

export function seedEmail(user: SeedUser): string {
  return user.student
    ? `${user.key.toLowerCase()}@hocsinh.hoamatoan.edu.vn`
    : `${user.key}@${SEED_DOMAIN}`;
}

type AuthBody = {
  id?: string;
  users?: { id: string; email: string }[];
  msg?: string;
  message?: string;
};

async function authAdmin(
  apiUrl: string,
  secretKey: string,
  path: string,
  init: RequestInit = {},
): Promise<AuthBody> {
  const response = await fetch(`${apiUrl}/auth/v1/admin${path}`, {
    ...init,
    headers: {
      apikey: secretKey,
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/json',
    },
  });
  const body = (await response.json().catch(() => ({}))) as AuthBody;
  if (!response.ok)
    throw new Error(`Supabase Auth ${path}: ${response.status} ${body.msg ?? body.message ?? ''}`);
  return body;
}

async function main() {
  const { API_URL, SECRET_KEY, DB_URL, SEED_PASSWORD } = process.env;
  if (!API_URL || !SECRET_KEY || !DB_URL || !SEED_PASSWORD) {
    throw new Error('Thiếu API_URL, SECRET_KEY, DB_URL hoặc SEED_PASSWORD.');
  }
  if (!(SEED_PASSWORD.length >= 8 && /\p{L}/u.test(SEED_PASSWORD) && /\d/.test(SEED_PASSWORD))) {
    throw new Error('SEED_PASSWORD phải đủ 8 ký tự, có chữ và số.');
  }
  // Chặn chạy nhầm vào bản chạy thật.
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  const marker = await db.query<{ staging: boolean }>(
    "select exists (select from app.holiday where name like '%(thử nghiệm)') as staging",
  );
  if (!marker.rows[0]?.staging) {
    await db.end();
    throw new Error(
      'Không thấy dữ liệu giả (seed.sql) trong DB này: dừng, để không tạo tài khoản giả trên bản chạy thật.',
    );
  }

  const existing = await authAdmin(API_URL, SECRET_KEY, '/users?per_page=1000');
  const byEmail = new Map((existing.users ?? []).map((u) => [u.email, u.id]));

  for (const user of SEED_USERS) {
    const email = seedEmail(user);
    let id = byEmail.get(email);
    if (id) {
      await authAdmin(API_URL, SECRET_KEY, `/users/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ password: SEED_PASSWORD }),
      });
    } else {
      const created = await authAdmin(API_URL, SECRET_KEY, '/users', {
        method: 'POST',
        body: JSON.stringify({ email, password: SEED_PASSWORD, email_confirm: true }),
      });
      id = created.id;
      if (!id) throw new Error(`Không tạo được tài khoản ${email}.`);
    }
    await db.query(
      `insert into app.user_account (id, display_name, login_name, branch_id, student_code, is_locked, lock_reason, must_change_password)
       values ($1, $2, $3, (select id from app.branch where code = $4), $5, $6, $7, $8)
       on conflict (id) do update set display_name = excluded.display_name, branch_id = excluded.branch_id,
         is_locked = excluded.is_locked, lock_reason = excluded.lock_reason,
         must_change_password = excluded.must_change_password, failed_login_count = 0, temp_locked_until = null`,
      [
        id,
        user.name,
        email,
        user.branch,
        user.student ? user.key : null,
        Boolean(user.locked),
        user.locked ? 'Tài khoản giả để thử khoá' : null,
        Boolean(user.student),
      ],
    );
    // Học sinh: chụp mã băm mật khẩu tạm để buộc đổi mật khẩu lần đầu.
    if (user.student) {
      await db.query('select app.remember_temp_password($1)', [id]);
    }
    await db.query(
      'update app.user_role set is_active = (role_code = any ($2)) where user_id = $1',
      [id, user.roles],
    );
    await db.query(
      `insert into app.user_role (user_id, role_code) select $1, unnest($2::text[])
       on conflict (user_id, role_code) do update set is_active = true`,
      [id, user.roles],
    );
    await authAdmin(API_URL, SECRET_KEY, `/users/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ ban_duration: user.locked ? '876000h' : 'none' }),
    });
  }
  if (process.env.SEED_ASSIGN_MANAGERS === '1') {
    // Cờ cục bộ của hàm set_manager cho phép đổi quản lý ngoài màn Người dùng; chỉ gán khi đang trống.
    await db.query('begin');
    await db.query("select set_config('hmt.manager', 'on', true)");
    for (const [user, manager] of Object.entries(SEED_MANAGERS)) {
      await db.query(
        `update app.user_account set manager_id = (select id from app.user_account where login_name = $2)
          where login_name = $1 and manager_id is null`,
        [`${user}@${SEED_DOMAIN}`, `${manager}@${SEED_DOMAIN}`],
      );
    }
    await db.query('commit');
    console.log('Đã gán sẵn quản lý trực tiếp cho Sale, CSKH giả (chỉ chỗ đang trống).');
  }
  await db.end();
  console.log(`Đã tạo/cập nhật ${SEED_USERS.length} tài khoản giả.`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
