// GV-18 Chấm bài nộp online (cổng giáo viên, điện thoại và máy tính): danh sách em, chấm bốn bước, Lưu và em tiếp theo, khoá bài đã chấm và Mở lại.
// Dữ liệu giả: lớp do seedAttendance dựng (giáo viên gv.cs5, 3 em), bài giao và bài nộp dựng bằng quyền hệ thống (chưa có hàm nộp bài của học sinh, HT-05).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, expectAccessible, loginStaff } from './helpers';
import { seedAttendance } from './gv-diem-danh-seed';
import { DB_URL } from './bao-gia-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let classId = '';
let assignmentId = '';
let names: string[] = [];

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select 'HOC_TAP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const cls = await db.query<{ class_id: string }>(
      'select class_id from app.class_session where id = $1',
      [seed.chot],
    );
    classId = cls.rows[0]?.class_id ?? '';
    const tag = `${Date.now()}`.slice(-8);
    const students = await db.query<{ id: string; parent_id: string; full_name: string }>(
      `select st.id, st.parent_id, st.full_name from app.student st join app.session_attendance sa on sa.student_id = st.id where sa.session_id = $1 order by st.full_name`,
      [seed.chot],
    );
    names = students.rows.map((s) => s.full_name);
    for (const [i, st] of students.rows.entries()) {
      const en = await db.query<{ id: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code) values ($1, $2, $3, ${branch}, 'TOAN') returning id`,
        [`GDCB${tag}${i}`, st.id, st.parent_id],
      );
      await db.query(
        `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 30)`,
        [en.rows[0]?.id, classId],
      );
    }
    const a = await db.query<{ id: string }>(
      `insert into app.lms_assignment (class_id, session_id, branch_id, title, description, due_at, audience)
       values ($1, $2, ${branch}, 'Bài chấm E2E', 'Làm bài 1 đến 5', now() + interval '3 days', 'CA_LOP') returning id`,
      [classId, seed.chot],
    );
    assignmentId = a.rows[0]?.id ?? '';
    await db.query(
      `insert into app.lms_assignment_target (assignment_id, student_id) select $1, id from app.student where id = any($2::uuid[])`,
      [assignmentId, students.rows.map((s) => s.id)],
    );
    // Em 1 nộp đúng hạn, em 2 nộp muộn (nộp lại 1 lần), em 3 chưa nộp.
    await db.query(
      `insert into app.lms_submission (assignment_id, student_id, attempt_count, submitted_at, is_late) values ($1, $2, 1, now(), false), ($1, $3, 2, now(), true)`,
      [assignmentId, students.rows[0]?.id, students.rows[1]?.id],
    );
  } finally {
    await db.end();
  }
});

const listUrl = () => `/gv/lop/${classId}/bai-giao/${assignmentId}/cham`;

test('GV-18: danh sách em: tiến độ, nhãn nộp, lọc Chưa chấm', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(listUrl());
  await expect(page.getByRole('heading', { level: 1, name: 'Chấm bài nộp' })).toBeVisible();
  await expect(page.getByText('Đã chấm 0/3')).toBeVisible();
  const rows = page.getByRole('list', { name: 'Danh sách em' }).getByRole('listitem');
  await expect(rows).toHaveCount(3);
  await expect(rows.nth(1).getByText('Nộp muộn')).toBeVisible();
  await expect(rows.nth(1).getByText('Nộp lại 1 lần')).toBeVisible();
  await expect(rows.nth(2).getByText('Chưa nộp')).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Đã chấm', exact: true }).click();
  await expect(page.getByText('Không có em nào trong mục này')).toBeVisible();
});

test('GV-18: chấm bốn bước, Lưu và em tiếp theo; bài đã chấm khoá, Mở lại có hộp xác nhận', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(listUrl());
  await page.getByRole('link', { name: new RegExp(names[0] ?? 'zzz') }).click();
  await expect(page.getByText('BƯỚC 1/4 · XEM BÀI NỘP')).toBeVisible();
  await expect(page.getByText('Chưa bật lưu tệp.')).toBeVisible();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await expect(page.getByText('BƯỚC 2/4 · ĐIỂM')).toBeVisible();
  await page.getByRole('button', { name: '4', exact: true }).click();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await expect(page.getByText('BƯỚC 3/4 · TRẠNG THÁI')).toBeVisible();
  // Chọn Không làm: điểm đã chọn bị bỏ (Q5), có dòng nhắc.
  await page.getByRole('radio', { name: /Không làm/ }).check();
  await expect(page.getByText('điểm đã chọn sẽ bị bỏ khi lưu')).toBeVisible();
  await page.getByRole('radio', { name: /^Đã chấm/ }).check();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await expect(page.getByText('BƯỚC 4/4 · LỜI PHÊ')).toBeVisible();
  await page.getByRole('textbox', { name: 'Lời phê' }).fill('Làm tốt');
  await page.getByRole('button', { name: 'Lưu và em tiếp theo' }).click();
  // Em tiếp theo chưa chấm là em 2 (Q8).
  await expect(page.getByRole('heading', { level: 1, name: names[1] ?? 'zzz' })).toBeVisible();

  // Về danh sách: em 1 đã chấm 4; tiến độ 1/3.
  await page.goto(listUrl());
  await expect(page.getByText('Đã chấm 1/3')).toBeVisible();
  await expect(page.getByText('Đã chấm · 4')).toBeVisible();

  // Mở lại em 1 (bài đang khoá).
  await page.getByRole('link', { name: new RegExp(names[0] ?? 'zzz') }).click();
  await expect(page.getByText('Bài đã chấm, bài nộp đang khoá.')).toBeVisible();
  await page.getByRole('button', { name: 'Mở lại', exact: true }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Mở lại' }).click();
  await expect(page.getByText('Bài đã chấm, bài nộp đang khoá.')).toHaveCount(0);
});

test('GV-18: em chưa nộp: chỉ chọn Nộp sau hoặc Không làm, chấm điểm bị khoá', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(listUrl());
  await page.getByRole('link', { name: new RegExp(names[2] ?? 'zzz') }).click();
  await expect(page.getByText('Em chưa nộp bài')).toBeVisible();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await expect(page.getByRole('button', { name: '4', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await expect(page.getByRole('radio', { name: /^Đã chấm/ })).toBeDisabled();
  await page.getByRole('radio', { name: /^Nộp sau/ }).check();
  await page.getByRole('button', { name: 'Tiếp' }).click();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`${listUrl()}$`));
});
