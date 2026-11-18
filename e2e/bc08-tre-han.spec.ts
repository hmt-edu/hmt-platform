// BC-08 Giáo viên trễ hạn hằng tháng: Trưởng cơ sở (có quyền Báo cáo) mở màn thấy tiêu đề và thẻ tổng; nhân viên bán hàng bị chặn.
// Tài khoản giả, không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('truongcs.cs5: mở Giáo viên trễ hạn thấy tiêu đề và thẻ tổng', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/bao-cao/giao-vien-tre-han');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Giáo viên trễ hạn hằng tháng' }),
  ).toBeVisible();
  await expect(page.getByText('Người có buổi trễ')).toBeVisible();
});

test('sale.cs5: không có quyền Báo cáo nên báo không có quyền', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/bao-cao/giao-vien-tre-han');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
  ).toBeVisible();
});
