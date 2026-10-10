import { expect, test, type Page } from '@playwright/test';

// Đăng nhập từng vai trò bằng tài khoản giả (scripts/seed-users.mjs), cỡ máy tính và điện thoại.
// Cần SEED_PASSWORD (CI tự sinh; local đặt trong môi trường) và Supabase local đã chạy seed-users.
const PASSWORD = process.env.SEED_PASSWORD ?? '';
const DOMAIN = 'thu.hoamatoan.invalid';

test.skip(!PASSWORD, 'Chưa có SEED_PASSWORD: bỏ qua kiểm thử đăng nhập.');

async function login(page: Page, login: string, password = PASSWORD) {
  await page.goto('/dang-nhap');
  await page.getByLabel('Email hoặc mã học sinh').fill(login);
  await page.getByLabel('Mật khẩu').fill(password);
  await page.getByRole('button', { name: 'Đăng nhập' }).click();
}

for (const [account, portal, heading] of [
  ['sale.cs5', '/crm', 'Cổng CRM'],
  ['truongcs.cs5', '/crm', 'Cổng CRM'],
  ['cskh.cs1', '/crm', 'Cổng CRM'],
  ['gv.cs5', '/gv', 'Cổng Giáo viên'],
  ['tg.cs5', '/gv', 'Cổng Giáo viên'],
] as const) {
  test(`${account} đăng nhập vào đúng cổng ${portal}`, async ({ page }) => {
    await login(page, `${account}@${DOMAIN}`);
    await expect(page).toHaveURL(new RegExp(`${portal}$`));
    await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
    await expect(page.getByTestId('ten-nguoi-dung')).toContainText('(giả)');
  });
}

test('sale vào cổng Giáo viên: báo rõ không có quyền', async ({ page }) => {
  await login(page, `sale.cs5@${DOMAIN}`);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/gv');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền vào cổng Giáo viên' }),
  ).toBeVisible();
});

test('giáo viên không thấy cổng CRM trên menu', async ({ page }) => {
  await login(page, `gv.cs5@${DOMAIN}`);
  await expect(page).toHaveURL(/\/gv$/);
  await expect(page.getByRole('navigation').getByRole('link', { name: 'CRM' })).toHaveCount(0);
});

test('sai mật khẩu: báo lỗi, không vào được', async ({ page }) => {
  await login(page, `cskh.cs5@${DOMAIN}`, 'saiMatKhau123');
  await expect(page.getByRole('alert')).toHaveText('Tên đăng nhập hoặc mật khẩu không đúng.');
  await expect(page).toHaveURL(/\/dang-nhap/);
});

test('tài khoản bị khoá không đăng nhập được, báo giống sai mật khẩu', async ({ page }) => {
  await login(page, `khoa.cs5@${DOMAIN}`);
  await expect(page.getByRole('alert')).toHaveText('Tên đăng nhập hoặc mật khẩu không đúng.');
});

test('tài khoản không có: báo giống sai mật khẩu (không lộ ai có tài khoản)', async ({ page }) => {
  await login(page, `khongco@${DOMAIN}`);
  await expect(page.getByRole('alert')).toHaveText('Tên đăng nhập hoặc mật khẩu không đúng.');
});

test('học sinh đăng nhập bằng mã HS, bị yêu cầu đổi mật khẩu lần đầu', async ({ page }) => {
  await login(page, 'hs900001');
  await expect(page).toHaveURL(/\/doi-mat-khau$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Đổi mật khẩu' })).toBeVisible();
  await page.goto('/hoc');
  await expect(page).toHaveURL(/\/doi-mat-khau$/);
});

test('Admin đăng nhập: bắt xác thực hai bước trước khi vào cổng', async ({ page }) => {
  await login(page, `admin.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/xac-thuc-hai-buoc$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Xác thực hai bước' })).toBeVisible();
  await page.goto('/crm');
  await expect(page).toHaveURL(/\/xac-thuc-hai-buoc$/);
});

test('đăng xuất: quay lại trang đăng nhập, không vào lại cổng được', async ({ page }) => {
  await login(page, `truongcs.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/crm$/);
  await page.getByRole('button', { name: 'Đăng xuất' }).click();
  await expect(page).toHaveURL(/\/dang-nhap/);
  await page.goto('/crm');
  await expect(page).toHaveURL(/\/dang-nhap/);
});
