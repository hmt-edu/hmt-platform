// GV-17 Giao bài trên LMS (cổng giáo viên, điện thoại và máy tính): Bài đã giao trống, Giao bài (hộp xác nhận), Sửa, Gỡ bài, lỗi nhập liệu.
// Dữ liệu giả: lớp do seedAttendance dựng (giáo viên gv.cs5, 3 em), công tắc HOC_TAP bật cho CS5 trong bài này.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, expectAccessible, loginStaff } from './helpers';
import { seedAttendance } from './gv-diem-danh-seed';
import { DB_URL } from './bao-gia-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let classId = '';
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'HOC_TAP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const r = await db.query<{ class_id: string }>(
      'select class_id from app.class_session where id = $1',
      [seed.chot],
    );
    classId = r.rows[0]?.class_id ?? '';
    // Xếp ba em của buổi Đã chốt vào lớp (đang học) để có người nhận bài: seedAttendance chỉ tạo dòng điểm danh.
    const tag = `${Date.now()}`.slice(-8);
    const students = await db.query<{ id: string; parent_id: string }>(
      `select st.id, st.parent_id from app.student st join app.session_attendance sa on sa.student_id = st.id where sa.session_id = $1 order by st.full_name`,
      [seed.chot],
    );
    for (const [i, st] of students.rows.entries()) {
      const en = await db.query<{ id: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
         values ($1, $2, $3, (select id from app.branch where code = 'CS5'), 'TOAN') returning id`,
        [`GDLMS${tag}${i}`, st.id, st.parent_id],
      );
      await db.query(
        `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
         values ($1, $2, (select id from app.branch where code = 'CS5'), (now() at time zone 'Asia/Ho_Chi_Minh')::date - 30)`,
        [en.rows[0]?.id, classId],
      );
    }
  } finally {
    await db.end();
  }
});

const ahead = (days: number) => {
  const d = new Date(Date.now() + days * 86_400_000);
  return d.toISOString().slice(0, 10);
};

test('GV-17: giao bài, thấy trong Bài đã giao, sửa, rồi gỡ bài', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/lop/${classId}/bai-giao`);
  await expect(page.getByRole('heading', { level: 1, name: 'Bài đã giao' })).toBeVisible();
  await expect(page.getByText('Lớp này chưa giao bài nào')).toBeVisible();
  await expectAccessible(page);

  await page.getByRole('link', { name: 'Giao bài' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Giao bài trên LMS' })).toBeVisible();
  await expect(page.getByText('3 em sẽ nhận bài.')).toBeVisible();
  // Ô «Buổi giao» chỉ có buổi của chính giáo viên: buổi 903 của giáo viên khác không được mời chọn (lỗi gốc của Tester 21/11).
  await expect(page.getByRole('combobox', { name: 'Buổi giao' })).not.toContainText('903');
  // Chưa nhập gì: bấm Giao bài báo lỗi ngay tại chỗ, không gọi máy chủ.
  await page.getByRole('button', { name: 'Giao bài', exact: true }).click();
  await expect(page.getByText('Cần nhập tiêu đề bài.')).toBeVisible();
  await expect(page.getByText('Cần nhập mô tả, đề bài.')).toBeVisible();
  // Hạn trong quá khứ.
  await page.getByLabel('Tiêu đề bài').fill('Bài tập về nhà E2E');
  await page.getByLabel('Mô tả, đề bài').fill('Làm bài 1 đến 5');
  await page.getByLabel('Hạn nộp: ngày').fill('2020-01-01');
  await page.getByLabel('Giờ', { exact: true }).fill('18:00');
  await page.getByRole('button', { name: 'Giao bài', exact: true }).click();
  await expect(page.getByText('Hạn nộp không được trước thời điểm giao.')).toBeVisible();
  // Hạn hợp lệ, hai công tắc mặc định (Q4), xác nhận Giao.
  await page.getByLabel('Hạn nộp: ngày').fill(ahead(3));
  await expect(page.getByRole('switch', { name: 'Cho nộp lại' })).toHaveAttribute(
    'aria-checked',
    'true',
  );
  await expect(page.getByRole('switch', { name: 'Nhận bài muộn' })).toHaveAttribute(
    'aria-checked',
    'false',
  );
  await page.getByRole('button', { name: 'Giao bài', exact: true }).click();
  await expect(page.getByRole('alertdialog').getByText('3 em')).toBeVisible();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Giao bài' }).click();

  await expect(page).toHaveURL(new RegExp(`/gv/lop/${classId}/bai-giao$`));
  const item = page.getByRole('link', { name: /Bài tập về nhà E2E/ });
  await expect(item).toBeVisible();
  await expect(item.getByText('Đang mở')).toBeVisible();
  await expect(item.getByText('0/3 em đã nộp')).toBeVisible();

  // Sửa tiêu đề (chưa em nào nộp).
  await item.click();
  await expect(page.getByRole('heading', { level: 1, name: 'Sửa bài đã giao' })).toBeVisible();
  await page.getByLabel('Tiêu đề bài').fill('Bài tập về nhà E2E (sửa)');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByRole('link', { name: /Bài tập về nhà E2E \(sửa\)/ })).toBeVisible();

  // Gỡ bài.
  await page.getByRole('link', { name: /Bài tập về nhà E2E \(sửa\)/ }).click();
  await page.getByRole('button', { name: 'Gỡ bài' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Gỡ bài' }).click();
  const gone = page.getByRole('link', { name: /Bài tập về nhà E2E \(sửa\)/ });
  await expect(gone.getByText('Đã gỡ')).toBeVisible();
});

test('GV-17: chọn từng em mà chưa chọn em nào thì báo lỗi (Q11)', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/lop/${classId}/bai-giao/moi`);
  await page.getByLabel('Chọn từng em').check();
  await page.getByLabel('Tiêu đề bài').fill('Bài riêng');
  await page.getByLabel('Mô tả, đề bài').fill('Chỉ vài em');
  await page.getByLabel('Hạn nộp: ngày').fill(ahead(3));
  await page.getByLabel('Giờ', { exact: true }).fill('18:00');
  await page.getByRole('button', { name: 'Giao bài', exact: true }).click();
  await expect(page.getByText('Chọn ít nhất một em đang học để giao bài.')).toBeVisible();
  await expect(page.getByText('0 em sẽ nhận bài.')).toBeVisible();
});
