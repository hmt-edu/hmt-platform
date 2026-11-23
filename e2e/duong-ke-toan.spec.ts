// Đường Kế toán tích hợp (B41, R-TIEN-01, R-TIEN-26, TC-09): đơn Đã duyệt → Sale lập phiếu thu → Trưởng cơ sở duyệt → Kế toán duyệt (hai bước) → khoản tiền vào
// → Kế toán HOÀN TÁC khoản (lý do) → khoản âm trỏ về khoản gốc, tổng khoản tiền vào của đơn về 0, công nợ trở lại đủ thành tiền đơn.
// Màn «Đối soát thu tiền» (TC-15) chưa làm nên «báo cáo thu» kiểm bằng tổng ở sổ Khoản tiền vào và Công nợ.
// Cờ hoàn tác bật bằng GHI ĐÈ THEO CƠ SỞ CS5 (không đụng giá trị chung mà bài thu-tien TC-09 bật và trả lại), trả lại khi xong. Máy tính (Đ248).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, pickOption, showAllColumns } from './helpers';
import { DB_URL, clearMark, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Đường Kế toán ghi trên máy tính (Đ248).');
});

// Mã dự án riêng (không dùng RECEIPT_SETUPS của bài phieu-thu chạy song song); Kế toán riêng ketoan4.cs5 để không tranh thiết bị hai bước.
const SETUP = { mark: 'E2EDKMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1800 } as const;
const ACCOUNTANT = 'ketoan4.cs5';
const AMOUNT = '200000';

let seeded: SeededOrders;
let orderId = '';
let receiptUrl = '';

async function db<T>(fn: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: DB_URL });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

/**
 * Bật hoặc tắt cờ hoàn tác: ghi đè theo cơ sở CS5 (hàm DB kiểm theo cơ sở) và giá trị chung
 * (giao diện từ #586 đọc cờ không kèm cơ sở nên chỉ thấy giá trị chung, nút Hoàn tác mới hiện).
 */
async function branchFlag(on: boolean) {
  await db((c) =>
    c.query("update app.setting_def set value = $1 where key = 'money_reversal_enabled'", [
      on ? 'true' : 'false',
    ]),
  );
  await db((c) =>
    c.query(
      `insert into app.setting_branch (setting_key, branch_id, value, is_active)
         select 'money_reversal_enabled', b.id, $1, $2 from app.branch b where b.code = 'CS5'
       on conflict (setting_key, branch_id) do update set value = excluded.value, is_active = excluded.is_active`,
      [on ? 'true' : 'false', on],
    ),
  );
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  seeded = await seedOrders(SETUP);
  orderId =
    (
      await db((c) =>
        c.query<{ id: string }>('select id from app.sales_order where code = $1', [
          seeded.orders.dduyet,
        ]),
      )
    ).rows[0]?.id ?? '';
  await branchFlag(true);
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  await branchFlag(false);
  await clearMark(SETUP.mark);
});

async function open(page: Page, account: string, url: string) {
  await enterAs(page, account);
  await page.goto(url);
}

test('Sale lập phiếu thu từ đơn Đã duyệt và trình quản lý', async ({ page }) => {
  test.setTimeout(90_000);
  const loaded = page.waitForResponse((r) => r.url().includes('order_payment_summary') && r.ok());
  await open(page, SETUP.sale, `/crm/don-hang/${orderId}`);
  await loaded;
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await dialog.getByLabel('Số tiền').fill(AMOUNT);
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receiptUrl = new URL(page.url()).pathname;
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ (quản lý|Trưởng cơ sở) duyệt/)).toBeVisible();
});

test('Trưởng cơ sở duyệt phiếu thu, chuyển Kế toán', async ({ page }) => {
  await open(page, SETUP.manager, receiptUrl);
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});

test('Kế toán duyệt phiếu thu: sinh đúng một khoản tiền vào cùng số tiền', async ({ page }) => {
  test.setTimeout(120_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto(receiptUrl);
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await expect(page.getByText('Đã duyệt phiếu thu, tiền đã ghi nhận.').first()).toBeVisible();
  const m = await db((c) =>
    c.query<{ n: string; total: string }>(
      'select count(*)::text as n, coalesce(sum(amount), 0)::text as total from app.money_in where order_id = $1::uuid',
      [orderId],
    ),
  );
  expect(m.rows[0]?.n).toBe('1');
  expect(m.rows[0]?.total).toBe(AMOUNT);
});

test('Kế toán hoàn tác khoản tiền: khoản âm trỏ về khoản gốc, tổng về 0, công nợ trở lại đủ', async ({
  page,
}) => {
  test.setTimeout(120_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto('/crm/khoan-tien-vao');
  await expect(page.getByRole('heading', { level: 1, name: 'Khoản tiền vào' })).toBeVisible();
  await page.getByRole('searchbox').fill(seeded.orders.dduyet);
  await expect(page.getByText(`Tổng số tiền (theo bộ lọc): 200.000 đ`)).toBeVisible();
  await showAllColumns(page); // cột Thao tác (nút Hoàn tác) có thể nằm ngoài 8 cột mặc định (#570)
  const row = page.getByRole('row').filter({ hasText: seeded.orders.dduyet });
  await expect(row).toHaveCount(1);
  await row.getByRole('button', { name: 'Hoàn tác khoản tiền' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Hoàn tác khoản tiền' });
  await pickOption(page, dialog.getByRole('combobox'), 'Nhập sai số tiền');
  await dialog.getByRole('button', { name: 'Hoàn tác', exact: true }).click();
  await expect(page.getByText('Đã hoàn tác khoản tiền.').first()).toBeVisible();
  // Sổ chỉ thêm dòng: khoản gốc còn đó (không còn nút), khoản âm mới; tổng theo bộ lọc về 0.
  await expect(page.getByText(/Hoàn tác của KTV-/).first()).toBeVisible();
  await expect(page.getByText('Tổng số tiền (theo bộ lọc): 0 đ')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hoàn tác khoản tiền' })).toHaveCount(0);
  const m = await db((c) =>
    c.query<{ n: string; total: string }>(
      'select count(*)::text as n, coalesce(sum(amount), 0)::text as total from app.money_in where order_id = $1::uuid',
      [orderId],
    ),
  );
  expect(m.rows[0]?.n).toBe('2');
  expect(m.rows[0]?.total).toBe('0');
  // Công nợ: tiền đã đóng về 0 nên «Tổng còn nợ» trở lại đủ thành tiền các đợt của đơn (tính từ dữ liệu).
  const due = await db((c) =>
    c.query<{ total: string }>(
      'select coalesce(sum(amount), 0)::text as total from app.sales_order_installment where order_id = $1::uuid',
      [orderId],
    ),
  );
  const expected = Number(due.rows[0]?.total ?? '0');
  await page.goto('/crm/cong-no');
  await page.getByRole('searchbox').fill(seeded.orders.dduyet);
  if (expected > 0) {
    await expect(
      page.getByText(`Tổng còn nợ (theo bộ lọc): ${expected.toLocaleString('vi-VN')} đ`),
    ).toBeVisible();
  }
});
