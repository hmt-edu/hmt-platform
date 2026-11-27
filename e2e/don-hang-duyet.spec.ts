// BH-07 Duyệt, Từ chối đơn hàng: Trưởng cơ sở (người duyệt đã chốt) thấy cảnh báo vượt trần (chỉ cảnh báo, không ô tích), duyệt được; từ chối chọn lý do thì đơn
// về Nháp. Người khác không thấy nút. Máy tính và điện thoại (hộp thoại dùng cho cả hai, BH-07 "Cả hai"). Dữ liệu giả dựng bằng don-hang-seed.ts.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, DOMAIN, enterAs, expectAccessible, showAllTimeline } from './helpers';
import { DB_URL, approveSetupOf, clearMark, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededOrders;

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const result = await run(db);
    await db.query('commit');
    return result;
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = approveSetupOf(testInfo.project.name);
  seeded = await seedOrders(setup);
  await withDb(async (db) => {
    // Hai đơn Đã trình với người duyệt đã chốt là Trưởng cơ sở (không đổi Quản lý trực tiếp của tài khoản giả dùng chung, tránh đè bài khác chạy song song):
    // đơn Nháp của bộ seed (có cảnh báo vượt trần) và đơn Đã trình sẵn.
    await db.query(
      `update app.sales_order set status_code = 'DA_TRINH', approval_route = 'QUAN_LY', submitted_at = now(),
              assigned_approver_id = (select id from app.user_account where login_name = $2) where code = any($1::text[])`,
      [[seeded.orders.nhap, seeded.orders.dtrinh], `${setup.manager}@${DOMAIN}`],
    );
    await db.query(
      `update app.sales_order_line set over_cap = true, discount_percent = 15, gift_percent = 8.3 where order_id = (select id from app.sales_order where code = $1)`,
      [seeded.orders.nhap],
    );
  });
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(approveSetupOf(testInfo.project.name).mark);
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  const list =
    (page.viewportSize()?.width ?? 0) < 1024
      ? page.getByRole('list', { name: 'Đơn hàng' })
      : page.getByRole('table', { name: 'Đơn hàng' });
  await list.getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('Người lập không có nút Duyệt, Từ chối trên đơn Đã trình của mình', async ({
  page,
}, testInfo) => {
  const setup = approveSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.orders.dtrinh);
  await expect(page.getByRole('button', { name: 'Duyệt', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toHaveCount(0);
});

test('Trưởng cơ sở thấy cảnh báo vượt trần (không ô tích) và duyệt được; đơn thành Đã duyệt, nhật ký ghi vượt trần', async ({
  page,
}, testInfo) => {
  const setup = approveSetupOf(testInfo.project.name);
  await openOrder(page, setup.manager, seeded.orders.nhap);
  await expect(page.getByRole('status').filter({ hasText: /Ưu đãi vượt trần/ })).toBeVisible();
  // Q-163 (BH05_chip_vuot_tran): bản đã lưu vượt trần thì câu trần dưới bảng nằm trong hộp cảnh báo vàng, cả ở Đơn Xem.
  await expect(
    page.getByRole('status').filter({
      hasText:
        /^Ưu đãi cộng dồn; giờ tặng quy ra % tính vào trần \d+%\. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được\.$/,
    }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Duyệt đơn hàng' });
  await expect(dialog.getByText(/Ưu đãi vượt trần/)).toBeVisible();
  await expect(dialog.getByText(/Chỉ cảnh báo, không chặn/)).toBeVisible();
  await expect(dialog.getByRole('checkbox')).toHaveCount(0);
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Duyệt', exact: true }).click();
  await expect(page.getByText('Đã duyệt đơn hàng.').first()).toBeVisible();
  await expect(page.getByText('Đã duyệt · khoá').first()).toBeVisible();
  await showAllTimeline(page);
  await expect(page.getByText(/Duyệt đơn vượt trần/).first()).toBeVisible();
});

test('Từ chối đơn Đã trình: chọn lý do, "Khác" bắt ghi chú; đơn về Nháp, lịch sử giữ lý do', async ({
  page,
}, testInfo) => {
  const setup = approveSetupOf(testInfo.project.name);
  await openOrder(page, setup.manager, seeded.orders.dtrinh);
  await page.getByRole('button', { name: 'Từ chối', exact: true }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Từ chối đơn hàng' })).toBeVisible();
  await dialog.getByLabel('Lý do').click();
  await page.getByRole('option', { name: 'Khác', exact: true }).click();
  await expect(dialog.getByRole('button', { name: 'Xác nhận từ chối' })).toBeDisabled();
  await dialog.getByLabel('Lý do').click();
  await page.getByRole('option', { name: 'Không đúng chính sách' }).click();
  await dialog.getByRole('button', { name: 'Xác nhận từ chối' }).click();
  await expect(page.getByText('Đã từ chối đơn, đơn về Nháp.').first()).toBeVisible();
  await expect(page.getByText('Nháp · bị từ chối').first()).toBeVisible();
});
