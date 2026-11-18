// CHUNG-15 Việc chờ tôi duyệt: người có quyền Duyệt (Trưởng cơ sở) mở màn thấy bảng hoặc trạng thái trống đúng chữ; nhân viên bán hàng (có một quyền Duyệt)
// thấy trạng thái trống. Dùng tài khoản giả không cần hai bước. Không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('truongcs.cs5: mở Việc chờ tôi duyệt thấy tiêu đề và bảng hoặc trạng thái trống', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/viec-cho-duyet');
  await expect(page.getByRole('heading', { level: 1, name: 'Việc chờ tôi duyệt' })).toBeVisible();
  await expect(page.getByRole('table').or(page.getByText('Không có việc chờ duyệt'))).toBeVisible();
});

test('sale.cs5: có một quyền Duyệt nên mở được màn; chưa có việc đến lượt thì thấy trạng thái trống', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/viec-cho-duyet');
  await expect(page.getByRole('heading', { level: 1, name: 'Việc chờ tôi duyệt' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Không có việc chờ duyệt' })).toBeVisible();
});
