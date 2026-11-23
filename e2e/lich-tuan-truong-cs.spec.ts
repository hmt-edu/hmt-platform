// LOP-08 Lịch tuần cơ sở: Trưởng cơ sở CS5 (vai trò một cơ sở, không có ô chọn cơ sở) mở lịch tuần phải xem cơ sở CS5 của mình,
// không báo «không có quyền» (lỗi cũ: màn lấy cơ sở đầu danh sách là CS1). Tài khoản giả, không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('truongcs.cs5: mở Lịch tuần cơ sở không bị báo không có quyền', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/lich-tuan');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch tuần cơ sở' })).toBeVisible();
  await expect(page.getByText(/không có quyền xem lịch tuần/)).toHaveCount(0);
  // Người một cơ sở không có ô chọn cơ sở.
  await expect(page.getByLabel('Cơ sở', { exact: true })).toHaveCount(0);
});
