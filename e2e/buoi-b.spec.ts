// Cụm Buổi B: BUOI-04 huỷ buổi (lưu lý do), BUOI-05 dời buổi, BUOI-12 buổi chưa hoàn tất và Nhắc GV. Dữ liệu giả dựng bằng gv-diem-danh-seed.ts (lớp CS5).
// Máy tính: cổng CRM ưu tiên máy tính nên chỉ chạy dự án may-tinh.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, pickOption, showAllColumns } from './helpers';
import { DB_URL } from './bao-gia-seed';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.skip(({ isMobile }) => isMobile, 'Cổng CRM ưu tiên máy tính.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
let classCode = '';

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
  await withDb(async (db) => {
    classCode =
      (
        await db.query<{ code: string }>(
          'select c.code from app.class_session s join app.class c on c.id = s.class_id where s.id = $1',
          [seed.chot],
        )
      ).rows[0]?.code ?? '';
    // Buổi Đã chốt đã kết thúc từ 00:30 NGÀY HÔM QUA (giờ Việt Nam, không dùng ngày máy chủ): luôn nằm trong danh sách "chưa hoàn tất", kể cả chạy quanh nửa đêm.
    await db.query(
      `update app.class_session set start_time = '00:00', end_time = '00:30',
              session_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1 where id = $1`,
      [seed.chot],
    );
  });
});

test('BUOI-04: lớp thường chỉ có "Trung tâm huỷ"; chọn lý do, xem trước, huỷ rồi bản ghi hiện lý do', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.nhap}`);
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Huỷ buổi' });
  await expect(dialog.getByRole('radio', { name: 'Trung tâm huỷ (cả lớp nghỉ)' })).toBeChecked();
  await expect(dialog.getByRole('radio', { name: 'Học sinh huỷ (lớp riêng)' })).toHaveCount(0);
  await expect(dialog.getByRole('button', { name: 'Xác nhận huỷ buổi' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Lý do huỷ' }), 'Thời tiết');
  await expect(dialog.getByText('Buổi thêm vào cuối lịch', { exact: false })).toBeVisible();
  await dialog.getByRole('button', { name: 'Xác nhận huỷ buổi' }).click();
  await expect(page.getByText('Đã huỷ buổi', { exact: true })).toBeVisible();
  await expect(page.getByText('Lý do: Thời tiết', { exact: false })).toBeVisible();
});

test('BUOI-01: buổi đã huỷ hiện lý do ở cột Ghi chú', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/buoi-hoc');
  await page.getByRole('searchbox').fill(classCode);
  await showAllColumns(page);
  const row = page.locator(`a[href="/crm/buoi-hoc/${seed.nhap}"]`).first();
  await expect(row).toBeVisible();
  await expect(page.getByRole('row').filter({ has: row })).toContainText('Thời tiết');
});

test('BUOI-05: dời giờ kết thúc, lưu rồi bản ghi hiện giờ mới', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.khac}`);
  await page.getByRole('button', { name: 'Dời', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Dời buổi' });
  await dialog.getByLabel('Giờ kết thúc').fill('20:00');
  await dialog.getByRole('button', { name: 'Xác nhận' }).click();
  await expect(page.getByText('Đã dời buổi', { exact: true })).toBeVisible();
  await expect(page.getByText('18:00–20:00', { exact: false })).toBeVisible();
});

test('BUOI-05: giờ kết thúc không sau giờ bắt đầu thì chưa cho xác nhận', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.khac}`);
  await page.getByRole('button', { name: 'Dời', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Dời buổi' });
  await dialog.getByLabel('Giờ kết thúc').fill('17:00');
  await expect(dialog.getByRole('button', { name: 'Xác nhận' })).toBeDisabled();
});

test('BUOI-12: buổi Đã chốt đã kết thúc có trong danh sách kèm hạn; nút Nhắc GV mờ kèm chữ giải thích', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/buoi-chua-done');
  await expect(page.getByRole('heading', { level: 1, name: 'Buổi chưa hoàn tất' })).toBeVisible();
  await page.getByRole('searchbox').fill(classCode);
  const row = page.getByRole('row').filter({ hasText: classCode }).first();
  await expect(row).toBeVisible();
  await expect(row).toContainText(/Quá hạn|Còn/);
  await expect(row.getByRole('button', { name: 'Nhắc GV' })).toBeDisabled();
  await expect(row).toContainText('Giáo viên chưa có hộp thông báo, làm sau 17/11');
});
