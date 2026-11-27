// Cụm Khách hàng: KH-01 danh sách phụ huynh, KH-02 bản ghi, KH-04 danh sách học sinh, KH-05 hồ sơ 360°.
// Dữ liệu giả dựng bằng SQL trực tiếp (không dữ liệu thật), dọn sau bài. Tài khoản Trưởng cơ sở CS5 giả.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

const suffix = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
// Số điện thoại giả riêng từng dự án để tìm đúng phụ huynh của mình.
const phone = (project: string) => (project === 'dien-thoai' ? '0900000902' : '0900000901');

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, code: string) {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  await db.query(
    'delete from app.student where parent_id in (select id from app.parent where code = $1)',
    [code],
  );
  await db.query('delete from app.parent where code = $1', [code]);
  await db.query('commit');
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const sfx = suffix(testInfo.project.name);
  const code = `PHE2EKH${sfx}`;
  await withDb(async (db) => {
    await clear(db, code);
    const branch = await db.query<{ id: string }>("select id from app.branch where code = 'CS5'");
    const parent = await db.query<{ id: string }>(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, $4) returning id`,
      [code, `Phụ huynh E2EKH ${sfx}`, phone(testInfo.project.name), branch.rows[0]!.id],
    );
    for (const n of [1, 2]) {
      await db.query(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade) values ($1, $2, $3, 2014, $4, 6)`,
        [`HSE2EKH${sfx}${n}`, parent.rows[0]!.id, `Em E2EKH ${sfx} ${n}`, branch.rows[0]!.id],
      );
    }
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, `PHE2EKH${suffix(testInfo.project.name)}`));
});

test('KH-01 → KH-02: tìm phụ huynh theo SĐT, mở bản ghi, thấy hai con', async ({
  page,
}, testInfo) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/phu-huynh');
  await expect(page.getByRole('heading', { level: 1, name: 'Phụ huynh' })).toBeVisible();
  await page.getByPlaceholder('Tìm tên, số điện thoại, mã…').fill(phone(testInfo.project.name));
  await page
    .getByRole('link', { name: `Phụ huynh E2EKH ${suffix(testInfo.project.name)}` })
    .first()
    .click();
  await expect(page.getByText('Chưa có con đang học').first()).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('tab', { name: 'Các con' }).click();
  await expect(page.getByText(`Em E2EKH ${suffix(testInfo.project.name)} 1`)).toBeVisible();
  await expect(page.getByText(`Em E2EKH ${suffix(testInfo.project.name)} 2`)).toBeVisible();
  // KH-02: tab Ticket mở được (phụ huynh giả chưa có ticket), không còn mờ «ticket làm sau».
  await page.getByRole('tab', { name: 'Ticket' }).click();
  await expect(page.getByText('Chưa có ticket nào.')).toBeVisible();
  await expect(page.getByRole('columnheader', { name: 'Hạn' })).toBeVisible();
  // Tab Tài chính bấm được và hiện đủ cột dù chưa có dữ liệu.
  await page.getByRole('tab', { name: 'Tài chính' }).click();
  await expect(page.getByRole('columnheader', { name: 'Thành tiền' })).toBeVisible();
  await expect(page.getByText('Chưa có ghi danh.')).toBeVisible();
  await expectAccessible(page);
});

test('KH-04 → KH-05: tìm học sinh, hồ sơ 360° là Tiềm năng, chưa có ghi danh', async ({
  page,
}, testInfo) => {
  const sfx = suffix(testInfo.project.name);
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/hoc-sinh');
  await expect(page.getByRole('heading', { level: 1, name: 'Học sinh' })).toBeVisible();
  await page.getByPlaceholder('Tìm tên, mã, mã cũ…').fill(`Em E2EKH ${sfx} 1`);
  await page
    .getByRole('link', { name: `Em E2EKH ${sfx} 1` })
    .first()
    .click();
  await expect(page.getByText('Tiềm năng').first()).toBeVisible();
  await page.getByRole('tab', { name: 'Học tập' }).click();
  await expect(page.getByText('Chưa có ghi danh.')).toBeVisible();
  await expect(page.getByRole('columnheader', { name: 'Ngày hết phí' })).toBeVisible();
  await page.getByRole('tab', { name: 'Điểm kiểm tra' }).click();
  await expect(page.getByText('Chưa có phiếu Test.')).toBeVisible();
  await page.getByRole('tab', { name: 'Điểm danh' }).click();
  await expect(page.getByText('Chưa có điểm danh.')).toBeVisible();
  await page.getByRole('tab', { name: 'Chăm sóc' }).click();
  await expect(page.getByRole('columnheader', { name: 'Hài lòng' })).toBeVisible();
  await expect(page.getByText('Chưa có dữ liệu chăm sóc.')).toBeVisible();
  // KH-05: tab «Đề nghị & khiếu nại» mở được (học sinh giả chưa có ticket).
  await page.getByRole('tab', { name: 'Đề nghị & khiếu nại' }).click();
  await expect(page.getByText('Chưa có ticket nào.')).toBeVisible();
  await expectAccessible(page);
});

