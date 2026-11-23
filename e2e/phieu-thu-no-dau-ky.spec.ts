// TC-02 Thu nợ đầu kỳ (R-V2-15, canvas abea TC02_no_dau_ky_*): CSKH tạo phiếu không cần đơn, chọn em, số tiền không vượt nợ còn lại của em; phiếu hiện ở danh sách
// và bản ghi như phiếu «Thu nợ đầu kỳ · không có đơn». Máy tính (điện thoại chỉ đọc, Đ248). Dữ liệu giả dựng thẳng bằng SQL: một phụ huynh CS5 có nợ đầu kỳ 3.000.000
// ghi theo từng em. Cờ opening_debt_receipt_enabled (tắt mặc định) bật trong bài và trả lại như cũ ở cuối. Chỉ chạy bằng CI.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, expectAccessible } from './helpers';
import { DB_URL } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phụ huynh có nợ đầu kỳ giả).');
test.describe.configure({ mode: 'serial' });

const RUN = Date.now().toString(36).slice(-5).toUpperCase();
const PARENT = `Chị E2ENDK ${RUN}`;
const STUDENT = `Em Nợ ${RUN}`;
let flagBefore = 'false';
let receiptPath = '';

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    flagBefore =
      (
        await db.query<{ value: string }>(
          "select value from app.setting_def where key = 'opening_debt_receipt_enabled'",
        )
      ).rows[0]?.value ?? 'false';
    await db.query(
      "update app.setting_def set value = 'true' where key = 'opening_debt_receipt_enabled'",
    );
    const phone = `09${String(Date.now() % 1e8).padStart(8, '0')}`;
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id)
       select 'PHN' || $3, $1, $2, id from app.branch where code = 'CS5'`,
      [PARENT, phone, RUN],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       select 'HSN' || $2, p.id, $1, 2012, p.branch_id from app.parent p where p.code = 'PHN' || $2`,
      [STUDENT, RUN],
    );
    await db.query(
      `insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
       select s.parent_id, s.id, s.branch_id, 'DAU_KY_CONG_NO', -3000000, (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'E2ENDK'
         from app.student s where s.code = 'HSN' || $1`,
      [RUN],
    );
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  await withDb(async (db) => {
    await db.query(
      "update app.setting_def set value = $1 where key = 'opening_debt_receipt_enabled'",
      [flagBefore],
    );
  });
});

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Phiếu thu chỉ ghi trên máy tính (Đ248).');
});

test('CSKH tạo phiếu Thu nợ đầu kỳ cho một em, số tiền vượt nợ của em bị chặn', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/phieu-thu');
  await page.getByRole('button', { name: 'Thu nợ đầu kỳ' }).click();
  const dialog = page.getByRole('dialog', { name: 'Thu nợ đầu kỳ' });
  await expect(dialog.getByRole('button', { name: 'Tạo phiếu nháp' })).toBeDisabled();
  // Chọn phụ huynh: tìm theo tên, nợ từng em hiện sau khi chọn.
  const parent = dialog.getByRole('combobox', { name: 'Phụ huynh' });
  await parent.click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(PARENT);
  await page.getByRole('option', { name: new RegExp(PARENT) }).click();
  await dialog.getByRole('combobox', { name: 'Em' }).click();
  await expect(page.getByRole('option', { name: new RegExp(`${STUDENT}.*nợ còn`) })).toBeVisible();
  await page.getByRole('option', { name: new RegExp(STUDENT) }).click();
  await dialog.getByRole('combobox', { name: 'Hình thức' }).click();
  await page.getByRole('option', { name: 'Tiền mặt' }).click();
  // Vượt nợ còn lại của em (3.000.000): máy chủ chặn, hộp hiện lỗi, chưa tạo phiếu.
  await dialog.getByLabel('Số tiền').fill('3000001');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(dialog.getByRole('alert')).toContainText(/vượt/i);
  // Đúng số tiền: tạo được, mở trang phiếu không có đơn.
  await dialog.getByLabel('Số tiền').fill('1000000');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receiptPath = new URL(page.url()).pathname;
  await expect(page.getByText('Thu nợ đầu kỳ · không có đơn')).toBeVisible();
  await expect(page.getByText(STUDENT)).toBeVisible();
  await expectAccessible(page);
});

