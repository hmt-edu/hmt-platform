// Hướng dẫn sử dụng (A-23-30): mọi người đăng nhập cổng CRM đều mở được; menu theo mục, đọc nội dung, tìm trong tài liệu.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('Hướng dẫn: mở từ menu tài khoản, đổi mục, tìm kiếm trong tài liệu', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/huong-dan');
  await expect(page).toHaveURL(/\/crm\/huong-dan\/bat-dau$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Hướng dẫn sử dụng' })).toBeVisible();
  const nav = page.getByRole('navigation', { name: 'Mục hướng dẫn' });
  await expect(nav.getByRole('link', { name: /^0\. Bắt đầu/ })).toHaveAttribute(
    'aria-current',
    'page',
  );
  await expect(page.getByRole('heading', { name: /Hướng dẫn chung/ })).toBeVisible();
  await expectAccessible(page);

  // Đổi sang mục Sale: nội dung đổi theo.
  await nav.getByRole('link', { name: /^1\. Sale và Tuyển sinh/ }).click();
  await expect(page).toHaveURL(/\/crm\/huong-dan\/sale$/);
  await expect(
    page.getByRole('heading', { name: /Hướng dẫn cho Sale và Tuyển sinh/ }),
  ).toBeVisible();

  // Tìm: kết quả trỏ về đúng mục; từ lạ thì báo không thấy.
  await page.getByLabel('Tìm trong hướng dẫn').fill('xếp lớp');
  const results = page.getByRole('list', { name: 'Kết quả tìm trong hướng dẫn' });
  await expect(results.getByRole('link').first()).toBeVisible();
  await page.getByLabel('Tìm trong hướng dẫn').fill('zzzkhongcotuNay');
  await expect(page.getByText('Không thấy mục nào có')).toBeVisible();
});

test('Hướng dẫn: mục không có thì báo không có mục, có đường về mục đầu', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/huong-dan/khong-ton-tai');
  await expect(page.getByRole('heading', { name: 'Không có mục hướng dẫn này' })).toBeVisible();
  await page.getByRole('link', { name: 'Về mục đầu' }).click();
  await expect(page).toHaveURL(/\/crm\/huong-dan\/bat-dau$/);
});
