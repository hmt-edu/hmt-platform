import { expect, test } from '@playwright/test';
import { expectAccessible } from './helpers';

const ENV_LABELS = ['Local', 'Xem trước', 'Thử nghiệm', 'Chạy thật', 'Không rõ'];

test('trang kiểm tra kết nối hiện môi trường và trạng thái cơ sở dữ liệu', async ({ page }) => {
  await page.goto('/trang-thai');
  const envLabel = page.getByTestId('env-label');
  await expect(envLabel).toBeVisible();
  expect(ENV_LABELS).toContain((await envLabel.textContent())?.trim());
  await expect(page.getByTestId('db-status')).toBeVisible();
});

test('đường dẫn gốc khi chưa đăng nhập: về trang đăng nhập', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/\/dang-nhap$/);
});

for (const [path, loginUrl, heading] of [
  ['/crm', /\/dang-nhap\?next=%2Fcrm$/, 'Đăng nhập'],
  ['/gv', /\/dang-nhap\?next=%2Fgv$/, 'Đăng nhập'],
  ['/hoc', /\/dang-nhap\/hoc-sinh\?next=%2Fhoc$/, 'Đăng nhập học tập'],
] as const) {
  test(`${path} khi chưa đăng nhập chuyển sang trang đăng nhập`, async ({ page }) => {
    await page.goto(path);
    await expect(page).toHaveURL(loginUrl);
    await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
  });
}

test('CHUNG-17: địa chỉ không tồn tại hiện trang không tìm thấy', async ({ page }) => {
  await page.goto('/khong-ton-tai');
  await expect(page.getByRole('heading', { level: 1, name: 'Không tìm thấy trang' })).toBeVisible();
});

for (const [name, path] of [
  ['CHUNG-01 đăng nhập nhân viên', '/dang-nhap'],
  ['CHUNG-06 đăng nhập học sinh', '/dang-nhap/hoc-sinh'],
  ['CHUNG-04 quên mật khẩu', '/quen-mat-khau'],
  ['CHUNG-05 đặt mật khẩu (đường dẫn hết hạn)', '/dat-mat-khau'],
  ['CHUNG-08 không đăng nhập được', '/khong-dang-nhap-duoc?ly-do=tam-chan'],
  ['CHUNG-17 không tìm thấy', '/khong-ton-tai'],
] as const) {
  test(`kiểm truy cập (axe): ${name}`, async ({ page }) => {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expectAccessible(page);
  });
}

test('CHUNG-01: thiếu thông tin thì báo ngay tại ô, không gửi đi', async ({ page }) => {
  await page.goto('/dang-nhap');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page.getByText('Nhập email.')).toBeVisible();
  await expect(page.getByText('Nhập mật khẩu.')).toBeVisible();
  await expect(page.getByLabel('Email', { exact: true })).toHaveAttribute('aria-invalid', 'true');
});

test('CHUNG-04: gửi yêu cầu đặt lại mật khẩu luôn trả cùng một câu (không lộ email có tài khoản hay không)', async ({
  page,
}) => {
  await page.goto('/quen-mat-khau');
  await page.getByLabel('Email', { exact: true }).fill('khongco@thu.hoamatoan.invalid');
  await page.getByRole('button', { name: 'Gửi email đặt lại mật khẩu' }).click();
  await expect(page.getByText('Nếu email này có tài khoản')).toBeVisible();
});

test('CHUNG-08: thông báo chung, không nói tài khoản bị khoá', async ({ page }) => {
  await page.goto('/khong-dang-nhap-duoc?ly-do=tam-chan');
  await expect(page.getByRole('heading', { level: 1, name: 'Không đăng nhập được' })).toBeVisible();
  await expect(page.getByText('Đăng nhập tạm thời bị chặn, thử lại sau.')).toBeVisible();
  await expect(page.getByText(/bị khoá/)).toHaveCount(0);
});
