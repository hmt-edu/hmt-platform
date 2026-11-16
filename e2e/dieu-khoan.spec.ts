// CH-09 Điều khoản thanh toán (canvas 9933: CH09_chinh, CH09_loi): danh sách, các đợt, thêm điều khoản (lỗi tổng % rồi lưu), Ngừng và Dùng lại.
// Chỉ bản máy tính (Cấu hình không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Điều khoản thử mã E2E_DIEU_KHOAN_*, dọn sau bài.
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

const NAME = 'E2E điều khoản thử';

// Điều khoản không cho xoá: dọn bằng phiên "replica" (bỏ trigger) trong một giao dịch.
async function clean() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      "delete from app.payment_term_installment where term_id in (select id from app.payment_term where code like 'E2E_DIEU_KHOAN%')",
    );
    await db.query("delete from app.payment_term where code like 'E2E_DIEU_KHOAN%'");
    await db.query('commit');
  } finally {
    await db.end();
  }
}
test.beforeAll(clean);
test.afterAll(clean);

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/dieu-khoan-thanh-toan');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Điều khoản thanh toán' }),
  ).toBeVisible();
}

test('Danh sách điều khoản và bảng các đợt của điều khoản đang chọn', async ({ page }) => {
  await open(page);
  await expect(page.getByRole('navigation', { name: 'Danh sách điều khoản' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Các đợt của điều khoản' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm điều khoản' })).toBeVisible();
  await expectAccessible(page);
});

test('Thêm điều khoản: tổng % sai thì báo lỗi và khoá Lưu; sửa đúng thì lưu, rồi Ngừng và Dùng lại', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await open(page);
  await page.getByRole('button', { name: 'Thêm điều khoản' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('textbox', { name: /Tên điều khoản/ }).fill(NAME);
  await dialog.getByRole('textbox', { name: /Hiệu lực từ/ }).fill('01/01/2030');
  const values = dialog.getByRole('textbox', { name: /Giá trị \(%\)/ });
  await values.nth(0).fill('30');
  await values.nth(1).fill('60');
  await dialog.getByRole('textbox', { name: 'Số ngày đến hạn' }).nth(1).fill('30');
  await expect(
    dialog.getByText('Tổng phần trăm các đợt chia theo % phải đúng 100 (đang 90).'),
  ).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  await values.nth(1).fill('70');
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await expect(page.getByText('Đã lưu điều khoản.').first()).toBeVisible();
  const item = page.getByRole('navigation', { name: 'Danh sách điều khoản' }).getByRole('button', {
    name: new RegExp(NAME),
  });
  await expect(item).toContainText('Chia 2 đợt');
  await item.click();
  const region = page.getByRole('region', { name: 'Các đợt của điều khoản' });
  await expect(region.getByRole('table')).toContainText('30%');
  await expect(region.getByRole('table')).toContainText('70%');
  await region.getByRole('button', { name: 'Ngừng', exact: true }).click();
  await expect(page.getByText('Đã ngừng điều khoản.').first()).toBeVisible();
  await expect(item).toContainText('Ngừng');
  await region.getByRole('button', { name: 'Dùng lại' }).click();
  await expect(item).toContainText('Đang dùng');
});