test('Phiếu Thu nợ đầu kỳ hiện ở danh sách, cột Đơn hàng không có liên kết', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/phieu-thu');
  await page.getByRole('searchbox').fill(PARENT);
  const row = page.getByRole('row', { name: new RegExp(PARENT) });
  await expect(row).toHaveCount(1);
  await expect(row.getByText('Thu nợ đầu kỳ')).toBeVisible();
  await expect(row.getByRole('link', { name: /^DH-/ })).toHaveCount(0);
});

// Ca chặn quyền (R-V2-15, R-HT-01, thẻ C25): CSKH gửi thẳng Kế toán nhưng không có nút Duyệt; Admin không có nút Duyệt tiền; Kế toán khác người lập duyệt được.
test('Phiếu nợ đầu kỳ: CSKH gửi kế toán, không có nút Duyệt', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(receiptPath);
  await page.getByRole('button', { name: 'Gửi kế toán duyệt' }).click();
  await expect(
    page.getByText(/chờ Kế toán duyệt \(phiếu nợ đầu kỳ không qua quản lý\)/),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt phiếu thu' })).toHaveCount(0);
});

// Mỗi bài một phiên đăng nhập mới (đăng nhập Admin ngay sau CSKH trong cùng trang không có ô Email).
test('Phiếu nợ đầu kỳ: Admin không có nút Duyệt tiền (R-HT-01)', async ({ page }) => {
  await enterAsAdmin(page, 'quantri.cs1');
  await page.goto(receiptPath);
  await expect(page.getByText(/chờ Kế toán duyệt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt phiếu thu' })).toHaveCount(0);
});

test('Phiếu nợ đầu kỳ: Kế toán khác người lập duyệt được, phiếu Đã duyệt', async ({ page }) => {
  await enterAsAdmin(page, 'ketoan.cs5');
  await page.goto(receiptPath);
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/Phiếu đã duyệt và khoá/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt phiếu thu' })).toHaveCount(0);
});

// N1 (Soát S14, migration 421), R-V2-15: Kế toán tự lập rồi tự gửi phiếu nợ đầu kỳ thì KHÔNG tự duyệt được (cần Kế toán khác). Bài chạy sau bài duyệt ở trên (nợ còn 2.000.000).
test('Phiếu nợ đầu kỳ: Kế toán tự lập, tự gửi không tự duyệt được', async ({ page }) => {
  await enterAsAdmin(page, 'ketoan.cs5');
  await page.goto('/crm/phieu-thu');
  await page.getByRole('button', { name: 'Thu nợ đầu kỳ' }).click();
  const dialog = page.getByRole('dialog', { name: 'Thu nợ đầu kỳ' });
  await dialog.getByRole('combobox', { name: 'Phụ huynh' }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(PARENT);
  await page.getByRole('option', { name: new RegExp(PARENT) }).click();
  await dialog.getByRole('combobox', { name: 'Em' }).click();
  await page.getByRole('option', { name: new RegExp(STUDENT) }).click();
  await dialog.getByRole('combobox', { name: 'Hình thức' }).click();
  await page.getByRole('option', { name: 'Tiền mặt' }).click();
  await dialog.getByLabel('Số tiền').fill('500000');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Gửi kế toán duyệt' }).click();
  await expect(page.getByText(/chờ Kế toán duyệt/)).toBeVisible();
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/không tự duyệt phiếu của mình/)).toBeVisible();
  // Phiếu vẫn chờ Kế toán khác duyệt.
  await expect(page.getByText(/chờ Kế toán duyệt/)).toBeVisible();
});
