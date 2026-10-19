// So bản dựng với gói thiết kế HIỆN HÀNH design/hmt-p0-p2/png (DN01 đến DN10, máy tính 1440×1000 và điện thoại 390×844).
// Ảnh ra thư mục tạm (docs/so-sanh khi đặt SO_SANH_GHI_VAO_REPO=1). Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh-dang-nhap.spec.ts --project=may-tinh
// Chạy xong thì chạy lại `npm run db:seed-users` (kịch bản đổi thiết bị hai bước, mật khẩu học sinh giả).
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { generateSync } from 'otplib';
import pg from 'pg';
import { DOMAIN, PASSWORD, fillLogin, loginStaff, loginStudent, signOut } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
const DESIGN_DIR = join(process.cwd(), 'design', 'hmt-p0-p2', 'png');
const OUT_DIR = process.env.SO_SANH_GHI_VAO_REPO
  ? join(process.cwd(), 'docs', 'so-sanh')
  : join(tmpdir(), 'hmt-so-sanh');
const DESKTOP = { width: 1440, height: 1000 };
const PHONE = { width: 390, height: 844 };

test.skip(
  !process.env.SO_SANH || !PASSWORD || !DB_URL,
  'Chỉ chạy khi SO_SANH=1 và có SEED_PASSWORD, DB_URL.',
);
test.describe.configure({ mode: 'serial' });

/** Ghép ảnh thiết kế (design/hmt-p0-p2/png/<tên>.png) với ảnh bản dựng thành một ảnh JPEG. */
async function save(browser: Browser, page: Page, name: string) {
  await page.waitForTimeout(500);
  const shot = await page.screenshot({
    type: 'png',
    mask: [page.locator('img[alt^="Mã QR"]'), page.locator('code')],
  });
  const designPath = join(DESIGN_DIR, `${name}.png`);
  const design = existsSync(designPath) ? readFileSync(designPath).toString('base64') : null;
  const phone = name.includes('_mb_');
  const composer = await browser.newPage({ viewport: { width: phone ? 900 : 1800, height: 800 } });
  const figure = (title: string, data: string) =>
    `<figure style="margin:0;flex:1"><figcaption style="font:600 14px system-ui;padding:6px 0">${title}</figcaption>` +
    `<img src="data:image/png;base64,${data}" style="width:100%;border:1px solid #bbb;display:block"></figure>`;
  await composer.setContent(
    `<body style="margin:0;padding:12px;background:#fff"><div style="display:flex;gap:16px;align-items:flex-start;${phone ? 'max-width:780px' : ''}">` +
      (design ? figure(`${name} · Thiết kế`, design) : '') +
      figure(`${name} · Bản dựng`, shot.toString('base64')) +
      `</div></body>`,
  );
  mkdirSync(OUT_DIR, { recursive: true });
  await composer.screenshot({
    path: join(OUT_DIR, `${name}.jpg`),
    type: 'jpeg',
    quality: 72,
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

async function size(page: Page, device: 'pc' | 'mb') {
  await page.setViewportSize(device === 'pc' ? DESKTOP : PHONE);
}

for (const device of ['pc', 'mb'] as const) {
  test(`DN01, DN02, DN05, DN08, DN07 (${device})`, async ({ page, browser }) => {
    await size(page, device);
    // DN01 nhân viên: bình thường và sai thông tin.
    await page.goto('/dang-nhap');
    await page.getByLabel('Email', { exact: true }).fill('ha.nguyen@hoamatoan.vn');
    await page.getByLabel('Mật khẩu', { exact: true }).fill('MatKhau1234');
    await save(browser, page, `DN01_${device}_ok`);
    await page.getByLabel('Email', { exact: true }).fill(`khong-co@${DOMAIN}`);
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await save(browser, page, `DN01_${device}_err`);
    // DN02 học sinh.
    await page.goto('/dang-nhap/hoc-sinh');
    await page.getByLabel('Mã học sinh', { exact: true }).fill('HS000123');
    await page.getByLabel('Mật khẩu', { exact: true }).fill('MatKhau1234');
    await save(browser, page, `DN02_${device}_ok`);
    await page.getByRole('button', { name: 'Vào học', exact: true }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await save(browser, page, `DN02_${device}_err`);
    // DN05, DN08.
    await page.goto('/quen-mat-khau');
    await save(browser, page, `DN05_${device}_form`);
    await page.goto('/khong-dang-nhap-duoc');
    await save(browser, page, `DN08_${device}_lock`);
    // DN07 đổi mật khẩu lần đầu của học sinh (không bấm gửi).
    await loginStudent(page, 'hs900001');
    await expect(page).toHaveURL(/\/doi-mat-khau$/);
    await save(browser, page, `DN07_${device}_new`);
    await page.getByLabel('Mật khẩu mới', { exact: true }).fill('MatKhauMoi123a');
    await page.getByLabel('Nhập lại mật khẩu mới', { exact: true }).fill('MatKhauMoi123a');
    await save(browser, page, `DN07_${device}_ok`);
  });

  test(`DN04, DN03, DN10 (${device})`, async ({ page, browser }) => {
    await size(page, device);
    await clearTotp(`admin.cs1@${DOMAIN}`);
    await loginStaff(page, 'admin.cs1');
    await expect(page).toHaveURL(/\/thiet-lap-hai-buoc$/);
    await expect(page.locator('code')).toBeVisible();
    await save(browser, page, `DN04_${device}_s1`);
    const secret = (await page.locator('code').first().textContent())?.replace(/\s+/g, '') ?? '';
    await page.getByRole('button', { name: 'Tiếp', exact: true }).click();
    await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
    await save(browser, page, `DN04_${device}_s2`);
    await page.getByRole('button', { name: 'Hoàn tất' }).click();
    await expect(page).toHaveURL(/\/crm$/);
    await page.goto('/chon-cong');
    await expect(
      page.getByText('Lịch dạy, điểm danh, chấm nhận xét, bài tập về nhà.'),
    ).toBeVisible();
    await save(browser, page, `DN10_${device}_ok`);
    await page.goto('/crm');
    if (device === 'mb') await page.getByRole('button', { name: 'Mở menu' }).click();
    await page.keyboard.press('Escape');
    await signOut(page);
    await fillLogin(page, 'Email', `admin.cs1@${DOMAIN}`);
    await expect(page).toHaveURL(/\/xac-thuc-hai-buoc$/);
    await save(browser, page, `DN03_${device}_code`);
    await page.getByLabel('Mã xác thực').fill('000000');
    await page.getByRole('button', { name: 'Xác nhận' }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await save(browser, page, `DN03_${device}_code_err`);
  });

  test(`DN09 (${device})`, async ({ page, browser }) => {
    await size(page, device);
    await page.clock.install();
    await loginStaff(page, 'sale.cs5');
    await expect(page).toHaveURL(/\/crm$/);
    await page.clock.fastForward('01:05:00');
    await expect(page.getByRole('dialog', { name: 'Phiên làm việc đã hết' })).toBeVisible();
    await save(browser, page, `DN09_${device}_end`);
  });
}
