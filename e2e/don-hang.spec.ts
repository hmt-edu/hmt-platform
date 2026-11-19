// BH-06 Đơn hàng (danh sách), P5a-UI-10: cột theo canvas, Đ262 (Đã thu, Còn phải thu để "—", không có bộ lọc đã thu đủ và nút Thu tiền),
// lọc theo tình trạng, Xuất theo quyền, mục menu theo công tắc Bán hàng. Dữ liệu giả dựng bằng don-hang-seed.ts.
import { readFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone } from './helpers';
import { DB_URL, clearMark, orderSetupOf, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededOrders;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seedOrders(orderSetupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(orderSetupOf(testInfo.project.name).mark);
});

async function openOrders(page: Page, account: string, mark: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await expect(page.getByRole('heading', { level: 1, name: 'Đơn hàng' })).toBeVisible();
  await page.getByRole('searchbox').fill(mark);
  // Tìm kiếm chờ một nhịp rồi mới gọi máy chủ: đợi tới khi chỉ còn ba đơn của dự án.
  await expect(page.getByText('1–3 / 3')).toBeVisible();
}

function list(page: Page) {
  return isPhone(page)
    ? page.getByRole('list', { name: 'Đơn hàng' })
    : page.getByRole('table', { name: 'Đơn hàng' });
}

test('Sale CS5: danh sách đủ cột (Đã thu, Còn phải thu, Thu tiền theo canvas BH06), không có nút Tạo, Thu tiền, Xuất', async ({
  page,
}, testInfo) => {
  const setup = orderSetupOf(testInfo.project.name);
  await openOrders(page, setup.sale, setup.mark);
  const rows = list(page);
  await expect(rows.getByText(seeded.orders.nhap)).toBeVisible();
  await expect(rows.getByText(seeded.orders.dtrinh)).toBeVisible();
  await expect(rows.getByText(seeded.orders.dduyet)).toBeVisible();
  // Cột Học sinh nêu tên các em theo dòng (student_names, migration 060), không còn chữ "· N dòng".
  await expect(rows.getByText('Em Đã Gửi')).toBeVisible();
  await expect(rows.getByText('Em Quá Hạn')).toBeVisible();
  await expect(rows.getByText(/· \d+ dòng/)).toHaveCount(0);
  await expect(rows.getByText('Nháp').first()).toBeVisible();
  await expect(rows.getByText('Đã trình').first()).toBeVisible();
  await expect(rows.getByText('Đã duyệt · khoá').first()).toBeVisible();
  if (!isPhone(page)) {
    for (const name of [
      'Mã',
      'Phụ huynh',
      'Học sinh',
      'Cơ sở',
      'Sale',
      'Tổng tiền (đ)',
      'Đã thu (đ)',
      'Còn phải thu (đ)',
      'Tình trạng',
      'Thu tiền',
    ]) {
      await expect(rows.getByRole('columnheader', { name })).toBeVisible();
    }
    // Đ262 giữ «—» «cho tới khi có phiếu thu»; phiếu thu đã làm (B50, canvas BH06): đơn chưa duyệt vẫn «—» ở Còn phải thu và Thu tiền.
    const nhapRow = rows.getByRole('row').filter({ hasText: seeded.orders.nhap });
    await expect(nhapRow.getByText('—').first()).toBeVisible();
  }
  // R-CRM-19, R-TIEN-02: danh sách không có nút Tạo; Đ262: không có nút Thu tiền; Đ105: Sale không có nút Xuất.
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Thu tiền' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xuất', exact: true })).toHaveCount(0);
  await expectAccessible(page);
});

test('Lọc nhanh Tình trạng; không có bộ lọc đã thu đủ, chưa thu (Đ262)', async ({
  page,
}, testInfo) => {
  const setup = orderSetupOf(testInfo.project.name);
  await openOrders(page, setup.sale, setup.mark);
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await expect(page.getByLabel('Đã thu đủ', { exact: true })).toHaveCount(0);
  await expect(page.getByLabel('Chưa thu', { exact: true })).toHaveCount(0);
  // R-TIEN-06: bị từ chối thì về Nháp, nên không có lựa chọn Từ chối.
  await expect(page.getByLabel('Từ chối', { exact: true })).toHaveCount(0);
  await page.getByLabel('Đã trình', { exact: true }).check();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.orders.dtrinh)).toBeVisible();
  await expect(list(page).getByText(seeded.orders.nhap)).toHaveCount(0);
});

test('Trưởng cơ sở có nút Xuất; file CSV có BOM và đơn trong phạm vi', async ({
  page,
}, testInfo) => {
  const setup = orderSetupOf(testInfo.project.name);
  await openOrders(page, setup.manager, setup.mark);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^don-hang-\d{4}-\d{2}-\d{2}\.csv$/);
  const text = readFileSync(await file.path(), 'utf8');
  expect(text.startsWith('﻿Mã,Tình trạng')).toBe(true);
  expect(text).toContain(seeded.orders.dtrinh);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Công tắc Bán hàng: CS1 chưa bật thì mở thẳng đường dẫn báo chưa bật', async ({ page }) => {
  await enterAs(page, 'sale.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/don-hang');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});

test('K03: cột bỏ ở nút «Cột» vẫn ẩn sau khi tải lại trang (T-STG2)', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Bảng cột là bảng tuỳ chỉnh của máy tính.');
  const setup = orderSetupOf(testInfo.project.name);
  await openOrders(page, setup.sale, setup.mark);
  const rows = list(page);
  await expect(rows.getByRole('columnheader', { name: 'Học sinh' })).toBeVisible();
  await page.getByRole('button', { name: 'Cột', exact: true }).click();
  await page.getByRole('checkbox', { name: 'Học sinh' }).uncheck();
  await page.keyboard.press('Escape');
  await expect(rows.getByRole('columnheader', { name: 'Học sinh' })).toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: 'Đơn hàng' })).toBeVisible();
  await expect(rows.getByRole('columnheader', { name: 'Mã' })).toBeVisible();
  await expect(rows.getByRole('columnheader', { name: 'Học sinh' })).toHaveCount(0);
  // Đặt lại về cột mặc định thì cột trở lại và không còn bản lưu.
  await page.getByRole('button', { name: 'Cột', exact: true }).click();
  await page.getByRole('button', { name: "Mặc định" }).click();
  await page.keyboard.press('Escape');
  await page.reload();
  await expect(rows.getByRole('columnheader', { name: 'Học sinh' })).toBeVisible();
});
