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
  ['CHUNG-08 không đăng nhập được', '/khong-dang-nhap-duoc'],
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

test('CHUNG-04: chỉ hướng dẫn liên hệ quản trị viên, không có ô email và không gửi email', async ({
  page,
}) => {
  const mail: string[] = [];
  page.on('request', (r) => {
    if (r.url().includes('/auth/v1/recover')) mail.push(r.url());
  });
  await page.goto('/quen-mat-khau');
  await expect(page.getByRole('heading', { level: 1, name: 'Quên mật khẩu' })).toBeVisible();
  await expect(
    page.getByText('Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.'),
  ).toBeVisible();
  await expect(page.getByLabel('Email')).toHaveCount(0);
  await page.getByRole('link', { name: 'Quay lại đăng nhập' }).click();
  await expect(page).toHaveURL(/\/dang-nhap$/);
  expect(mail).toHaveLength(0);
});

test('CHUNG-08: một câu chung, không nói lý do hay thời gian khoá', async ({ page }) => {
  await page.goto('/khong-dang-nhap-duoc');
  await expect(page.getByRole('heading', { level: 1, name: 'Không thể đăng nhập' })).toBeVisible();
  await expect(
    page.getByText(
      'Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.',
    ),
  ).toBeVisible();
  await expect(page.getByText(/bị khoá|tạm thời bị chặn|phút/)).toHaveCount(0);
  // Địa chỉ không mang tham số nào (trước đây có đuôi nói lý do tạm chặn).
  await expect(page).toHaveURL(/\/khong-dang-nhap-duoc$/);
});

test('cột giới thiệu của trang đăng nhập có nền cam (lỗi đã gặp: khai báo nền sai nên cột trắng, chữ trắng không đọc được)', async ({
  page,
}) => {
  await page.goto('/dang-nhap');
  const panel = page.getByRole('complementary', { name: 'Giới thiệu hệ thống' });
  test.skip(!(await panel.isVisible()), 'Điện thoại không có cột giới thiệu.');
  await expect(panel).not.toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
  await expect(panel).not.toHaveCSS('background-color', 'rgb(255, 255, 255)');
});
