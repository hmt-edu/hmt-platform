// BH-09 Cho học trước, đóng tiền sau (R-GD-12), canvas 9933 BH09_bat: Trưởng cơ sở thấy nút «Cho học trước» trên đơn Đã duyệt chưa thu tiền; cờ tham số tắt (mặc định) thì máy chủ từ chối;
// bật cờ thì bật được, ghi danh tạo sớm, nút đổi thành «Tắt cho học trước»; Sale không thấy nút. Chỉ máy tính. Dữ liệu giả dựng bằng don-hang-seed.ts, trả cờ về như cũ sau bài.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { DB_URL, clearMark, payLaterSetupOf, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededOrders;

async function setFlag(value: 'true' | 'false') {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query("update app.setting_def set value = $1 where key = 'pay_later_toggle_enabled'", [
      value,
    ]);
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seedOrders(payLaterSetupOf(testInfo.project.name));
  await setFlag('false');
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await setFlag('false');
  await clearMark(payLaterSetupOf(testInfo.project.name).mark);
});

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Cho học trước chỉ có trên máy tính.');
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await page.getByRole('table', { name: 'Đơn hàng' }).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('Sale không thấy nút Cho học trước (chỉ quản lý cơ sở)', async ({ page }, testInfo) => {
  await openOrder(page, payLaterSetupOf(testInfo.project.name).sale, seeded.orders.dduyet);
  await expect(page.getByRole('button', { name: 'Cho học trước' })).toHaveCount(0);
});

test('Cờ tắt: hộp báo máy chủ từ chối; cờ bật: bật được rồi tắt được', async ({
  page,
}, testInfo) => {
  test.setTimeout(90_000);
  const setup = payLaterSetupOf(testInfo.project.name);
  await openOrder(page, setup.manager, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Cho học trước' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByText('Bật cho học trước, đóng tiền sau')).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Bật', exact: true }).click();
  await expect(dialog.getByText('chưa được bật cho cơ sở này')).toBeVisible();
  await dialog.getByRole('button', { name: 'Huỷ' }).click();
  // Bật cờ như Chat/Admin bật ở Cài đặt tham số.
  await setFlag('true');
  await page.reload();
  await page.getByRole('button', { name: 'Cho học trước' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Bật', exact: true }).click();
  await expect(page.getByText('Đã bật cho học trước.').first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tắt cho học trước' })).toBeVisible();
  await page.getByRole('button', { name: 'Tắt cho học trước' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Tắt', exact: true }).click();
  await expect(page.getByText('Đã tắt cho học trước.').first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Cho học trước' })).toBeVisible();
});
