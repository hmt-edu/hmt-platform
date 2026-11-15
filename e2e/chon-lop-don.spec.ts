// BH-08 Chọn lớp và ngày vào lớp cho dòng đơn Nháp (hộp thoại mở từ bảng Sửa đơn). Máy tính (điện thoại chỉ đọc, Đ248). Dữ liệu giả: đơn Nháp dựng bằng don-hang-seed.ts,
// lớp đã duyệt dựng bằng ghi-danh-seed.ts (Đại số khối 9, khớp gói LC-TOAN-K09).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone } from './helpers';
import {
  DB_URL,
  classSetupOf,
  clearMark,
  seedOrderRecords,
  type SeededRecords,
} from './don-hang-seed';
import { seedGhiDanh, type GhiDanhSeed } from './ghi-danh-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng và lớp giả).');
test.describe.configure({ mode: 'serial' });

let orders: SeededRecords;
let grid: GhiDanhSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  orders = await seedOrderRecords(classSetupOf(testInfo.project.name));
  grid = await seedGhiDanh(testInfo.project.name);
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(classSetupOf(testInfo.project.name).mark);
});

test('BH-08: Sửa đơn Nháp, chọn lớp cho một dòng thì hiện mã lớp và ngày vào lớp; bỏ lớp thì về "—"', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = classSetupOf(testInfo.project.name);
  await enterAs(page, setup.sale);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(orders.records.rejected);
  await page
    .getByRole('table', { name: 'Đơn hàng' })
    .getByRole('link', { name: orders.records.rejected })
    .click();
  await expect(
    page.getByRole('heading', { level: 2, name: orders.records.rejected }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  const lines = page.getByRole('table', { name: 'Dòng đơn đang sửa' });
  await lines.getByRole('button', { name: 'Chọn lớp' }).first().click();
  const dialog = page.getByRole('dialog', { name: 'Chọn lớp và ngày vào lớp' });
  await expect(dialog).toBeVisible();
  await expectAccessible(page);
  // Chỉ lớp đúng gói (Đại số khối 9, đã duyệt, còn chỗ, cùng cơ sở); chọn lớp rồi ngày vào lớp mặc định là buổi sắp tới đầu tiên.
  await dialog.getByRole('radio', { name: new RegExp(grid.classCode) }).check();
  await expect(dialog.getByRole('button', { name: 'Chọn', exact: true })).toBeEnabled();
  await dialog.getByRole('button', { name: 'Chọn', exact: true }).click();
  await expect(page.getByText('Đã chọn lớp cho dòng đơn.', { exact: true })).toBeVisible();
  await expect(lines.getByText(grid.classCode).first()).toBeVisible();
  await expect(lines.getByRole('button', { name: 'Đổi lớp' }).first()).toBeVisible();
  // Chọn "Chưa chọn lớp" thì bỏ lớp (ghi danh sẽ Chờ xếp lớp).
  await lines.getByRole('button', { name: 'Đổi lớp' }).first().click();
  const again = page.getByRole('dialog', { name: 'Chọn lớp và ngày vào lớp' });
  await again.getByRole('radio', { name: /^Chưa chọn lớp/ }).check();
  await again.getByRole('button', { name: 'Chọn', exact: true }).click();
  // Thông báo hiện cả ở khung toast và vùng đọc màn hình: chữ khớp 2 phần tử (strict mode); lấy phần tử đầu.
  await expect(page.getByText(/Dòng đơn chưa chọn lớp/).first()).toBeVisible();
  await expect(lines.getByText(grid.classCode)).toHaveCount(0);
});
