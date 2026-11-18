// BC-09 Giờ dạy giáo viên: người có quyền Báo cáo (Admin cần hai bước nên dùng Trưởng cơ sở) mở màn thấy tiêu đề, thẻ tổng và bảng hoặc trạng thái trống;
// nhân viên bán hàng không có quyền Báo cáo thì không thấy dữ liệu. Tài khoản giả, không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('truongcs.cs5: mở Giờ dạy giáo viên thấy tiêu đề và thẻ tổng', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/bao-cao/gio-day');
  await expect(page.getByRole('heading', { level: 1, name: 'Giờ dạy giáo viên' })).toBeVisible();
  await expect(page.getByText('Tổng giờ dạy')).toBeVisible();
});

test('sale.cs5: không có quyền Báo cáo nên báo không có quyền', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/bao-cao/gio-day');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
  ).toBeVisible();
});
