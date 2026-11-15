// BUOI-14 Sửa điểm danh sau khi buổi Done: chỉ Trưởng cơ sở (Điểm danh · Duyệt), bắt buộc lý do; CSKH không thấy nút. Máy tính (cổng CRM ưu tiên máy tính).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, pickOption } from './helpers';
import { DB_URL } from './bao-gia-seed';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.skip(({ isMobile }) => isMobile, 'Cổng CRM ưu tiên máy tính.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    // Đưa buổi Đã chốt sang Done (dữ liệu giả); điểm danh giáo viên em đầu có sẵn từ seed.
    await db.query(`update app.class_session set status_code = 'DONE' where id = $1`, [seed.chot]);
  } finally {
    await db.end();
  }
});

test('BUOI-14: CSKH không có nút Sửa điểm danh (thiếu quyền Điểm danh · Duyệt)', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.chot}`);
  await expect(page.getByRole('heading', { name: 'Danh sách và điểm danh' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa điểm danh' })).toHaveCount(0);
});

test('BUOI-14: Trưởng cơ sở sửa điểm danh một em kèm lý do; bảng hiện trạng thái mới', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.chot}`);
  await page.getByRole('button', { name: 'Sửa điểm danh' }).click();
  const dialog = page.getByRole('dialog', { name: 'Sửa điểm danh' });
  const save = dialog.getByRole('button', { name: 'Lưu sửa điểm danh' });
  await expect(save).toBeDisabled();
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Học sinh' }),
    new RegExp(seed.names[0]),
  );
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Trạng thái đúng' }),
    'Vắng không phép',
  );
  // Chưa chọn lý do thì chưa lưu được.
  await expect(save).toBeDisabled();
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Lý do' }),
    'Sửa sai danh sách/điểm danh',
  );
  await expect(save).toBeEnabled();
  await save.click();
  await expect(page.getByText('Đã sửa điểm danh', { exact: true })).toBeVisible();
  const row = page.getByRole('row').filter({ hasText: seed.names[0] });
  await expect(row).toContainText('Vắng không phép');
});
