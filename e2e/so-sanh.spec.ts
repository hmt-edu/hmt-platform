// Chụp từng màn ở trạng thái mặc định, đặt cạnh ảnh thiết kế (design/hmt-platform/screens/<MÃ>.png),
// lưu docs/so-sanh/<MÃ>.jpg (đã nén) để đưa vào mô tả PR. Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh.spec.ts --project=may-tinh
// Chạy xong thì chạy lại `npm run db:seed-users` (kịch bản đổi mật khẩu học sinh giả để vào cổng Học tập).
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { generateSync } from 'otplib';
import pg from 'pg';
import { DOMAIN, PASSWORD, fillLogin, loginStaff, loginStudent, signOut } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
// Playwright chạy từ thư mục gốc của repo.
const DESIGN_DIR = join(process.cwd(), 'design', 'hmt-platform', 'screens');
const OUT_DIR = join(process.cwd(), 'docs', 'so-sanh');
const DESKTOP = { width: 1440, height: 900 };
const PHONE = { width: 390, height: 844 };
const JPEG_QUALITY = 70;

test.skip(
  !process.env.SO_SANH || !PASSWORD || !DB_URL,
  'Chỉ chạy khi SO_SANH=1 và có SEED_PASSWORD, DB_URL.',
);
test.describe.configure({ mode: 'serial' });

/** Ghép ảnh thiết kế (nếu có) và ảnh bản dựng thành một ảnh JPEG. */
async function save(browser: Browser, page: Page, code: string, suffix = '') {
  await page.waitForTimeout(400);
  // Che mã QR và khoá TOTP: là bí mật, kể cả của tài khoản giả.
  const shot = await page.screenshot({
    type: 'png',
    mask: [page.locator('img[alt^="Mã QR"]'), page.locator('code')],
  });
  const designPath = join(DESIGN_DIR, `${code}.png`);
  const design = existsSync(designPath) ? readFileSync(designPath).toString('base64') : null;
  const narrow = suffix !== '';
  const composer = await browser.newPage({
    viewport: { width: design ? 1800 : narrow ? 480 : 1000, height: 800 },
  });
  const figure = (title: string, data: string, width: string) =>
    `<figure style="margin:0;width:${width}"><figcaption style="font:600 14px system-ui;padding:6px 0">${title}</figcaption>` +
    `<img src="data:image/png;base64,${data}" style="width:100%;border:1px solid #bbb;display:block"></figure>`;
  await composer.setContent(
    `<body style="margin:0;padding:12px;background:#fff"><div style="display:flex;gap:16px;align-items:flex-start">` +
      (design ? figure(`${code} · Thiết kế`, design, narrow ? '70%' : '50%') : '') +
      figure(
        `${code} · Bản dựng${suffix ? ` (${suffix})` : ''}`,
        shot.toString('base64'),
        design ? (narrow ? '30%' : '50%') : '100%',
      ) +
      `</div></body>`,
  );
  mkdirSync(OUT_DIR, { recursive: true });
  const name = `${code}${suffix ? '-dien-thoai' : ''}.jpg`;
  await composer.screenshot({
    path: join(OUT_DIR, name),
    type: 'jpeg',
    quality: JPEG_QUALITY,
    fullPage: true,
  });
  await composer.close();
}

async function clearTotp(email: string) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  await db.query(
    'delete from auth.mfa_factors where user_id = (select id from auth.users where email = $1)',
    [email],
  );
  await db.end();
}

test('màn đăng nhập và các trang đơn (K11)', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await page.goto('/dang-nhap');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-01');
  await page.goto('/quen-mat-khau');
  await save(browser, page, 'CHUNG-04');
  await page.goto('/dat-mat-khau');
  await save(browser, page, 'CHUNG-05');
  await page.goto('/khong-dang-nhap-duoc?ly-do=tam-chan');
  await save(browser, page, 'CHUNG-08');
  await page.goto('/khong-ton-tai');
  await save(browser, page, 'CHUNG-17');

  await page.setViewportSize(PHONE);
  await page.goto('/dang-nhap');
  await save(browser, page, 'CHUNG-01', 'điện thoại');
  await page.goto('/dang-nhap/hoc-sinh');
  await save(browser, page, 'CHUNG-06', 'điện thoại');
});

test('hai bước, khung CRM của Admin, hồ sơ cá nhân, chọn cổng', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await clearTotp(`admin.cs1@${DOMAIN}`);
  await loginStaff(page, 'admin.cs1');
  await expect(page).toHaveURL(/\/thiet-lap-hai-buoc$/);
  await expect(page.locator('code')).toBeVisible();
  await save(browser, page, 'CHUNG-03');
  const secret = (await page.locator('code').first().textContent())?.trim() ?? '';
  await page.getByRole('button', { name: 'Tiếp', exact: true }).click();
  await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
  await page.getByRole('button', { name: 'Hoàn tất' }).click();
  await expect(page).toHaveURL(/\/crm$/);
  await page.getByRole('button', { name: 'Quản trị', exact: true }).click();
  await save(browser, page, 'CHUNG-10');
  await page.goto('/crm/tai-khoan');
  await expect(page.getByText('Thiết bị 1')).toBeVisible();
  await save(browser, page, 'CHUNG-13');
  await page.goto('/chon-cong');
  await save(browser, page, 'CHUNG-25');

  await page.setViewportSize(PHONE);
  await page.goto('/crm');
  await page.getByRole('button', { name: 'Mở menu' }).click();
  await save(browser, page, 'CHUNG-10', 'điện thoại');
  await page.keyboard.press('Escape');
  await page.setViewportSize(DESKTOP);
  await signOut(page);
  await fillLogin(page, 'Email', `admin.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/xac-thuc-hai-buoc$/);
  await save(browser, page, 'CHUNG-02');
});

test('không có quyền, phân hệ chưa bật, hết phiên', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await page.clock.install();
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/quan-tri/nguoi-dung');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-16');
  await page.clock.fastForward('01:05:00');
  await expect(page.getByRole('dialog', { name: 'Hết phiên làm việc' })).toBeVisible();
  await save(browser, page, 'CHUNG-09');
  await page.getByRole('button', { name: 'Đăng nhập lại' }).click();
  await page.clock.setSystemTime(new Date());

  await fillLogin(page, 'Email', `cskh.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/crm/);
  await page.goto('/crm/lead');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-24');
});

test('khung cổng Giáo viên và cổng Học tập', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await save(browser, page, 'GV-01');
  await page.setViewportSize(PHONE);
  await save(browser, page, 'GV-01', 'điện thoại');
  await signOut(page);

  await page.setViewportSize(DESKTOP);
  await loginStudent(page, 'hs900001');
  await expect(page).toHaveURL(/\/doi-mat-khau$/);
  await save(browser, page, 'CHUNG-07');
  const newPassword = `Moi${Date.now()}a`;
  await page.getByLabel('Mật khẩu mới', { exact: true }).fill(newPassword);
  await page.getByLabel('Nhập lại mật khẩu mới', { exact: true }).fill(newPassword);
  await page.getByRole('button', { name: 'Lưu mật khẩu mới' }).click();
  await expect(page).toHaveURL(/\/hoc$/);
  await save(browser, page, 'HT-09');
  await page.setViewportSize(PHONE);
  await save(browser, page, 'HT-09', 'điện thoại');
});
