// QT-17 Tài khoản phụ huynh (migration 616): Admin thấy phụ huynh kèm tình trạng tài khoản, nút theo tình trạng (Chưa cấp: Cấp tài khoản; Đang dùng: Đặt lại mật khẩu + Khoá;
// Đã khoá: Đặt lại mật khẩu + Mở khoá, chốt 24/11), hộp Khoá KHÔNG có ô lý do và vẫn gửi lý do mặc định để hàm khoá không báo thiếu lý do
// (lỗi Tester 23/11, sửa ở #531). Edge Function admin-users không chạy ở môi trường kiểm thử: bài chặn lời gọi bằng page.route để xem nội dung gửi đi.
// Máy tính (QT chỉ có bản máy tính). Phụ huynh và tài khoản giả riêng, dọn ở cuối bài.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { enterAs, enterAsAdmin, PASSWORD } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

// Ba phụ huynh giả: chưa cấp, đang dùng, đã khoá. Mã PH có dấu riêng của bài.
const P = { none: 'PH991701', active: 'PH991702', locked: 'PH991703' };
const NAME = (key: keyof typeof P) => `Phụ huynh E2E QT17 ${key}`;

async function withDb(run: (db: pg.Client) => Promise<void>) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await run(db);
  } finally {
    await db.end();
  }
}

/** Dọn dữ liệu giả: bảng nghiệp vụ chặn xoá (khung chung), nên xoá trong một giao dịch tắt trigger. */
async function cleanup() {
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const codes = Object.values(P);
    await db.query(
      'delete from app.user_role where user_id in (select id from app.user_account where parent_code = any($1))',
      [codes],
    );
    await db.query(
      'delete from auth.users where id in (select id from app.user_account where parent_code = any($1))',
      [codes],
    );
    await db.query('delete from app.user_account where parent_code = any($1)', [codes]);
    await db.query('delete from app.parent where code = any($1)', [codes]);
    await db.query('commit');
  });
}

test.beforeAll(async () => {
  await cleanup();
  await withDb(async (db) => {
    for (const [key, code] of Object.entries(P)) {
      await db.query(
        `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, (select id from app.branch where code = 'CS5'))`,
        [code, NAME(key as keyof typeof P), `099170${code.slice(-4)}`],
      );
    }
    for (const key of ['active', 'locked'] as const) {
      const code = P[key];
      const email = `${code.toLowerCase()}@phuhuynh.hoamatoan.edu.vn`;
      const id = (
        await db.query<{ id: string }>(
          `insert into auth.users (id, aud, role, email) values (gen_random_uuid(), 'authenticated', 'authenticated', $1) returning id`,
          [email],
        )
      ).rows[0]?.id;
      await db.query(
        `insert into app.user_account (id, display_name, login_name, branch_id, parent_code, is_locked, must_change_password)
         values ($1, $2, $3, (select id from app.branch where code = 'CS5'), $4, $5, false)`,
        [id, NAME(key), email, code, key === 'locked'],
      );
      await db.query(`insert into app.user_role (user_id, role_code) values ($1, 'PARENT')`, [id]);
    }
  });
});

test.afterAll(cleanup);

async function openList(page: import('@playwright/test').Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/tai-khoan-phu-huynh');
  await expect(page.getByRole('heading', { level: 1, name: 'Tài khoản phụ huynh' })).toBeVisible();
  await page
    .getByRole('main')
    .getByPlaceholder(/Tìm tên phụ huynh/)
    .fill('E2E QT17');
}

test('Nút theo tình trạng: Chưa cấp có Cấp; Đang dùng có Đặt lại + Khoá; Đã khoá có Đặt lại + Mở khoá', async ({
  page,
}) => {
  await openList(page);
  const none = page.getByRole('row', { name: new RegExp(P.none) });
  const active = page.getByRole('row', { name: new RegExp(P.active) });
  const locked = page.getByRole('row', { name: new RegExp(P.locked) });
  await expect(none.getByText('Chưa cấp')).toBeVisible();
  await expect(none.getByRole('button', { name: 'Cấp tài khoản' })).toBeVisible();
  await expect(none.getByRole('button', { name: 'Khoá' })).toHaveCount(0);
  await expect(active.getByText('Đang dùng')).toBeVisible();
  await expect(active.getByRole('button', { name: 'Đặt lại mật khẩu' })).toBeVisible();
  await expect(active.getByRole('button', { name: 'Khoá' })).toBeVisible();
  await expect(locked.getByText('Đã khoá')).toBeVisible();
  await expect(locked.getByRole('button', { name: 'Đặt lại mật khẩu' })).toBeVisible();
  await expect(locked.getByRole('button', { name: 'Khoá' })).toHaveCount(0);
  await expect(locked.getByRole('button', { name: 'Mở khoá' })).toBeVisible();
  await expect(active.getByRole('button', { name: 'Mở khoá' })).toHaveCount(0);
});

test('Khoá không cần lý do: hộp không có ô lý do, lời gọi vẫn kèm lý do mặc định không rỗng', async ({
  page,
}) => {
  let sent: Record<string, unknown> | null = null;
  await page.route('**/functions/v1/admin-users', async (route) => {
    sent = route.request().postDataJSON() as Record<string, unknown>;
    await route.fulfill({ json: { ok: true } });
  });
  await openList(page);
  const row = page.getByRole('row', { name: new RegExp(P.active) });
  await row.getByRole('button', { name: 'Khoá' }).click();
  const dialog = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  await expect(dialog.getByText('Khoá tài khoản').first()).toBeVisible();
  // Không có ô chọn lý do, không có ô ghi chú.
  await expect(dialog.getByRole('combobox')).toHaveCount(0);
  await expect(dialog.getByRole('textbox')).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Khoá', exact: true }).click();
  await expect(page.getByText(/Đã khoá tài khoản của/)).toBeVisible();
  const body = sent as Record<string, unknown> | null;
  expect(body?.action).toBe('lock');
  expect(typeof body?.reason === 'string' ? body.reason.trim() : '').not.toBe('');
});

test('Nhân viên không phải Admin: không vào được màn Tài khoản phụ huynh', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/quan-tri/tai-khoan-phu-huynh');
  await expect(page.getByRole('heading', { level: 1, name: 'Tài khoản phụ huynh' })).toHaveCount(0);
});

test('Mở khoá phụ huynh: hộp xác nhận gọi admin-users action unlock với đúng tài khoản (QT-17, chốt 24/11)', async ({
  page,
}) => {
  const sent: { body?: Record<string, unknown> } = {};
  await page.route('**/functions/v1/admin-users', async (route) => {
    sent.body = route.request().postDataJSON() as Record<string, unknown>;
    await route.fulfill({ json: { ok: true } });
  });
  await openList(page);
  const row = page.getByRole('row', { name: new RegExp(P.locked) });
  await row.getByRole('button', { name: 'Mở khoá' }).click();
  const dialog = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  await expect(dialog.getByText('Mở khoá tài khoản').first()).toBeVisible();
  await dialog.getByRole('button', { name: 'Mở khoá' }).click();
  await expect.poll(() => sent.body?.action).toBe('unlock');
  expect(typeof sent.body?.userId).toBe('string');
});
