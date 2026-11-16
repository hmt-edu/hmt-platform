// QT-04 Vai trò (danh sách + mô tả): chỉ đọc, máy tính. Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Không thêm, sửa, ngừng vai trò; có link «Mở ma trận».
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (thiết bị hai bước giả).');

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

test('Danh sách vai trò kèm phạm vi, cổng, hai bước, số người, số ô quyền; có Mở ma trận, không có nút Thêm', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/vai-tro');
  await expect(page.getByRole('heading', { level: 1, name: 'Vai trò' })).toBeVisible();
  const table = page.getByRole('table', { name: 'Các vai trò' });
  await expect(table.getByRole('row', { name: /ADMIN/ })).toContainText('Toàn hệ thống');
  await expect(table.getByRole('row', { name: /ADMIN/ })).toContainText('Bắt buộc');
  await expect(table.getByRole('row', { name: /TEACHER/ })).toContainText('Giáo viên');
  await expect(table.getByRole('link', { name: /Mở ma trận quyền của/ }).first()).toBeVisible();
  await expect(page.getByRole('button', { name: /^Thêm/ })).toHaveCount(0);
  await page.getByRole('textbox', { name: 'Tìm vai trò' }).fill('kế toán');
  await expect(table.getByRole('row', { name: /ACCOUNTANT/ })).toBeVisible();
  await expect(table.getByRole('row', { name: /TEACHER/ })).toHaveCount(0);
  await expectAccessible(page);
});
