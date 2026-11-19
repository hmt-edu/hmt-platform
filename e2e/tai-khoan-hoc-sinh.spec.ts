// QT-13 Tài khoản học sinh: Admin thấy danh sách học sinh kèm tình trạng tài khoản, tìm theo mã HS, lọc «Chưa cấp», mở hộp cấp tài khoản;
// nhân viên không phải Admin không vào được. Edge Function admin-users không chạy ở môi trường kiểm thử: hộp chỉ kiểm tới bước xác nhận.
// Máy tính (QT chỉ có bản máy tính). Học sinh giả riêng, dọn ở cuối bài.
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

const CODE = 'HS991301';
const NAME = 'Em Thử Tài Khoản E2E';

async function sql(query: string, params: unknown[] = []) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(query, params);
  } finally {
    await db.end();
  }
}

/** Dọn dữ liệu giả: bảng nghiệp vụ chặn xoá (khung chung), nên xoá trong một giao dịch tắt trigger. */
async function purge(statements: [string, unknown[]?][]) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    for (const [q, p] of statements) await db.query(q, p ?? []);
    await db.query('commit');
  } finally {
    await db.end();
  }
}

async function cleanup() {
  await purge([
    ['delete from app.student where code = $1', [CODE]],
    ["delete from app.parent where code = 'PHE2EQT13'"],
  ]);
}

test.beforeAll(async () => {
  await cleanup();
  await sql(
    `insert into app.parent (code, full_name, phone, branch_id) values ('PHE2EQT13', 'Phụ huynh E2E QT13', '0991301301', (select id from app.branch where code = 'CS5'))`,
  );
  await sql(
    `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
     values ($1, (select id from app.parent where code = 'PHE2EQT13'), $2, 2012, (select id from app.branch where code = 'CS5'))`,
    [CODE, NAME],
  );
});

test.afterAll(cleanup);

test('Admin: tìm theo mã HS thấy em «Chưa cấp», mở hộp cấp tài khoản, lọc Chưa cấp', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/tai-khoan-hoc-sinh');
  await expect(page.getByRole('heading', { level: 1, name: 'Tài khoản học sinh' })).toBeVisible();
  await page
    .getByRole('main')
    .getByPlaceholder(/Tìm tên em/)
    .fill(CODE);
  const row = page.getByRole('row', { name: new RegExp(CODE) });
  await expect(row).toBeVisible();
  await expect(row.getByText('Chưa cấp')).toBeVisible();
  await row.getByRole('button', { name: 'Cấp tài khoản' }).click();
  await expect(page.getByText('Tên đăng nhập là mã HS')).toBeVisible();
  await page.getByRole('button', { name: 'Huỷ' }).click();
  await expect(page.getByText('Tên đăng nhập là mã HS')).toBeHidden();
});

test('Nhân viên không phải Admin: không vào được màn Tài khoản học sinh', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/quan-tri/tai-khoan-hoc-sinh');
  await expect(page.getByRole('heading', { level: 1, name: 'Tài khoản học sinh' })).toHaveCount(0);
});
