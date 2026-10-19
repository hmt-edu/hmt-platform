// Nhóm đăng nhập (P1) theo gói thiết kế hiện hành design/hmt-p0-p2 (DN01 đến DN10): các nét chính của bản vẽ.
// Lỗi đã gặp: dựng theo gói cũ design/hmt-platform nên ô nhập thấp, có dấu *, nút "Hiện" bằng chữ, câu lỗi nằm dưới nút.
import { expect, test } from '@playwright/test';
import { DOMAIN, PASSWORD, loginStaff } from './helpers';

const INPUT_HEIGHT = 44; // ô nhập và nút của nhóm đăng nhập cao 44px (bản vẽ)

test('DN01: ô và nút cao 44px, nhãn không có dấu *, mật khẩu có nút con mắt, liên kết căn giữa không gạch chân', async ({
  page,
}) => {
  await page.goto('/dang-nhap');
  await expect(page.getByText('Dành cho nhân viên, giáo viên và trợ giảng.')).toBeVisible();
  const email = page.getByLabel('Email', { exact: true });
  const password = page.getByLabel('Mật khẩu', { exact: true });
  expect((await email.boundingBox())?.height).toBe(INPUT_HEIGHT);
  expect((await password.boundingBox())?.height).toBe(INPUT_HEIGHT);
  expect(
    (await page.getByRole('button', { name: 'Đăng nhập', exact: true }).boundingBox())?.height,
  ).toBe(INPUT_HEIGHT);
  // Nhãn trơn: không có dấu * (ô vẫn báo bắt buộc cho trình đọc màn hình).
  await expect(page.locator('label', { hasText: /^Email$/ })).toBeVisible();
  await expect(page.locator('label', { hasText: /^Mật khẩu$/ })).toBeVisible();
  await expect(email).toHaveAttribute('aria-required', 'true');
  // Nút con mắt, không phải chữ "Hiện".
  const eye = page.getByRole('button', { name: 'Hiện mật khẩu' });
  await expect(eye).toHaveText('');
  await password.fill('MatKhau1234');
  await eye.click();
  await expect(password).toHaveAttribute('type', 'text');
  await expect(page.getByRole('button', { name: 'Ẩn mật khẩu' })).toBeVisible();
  // Liên kết căn giữa cột biểu mẫu, không gạch chân.
  const form = (await email.boundingBox()) ?? { x: 0, width: 0 };
  const forgot = page.getByRole('link', { name: 'Quên mật khẩu?' });
  const box = (await forgot.boundingBox()) ?? { x: 0, width: 0 };
  expect(Math.abs(box.x + box.width / 2 - (form.x + form.width / 2))).toBeLessThan(4);
  await expect(forgot).toHaveCSS('text-decoration-line', 'none');
  await expect(page.getByText('Học sinh?')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Đăng nhập bằng mã học sinh' })).toBeVisible();
});

test('DN01: sai thông tin thì câu lỗi nằm trên các ô, hai ô viền đỏ, mật khẩu đã gõ vẫn còn', async ({
  page,
}) => {
  test.skip(!PASSWORD, 'Cần SEED_PASSWORD (kết nối cơ sở dữ liệu thử).');
  await page.goto('/dang-nhap');
  const email = page.getByLabel('Email', { exact: true });
  const password = page.getByLabel('Mật khẩu', { exact: true });
  await email.fill(`khong-co@${DOMAIN}`);
  await password.fill('MatKhauSai1');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  const alert = page.getByRole('alert');
  await expect(alert).toHaveText('Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa.');
  expect((await alert.boundingBox())?.y).toBeLessThan((await email.boundingBox())?.y ?? 0);
  await expect(email).toHaveAttribute('aria-invalid', 'true');
  await expect(password).toHaveAttribute('aria-invalid', 'true');
  await expect(password).toHaveValue('MatKhauSai1');
});

test('DN02: học sinh "Chào em", có khối nhắc quên mật khẩu và liên kết sang đăng nhập nhân viên', async ({
  page,
}) => {
  await page.goto('/dang-nhap/hoc-sinh');
  await expect(page.getByRole('heading', { level: 1, name: 'Chào em' })).toBeVisible();
  await expect(page.getByText('Đăng nhập để xem bài tập, lịch học và kết quả.')).toBeVisible();
  await expect(page.getByLabel('Mã học sinh', { exact: true })).toHaveAttribute(
    'placeholder',
    'HS000212',
  );
  await expect(page.getByRole('button', { name: 'Vào học', exact: true })).toBeVisible();
  await expect(
    page.getByRole('status').filter({ hasText: 'Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng' }),
  ).toBeVisible();
  await expect(page.getByText('Nhân viên, giáo viên:')).toBeVisible();
  await page.getByRole('link', { name: 'đăng nhập ở đây' }).click();
  await expect(page).toHaveURL(/\/dang-nhap$/);
});

test('DN05, DN08: câu hướng dẫn nằm dưới tiêu đề, một nút "Quay lại đăng nhập" không biểu tượng', async ({
  page,
}) => {
  await page.goto('/quen-mat-khau');
  await expect(
    page.getByText('Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.'),
  ).toBeVisible();
  const back = page.getByRole('link', { name: 'Quay lại đăng nhập' });
  await expect(back.locator('svg')).toHaveCount(0);
  expect((await back.boundingBox())?.height).toBe(INPUT_HEIGHT);

  await page.goto('/khong-dang-nhap-duoc');
  await expect(page.getByRole('heading', { level: 1, name: 'Không thể đăng nhập' })).toBeVisible();
  await expect(
    page.getByText(
      'Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.',
    ),
  ).toBeVisible();
  await expect(page.getByRole('link', { name: 'Quay lại đăng nhập' })).toBeVisible();
});

test('DN09: hộp hết phiên có biểu tượng đồng hồ, không có nút đóng, chú nhỏ về trang đang mở', async ({
  page,
}) => {
  test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');
  await page.clock.install();
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.clock.fastForward('01:05:00');
  const dialog = page.getByRole('dialog', { name: 'Phiên làm việc đã hết' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('button', { name: /Đóng/ })).toHaveCount(0);
  await expect(dialog.getByText('Đăng nhập lại xong sẽ quay về đúng trang đang mở.')).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Đăng nhập lại' })).toBeVisible();
});
