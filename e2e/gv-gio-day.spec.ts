// GV-16 Giờ dạy của tôi (cổng giáo viên). Dữ liệu giả dựng bằng gv-diem-danh-seed.ts: buổi Đã chốt hôm nay của gv.cs5 được đặt Done kèm dấu Trễ hạn 2,5 giờ
// (sửa thẳng cột, chỉ để dựng dữ liệu). Máy tính: bảng theo buổi; điện thoại: thẻ từng buổi. Chỉ buổi của chính mình (R-GV-08).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { PASSWORD, expectAccessible, isPhone, loginStaff } from './helpers';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `update app.class_session set status_code = 'DONE', completion_stamped_at = now(), completion_late = true, completion_late_hours = 2.5
        where id = $1`,
      [seed.chot],
    );
  } finally {
    await db.end();
  }
});

test('GV-16: giờ dạy tháng này có buổi Done (1,5 giờ) kèm Trễ hạn 2,5 giờ; đổi tháng; link từ Lịch dạy', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lich-day');
  await page.getByRole('link', { name: 'Giờ dạy của tôi' }).click();
  await expect(page).toHaveURL(/\/gv\/gio-day$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Giờ dạy của tôi' })).toBeVisible();
  const summary = page.getByRole('region', { name: 'Tóm tắt' });
  for (const label of ['Số buổi', 'Tổng giờ', 'Buổi trễ hạn', 'Giờ trễ'])
    await expect(summary.getByText(label, { exact: true })).toBeVisible();
  // Điện thoại (canvas GV16_dt): danh sách «Buổi trong tháng» nằm sau nút «Xem chi tiết», mở thành tấm trượt có nút Đóng.
  const phone = isPhone(page);
  if (phone) await page.getByRole('button', { name: 'Xem chi tiết' }).click();
  await expect(page.getByText('Trễ hạn 2,5 giờ').first()).toBeVisible();
  await expect(page.getByText('Buổi chính').first()).toBeVisible();
  await expect(page.getByText(/Buổi huỷ không tính/)).toBeVisible();
  // Hộp có nút «Đóng» ở chân và nút đóng góc (cùng tên): bấm nút chân hộp (cuối cùng).
  if (phone) await page.getByRole('dialog').getByRole('button', { name: 'Đóng' }).last().click();
  await expectAccessible(page);
  // Đổi tháng: nhãn tháng đổi, Tháng này quay lại đúng tháng cũ.
  const label = page.getByText(/^Tháng \d{2}\/\d{4}$/);
  const before = await label.textContent();
  await page.getByRole('button', { name: 'Tháng trước' }).click();
  await expect(label).not.toHaveText(before ?? '');
  await page.getByRole('button', { name: 'Tháng này' }).click();
  await expect(label).toHaveText(before ?? '');
});
