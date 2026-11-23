import { expect, test, type Page } from '@playwright/test';
import { generateSync } from 'otplib';
import pg from 'pg';
import {
  DOMAIN,
  PASSWORD,
  expectAccessible,
  isPhone,
  loginStaff,
  loginStaffUntil,
  loginStudent,
  openCrmMenu,
  signOut,
} from './helpers';

// Đăng nhập từng vai trò bằng tài khoản giả, ở hai cỡ màn. Cần Supabase local đã chạy seed-users.
test.skip(!PASSWORD, 'Chưa có SEED_PASSWORD: bỏ qua kiểm thử đăng nhập.');

const WRONG = 'Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa.';

for (const [account, portal, heading] of [
  ['sale.cs5', '/crm', 'Việc của tôi hôm nay'],
  ['truongcs.cs5', '/crm', 'Việc của tôi hôm nay'],
  ['cskh.cs1', '/crm', 'Việc của tôi hôm nay'],
  ['gv.cs5', '/gv', 'Hôm nay'],
  ['tg.cs5', '/gv', 'Hôm nay'],
] as const) {
  test(`${account} đăng nhập vào đúng cổng ${portal}`, async ({ page }) => {
    await loginStaff(page, account);
    await expect(page).toHaveURL(new RegExp(`${portal}$`));
    await expect(page.getByRole('heading', { name: heading }).first()).toBeVisible();
    await expect(page.getByRole('button', { name: /\(giả\).* Tài khoản$/ })).toBeVisible();
  });
}

test('CHUNG-16: sale mở cổng Giáo viên thì báo rõ không có quyền', async ({ page }) => {
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/gv');
  await expect(
    page.getByRole('heading', { name: 'Tài khoản chưa liên kết hồ sơ giáo viên' }),
  ).toBeVisible();
  await expectAccessible(page);
  // Trang chặn luôn có lối thoát: Đăng xuất để dùng tài khoản khác (không bị kẹt).
  await page.getByRole('button', { name: 'Đăng xuất' }).click();
  await expect(page).toHaveURL(/\/dang-nhap/);
});

