// «Việc của tôi» (canvas 1bcc): mở từ menu, thấy ba ô đếm rồi danh sách thẻ hoặc trạng thái trống đúng chữ. Chỉ đọc, không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('sale.cs5: mở Việc của tôi thấy tiêu đề, ba nhóm và danh sách hoặc trạng thái trống', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/viec-cua-toi');
  await expect(page.getByRole('heading', { level: 1, name: 'Việc của tôi' })).toBeVisible();
  for (const label of ['Làm ngay', 'Hôm nay', 'Sắp tới']) {
    await expect(page.getByRole('term').filter({ hasText: label })).toBeVisible();
  }
  await expect(
    page
      .getByRole('region', { name: 'Làm ngay' })
      .or(page.getByRole('region', { name: 'Hôm nay' }))
      .or(page.getByRole('region', { name: 'Sắp tới' }))
      .or(page.getByRole('heading', { name: 'Chưa có việc nào cần làm' }))
      .first(),
  ).toBeVisible();
  await expectAccessible(page);
});

test('sale.cs5: tab Lịch tuần hiện lưới tuần, chú thích màu, nút Tạo lịch hẹn mở hộp thoại', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/viec-cua-toi');
  await page.getByRole('tab', { name: 'Lịch tuần' }).click();
  await expect(page).toHaveURL(/xem=tuan/);
  await expect(page.getByRole('button', { name: 'Hôm nay', exact: true })).toBeVisible();
  await expect(page.getByText('Đã hoàn thành', { exact: true })).toBeVisible();
  await expect(page.getByRole('radio', { name: 'Tháng' })).toHaveCount(0);
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
});
