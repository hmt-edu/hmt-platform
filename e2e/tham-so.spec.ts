// QT-09 Cài đặt tham số nghiệp vụ (canvas bổ sung v2 `1794124725-dc47`, khung QT09_*): nhóm bên trái, bảng bên phải, sửa có kiểm khoảng, hộp xác nhận cũ → mới,
// ghi đè theo cơ sở. Chỉ bản máy tính (Quản trị không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Trả giá trị về như cũ sau bài.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

const KEY = 'quotation_validity_days';

async function sql<T = unknown>(query: string, params: unknown[] = []): Promise<T[]> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return (await db.query(query, params)).rows as T[];
  } finally {
    await db.end();
  }
}

// Trả giá trị chung về 14 và bỏ ghi đè (đặt is_active = false, bảng không cho xoá). Một kết nối: cờ migration chỉ có hiệu lực trong cùng phiên.
async function restore() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query("select set_config('hmt.migration', 'on', false)");
    await db.query('update app.setting_def set value = $2 where key = $1', [KEY, '14']);
    await db.query('update app.setting_branch set is_active = false where setting_key = $1', [KEY]);
  } finally {
    await db.end();
  }
}
test.beforeAll(restore);
test.afterAll(restore);

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/tham-so');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Cài đặt tham số nghiệp vụ' }),
  ).toBeVisible();
}

const groups = (page: Page) => page.getByRole('navigation', { name: 'Nhóm tham số' });
const table = (page: Page) => page.getByRole('region', { name: 'Tham số của nhóm' });
const rowOf = (page: Page) => table(page).getByRole('row', { name: /Hạn hiệu lực báo giá/ });

test('Nhóm bên trái, tìm tham số, Lịch sử thay đổi mờ', async ({ page }) => {
  await open(page);
  await expect(page.getByRole('button', { name: 'Lịch sử thay đổi' })).toBeDisabled();
  await expect(groups(page).getByRole('button', { name: /^Bán hàng/ })).toBeVisible();
  await groups(page).getByRole('textbox', { name: 'Tìm tham số' }).fill('hạn hiệu lực báo giá');
  await expect(rowOf(page)).toBeVisible();
  await expect(rowOf(page).getByRole('cell', { name: '14', exact: true })).toBeVisible();
  await expect(rowOf(page).getByRole('cell', { name: 'ngày', exact: true }).first()).toBeVisible();
  await expect(rowOf(page)).toContainText('1–90 ngày');
  await expectAccessible(page);
});

test('Sửa giá trị chung: ngoài khoảng khoá nút Lưu; hợp lệ thì xác nhận cũ → mới rồi lưu', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await open(page);
  await groups(page).getByRole('textbox', { name: 'Tìm tham số' }).fill('hạn hiệu lực báo giá');
  await rowOf(page).getByRole('button', { name: 'Sửa', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('textbox', { name: /Giá trị/ }).fill('120');
  await expect(dialog.getByText('Giá trị phải trong khoảng 1–90 ngày.')).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  await dialog.getByRole('textbox', { name: /Giá trị/ }).fill('20');
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  const confirm = page.getByRole('alertdialog');
  await expect(confirm.getByText('14 ngày')).toBeVisible();
  await expect(confirm.getByText('20 ngày')).toBeVisible();
  await confirm.getByRole('button', { name: 'Lưu' }).click();
  await expect(page.getByText('Đã lưu tham số.').first()).toBeVisible();
  await expect(rowOf(page).getByRole('cell', { name: '20', exact: true })).toBeVisible();
  const rows = await sql<{ value: string }>('select value from app.setting_def where key = $1', [
    KEY,
  ]);
  expect(rows[0]?.value).toBe('20');
});

test('Ghi đè theo cơ sở: thêm rồi bỏ ghi đè', async ({ page }) => {
  test.setTimeout(90_000);
  await open(page);
  await groups(page).getByRole('textbox', { name: 'Tìm tham số' }).fill('hạn hiệu lực báo giá');
  await rowOf(page).getByRole('button', { name: 'Ghi đè cơ sở' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('combobox', { name: 'Cơ sở' }).click();
  await page.getByRole('option', { name: /^CS5/ }).click();
  await dialog.getByRole('textbox', { name: /Giá trị/ }).fill('7');
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Lưu' }).click();
  await expect(rowOf(page)).toContainText('CS5');
  await expect(rowOf(page).getByRole('cell', { name: '7', exact: true })).toBeVisible();
  await rowOf(page).getByRole('button', { name: 'Bỏ ghi đè CS5' }).click();
  await expect(page.getByText('Đã bỏ ghi đè CS5.').first()).toBeVisible();
  await expect(rowOf(page)).toContainText('chưa ghi đè');
});
