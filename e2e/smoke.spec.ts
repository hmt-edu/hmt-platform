import { expect, test } from '@playwright/test';

const ENV_LABELS = ['Local', 'Xem trước', 'Thử nghiệm', 'Chạy thật', 'Không rõ'];

test('trang chủ hiện môi trường và ô trạng thái cơ sở dữ liệu', async ({ page }) => {
  await page.goto('/');
  const envLabel = page.getByTestId('env-label');
  await expect(envLabel).toBeVisible();
  expect(ENV_LABELS).toContain((await envLabel.textContent())?.trim());
  await expect(page.getByTestId('db-status')).toBeVisible();
});

for (const [path, title] of [
  ['/crm', 'Cổng CRM'],
  ['/gv', 'Cổng Giáo viên'],
  ['/hoc', 'Cổng Học tập'],
] as const) {
  test(`${path} hiện tiêu đề "${title}"`, async ({ page }) => {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
  });
}

test('địa chỉ không tồn tại hiện trang 404', async ({ page }) => {
  await page.goto('/khong-ton-tai');
  await expect(page.getByRole('heading', { level: 1, name: 'Không tìm thấy trang' })).toBeVisible();
});
