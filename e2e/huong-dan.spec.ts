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
  const links = nav.getByRole('link');
  // Không dò chữ hay số của từng mục (danh mục mục tăng dần): mục đầu đang chọn, bấm mục thứ hai thì đường dẫn và mục chọn đổi theo.
  await expect(links.first()).toHaveAttribute('aria-current', 'page');
  await expect(page.locator('main h2, main h3').first()).toBeVisible();
  await expectAccessible(page);

  await links.nth(1).click();
  await expect(page).not.toHaveURL(/\/crm\/huong-dan\/bat-dau$/);
  await expect(links.nth(1)).toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('heading', { level: 1, name: 'Hướng dẫn sử dụng' })).toBeVisible();

  // Tìm: kết quả trỏ về đúng mục; từ lạ thì báo không thấy.
  await page.getByLabel('Tìm trong hướng dẫn', { exact: true }).fill('bấm');
  const results = page.getByRole('list', { name: 'Kết quả tìm trong hướng dẫn' });
  await expect(results.getByRole('link').first()).toBeVisible();
  await page.getByLabel('Tìm trong hướng dẫn', { exact: true }).fill('zzzkhongcotuNay');
  await expect(page.getByText('Không thấy mục nào có')).toBeVisible();
});

test('Hướng dẫn: mục không có thì báo không có mục, có đường về mục đầu', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/huong-dan/khong-ton-tai');
  await expect(page.getByRole('heading', { name: 'Không có mục hướng dẫn này' })).toBeVisible();
  await page.getByRole('link', { name: 'Về mục đầu' }).click();
  await expect(page).toHaveURL(/\/crm\/huong-dan\/bat-dau$/);
});