test('KH-03, KH-06: nhân viên Sale sửa phụ huynh và học sinh; số điện thoại sai bị chặn', async ({
  page,
}, testInfo) => {
  const sfx = suffix(testInfo.project.name);
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/phu-huynh');
  await page.getByPlaceholder('Tìm tên, số điện thoại, mã…').fill(phone(testInfo.project.name));
  await page
    .getByRole('link', { name: `Phụ huynh E2EKH ${sfx}` })
    .first()
    .click();
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Địa chỉ', { exact: true }).fill('Số 9 phố Mẫu');
  await page.getByLabel('Số điện thoại', { exact: true }).fill('123');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Số điện thoại cần đủ 10 số, bắt đầu bằng 0.').first()).toBeVisible();
  await page.getByLabel('Số điện thoại', { exact: true }).fill(phone(testInfo.project.name));
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Số 9 phố Mẫu').first()).toBeVisible();

  await page.getByRole('tab', { name: 'Các con' }).click();
  await page.getByRole('button', { name: `Em E2EKH ${sfx} 1` }).click();
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Trường học', { exact: true }).fill('THCS Mẫu E2E');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('THCS Mẫu E2E').first()).toBeVisible();
});

// Quyền đọc từng vai: tab của hồ sơ phụ huynh mở được, đủ cột, không báo lỗi tải.
for (const account of ['sale.cs5', 'cskh.cs5']) {
  test(`KH-02: ${account} mở các tab Đơn hàng, Phiếu thu, Tài chính`, async ({
    page,
  }, testInfo) => {
    const sfx = suffix(testInfo.project.name);
    await enterAs(page, account);
    await page.goto('/crm/phu-huynh');
    await page.getByPlaceholder('Tìm tên, số điện thoại, mã…').fill(phone(testInfo.project.name));
    await page
      .getByRole('link', { name: `Phụ huynh E2EKH ${sfx}` })
      .first()
      .click();
    await page.getByRole('tab', { name: 'Đơn hàng' }).click();
    await expect(page.getByText('Chưa có đơn hàng.')).toBeVisible();
    await expect(page.getByRole('columnheader', { name: 'Đã đóng (đ)' })).toBeVisible();
    await page.getByRole('tab', { name: 'Phiếu thu' }).click();
    await expect(page.getByText('Chưa có phiếu thu.')).toBeVisible();
    await expect(page.getByRole('columnheader', { name: 'Người nhận tiền' })).toBeVisible();
    await page.getByRole('tab', { name: 'Tài chính' }).click();
    await expect(page.getByText('Chưa có ghi danh.')).toBeVisible();
    await expect(page.getByText(/Không tải được/)).toHaveCount(0);
    await expectAccessible(page);
  });
}

test('KH-05: Admin thấy khối tài khoản app và mở hộp cấp tài khoản', async ({ page }, testInfo) => {
  const name = `Em E2EKH ${suffix(testInfo.project.name)} 2`;
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/hoc-sinh');
  await page.getByPlaceholder('Tìm tên, mã, mã cũ…').fill(name);
  await page.getByRole('link', { name }).first().click();
  await expect(page.getByText('Chưa có tài khoản', { exact: true })).toBeVisible();
  // R-CRM-32, KH05_tk_chua_co: chỉ có nút Cấp, ở đầu hồ sơ và trong khối; không còn trong menu Hành động.
  const issue = page.getByRole('button', { name: 'Cấp tài khoản', exact: true });
  await expect(issue).toHaveCount(2);
  await expect(page.getByRole('button', { name: 'Khoá tài khoản' })).toHaveCount(0);
  await issue.first().click();
  await expect(page.getByText(/CHỈ HIỆN MỘT LẦN/)).toBeVisible();
  await page.getByRole('button', { name: 'Huỷ' }).click();
});
