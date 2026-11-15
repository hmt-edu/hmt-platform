// QT-05 Ma trận quyền (canvas 9933: MaTranQuyen, _ct, _ls): chọn vai trò, bấm Sửa, đổi một ô, Lưu thay đổi tạo phiên bản mới có hiệu lực ngay; trả ô về như cũ bằng phiên bản kế.
// Chỉ bản máy tính (Quản trị không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Ô thử: vai trò Phụ huynh (chưa cấp quyền), phân hệ Lead, hành động Xem.
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

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

test('Ma trận hiện vai trò, lưới phân hệ × hành động, phiên bản hiện hành và lịch sử', async ({
  page,
}) => {
  await open(page);
  await expect(page.getByText(/Hiện hành: phiên bản \d+/)).toBeVisible();
  await expect(page.getByRole('region', { name: 'Lịch sử thay đổi quyền' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa' })).toBeVisible();
  await expectAccessible(page);
});

test('Sửa một ô, lưu thành phiên bản mới; trả về như cũ bằng phiên bản kế', async ({ page }) => {
  test.setTimeout(120_000);
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
