// So bản dựng màn Phiếu kiểm tra với gói thiết kế hiện hành design/hmt-p3/png (TS15 tạo phiếu, TS16 danh sách, TS16b Kanban, TS16c Lịch, TS17 bản ghi).
// Ảnh ra thư mục tạm (docs/so-sanh khi đặt SO_SANH_GHI_VAO_REPO=1). Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh-phieu.spec.ts --project=may-tinh
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { PASSWORD, loginStaff } from './helpers';
import { DB_URL, clearMark, seed, setupOf } from './phieu-seed';

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
  const design = existsSync(designPath) ? readFileSync(designPath).toString('base64') : null;
  const composer = await browser.newPage({ viewport: { width: 1800, height: 800 } });
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

test('Phiếu kiểm tra: danh sách, Kanban, Lịch, bản ghi, hộp tạo (máy tính)', async ({
  page,
  browser,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const seeded = await seed(setup);
  try {
    await page.setViewportSize(DESKTOP);
    await loginStaff(page, setup.account);
    await expect(page).toHaveURL(/\/crm$/);
    await page.goto('/crm/phieu-kiem-tra');
    await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
    await expect(page.getByText(seeded.test.edit.code).first()).toBeVisible();
    await save(browser, page, 'TS16_pc', 'TS16');
    await page.getByRole('button', { name: 'Kanban', exact: true }).click();
    await expect(
      page.getByRole('heading', { name: 'Đang test', exact: true }).first(),
    ).toBeVisible();
    await save(browser, page, 'TS16b_pc', 'TS16b');
    await page.getByRole('button', { name: 'Calendar', exact: true }).click();
    await page.getByRole('button', { name: 'Tháng', exact: true }).click();
    await page
      .getByRole('button', { name: new RegExp(seeded.student.edit) })
      .first()
      .click();
    await expect(page.getByRole('link', { name: /^Mở phiếu/ })).toBeVisible();
    await save(browser, page, 'TS16c_pc', 'TS16c');

    await page.goto(`/crm/phieu-kiem-tra/${seeded.test.review.id}`);
    await expect(page.getByRole('heading', { level: 1, name: 'Phiếu kiểm tra' })).toBeVisible();
    await save(browser, page, 'TS17_pc', 'TS17');

    await page.goto(`/crm/co-hoi/${seeded.opportunity.fresh.id}`);
    await page.getByRole('button', { name: 'Tạo lịch Test' }).click();
    await expect(page.getByRole('dialog', { name: 'Tạo phiếu kiểm tra' })).toBeVisible();
    await save(browser, page, 'TS15_pc', 'TS15');
  } finally {
    await clearMark(setup.mark);
  }
});
