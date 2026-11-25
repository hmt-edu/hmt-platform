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

test('Hướng dẫn: menu chia ba nhóm không trùng, «Bạn là ai?» dẫn tới bài của vai, có Bài trước/Bài sau, địa chỉ cũ chuyển sang mục mới (A-23-37)', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/huong-dan');
  const nav = page.getByRole('navigation', { name: 'Mục hướng dẫn' });
  for (const group of ['Bắt đầu', 'Theo vai trò', 'Tra cứu'])
    await expect(nav.getByText(group, { exact: true })).toBeVisible();
  // Không còn mục trùng: mỗi tên mục xuất hiện một lần.
  const names = (await nav.getByRole('link').allTextContents()).map((t) => t.trim());
  expect(new Set(names).size).toBe(names.length);
  // Khối «Bạn là ai?»: bấm vai Kế toán thì sang bài của vai đó.
  await expect(page.getByRole('heading', { name: /Bạn là ai/ })).toBeVisible();
  // Mỗi vai đúng MỘT nút (A-24-05).
  const roleNames = (
    await page
      .getByRole('region', { name: /Bạn là ai/ })
      .getByRole('link')
      .allTextContents()
  ).map((t) => t.trim());
  expect(new Set(roleNames).size).toBe(roleNames.length);
  await page
    .getByRole('region', { name: /Bạn là ai/ })
    .getByRole('link', { name: 'Kế toán', exact: true })
    .click();
  await expect(page).toHaveURL(/\/crm\/huong-dan\/theo-vai-ke-toan$/);
  // Cuối bài: Bài trước / Bài sau.
  const pager = page.getByRole('navigation', { name: 'Bài trước và bài sau' });
  await expect(pager.getByRole('link')).toHaveCount(2);
  await pager.getByRole('link', { name: /Bài sau/ }).click();
  await expect(page).not.toHaveURL(/theo-vai-ke-toan$/);
  // Địa chỉ cũ (trước khi gộp menu) chuyển sang mục mới.
  await page.goto('/crm/huong-dan/sale');
  await expect(page).toHaveURL(/\/crm\/huong-dan\/theo-vai-tu-van$/);
});

test('Hướng dẫn: menu «Theo vai trò»: mỗi vai một mục bấm mở/đóng, không có nhóm «Theo phân hệ», không chữ «Vai:»; vào bài con thì vai mở sẵn (A-24-07)', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/huong-dan');
  const nav = page.getByRole('navigation', { name: 'Mục hướng dẫn' });
  await expect(nav.getByText('Theo phân hệ')).toHaveCount(0);
  await expect(nav.getByText(/^Vai: /)).toHaveCount(0);
  const cha = nav.getByRole('button', { expanded: false }).first();
  await expect(cha).toBeVisible();
  await cha.click();
  await expect(nav.getByRole('button', { expanded: true }).first()).toBeVisible();
  const con = nav.locator('ul[id^="huong-dan-vai-"] a').first();
  await con.click();
  await expect(nav.getByRole('button', { expanded: true }).first()).toBeVisible();
  await expect(nav.locator('a[aria-current="page"]')).toHaveCount(1);
});
