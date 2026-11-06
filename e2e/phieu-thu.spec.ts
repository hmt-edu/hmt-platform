// TC-02, TC-03 Phiếu thu: Sale tạo phiếu nháp từ đơn Đã duyệt, sửa, trình; Trưởng cơ sở duyệt (chuyển Kế toán); huỷ phiếu. Máy tính (điện thoại chỉ đọc, Đ248).
// Dữ liệu giả dựng bằng don-hang-seed.ts (seedOrders).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, DOMAIN, enterAs, expectAccessible, isPhone, pickOption } from './helpers';
import { DB_URL, clearMark, receiptSetupOf, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededOrders;
let receiptUrl = '';

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  seeded = await seedOrders(setup);
  await setManager(setup.sale, setup.manager);
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await clearMark(setup.mark);
  await setManager(setup.sale, null);
});

/** Gán (hoặc bỏ) Quản lý trực tiếp của tài khoản giả: phiếu thu đi qua bước quản lý nên người lập cần có quản lý (R-HT-06). */
async function setManager(account: string, manager: string | null) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `update app.user_account set manager_id = (select id from app.user_account where login_name = $2)
        where login_name = $1`,
      [`${account}@${DOMAIN}`, manager === null ? null : `${manager}@${DOMAIN}`],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Phiếu thu chỉ ghi trên máy tính (Đ248).');
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await page.getByRole('table', { name: 'Đơn hàng' }).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('Sale tạo phiếu thu nháp từ đơn Đã duyệt, sửa ghi chú, trình quản lý', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await expect(dialog.getByRole('button', { name: 'Tạo phiếu nháp' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await expect(dialog.getByLabel('Số tiền')).not.toHaveValue('');
  await dialog.getByLabel('Số tiền').fill('1000000');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receiptUrl = new URL(page.url()).pathname;
  await expect(page.getByRole('heading', { level: 2, name: /^PT-/ })).toBeVisible();
  await expect(page.getByText('1.000.000 đ').first()).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Ghi chú', { exact: true }).fill('Thu đợt đầu');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu phiếu thu.').first()).toBeVisible();
  await expect(page.getByText('Thu đợt đầu')).toBeVisible();
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ quản lý duyệt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình quản lý' })).toHaveCount(0);
  // Bản in biên nhận (TC-07): nhãn CHỜ DUYỆT, số tiền, số điện thoại chỉ che ở bản in.
  await page.getByRole('button', { name: 'In biên nhận' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}\/in$/);
  const sheet = page.getByRole('article', { name: 'BIÊN NHẬN' });
  await expect(sheet.getByText('CHỜ DUYỆT')).toBeVisible();
  await expect(sheet.getByText('1.000.000 đ')).toBeVisible();
  await expect(sheet.getByText(/\d{4} \*\*\* \d{3}/)).toBeVisible();
  await expectAccessible(page);
});

test('Trưởng cơ sở duyệt phiếu: chuyển Kế toán, không còn nút Duyệt cho quản lý', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.manager);
  await page.goto(receiptUrl);
  await expect(
    page.getByText('Phiếu chờ').or(page.getByText(/Đã trình, chờ quản lý duyệt/)),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' })).toHaveCount(0);
});

test('Người lập huỷ phiếu chưa duyệt: chọn lý do, phiếu về Huỷ và chỉ còn xem', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.sale);
  await page.goto(receiptUrl);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ phiếu thu' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Huỷ phiếu thu' })).toBeVisible();
  await dialog.getByLabel('Lý do huỷ').click();
  await page.getByRole('option', { name: 'Sai số tiền' }).click();
  await dialog.getByRole('button', { name: 'Huỷ phiếu thu' }).click();
  await expect(page.getByText(/Phiếu đã huỷ: Sai số tiền/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toHaveCount(0);
  void isPhone;
});
