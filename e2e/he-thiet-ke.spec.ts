// PR 2: hệ thiết kế qua trang mẫu thành phần (/dev/khuon, chỉ có ở bản không phải chạy thật) và khung CRM mới.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone, openCrmMenu } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('trang mẫu thành phần: đạt kiểm truy cập, đổi Stage, hộp thoại giữ focus và đóng bằng Esc', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/dev/khuon');
  await expect(page.getByRole('heading', { level: 1, name: 'Trang mẫu thành phần' })).toBeVisible();
  await expectAccessible(page);

  // Thanh Stage: bước đang ở có aria-current; bước đã qua bấm không được (chỉ đi tới).
  const stage = page.getByRole('navigation', { name: 'Giai đoạn' });
  await expect(stage.getByRole('button', { name: /^L4/ })).toHaveAttribute('aria-current', 'step');
  await expect(stage.getByRole('button', { name: /^L2/ })).toHaveAttribute('aria-disabled', 'true');
  await stage.getByRole('button', { name: /^L5/ }).click();
  // Toast có hai bản (hiện và vùng đọc cho trình đọc màn hình): lấy bản đầu.
  await expect(page.getByText('Đã chuyển sang L5').first()).toBeVisible();
  await expect(stage.getByRole('button', { name: /^L5/ })).toHaveAttribute('aria-current', 'step');

  // Hộp thoại: focus vào trong hộp, Esc đóng, focus trả về nút đã mở.
  const open = page.getByRole('button', { name: 'Mở hộp thoại' });
  await open.click();
  const dialog = page.getByRole('dialog', { name: 'Từ chối đơn hàng' });
  await expect(dialog).toBeVisible();
  await expectAccessible(page);
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  // Safari trên điện thoại không đưa focus vào nút khi chạm nên chỉ kiểm trả focus ở máy tính (bàn phím).
  if (!isPhone(page)) await expect(open).toBeFocused();

  // Ngăn kéo bên phải (K07b).
  await page.getByRole('button', { name: 'Mở ngăn kéo' }).click();
  await expect(page.getByRole('dialog', { name: 'Tạo nhanh lead' })).toBeVisible();
  await page.keyboard.press('Escape');
});

test('khung CRM: menu tối theo quyền, đường dẫn trên thanh trên, chuông chưa dùng được', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  // Thanh trên: đường dẫn, dòng "vai trò · cơ sở" dưới tên (kiểm trước khi mở ngăn kéo menu trên điện thoại).
  const crumbs = page.getByRole('navigation', { name: 'Đường dẫn' });
  await expect(crumbs).toContainText('Trang chủ');
  if (!isPhone(page)) {
    await expect(page.getByTestId('ten-nguoi-dung')).toBeVisible();
    // Thanh tài khoản (T13): vai trò và cơ sở mỗi thứ một dòng dưới tên, không còn dấu «·».
    const account = page.getByTestId('ten-nguoi-dung').locator('..');
    await expect(account).toContainText('Tuyển sinh');
    await expect(account).toContainText('CS5 Mỹ Đình');
  }
  await expect(page.getByRole('button', { name: /^Thông báo/ })).toBeEnabled();
  await expectAccessible(page);

  const menu = await openCrmMenu(page);
  // Sale thấy Tuyển sinh, không thấy Quản trị.
  await expect(menu.getByRole('button', { name: 'Tuyển sinh', exact: true })).toBeVisible();
  await expect(menu.getByRole('button', { name: 'Quản trị', exact: true })).toHaveCount(0);
});
