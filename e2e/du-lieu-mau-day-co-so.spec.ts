// E-23-38: Dữ liệu mẫu của tôi: cơ sở đã đủ số bộ, người chưa có bộ nào bấm Tạo thì thấy câu nhờ Admin xoá bớt.
// Máy chủ giả lập qua page.route (không phụ thuộc cờ staging và hạn mức thật); đăng nhập bằng tài khoản giả sale.cs5.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('Cơ sở đủ bộ: báo nhờ Admin xoá bớt (không bảo xoá bớt bộ của mình)', async ({ page }) => {
  await page.route('**/rpc/demo_data_available', (route) => route.fulfill({ json: true }));
  await page.route('**/rpc/list_demo_data_sets', (route) => route.fulfill({ json: [] }));
  await page.route('**/rpc/create_demo_data_set', (route) =>
    route.fulfill({
      status: 400,
      json: {
        code: 'P0001',
        message: 'Cơ sở này đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.',
        hint: 'HMT_DEMO_QUA_HAN_MUC_CO_SO',
        details: null,
      },
    }),
  );
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/du-lieu-mau');
  await expect(page.getByRole('heading', { level: 1, name: 'Dữ liệu mẫu của tôi' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo bộ dữ liệu mẫu' }).click();
  await expect(page.getByText('Cơ sở đã đủ số bộ mẫu, nhờ Admin xoá bớt.')).toBeVisible();
  await expect(page.getByText(/Xoá bớt một bộ trước/)).toHaveCount(0);
});
