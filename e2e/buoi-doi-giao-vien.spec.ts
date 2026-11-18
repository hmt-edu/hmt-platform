// BUOI-13 Đổi giáo viên, trợ giảng cho một buổi (dạy thay): CSKH có quyền Sửa buổi; chỉ buổi Nháp, Đã chốt. Máy tính (cổng CRM ưu tiên máy tính).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, pickOption } from './helpers';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.skip(({ isMobile }) => isMobile, 'Cổng CRM ưu tiên máy tính.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
});

test('BUOI-13: chưa đổi gì thì chưa cho lưu; đổi trợ giảng, lưu, bản ghi hiện trợ giảng mới', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.khac}`);
  await page.getByRole('button', { name: 'Đổi giáo viên' }).click();
  const dialog = page.getByRole('dialog', { name: 'Đổi giáo viên' });
  const save = dialog.getByRole('button', { name: 'Lưu người dạy' });
  await expect(save).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Trợ giảng' }), /Trợ giảng CS5/);
  await expect(save).toBeEnabled();
  await save.click();
  await expect(page.getByText('Đã đổi người dạy', { exact: true })).toBeVisible();
  await expect(page.getByText('Trợ giảng CS5 (giả)').first()).toBeVisible();
});

test('BUOI-13: Sale chỉ xem được buổi, không có nút Đổi giáo viên (thiếu quyền Buổi học · Sửa)', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.khac}`);
  await expect(page.getByRole('heading', { name: 'Danh sách và điểm danh' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Đổi giáo viên' })).toHaveCount(0);
});
