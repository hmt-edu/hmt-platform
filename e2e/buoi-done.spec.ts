// BUOI-02, BUOI-12 giao diện DD2: Done tay liệt kê điều còn thiếu, Nhập thay chỉ Điểm danh · Duyệt và bắt buộc lý do. Máy tính (cổng CRM ưu tiên máy tính).
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

test('BUOI-02: CSKH có Done tay, không có Nhập thay; chưa đủ thì liệt kê còn thiếu', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.chot}`);
  await expect(page.getByRole('button', { name: 'Nhập thay' })).toHaveCount(0);
  await page.getByRole('button', { name: 'Done tay' }).click();
  await expect(page.getByText('Chưa Done được. Còn thiếu:')).toBeVisible();
});

test('BUOI-02: Trưởng cơ sở nhập thay điểm danh kèm lý do; bản ghi hiện lượt nhập thay', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.chot}`);
  await page.getByRole('button', { name: 'Nhập thay' }).click();
  const dialog = page.getByRole('dialog', { name: 'Nhập thay điểm danh' });
  const save = dialog.getByRole('button', { name: 'Lưu nhập thay' });
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: new RegExp(seed.names[0]) }),
    'Vắng không phép',
  );
  await expect(save).toBeDisabled();
  await dialog.getByRole('textbox', { name: 'Lý do' }).fill('Giáo viên giả bị ốm');
  await save.click();
  await expect(page.getByText('Đã nhập thay điểm danh', { exact: true })).toBeVisible();
  await expect(page.getByText(/Lý do: Giáo viên giả bị ốm/)).toBeVisible();
});
