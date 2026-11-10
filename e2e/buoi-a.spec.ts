// Cụm Buổi A: BUOI-01 danh sách buổi, BUOI-02 bản ghi, BUOI-03 điểm danh vận hành, BUOI-11 vắng / chưa đến, và cột "Ghi chú vận hành (chỉ xem)" của GV-05.
// Dữ liệu giả dựng bằng gv-diem-danh-seed.ts (lớp CS5, buổi hôm nay do gv.cs5 dạy). Máy tính: cổng CRM ưu tiên máy tính nên chỉ chạy dự án may-tinh.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, loginStaff, pickOption } from './helpers';
import { DB_URL } from './bao-gia-seed';
import { markAsAssistant, seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.skip(({ isMobile }) => isMobile, 'Cổng CRM ưu tiên máy tính.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
let classCode = '';
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    classCode =
      (
        await db.query<{ code: string }>(
          'select c.code from app.class_session s join app.class c on c.id = s.class_id where s.id = $1',
          [seed.chot],
        )
      ).rows[0]?.code ?? '';
  } finally {
    await db.end();
  }
});

test('BUOI-01: danh sách mặc định hôm nay, tìm theo mã lớp thấy buổi, bấm Mở sang BUOI-02', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/buoi-hoc');
  await expect(page.getByRole('heading', { level: 1, name: 'Buổi học' })).toBeVisible();
  await page.getByRole('searchbox').fill(classCode);
  const link = page.locator(`a[href="/crm/buoi-hoc/${seed.chot}"]`).first();
  await expect(link).toBeVisible();
  await link.click();
  await expect(page).toHaveURL(new RegExp(`/crm/buoi-hoc/${seed.chot}$`));
});

test('BUOI-02: bản ghi buổi Đã chốt có danh sách, hai cột điểm danh và nút Điểm danh vận hành', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.chot}`);
  await expect(page.getByRole('heading', { name: 'Danh sách và điểm danh' })).toBeVisible();
  for (const name of seed.names) await expect(page.getByRole('cell', { name })).toBeVisible();
  await expect(
    page.getByRole('columnheader', { name: 'Điểm danh giáo viên (chính thức)' }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Điểm danh vận hành' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Chốt danh sách' })).toHaveCount(0);
});

test('BUOI-02: buổi Nháp có nút Chốt danh sách; chốt xong thì thành Đã chốt', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${seed.nhap}`);
  await expect(page.getByText('Buổi ở Nháp: danh sách chưa chốt', { exact: false })).toBeVisible();
  await page.getByRole('button', { name: 'Chốt danh sách' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Chốt danh sách' }).click();
  await expect(page.getByText('Đã chốt danh sách', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Điểm danh vận hành' })).toBeVisible();
});

test('BUOI-03: ghi trạng thái trung tâm, Lưu, tải lại vẫn còn; không tự lưu', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/diem-danh/buoi/${seed.chot}`);
  await expect(page.getByText('Đã ghi 0/3 em')).toBeVisible();
  await pickOption(
    page,
    page.getByRole('combobox', { name: `Trung tâm điểm danh · ${seed.names[0]}` }),
    'Có mặt',
  );
  await expect(page.getByText('Chưa lưu', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu điểm danh vận hành', { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText('Đã ghi 1/3 em')).toBeVisible();
});

test('BUOI-11: em giáo viên ghi Vắng hiện ở danh sách, em Có mặt không hiện; Ghi lý do rồi đọc lại', async ({
  page,
}) => {
  await markAsAssistant(seed.chot, seed.names[1], 'VANG_KHONG_PHEP');
  await markAsAssistant(seed.chot, seed.names[2], 'CO_MAT');
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/diem-danh');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Học sinh vắng / chưa đến' }),
  ).toBeVisible();
  await page.getByRole('searchbox').fill('Em E2E');
  // Buổi "khác" của seed cũng có em này nhưng chưa ai ghi (Chưa đến): chỉ xét dòng Vắng của buổi giáo viên đã ghi.
  const row = page.getByRole('row').filter({ hasText: seed.names[1] }).filter({ hasText: 'Vắng' });
  await expect(row).toBeVisible();
  await expect(
    page.getByRole('row').filter({ hasText: seed.names[2] }).filter({ hasText: 'Vắng' }),
  ).toHaveCount(0);
  await row.getByRole('button', { name: 'Ghi lý do' }).click();
  const dialog = page.getByRole('dialog', { name: 'Ghi lý do liên hệ' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Lý do liên hệ' }), 'Không nghe máy');
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await expect(page.getByText('Đã ghi lý do liên hệ', { exact: true })).toBeVisible();
  await expect(row).toContainText('Không nghe máy');
});

test('GV-05: giáo viên thấy lý do liên hệ do vận hành ghi ở cột Ghi chú vận hành (chỉ xem)', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/buoi/${seed.chot}/diem-danh`);
  const li = page.getByRole('listitem').filter({ hasText: seed.names[1] });
  await expect(li).toContainText('Ghi chú vận hành (chỉ xem)');
  await expect(li).toContainText('Không nghe máy');
});
