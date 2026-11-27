// UI-O4 Tạo đơn hàng (R-CRM-16, R-CRM-19, R-TIEN-14, R-TIEN-39, Đ259): "Tạo đơn hàng" ở cơ hội L8 và "Chuyển thành đơn" ở báo giá Đã gửi chỉ mở form trắng; Lưu mới cấp mã và mở đơn Nháp.
// Máy tính (điện thoại ẩn nút, Đ248). Dữ liệu giả dựng bằng bao-gia-seed.ts (báo giá Đã gửi, Từ chối), cơ hội của báo giá Từ chối được đặt ở L8.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible, isPhone, pickProduct } from './helpers';
import { DB_URL, clearMark, seed, type Seeded } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng báo giá giả).');
test.describe.configure({ mode: 'serial' });

const SETUP = {
  'may-tinh': { mark: 'E2EOTMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1400 },
  'dien-thoai': { mark: 'E2EOTDT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1450 },
} as const;
const setupOf = (project: string) => SETUP[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

let seeded: Seeded;
let sentQuoteId = '';
let sentOppId = '';
let l8OppId = '';

async function one<T extends pg.QueryResultRow>(sql: string, args: unknown[]): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    const r = await db.query<T>(sql, args);
    const row = r.rows[0];
    if (!row) throw new Error(`Không có dòng: ${sql}`);
    return row;
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  seeded = await seed(setup);
  const sent = await one<{ id: string; opportunity_id: string }>(
    'select id, opportunity_id from app.quotation where code = $1',
    [seeded.code.sent],
  );
  sentQuoteId = sent.id;
  sentOppId = sent.opportunity_id;
  // Cơ hội của báo giá Từ chối đặt ở L8 (R-CRM-16) để tạo đơn thẳng; dữ liệu giả, sửa thẳng cột.
  const rejected = await one<{ opportunity_id: string }>(
    'select opportunity_id from app.quotation where code = $1',
    [seeded.code.rejected],
  );
  l8OppId = rejected.opportunity_id;
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = $1`,
      [l8OppId],
    );
  } finally {
    await db.end();
  }
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(setupOf(testInfo.project.name).mark);
});

test('Cơ hội chưa ở L8: nút Tạo đơn hàng mờ kèm lý do (R-CRM-16)', async ({ page }, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại ẩn nút Tạo đơn hàng.');
  await enterAs(page, setupOf(testInfo.project.name).sale);
  await page.goto(`/crm/co-hoi/${sentOppId}`);
  const create = page.getByRole('button', { name: 'Tạo đơn hàng', exact: true });
  await expect(create).toBeDisabled();
  await expect(create).toHaveAttribute('title', /L8/);
});

test('Báo giá Đã gửi: Chuyển thành đơn mở form trắng, bỏ dòng bằng ✕ không hết dòng; Lưu tạo đơn Nháp', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại ẩn nút Chuyển thành đơn.');
  await enterAs(page, setupOf(testInfo.project.name).sale);
  await page.goto(`/crm/bao-gia/${sentQuoteId}`);
  // Cơ hội chưa ở L8 (R-CRM-16): nút mờ kèm lý do ngay trên báo giá (T2-03), không đợi tới lúc Lưu mới báo.
  const convert = page.getByRole('button', { name: 'Chuyển thành đơn' });
  await expect(convert).toBeDisabled();
  await expect(convert).toHaveAttribute('title', /L8/);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = $1`,
      [sentOppId],
    );
  } finally {
    await db.end();
  }
  await page.reload();
  await expect(convert).toBeEnabled();
  await convert.click();
  await expect(page).toHaveURL(new RegExp(`/crm/don-hang/tao\\?bao-gia=${sentQuoteId}$`));
  // Form trắng: chưa có bản ghi, chưa cấp mã.
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo đơn hàng' })).toBeVisible();
  await expect(page.getByText('Chưa lưu', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'cấp khi Lưu, không sửa' })).toBeVisible();
  await expect(page.getByText(seeded.code.sent).first()).toBeVisible();
  await expectAccessible(page);
  const rows = page.getByRole('table', { name: 'Dòng đơn' }).getByRole('row');
  const before = (await rows.count()) - 1;
  expect(before).toBeGreaterThan(0);
  await page.getByRole('button', { name: 'Bỏ dòng 1 khỏi đơn' }).click();
  if (before === 1) {
    // Bỏ hết dòng thì không lưu được.
    await expect(page.getByText('Đơn cần ít nhất một dòng')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeDisabled();
    return;
  }
  await expect(rows).toHaveCount(before);
  // Điều khoản thanh toán bắt buộc chọn (anh chốt 23/11): chưa chọn thì Lưu mờ.
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeDisabled();
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option').first().click();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]{36}$/);
  await expect(page.getByRole('heading', { level: 2, name: /^DH-/ })).toBeVisible();
  await expect(page.getByText('Nháp').first()).toBeVisible();
});

