// QT-14 Ngày nghỉ lễ: bảng theo năm, thêm ngày nghỉ (chặn trùng), ngừng và dùng lại, hộp Xem buổi bị ảnh hưởng. Chỉ bản máy tính (Cấu hình không có bản điện thoại).
// Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Ngày thử cố định xa (31/12 năm sau) rồi dọn sau bài.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Cấu hình chỉ có bản máy tính.');
});

const NAME = 'Nghỉ thử e2e QT-14';
const YEAR = new Date().getFullYear();

// Ngày nghỉ không cho xoá cứng; bài dọn bằng phiên "replica" (bỏ trigger) trong một giao dịch.
async function clean() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query('delete from app.holiday where name = $1', [NAME]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}
test.beforeAll(clean);
test.afterAll(clean);

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/ngay-nghi');
  await expect(page.getByRole('heading', { level: 1, name: 'Ngày nghỉ lễ' })).toBeVisible();
}

test('Bảng ngày nghỉ của năm hiện tại, có nút Thêm', async ({ page }) => {
  await open(page);
  await expect(page.getByRole('button', { name: 'Thêm ngày nghỉ' })).toBeVisible();
  await expect(page.getByRole('table', { name: `Ngày nghỉ năm ${YEAR}` })).toBeVisible();
  await expectAccessible(page);
});

test('Thêm ngày nghỉ chung, chặn trùng, ngừng rồi dùng lại', async ({ page }) => {
  test.setTimeout(90_000);
  await open(page);
  await page.getByRole('button', { name: 'Thêm ngày nghỉ' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('textbox', { name: /Ngày nghỉ/ }).fill(`31/12/${YEAR}`);
  await dialog.getByRole('textbox', { name: /Tên ngày nghỉ/ }).fill(NAME);
  await dialog.getByRole('button', { name: 'Thêm', exact: true }).click();
  await expect(page.getByText(/Đã lưu/).first()).toBeVisible();
  const row = page.getByRole('row', { name: new RegExp(NAME) });
  await expect(row).toContainText('Mọi cơ sở');
  await expect(row).toContainText('Đang dùng');
  // Thêm lại đúng ngày đó: DB chặn trùng, hộp hiện câu lỗi.
  await page.getByRole('button', { name: 'Thêm ngày nghỉ' }).click();
  const again = page.getByRole('dialog');
  await again.getByRole('textbox', { name: /Ngày nghỉ/ }).fill(`31/12/${YEAR}`);
  await again.getByRole('textbox', { name: /Tên ngày nghỉ/ }).fill(NAME);
  await again.getByRole('button', { name: 'Thêm', exact: true }).click();
  await expect(again.getByText('Ngày này đã là ngày nghỉ chung.')).toBeVisible();
  await again.getByRole('button', { name: 'Huỷ' }).click();
  await row.getByRole('button', { name: 'Ngừng' }).click();
  await expect(page.getByText('Đã ngừng ngày nghỉ.').first()).toBeVisible();
  await expect(row).toContainText('Ngừng');
  await row.getByRole('button', { name: 'Dùng lại' }).click();
  await expect(row).toContainText('Đang dùng');
});

test('Xem buổi bị ảnh hưởng: hộp hiện kết quả', async ({ page }) => {
  await open(page);
  await page
    .getByRole('row', { name: new RegExp(NAME) })
    .getByRole('button', { name: 'Xem buổi bị ảnh hưởng' })
    .click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByText('Buổi bị ảnh hưởng')).toBeVisible();
  await expect(dialog.getByText('Không có buổi nào chưa diễn ra trùng ngày này.')).toBeVisible();
});