test('trang /khong-co-quyen có nút Đăng xuất (không kẹt tài khoản)', async ({ page }) => {
  await loginStaff(page, 'sale.cs5');
  await page.goto('/khong-co-quyen');
  await expect(
    page.getByRole('heading', { name: 'Tài khoản chưa được cấp cổng nào' }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Đăng xuất' }).click();
  await expect(page).toHaveURL(/\/dang-nhap/);
});

test('đăng nhập xong tự về đúng cổng của mình khi địa chỉ đang mở dở thuộc cổng khác', async ({
  page,
}) => {
  await page.goto('/crm');
  await expect(page).toHaveURL(/\/dang-nhap\?next=%2Fcrm$/);
  await page.getByLabel('Email', { exact: true }).fill(`gv.cs5@${DOMAIN}`);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/gv$/);
});

test('CHUNG-10: menu dựng từ ma trận quyền; mở link ngoài quyền gặp CHUNG-16', async ({ page }) => {
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  const menu = await openCrmMenu(page);
  await expect(menu.getByRole('button', { name: 'Tuyển sinh', exact: true })).toBeVisible();
  await expect(menu.getByRole('button', { name: 'Quản trị', exact: true })).toHaveCount(0);
  await expect(menu.getByRole('button', { name: 'Báo cáo', exact: true })).toHaveCount(0);
  await menu.getByRole('button', { name: 'Tuyển sinh', exact: true }).click();
  await menu.getByRole('link', { name: 'Lead' }).click();
  await expect(page).toHaveURL(/\/crm\/lead$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  // Màn Lead, Cơ hội là màn thật (P3c, P3d); màn Phiếu kiểm tra là màn thật (P3e). «Việc chờ tôi duyệt» (CHUNG-15) là màn thật: nhân viên bán hàng
  // có một quyền Duyệt nên mở được, và chưa có việc nào đến lượt thì thấy trạng thái trống.
  await page.goto('/crm/viec-cho-duyet');
  await expect(page.getByRole('heading', { level: 1, name: 'Việc chờ tôi duyệt' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Không có việc chờ duyệt' })).toBeVisible();

  await page.goto('/crm/quan-tri/nguoi-dung');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
  ).toBeVisible();
  await page.goto('/crm/khong-co-trang-nay');
  await expect(page.getByRole('heading', { level: 1, name: 'Không tìm thấy trang' })).toBeVisible();
});

test('CHUNG-24: phân hệ chưa bật ở cơ sở thì ẩn khỏi menu, mở link thì báo chưa bật', async ({
  page,
}) => {
  // Dữ liệu giả: phân hệ Bán hàng chỉ bật ở CS5.
  await loginStaff(page, 'cskh.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  const menu = await openCrmMenu(page);
  await expect(menu.getByRole('button', { name: 'Khách hàng', exact: true })).toBeVisible();
  await expect(menu.getByRole('button', { name: 'Tuyển sinh', exact: true })).toHaveCount(0);
  await page.goto('/crm/lead');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Phân hệ chưa bật ở cơ sở này' }),
  ).toBeVisible();
});

test('GV-01: giáo viên chỉ có cổng Giáo viên; điện thoại có thanh dưới, laptop có menu trái', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  const nav = page.getByRole('navigation', {
    name: isPhone(page) ? 'Thanh điều hướng Cổng Giáo viên' : 'Menu Cổng Giáo viên',
  });
  // Menu «Cần làm» có thể kèm số đếm công việc (R-V2-37, E73) tuỳ dữ liệu giả lúc chạy: nhãn chấp nhận số sau chữ.
  await expect(nav.getByRole('link')).toHaveText([
    'Hôm nay',
    'Lịch dạy',
    'Lớp',
    /^Cần làm\d*\+?$/,
    'Tài khoản',
  ]);
  await nav.getByRole('link', { name: 'Lịch dạy' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch dạy' })).toBeVisible();
  await expect(page.locator('html')).toHaveAttribute('data-product', 'teacher');
  await expectAccessible(page);
  await page.goto('/crm');
  await expect(
    page.getByRole('heading', { name: 'Bạn không có quyền vào cổng CRM' }),
  ).toBeVisible();
});

test('sai mật khẩu, tài khoản bị khoá, tài khoản không có: cùng một câu báo lỗi', async ({
  page,
}) => {
  await loginStaff(page, 'cskh.cs5', 'saiMatKhau123');
  await expect(page.getByRole('alert')).toHaveText(WRONG);
  await expect(page).toHaveURL(/\/dang-nhap/);
  await loginStaff(page, 'khoa.cs5');
  await expect(page.getByRole('alert')).toHaveText(WRONG);
  await loginStaff(page, 'khongco');
  await expect(page.getByRole('alert')).toHaveText(WRONG);
  // Đăng nhập đúng để xoá đếm lần sai (chạy lại nhiều lần trên máy không bị khoá tạm).
  await loginStaff(page, 'cskh.cs5');
  await expect(page).toHaveURL(/\/crm$/);
});

test('CHUNG-06, CHUNG-07: học sinh đăng nhập bằng mã HS vào thẳng cổng học, không bị bắt đổi mật khẩu lần đầu (E31)', async ({
  page,
}) => {
  await loginStudent(page, 'hs900001');
  await expect(page).toHaveURL(/\/hoc$/);
  await expect(page.locator('html')).toHaveAttribute('data-product', 'lms');
  // Tham số «Học sinh bắt đổi mật khẩu lần đầu» mặc định Tắt: màn đổi mật khẩu không chặn; mở thẳng vẫn vào được cổng học.
  await page.goto('/hoc');
  await expect(page).toHaveURL(/\/hoc$/);
  await expectAccessible(page);
});

test('CHUNG-10, CHUNG-13: khung CRM và hồ sơ cá nhân đạt kiểm truy cập; đăng xuất về trang đăng nhập', async ({
  page,
}) => {
  await loginStaff(page, 'truongcs.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  await expect(page.locator('html')).toHaveAttribute('data-product', 'crm');
  await expectAccessible(page);
  await page.goto('/crm/tai-khoan');
  await expect(page.getByRole('heading', { level: 1, name: 'Hồ sơ cá nhân' })).toBeVisible();
  // Vai trò không bắt hai bước thì không có mục xác thực hai bước.
  await expect(page.getByRole('heading', { name: 'Xác thực hai bước' })).toHaveCount(0);
  // Chờ luật mật khẩu tải xong (nút hết mờ) rồi mới kiểm tương phản.
  await expect(page.getByRole('button', { name: 'Đổi mật khẩu' })).toBeEnabled();
  // S8: đổi mật khẩu trong hồ sơ phải hỏi mật khẩu hiện tại.
  await expect(page.getByLabel('Mật khẩu hiện tại')).toBeVisible();
  await page.waitForTimeout(300);
  await expectAccessible(page);
  await signOut(page);
  await expect(page).toHaveURL(/\/dang-nhap/);
  await page.goto('/crm');
  await expect(page).toHaveURL(/\/dang-nhap/);
});

test('CHUNG-09: không thao tác quá thời gian trong Cài đặt thì tự đăng xuất, hiện hộp thoại hết phiên', async ({
  page,
}) => {
  // Dùng đồng hồ giả của trình duyệt để tua thời gian thay vì chờ thật.
  await page.clock.install();
  await loginStaff(page, 'sale.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Việc của tôi hôm nay' })).toBeVisible();
  // Nhân viên: tự đăng xuất sau 60 phút không thao tác (tham số staff_idle_logout_minutes). Tua 65 phút.
  await page.clock.fastForward('01:05:00');
  await expect(page).toHaveURL(/\/dang-nhap/);
  const dialog = page.getByRole('dialog', { name: 'Phiên làm việc đã hết' });
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText('Bạn không thao tác quá 60 phút nên');
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Đăng nhập lại' }).click();
  await expect(dialog).toHaveCount(0);
  // Lỗi đã gặp: đăng nhập lại sau khi hết phiên thì bị đăng xuất ngay lần nữa (mốc thao tác cũ còn lưu).
  await page.clock.setSystemTime(new Date());
  await page.evaluate(() => localStorage.setItem('hmt:last-activity', '1'));
  await page.getByLabel('Email', { exact: true }).fill(`sale.cs1@${DOMAIN}`);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/crm$/);
  await page.waitForTimeout(1500);
  await expect(page).toHaveURL(/\/crm$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Việc của tôi hôm nay' })).toBeVisible();
});

test('P-100: trên điện thoại, nút và ô nhập của trang đăng nhập cao tối thiểu 44px', async ({
  page,
}) => {
  test.skip(!isPhone(page), 'Chỉ kiểm ở cỡ điện thoại.');
  await page.goto('/dang-nhap');
  for (const target of [
    page.getByLabel('Email', { exact: true }),
    page.getByLabel('Mật khẩu', { exact: true }),
    page.getByRole('button', { name: 'Đăng nhập', exact: true }),
  ]) {
    const box = await target.boundingBox();
    expect(box?.height ?? 0).toBeGreaterThanOrEqual(44);
  }
});

// ---------- Xác thực hai bước (CHUNG-02, CHUNG-03, CHUNG-13) ----------
// Mỗi cỡ màn dùng một tài khoản bắt hai bước riêng để hai lượt chạy song song không giẫm nhau.
const DB_URL = process.env.DB_URL ?? '';

async function clearTotp(email: string) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  await db.query(
    'delete from auth.mfa_factors where user_id = (select id from auth.users where email = $1)',
    [email],
  );
  await db.end();
}

async function enrollDevice(page: Page): Promise<string> {
  const secret = (await page.locator('code').first().textContent())?.replace(/\s+/g, '') ?? '';
  expect(secret.length).toBeGreaterThan(10);
  // Trang thiết lập lần đầu chia hai bước (Tiếp → Hoàn tất); hồ sơ cá nhân thêm thiết bị một bước (Xác nhận).
  const next = page.getByRole('button', { name: 'Tiếp', exact: true });
  if (await next.isVisible()) await next.click();
  await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
  await page.getByRole('button', { name: /^(Hoàn tất|Xác nhận)$/ }).click();
  return secret;
}

test('Admin, Kế toán: không bắt hai bước (D41), vào CRM bằng mật khẩu, tự nguyện thêm tối đa 2 thiết bị', async ({
  page,
}) => {
  test.skip(!DB_URL, 'Chưa có DB_URL: không dọn được thiết bị hai bước của tài khoản giả.');
  const phone = isPhone(page);
  const account = phone ? 'ketoan' : 'admin.cs1';
  await clearTotp(`${account}@${DOMAIN}`);

  // Tham số mfa_required_enabled tắt (mặc định): đăng nhập mật khẩu là vào thẳng CRM, không qua trang thiết lập.
  await loginStaffUntil(page, account, /\/crm$/);
  await page.goto('/crm');
  await expect(page).toHaveURL(/\/crm$/);

  if (!phone) {
    const menu = await openCrmMenu(page);
    await expect(menu.getByRole('button', { name: 'Quản trị', exact: true })).toBeVisible();
    // Ô chọn cơ sở của dữ liệu nghiệp vụ có CS3 từ 04/11/2026 (Đ286, R-V2-10; thay R-HT-02).
    // Chờ trang chủ dựng xong (quyền đã tải) rồi mới mở danh sách: bấm sớm quá thì Radix chưa nhận.
    await expect(
      page.getByRole('heading', { level: 1, name: 'Việc của tôi hôm nay' }),
    ).toBeVisible();
    await page.getByRole('combobox', { name: 'Cơ sở đang xem' }).click();
    await expect(page.getByRole('option')).toHaveText([
      'Tất cả cơ sở',
      'CS1 Nguyễn Chí Thanh',
      'CS2 Đỗ Quang',
      'CS4 Hà Đông',
      'CS5 Mỹ Đình',
      'CS3 Hội sở',
    ]);
    await page.keyboard.press('Escape');
  }

  await page.goto('/crm/tai-khoan');
  if (phone) {
    // A-23-27: Kế toán không thuộc diện hai bước, Hồ sơ không có mục «Xác thực hai bước». Phần thêm thiết bị chỉ thử với Admin (bản máy tính).
    await expect(page.getByRole('heading', { name: 'Đổi mật khẩu' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Xác thực hai bước' })).toHaveCount(0);
    return;
  }
  await expect(page.getByRole('heading', { name: 'Xác thực hai bước' })).toBeVisible();
  // Tự nguyện thêm thiết bị đầu tiên.
  await page.getByRole('button', { name: 'Thêm thiết bị' }).click();
  await enrollDevice(page);
  await expect(page.getByText('Thiết bị 1')).toBeVisible();
  // Chỉ còn một thiết bị thì không gỡ được.
  await expect(page.getByRole('button', { name: 'Gỡ' })).toBeDisabled();
  await page.getByRole('button', { name: 'Thêm thiết bị' }).click();
  await enrollDevice(page);
  await expect(page.getByText('Thiết bị 2')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm thiết bị' })).toBeDisabled();
  await expect(page.getByText('Đã đủ 2 thiết bị.')).toBeVisible();
  await expectAccessible(page);

  await page.getByRole('button', { name: 'Gỡ' }).first().click();
  await page.getByRole('dialog').getByRole('button', { name: 'Gỡ thiết bị' }).click();
  await expect(page.getByRole('button', { name: 'Gỡ' })).toHaveCount(1);
});
