// TC-16 «Dùng số dư khách hàng cho đơn mới» (hộp K08), R-CS-03, R-TIEN-33: Kế toán cấn số dư của phụ huynh vào đơn Đã duyệt còn thu; Sale lập đơn không có mục «Dùng số dư».
// Cờ customer_balance_apply_enabled tắt thì máy chủ từ chối; bật thì cấn được, số dư giảm. Chỉ máy tính (điện thoại chỉ đọc, Đ248). Số tiền trong bài là số giả của riêng bài.
// Dữ liệu giả dựng bằng don-hang-seed.ts; số dư giả ghi chú theo dấu bài, dọn sau bài; cờ trả về như cũ.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { DB_URL, balanceSetupOf, clearMark, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

const ACCOUNTANT = 'ketoan.cs5';
let seeded: SeededOrders;
let flagBefore = 'false';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

const setFlag = (value: string) =>
  withDb((db) =>
    db.query("update app.setting_def set value = $1 where key = 'customer_balance_apply_enabled'", [
      value,
    ]),
  );

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = balanceSetupOf(testInfo.project.name);
  seeded = await seedOrders(setup);
  await withDb(async (db) => {
    flagBefore =
      (
        await db.query<{ value: string }>(
          "select value from app.setting_def where key = 'customer_balance_apply_enabled'",
        )
      ).rows[0]?.value ?? 'false';
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    // Số dư giả 100.000 đ cho phụ huynh của đơn Đã duyệt (nhỏ hơn mọi phần còn thu của đơn).
    await db.query(
      `insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount, entry_date, note)
       select o.parent_id, o.branch_id, 'TU_DUNG_HOC', 100000, (now() at time zone 'Asia/Ho_Chi_Minh')::date, $2
         from app.sales_order o where o.code = $1`,
      [seeded.orders.dduyet, `${setup.mark} số dư giả`],
    );
    await db.query('commit');
  });
  await setFlag('false');
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const setup = balanceSetupOf(testInfo.project.name);
  await setFlag(flagBefore);
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `delete from app.money_in where balance_entry_id in
         (select id from app.customer_balance_entry where note like $1 or note like $2)`,
      [`${setup.mark}%`, `%${seeded.orders.dduyet}`],
    );
    await db.query('delete from app.customer_balance_entry where note like $1 or note like $2', [
      `${setup.mark}%`,
      `%${seeded.orders.dduyet}`,
    ]);
    await db.query('commit');
  });
  await clearMark(setup.mark);
});

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Dùng số dư chỉ có trên máy tính (Đ248).');
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await page.getByRole('table', { name: 'Đơn hàng' }).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('Sale lập đơn không có mục «Dùng số dư» (chỉ Kế toán)', async ({ page }, testInfo) => {
  await openOrder(page, balanceSetupOf(testInfo.project.name).sale, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'In', exact: true })).toBeVisible();
  await expect(page.getByRole('menuitem', { name: 'Dùng số dư' })).toHaveCount(0);
});

test('Cờ tắt: máy chủ từ chối; cờ bật: cấn được và số dư giảm', async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  void testInfo;
  await openOrder(page, ACCOUNTANT, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Dùng số dư' }).click();
  const dialog = page.getByRole('dialog', { name: 'Dùng số dư cho đơn' });
  await expect(dialog.getByText('Số dư hiện có')).toBeVisible();
  await expect(dialog.getByText('100.000').first()).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Xác nhận dùng số dư' }).click();
  // Cờ tắt (mặc định): máy chủ trả lỗi tiếng Việt ngay trong hộp, hộp vẫn mở.
  await expect(dialog.getByRole('alert')).toBeVisible();
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Huỷ' }).click();
  // Bật cờ như Admin bật ở Cài đặt tham số.
  await setFlag('true');
  await page.reload();
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Dùng số dư' }).click();
  await page
    .getByRole('dialog', { name: 'Dùng số dư cho đơn' })
    .getByRole('button', { name: 'Xác nhận dùng số dư' })
    .click();
  await expect(page.getByText(/Đã dùng 100\.000 đ số dư cho đơn/).first()).toBeVisible();
  // Số dư giả đã cấn hết: lần mở sau hiện số dư hiện có bằng 0.
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Dùng số dư' }).click();
  await expect(
    page.getByRole('dialog', { name: 'Dùng số dư cho đơn' }).getByText('0 đ').first(),
  ).toBeVisible();
});
