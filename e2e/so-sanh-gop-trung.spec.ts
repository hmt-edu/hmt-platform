// So bản dựng hộp Gộp trùng và Nhập file với gói thiết kế hiện hành design/hmt-p3/png (TS04 nhập lead từ file, TS10 gộp trùng, TS10b lead đã gộp; TS10c khác cơ sở không dựng được bằng tài khoản thường).
// Ảnh ra thư mục tạm (docs/so-sanh khi đặt SO_SANH_GHI_VAO_REPO=1). Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh-gop-trung.spec.ts --project=may-tinh
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { DOMAIN, PASSWORD, loginStaff } from './helpers';
import { generateSync } from 'otplib';
import pg from 'pg';
import { DB_URL, clearMark, seed, seedOtherBranchLead, setupOf } from './gop-trung-seed';

const DESIGN_DIR = join(process.cwd(), 'design', 'hmt-p3', 'png');
const OUT_DIR = process.env.SO_SANH_GHI_VAO_REPO
  ? join(process.cwd(), 'docs', 'so-sanh')
  : join(tmpdir(), 'hmt-so-sanh');
const DESKTOP = { width: 1440, height: 1000 };

test.skip(
  !process.env.SO_SANH || !PASSWORD || !DB_URL,
  'Chỉ chạy khi SO_SANH=1 và có SEED_PASSWORD, DB_URL.',
);

/** Ghép ảnh thiết kế với ảnh bản dựng thành một ảnh JPEG. */
async function save(browser: Browser, page: Page, name: string, designName: string) {
  await page.waitForTimeout(600);
  const shot = await page.screenshot({ type: 'png' });
  const designPath = join(DESIGN_DIR, `${designName}.png`);
  const phone = name.endsWith('_mb');
  const design =
    !phone && existsSync(designPath) ? readFileSync(designPath).toString('base64') : null;
  const composer = await browser.newPage({ viewport: { width: phone ? 460 : 1800, height: 800 } });
  const figure = (title: string, data: string) =>
    `<figure style="margin:0;flex:1"><figcaption style="font:600 14px system-ui;padding:6px 0">${title}</figcaption>` +
    `<img src="data:image/png;base64,${data}" style="width:100%;border:1px solid #bbb;display:block"></figure>`;
  await composer.setContent(
    `<body style="margin:0;padding:12px;background:#fff"><div style="display:flex;gap:16px;align-items:flex-start">` +
      (design ? figure(`${designName} · Thiết kế`, design) : '') +
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

test('Gộp trùng và Nhập file (máy tính)', async ({ page, browser }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const seeded = await seed(setup);
  try {
    await page.setViewportSize(DESKTOP);
    await loginStaff(page, setup.account);
    await expect(page).toHaveURL(/\/crm$/);

    await page.goto('/crm/lead');
    await page.getByRole('button', { name: 'Nhập', exact: true }).click();
    const imp = page.getByRole('dialog', { name: 'Nhập lead từ file' });
    await expect(imp).toBeVisible();
    await save(browser, page, 'TS04_pc', 'TS04');
    const csv = `Họ tên phụ huynh;Số điện thoại;Tên học sinh;Nguồn;Ghi chú KH;Mã nội bộ\nChị ${setup.mark} Thử;0987111222;Em A;FACEBOOK_ADS;Hỏi lớp 9;X1\nAnh ${setup.mark} Sai;0903 22 44;;FACEBOOK_ADS;;X2\n`;
    await imp.getByLabel('Chọn file CSV').setInputFiles({
      name: 'leads-thang-10.csv',
      mimeType: 'text/csv',
      buffer: Buffer.from(csv, 'utf8'),
    });
    await expect(imp.getByText(/leads-thang-10\.csv/)).toBeVisible();
    await imp.getByRole('button', { name: 'Tiếp' }).click();
    await expect(imp.getByText(/cột chưa ghép/)).toBeVisible();
    await save(browser, page, 'TS04_b2_pc', 'TS04');
    await imp.getByRole('button', { name: 'Tiếp' }).click();
    await expect(imp.getByRole('table', { name: 'Kết quả từng dòng' })).toBeVisible();
    await save(browser, page, 'TS04_b3_pc', 'TS04');
    await page.keyboard.press('Escape');

    await page.goto(`/crm/lead/${seeded.lead.a.id}`);
    await page.getByRole('button', { name: 'Hành động' }).click();
    await page.getByRole('menuitem', { name: 'Gộp trùng' }).click();
    const merge = page.getByRole('dialog', { name: 'Gộp lead trùng' });
    await expect(merge.getByText('Lịch hẹn (1)')).toBeVisible();
    await merge.getByRole('checkbox', { name: /Gộp không hoàn tác được/ }).check();
    await save(browser, page, 'TS10_pc', 'TS10');
    await merge.getByRole('button', { name: `Gộp vào ${seeded.lead.a.code}` }).click();
    await expect(page.getByText(`Đã gộp vào ${seeded.lead.a.code}.`).first()).toBeVisible();
    await page.goto(`/crm/lead/${seeded.lead.b.id}`);
    await expect(page.getByText(/Lead này đã gộp vào/)).toBeVisible();
    await save(browser, page, 'TS10b_pc', 'TS10b');
  } finally {
    await clearMark(setup.mark);
  }
});

// TS10c: Admin (xác thực hai bước) mở hộp Gộp trùng và thấy bản cùng SĐT ở cơ sở khác. Bài này gắn thiết bị hai bước mới cho
// admin.cs1: chạy xong thì chạy lại `npm run db:seed-users`.
test('TS10c: Admin thấy bản ở cơ sở khác (máy tính)', async ({ page, browser }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const seeded = await seed(setup);
  try {
    const other = await seedOtherBranchLead(setup, seeded.phone, seeded.run);
    const db = new pg.Client({ connectionString: DB_URL });
    await db.connect();
    await db.query(
      'delete from auth.mfa_factors where user_id = (select id from auth.users where email = $1)',
      [`admin.cs1@${DOMAIN}`],
    );
    await db.end();
    await page.setViewportSize(DESKTOP);
    await loginStaff(page, 'admin.cs1');
    await expect(page).toHaveURL(/\/thiet-lap-hai-buoc$/);
    const secret = (await page.locator('code').first().textContent())?.replace(/\s+/g, '') ?? '';
    await page.getByRole('button', { name: 'Tiếp', exact: true }).click();
    await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
    await page.getByRole('button', { name: 'Hoàn tất' }).click();
    await expect(page).toHaveURL(/\/crm$/);
    await page.goto(`/crm/lead/${seeded.lead.a.id}`);
    await page.getByRole('button', { name: 'Hành động' }).click();
    await page.getByRole('menuitem', { name: 'Gộp trùng' }).click();
    const merge = page.getByRole('dialog', { name: 'Gộp lead trùng' });
    // Bản mới nhất (cơ sở khác) được chọn sẵn.
    await expect(
      merge.getByRole('heading', { name: new RegExp(`sang ${seeded.lead.a.code}$`) }),
    ).toBeVisible();
    await expect(merge.getByText(other.code).first()).toBeVisible();
    await save(browser, page, 'TS10c_pc', 'TS10c');
  } finally {
    await clearMark(setup.mark);
  }
});
