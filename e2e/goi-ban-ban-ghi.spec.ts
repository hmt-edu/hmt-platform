// CH-02 Gói bán (bản ghi): từ danh sách mở gói mẫu LC-TOAN-K09 thấy thông tin gói, giá đang hiệu lực, lịch sử giá và nút Thêm giá mới, Sửa, Ngừng. Máy tính. Không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAsAdmin } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Cấu hình chỉ có bản máy tính.');
});

test('Gói bán: mở bản ghi từ danh sách, thấy giá theo hiệu lực và các nút nghiệp vụ', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/goi-ban');
  await page.getByRole('link', { name: 'LC-TOAN-K09', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/cau-hinh\/goi-ban\/[0-9a-f-]{36}$/);
  await expect(page.getByRole('heading', { name: 'Thông tin gói' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Giá đang hiệu lực' })).toBeVisible();
  await expect(page.getByRole('table', { name: 'Giá theo hiệu lực của gói' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm giá mới' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
});