test('Huỷ ở form Tạo đơn hàng: về báo giá, không có đơn mới', async ({ page }, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại ẩn nút.');
  await enterAs(page, setupOf(testInfo.project.name).sale);
  await page.goto(`/crm/don-hang/tao?co-hoi=${l8OppId}`);
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo đơn hàng' })).toBeVisible();
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/co-hoi/${l8OppId}$`));
  const n = await one<{ n: string }>(
    'select count(*)::text as n from app.sales_order where opportunity_id = $1',
    [l8OppId],
  );
  expect(n.n).toBe('0');
});

test('Cơ hội L8: Tạo đơn hàng mở form trắng, nhập dòng, Lưu tạo đơn Nháp; tạo lần hai có hộp BH-11', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại ẩn nút Tạo đơn hàng.');
  test.setTimeout(90_000);
  await enterAs(page, setupOf(testInfo.project.name).sale);
  await page.goto(`/crm/co-hoi/${l8OppId}`);
  const create = page.getByRole('button', { name: 'Tạo đơn hàng', exact: true });
  await expect(create).toBeEnabled();
  await create.click();
  await expect(page).toHaveURL(new RegExp(`/crm/don-hang/tao\\?co-hoi=${l8OppId}$`));
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo đơn hàng' })).toBeVisible();
  await expect(page.getByText('Không qua báo giá')).toBeVisible();
  await page.getByRole('button', { name: 'Gói dòng 1' }).click();
  await pickProduct(page, 'LC-TOAN-K09');
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option').first().click();
  // Chưa nhập số lượng thì chưa tạo.
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Bắt buộc nhập số lượng.')).toBeVisible();
  await expect(page).toHaveURL(/\/crm\/don-hang\/tao\?co-hoi=/);
  await page.getByLabel('Số lượng dòng 1').fill('3');
  await expect(page.locator('p', { hasText: 'Tổng cộng đơn hàng' })).toContainText('đ');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]{36}$/);
  await expect(page.getByRole('heading', { level: 2, name: /^DH-/ })).toBeVisible();
  // BH-11: cơ hội đã có đơn Nháp thì tạo thêm phải xác nhận.
  await page.goto(`/crm/co-hoi/${l8OppId}`);
  await page.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Gói dòng 1' }).click();
  await pickProduct(page, 'LC-TOAN-K09');
  await page.getByLabel('Số lượng dòng 1').fill('2');
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option').first().click();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Cơ hội đã có đơn Nháp' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('link', { name: /^Mở đơn cũ DH-/ })).toBeVisible();
  await dialog.getByRole('button', { name: 'Vẫn tạo đơn mới' }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]{36}$/);
  const n = await one<{ n: string }>(
    `select count(*)::text as n from app.sales_order where opportunity_id = $1 and status_code = 'NHAP'`,
    [l8OppId],
  );
  expect(n.n).toBe('2');
});
