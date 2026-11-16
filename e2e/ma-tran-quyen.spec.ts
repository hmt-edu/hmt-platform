// QT-05 Ma trận quyền (canvas 9933: MaTranQuyen, _ct, _ls): chọn vai trò, bấm Sửa, đổi một ô, Lưu thay đổi tạo phiên bản mới có hiệu lực ngay; trả ô về như cũ bằng phiên bản kế.
// Chỉ bản máy tính (Quản trị không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Ô thử: vai trò Phụ huynh (chưa cấp quyền), phân hệ Lead, hành động Xem.
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

// Cờ sửa ma trận (migration 182) mặc định tắt: bài bật rồi tắt lại để các bài khác thấy trạng thái mặc định.
async function setFlag(value: 'true' | 'false') {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      "update app.setting_def set value = $1 where key = 'permission_matrix_edit_enabled'",
      [value],
    );
  } finally {
    await db.end();
  }
}
test.afterAll(() => setFlag('false'));

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/ma-tran-quyen');
  await expect(page.getByRole('heading', { level: 1, name: 'Ma trận quyền' })).toBeVisible();
  await page
    .getByRole('navigation', { name: 'Vai trò' })
    .getByRole('button', { name: /PARENT/ })
    .click();
}

const cell = (page: Page) => page.getByLabel(/^.*, Lead, Xem$/);

test('Cờ sửa ma trận tắt (mặc định): màn chỉ xem, không có nút Sửa', async ({ page }) => {
  await setFlag('false');
  await open(page);
  await expect(page.getByText(/Sửa ma trận quyền đang tắt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toHaveCount(0);
});

test('Ma trận hiện vai trò, lưới phân hệ × hành động, phiên bản hiện hành và lịch sử', async ({
  page,
}) => {
  await setFlag('true');
  await open(page);
  await expect(page.getByText(/Hiện hành: phiên bản \d+/)).toBeVisible();
  await expect(page.getByRole('region', { name: 'Lịch sử thay đổi quyền' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa' })).toBeVisible();
  await expectAccessible(page);
});

test('Sửa một ô, lưu thành phiên bản mới; trả về như cũ bằng phiên bản kế', async ({ page }) => {
  test.setTimeout(120_000);
  await setFlag('true');
  await open(page);
  await page.getByRole('button', { name: 'Sửa' }).click();
  await expect(page.getByRole('button', { name: 'Lưu thay đổi' })).toBeDisabled();
  await cell(page).selectOption({ label: 'Cơ sở mình' });
  await expect(page.getByText(/Đã đổi 1 ô của vai trò/)).toBeVisible();
  await page.getByRole('textbox', { name: /Ghi chú phiên bản/ }).fill('e2e thử ma trận');
  await page.getByRole('button', { name: 'Lưu thay đổi' }).click();
  await expect(page.getByText(/Đã lưu phiên bản \d+, có hiệu lực ngay/).first()).toBeVisible();
  await expect(page.getByRole('region', { name: 'Lịch sử thay đổi quyền' })).toContainText(
    'e2e thử ma trận',
  );
  // Trả về như cũ.
  await page.getByRole('button', { name: 'Sửa' }).click();
  await cell(page).selectOption({ label: 'Không có' });
  await page.getByRole('textbox', { name: /Ghi chú phiên bản/ }).fill('e2e trả lại');
  await page.getByRole('button', { name: 'Lưu thay đổi' }).click();
  await expect(page.getByText(/Đã lưu phiên bản \d+/).first()).toBeVisible();
});
