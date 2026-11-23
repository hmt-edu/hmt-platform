// Đường Sale tích hợp (B40, R-TIEN-01): báo giá Đã gửi → Chuyển thành đơn → Lưu → Trình duyệt → Trưởng cơ sở duyệt → Sale lập phiếu thu → Trình quản lý
// → Trưởng cơ sở duyệt (chuyển Kế toán) → Kế toán duyệt (hai bước) → khoản tiền vào đúng số tiền; đơn có số đã thu; công nợ còn lại đúng. Máy tính (Đ248).
// Dữ liệu giả dựng bằng bao-gia-seed.ts (báo giá Đã gửi; cơ hội đặt ở L8). Mỗi bài một thẻ trình duyệt mới.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, pickOption } from './helpers';
import { DB_URL, clearMark, seed, type Seeded } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng báo giá giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Đường Sale ghi trên máy tính (Đ248).');
});

const SETUP = { mark: 'E2EDSMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1700 } as const;
const ACCOUNTANT = 'ketoan3.cs5';
const AMOUNT = '100000';

let seeded: Seeded;
let orderUrl = '';
let orderCode = '';
let receiptUrl = '';

async function db<T>(fn: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: DB_URL });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

// Không đặt Quản lý trực tiếp của Sale: tài khoản sale.cs5 dùng chung với bài phieu-thu chạy song song (cùng đặt và gỡ quản lý). Sale chưa có quản lý vẫn trình được,
// đơn và phiếu đi tới Trưởng cơ sở (R-V2-12); Trưởng cơ sở của cơ sở duyệt được cả hai trường hợp.

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  seeded = await seed(SETUP);
  // Cơ hội của báo giá Đã gửi ở L8 (R-CRM-16) để chuyển thành đơn; dữ liệu giả.
  await db((c) =>
    c.query(
      `update app.opportunity set stage_code = 'L8', substage_code = 'L8A'
        where id = (select opportunity_id from app.quotation where code = $1)`,
      [seeded.code.sent],
    ),
  );
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  if (testInfo.project.name === 'dien-thoai') return;
  await clearMark(SETUP.mark);
});

async function openByUrl(page: Page, account: string, url: string) {
  await enterAs(page, account);
  await page.goto(url);
}

test('Sale: báo giá Đã gửi chuyển thành đơn, Lưu thành đơn Nháp rồi Trình duyệt', async ({
  page,
}) => {
  test.setTimeout(120_000);
  const quote = await db((c) =>
    c.query<{ id: string }>('select id from app.quotation where code = $1', [seeded.code.sent]),
  );
  await openByUrl(page, SETUP.sale, `/crm/bao-gia/${quote.rows[0]?.id ?? ''}`);
  await page.getByRole('button', { name: 'Chuyển thành đơn' }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/tao\?bao-gia=/);
  // Điều khoản thanh toán bắt buộc chọn lúc tạo đơn (anh chốt 23/11): chọn «Chia ba đợt» rồi mới Lưu được.
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option', { name: /Chia ba đợt/ }).click();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]{36}$/);
  orderUrl = new URL(page.url()).pathname;
  const heading = page.getByRole('heading', { level: 2, name: /^DH-/ });
  await expect(heading).toBeVisible();
  orderCode = (await heading.textContent())?.trim() ?? '';
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  // Em chưa đủ thông tin thì có hộp xác nhận «Vẫn trình»; không có thì trình luôn.
  const stillSubmit = page.getByRole('button', { name: 'Vẫn trình' });
  if (await stillSubmit.isVisible().catch(() => false)) await stillSubmit.click();
  await expect(page.getByText('Đã trình đơn.').first()).toBeVisible();
});

test('Trưởng cơ sở duyệt đơn; đơn thành Đã duyệt', async ({ page }) => {
  await openByUrl(page, SETUP.manager, orderUrl);
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Duyệt đơn hàng' });
  await dialog.getByRole('button', { name: 'Duyệt', exact: true }).click();
  await expect(page.getByText('Đã duyệt đơn hàng.').first()).toBeVisible();
  await expect(page.getByText('Đã duyệt · khoá').first()).toBeVisible();
});

test('Sale lập phiếu thu từ đơn Đã duyệt và trình quản lý', async ({ page }) => {
  test.setTimeout(90_000);
  const loaded = page.waitForResponse((r) => r.url().includes('order_payment_summary') && r.ok());
  await openByUrl(page, SETUP.sale, orderUrl);
  await loaded;
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await dialog.getByLabel('Số tiền').fill(AMOUNT);
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receiptUrl = new URL(page.url()).pathname;
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ (quản lý|Trưởng cơ sở) duyệt/)).toBeVisible();
});

test('Trưởng cơ sở duyệt phiếu thu, chuyển Kế toán', async ({ page }) => {
  await openByUrl(page, SETUP.manager, receiptUrl);
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});

test('Kế toán duyệt phiếu thu: sinh đúng một khoản tiền vào, đơn có số đã thu, hiện ở Khoản tiền vào', async ({
  page,
}) => {
  test.setTimeout(120_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto(receiptUrl);
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await expect(page.getByText('Đã duyệt phiếu thu, tiền đã ghi nhận.').first()).toBeVisible();
  const receiptId = receiptUrl.split('/').pop() ?? '';
  const money = await db((c) =>
    c.query<{ n: string; total: string }>(
      'select count(*)::text as n, coalesce(sum(amount), 0)::text as total from app.money_in where receipt_id = $1::uuid',
      [receiptId],
    ),
  );
  expect(money.rows[0]?.n).toBe('1');
  expect(money.rows[0]?.total).toBe(AMOUNT);
  // Đơn có số đã thu bằng số vừa duyệt (hàm tính ở máy chủ).
  const paid = await db((c) =>
    c.query<{ paid: string }>(
      'select app.order_paid_amount(id)::text as paid from app.sales_order where code = $1',
      [orderCode],
    ),
  );
  expect(paid.rows[0]?.paid).toBe(AMOUNT);
  await page.goto('/crm/khoan-tien-vao');
  await expect(page.getByRole('heading', { level: 1, name: 'Khoản tiền vào' })).toBeVisible();
  await page.getByRole('searchbox').fill(orderCode);
  await expect(page.getByText('100.000').first()).toBeVisible();
  // Công nợ: tổng còn nợ của đơn = thành tiền các dòng trừ số vừa thu (tính từ dữ liệu, không chép số minh hoạ).
  const total = await db((c) =>
    c.query<{ total: string }>(
      `select coalesce(sum(l.line_total), 0)::text as total from app.sales_order_line l
         join app.sales_order o on o.id = l.order_id where o.code = $1`,
      [orderCode],
    ),
  );
  const remaining = Number(total.rows[0]?.total ?? '0') - Number(AMOUNT);
  await page.goto('/crm/cong-no');
  await expect(page.getByRole('heading', { level: 1, name: 'Công nợ' })).toBeVisible();
  await page.getByRole('searchbox').fill(orderCode);
  await expect(
    page.getByText(`Tổng còn nợ (theo bộ lọc): ${remaining.toLocaleString('vi-VN')} đ`),
  ).toBeVisible();
});
