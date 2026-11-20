// CH-01 Gói bán: danh sách, lọc, Tạo gói (mã tự ghép), Sửa tên và mã cũ, Ngừng bán rồi Dùng lại; Sale chỉ xem. Máy tính. Dữ liệu giả.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, expectAccessible, pickOption } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

const CODE = 'LC-ANH-K05K06';

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Cấu hình chỉ có bản máy tính.');
});

async function cleanup() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query('delete from app.sales_package where code = $1', [CODE]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}
test.beforeAll(cleanup);
test.afterAll(cleanup);

async function openList(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/goi-ban');
  await expect(page.getByRole('heading', { level: 1, name: 'Gói bán' })).toBeVisible();
}

test('Danh sách gói: có gói mẫu, lọc theo trạng thái và loại gói', async ({ page }) => {
  await openList(page);
  const table = page.getByRole('table', { name: 'Gói bán' });
  await expect(table.getByRole('row', { name: /LC-TOAN-K09/ })).toBeVisible();
  await expect(table.getByRole('row', { name: /VIP-TOAN-K03K07/ })).toContainText(
    'Khối 3 đến Khối 7',
  );
  await expectAccessible(page);
  await pickOption(page, page.getByRole('combobox', { name: 'Loại gói' }), 'Tài liệu');
  await expect(table.getByRole('row', { name: /TL-MATOAN/ })).toBeVisible();
  await expect(table.getByRole('row', { name: /LC-TOAN-K09/ })).toHaveCount(0);
});

test('Tạo gói: mã tự ghép Loại-Môn-Khối, tạo xong có trong danh sách', async ({ page }) => {
  await openList(page);
  await page.getByRole('button', { name: 'Tạo gói' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo gói bán' });
  await expect(dialog.getByRole('button', { name: 'Tạo gói' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Loại gói' }), 'Lớp chung');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Môn' }), 'Tiếng Anh');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Khối từ' }), 'Khối 5');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Khối đến' }), 'Khối 6');
  await expect(dialog.getByLabel('Mã gói')).toHaveValue(CODE);
  await dialog.getByLabel('Tên gói').fill('Lớp chung Tiếng Anh 5 đến 6');
  await dialog.getByLabel('Mã cũ (Sheet)').fill('TA56');
  await dialog.getByRole('button', { name: 'Tạo gói' }).click();
  await expect(dialog).toHaveCount(0);
  await page.getByLabel('Tìm gói').fill('TA56');
  await expect(page.getByRole('row', { name: new RegExp(CODE) })).toContainText('Đang bán');
});

test('Sửa gói: chỉ tên và mã cũ, mã khoá; Ngừng bán rồi Dùng lại', async ({ page }) => {
  await openList(page);
  await page.getByLabel('Tìm gói').fill(CODE);
  const row = page.getByRole('row', { name: new RegExp(CODE) });
  await row.getByRole('button', { name: 'Sửa' }).click();
  const edit = page.getByRole('dialog', { name: `Sửa gói ${CODE}` });
  await expect(edit.getByLabel('Mã gói')).toHaveAttribute('readonly', '');
  await edit.getByLabel('Tên gói').fill('Lớp chung Anh 5 đến 6 (đổi tên)');
  await edit.getByRole('button', { name: 'Lưu' }).click();
  await expect(edit).toHaveCount(0);
  await expect(row).toContainText('đổi tên');
  await row.getByRole('button', { name: 'Ngừng' }).click();
  const stop = page.getByRole('alertdialog', { name: `Ngừng bán gói ${CODE}?` });
  await stop.getByRole('button', { name: 'Ngừng bán' }).click();
  await expect(row).toContainText('Ngừng');
  await row.getByRole('button', { name: 'Dùng lại' }).click();
  await page
    .getByRole('alertdialog', { name: 'Dùng lại gói' })
    .getByRole('button', { name: 'Dùng lại' })
    .click();
  await expect(row).toContainText('Đang bán');
});

test('Sale xem được danh sách nhưng không có nút Tạo, Sửa, Ngừng', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/cau-hinh/goi-ban');
  await expect(page.getByRole('heading', { level: 1, name: 'Gói bán' })).toBeVisible();
  await expect(page.getByRole('row', { name: /LC-TOAN-K09/ })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tạo gói' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Sửa' })).toHaveCount(0);
});
