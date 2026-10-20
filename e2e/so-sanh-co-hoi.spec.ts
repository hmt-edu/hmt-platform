// So bản dựng màn Cơ hội với gói thiết kế hiện hành design/hmt-p3/png (TS07 danh sách và Kanban, TS08 bản ghi, TS09 hộp chuyển
// giai đoạn, TS06 trang Lead có nút Tạo cơ hội).
// Ảnh ra thư mục tạm (docs/so-sanh khi đặt SO_SANH_GHI_VAO_REPO=1). Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh-co-hoi.spec.ts --project=may-tinh
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { PASSWORD, loginStaff } from './helpers';
import { DB_URL, clearMark, seed, setupOf } from './co-hoi-seed';

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

test('Cơ hội: danh sách, Kanban, bản ghi, hộp chuyển giai đoạn, trang Lead (máy tính)', async ({
  page,
  browser,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const seeded = await seed(setup);
  try {
    await page.setViewportSize(DESKTOP);
    await loginStaff(page, setup.account);
    await expect(page).toHaveURL(/\/crm$/);
    await page.goto('/crm/co-hoi');
    await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
    await expect(page.getByText(seeded.opportunity.fresh.code).first()).toBeVisible();
    await save(browser, page, 'TS07_K1_pc', 'TS07_K1');
    await page.getByRole('button', { name: 'Kanban', exact: true }).click();
    await expect(page.getByRole('heading', { name: /^L1 / })).toBeVisible();
    await save(browser, page, 'TS07_K2_pc', 'TS07_K2');

    await page.goto(`/crm/co-hoi/${seeded.opportunity.gated.id}`);
    await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
    await save(browser, page, 'TS08_K3_pc', 'TS08_K3');
    await page.getByRole('button', { name: 'Kiểm tra: 1' }).click();
    await save(browser, page, 'TS08b_K3_pc', 'TS08b_K3');
    await page
      .getByRole('navigation', { name: 'Giai đoạn' })
      .getByRole('button', { name: /^L7/ })
      .click();
    await expect(page.getByRole('dialog', { name: /Chuyển sang L7/ })).toBeVisible();
    await save(browser, page, 'TS09a_pc', 'TS09a');
    await page.keyboard.press('Escape');

    await page.goto(`/crm/co-hoi/${seeded.opportunity.skip.id}`);
    await page
      .getByRole('navigation', { name: 'Giai đoạn' })
      .getByRole('button', { name: /^L7/ })
      .click();
    await expect(page.getByRole('dialog', { name: /Chuyển sang L7/ })).toBeVisible();
    await save(browser, page, 'TS09b_pc', 'TS09b');
    await page.keyboard.press('Escape');
    await page
      .getByRole('navigation', { name: 'Giai đoạn' })
      .getByRole('button', { name: /^L8/ })
      .click();
    await expect(page.getByRole('dialog', { name: /Chuyển sang L8/ })).toBeVisible();
    await save(browser, page, 'TS09c_pc', 'TS09c');
    await page.keyboard.press('Escape');

    await page.goto(`/crm/co-hoi/${seeded.opportunity.nostudent.id}`);
    await page
      .getByRole('navigation', { name: 'Giai đoạn' })
      .getByRole('button', { name: /^L5/ })
      .click();
    await expect(page.getByRole('dialog', { name: /Chuyển sang L5/ })).toBeVisible();
    await save(browser, page, 'TS09d_pc', 'TS09d');
    await page.keyboard.press('Escape');

    await page.goto(`/crm/co-hoi/${seeded.opportunity.fresh.id}`);
    await page
      .getByRole('navigation', { name: 'Giai đoạn' })
      .getByRole('button', { name: /^L2/ })
      .click();
    await expect(page.getByRole('dialog', { name: /Chuyển sang L2/ })).toBeVisible();
    await save(browser, page, 'TS09_pc', 'TS09');
    await page.keyboard.press('Escape');

    await page.goto(`/crm/lead/${seeded.lonelyLeadId}`);
    await expect(page.getByRole('button', { name: 'Tạo cơ hội' })).toBeVisible();
    await save(browser, page, 'TS06_pc', 'TS06');
  } finally {
    await clearMark(setup.mark);
  }
});
