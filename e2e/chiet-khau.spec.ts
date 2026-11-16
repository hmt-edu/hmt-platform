// CH-04 Chính sách chiết khấu, quà tặng (canvas 9933: CH04_chinh, CH04_loi): hai tab, thêm chiết khấu (lỗi tóm tắt rồi lưu), Ngừng và Dùng lại, tab Quà tặng.
// Chỉ bản máy tính (Cấu hình không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Chính sách thử có mã bắt đầu E2E_CHIET_KHAU, dọn sau bài.
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

const NAME = 'E2E chiết khấu thử';

// Chính sách không cho xoá: dọn bằng phiên "replica" (bỏ trigger) trong một giao dịch.
async function clean() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query("delete from app.discount_policy where code like 'E2E_CHIET_KHAU%'");
    await db.query('commit');
  } finally {
    await db.end();
  }
}
test.beforeAll(clean);
test.afterAll(clean);

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/chiet-khau');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Chính sách chiết khấu' }),
  ).toBeVisible();
}

test('Hai tab Chiết khấu và Quà tặng; chính sách Ưu đãi linh hoạt của hệ thống không có nút Sửa', async ({
  page,
}) => {
  await open(page);
  await expect(page.getByRole('tab', { name: /^Chiết khấu/ })).toBeVisible();
  await expect(page.getByRole('tab', { name: /^Quà tặng/ })).toBeVisible();
  const flexible = page.getByRole('row', { name: /Ưu đãi linh hoạt/ });
  await expect(flexible).toContainText('Hệ thống');
  await expect(flexible.getByRole('button', { name: 'Sửa' })).toHaveCount(0);
  await page.getByRole('tab', { name: /^Quà tặng/ }).click();
  await expect(page.getByRole('button', { name: 'Thêm quà tặng' })).toBeVisible();
  await expectAccessible(page);
});

test('Thêm chiết khấu: thiếu thì báo tóm tắt; đủ thì lưu, rồi Ngừng và Dùng lại', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await open(page);
  await page.getByRole('button', { name: 'Thêm chiết khấu' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('textbox', { name: /Tên chính sách/ }).fill(NAME);
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await expect(dialog.getByText(/^Chưa lưu được: còn \d chỗ cần sửa/)).toBeVisible();
  await expect(dialog.getByText('Bắt buộc nhập mức tối đa')).toBeVisible();
  await dialog.getByRole('textbox', { name: /Mức tối đa/ }).fill('7');
  await dialog.getByRole('textbox', { name: /Hiệu lực từ/ }).fill('01/01/2030');
  await dialog.getByRole('checkbox', { name: 'Lớp chung' }).check();
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await expect(page.getByText('Đã lưu chính sách.').first()).toBeVisible();
  const row = page.getByRole('row', { name: new RegExp(NAME) });
  await expect(row).toContainText('7%');
  await expect(row).toContainText('Chưa tới hạn');
  await row.getByRole('button', { name: 'Ngừng' }).click();
  await expect(page.getByText('Đã ngừng chính sách.').first()).toBeVisible();
  await expect(row).toContainText('Ngừng');
  await row.getByRole('button', { name: 'Dùng lại' }).click();
  await expect(row).toContainText('Chưa tới hạn');
});
