// QT-16 Hồ sơ giáo viên, trợ giảng (khuôn K03 + hộp thoại K08, không có khung canvas): Admin tạo hồ sơ cho giáo viên gv.cs5 (môn, khối, cơ sở), thấy ở danh sách,
// Ngừng rồi Dùng lại. Trưởng cơ sở chỉ xem (không có nút Tạo, Sửa). Chỉ bản máy tính (Quản trị không có bản điện thoại). Dữ liệu giả; dọn hồ sơ trước và sau bài.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, enterAsAdmin, expectAccessible, pickOption } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dọn hồ sơ giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

async function clear() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      'delete from app.teaching_profile where user_id = (select id from auth.users where email = $1)',
      [`gv.cs5@${DOMAIN}`],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
}

test.beforeAll(clear);
test.afterAll(clear);

test('QT-16: Admin tạo hồ sơ dạy, thấy ở danh sách, Ngừng rồi Dùng lại', async ({ page }) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/giao-vien');
  await expect(page.getByRole('heading', { level: 1, name: 'Giáo viên, trợ giảng' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo hồ sơ' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo hồ sơ dạy' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Tạo hồ sơ' })).toBeDisabled();
  await expectAccessible(page);
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Giáo viên, trợ giảng' }),
    /Giáo viên CS5/,
  );
  await dialog.getByLabel('Toán', { exact: true }).check();
  await dialog.getByRole('button', { name: 'Tạo hồ sơ' }).click();
  await expect(page.getByText('Đã tạo hồ sơ dạy.').first()).toBeVisible();
  const row = page.getByRole('row').filter({ hasText: 'Giáo viên CS5' });
  await expect(row).toContainText('Toán');
  await expect(row).toContainText('Đang dạy');
  await row.getByRole('button', { name: 'Ngừng' }).click();
  await expect(page.getByText('Đã ngừng hồ sơ dạy.').first()).toBeVisible();
  await expect(row).toContainText('Ngừng');
  await row.getByRole('button', { name: 'Dùng lại' }).click();
  await expect(page.getByText('Đã dùng lại hồ sơ dạy.').first()).toBeVisible();
});

test('QT-16: Trưởng cơ sở chỉ xem, không có nút Tạo hồ sơ', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/quan-tri/giao-vien');
  // Mục menu chỉ cho Admin (quyền Quản trị): người khác mở link thì báo không có quyền.
  await expect(page.getByRole('button', { name: 'Tạo hồ sơ' })).toHaveCount(0);
});
