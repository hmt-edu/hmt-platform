// GV-07K: màn Chấm kiểm tra (cổng Giáo viên). Dữ liệu giả dựng bằng SQL trực tiếp rồi dọn sau bài: một buổi Kiểm tra Đã chốt, cấu hình 3 nhóm 3 + 4 + 3 = 10,
// ba em giả (có mặt, đi muộn, vắng có phép). Luật R-V2-20: tổng tự cộng, ô trống ≠ 0; R-GV-04: em vắng không nhập điểm.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng buổi học giả).');
test.describe.configure({ mode: 'serial' });

const MARK = 'E2EGV07K';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
let sessionId = '';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, project: string) {
  const code = `${MARK}-${tag(project)}`;
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const sessions = `(select id from app.class_session where class_id in (select id from app.class where code = $1))`;
  for (const table of [
    'exam_score',
    'session_student_review',
    'session_exam',
    'session_attendance',
  ]) {
    await db.query(`delete from app.${table} where session_id in ${sessions}`, [code]);
  }
  await db.query(
    'delete from app.class_session where class_id in (select id from app.class where code = $1)',
    [code],
  );
  await db.query('delete from app.class where code = $1', [code]);
  await db.query('delete from app.student where code like $1', [`${code}-%`]);
  await db.query('delete from app.parent where code = $1', [`${code}-P`]);
  await db.query('commit');
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const project = testInfo.project.name;
  const code = `${MARK}-${tag(project)}`;
  sessionId = await withDb(async (db) => {
    await clear(db, project);
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const branch = (await db.query<{ id: string }>("select id from app.branch where code = 'CS5'"))
      .rows[0]!.id;
    const teacher = (
      await db.query<{ id: string }>('select id from app.user_account where login_name = $1', [
        `gv.cs5@${DOMAIN}`,
      ])
    ).rows[0]!.id;
    const cls = (
      await db.query<{ id: string }>(
        `insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
         values ($1, $2, '2627', 'TOAN', 'K08', 'CB', 'A', current_date, 3) returning id`,
        [code, branch],
      )
    ).rows[0]!.id;
    const session = (
      await db.query<{ id: string }>(
        `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code, type_code, review_form)
         values ($1, $2, 1, current_date, '18:00', '19:30', $3, 'DA_CHOT', 'KIEM_TRA', 'DIEM') returning id`,
        [cls, branch, teacher],
      )
    ).rows[0]!.id;
    await db.query(
      `insert into app.session_exam (session_id, branch_id, scope_text, max_score, entry_mode, max_memory, max_understand, max_apply)
       values ($1, $2, 'Phương trình bậc nhất một ẩn', 10, 'NHOM', 3, 4, 3)`,
      [session, branch],
    );
    const parent = (
      await db.query<{ id: string }>(
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả E2E', '0900000002', $2) returning id",
        [`${code}-P`, branch],
      )
    ).rows[0]!.id;
    const plan: [string, string, string][] = [
      ['A', 'Em giả E2E An', 'CO_MAT'],
      ['B', 'Em giả E2E Bình', 'DI_MUON'],
      ['C', 'Em giả E2E Chi', 'VANG_CO_PHEP'],
    ];
    for (const [key, name, status] of plan) {
      const student = (
        await db.query<{ id: string }>(
          'insert into app.student (code, parent_id, full_name, birth_year, branch_id) values ($1, $2, $3, 2012, $4) returning id',
          [`${code}-${key}`, parent, name, branch],
        )
      ).rows[0]!.id;
      await db.query(
        `insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code) values ($1, $2, $3, $4, $5)`,
        [session, cls, branch, student, status],
      );
    }
    await db.query('commit');
    return session;
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, testInfo.project.name));
});

test('GV-07K: nhập điểm 3 nhóm, tổng tự cộng, chặn vượt tối đa, lưu một lần; em vắng không nhập', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  // Màn nhận xét 9 tiêu chí chuyển sang màn chấm kiểm tra khi là buổi Kiểm tra.
  await page.goto(`/gv/buoi/${sessionId}/cham-nhan-xet`);
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${sessionId}/cham-kiem-tra$`));
  await expect(page.getByRole('heading', { level: 1, name: /Chấm kiểm tra/ })).toBeVisible();
  await expect(page.getByText('Phương trình bậc nhất một ẩn')).toBeVisible();
  await expect(page.getByText('Đã chấm 0/2 em có mặt.', { exact: false })).toBeVisible();
  await expectAccessible(page);

  const save = page.getByRole('button', { name: 'Lưu', exact: true });
  await expect(save).toBeDisabled();
  await page.getByLabel('Ghi nhớ của Em giả E2E An').fill('3');
  await page.getByLabel('Hiểu của Em giả E2E An').fill('4');
  await page.getByLabel('Vận dụng của Em giả E2E An').fill('2,5');
  await expect(page.getByText('Tổng 9,5/10')).toBeVisible();
  // Một nhóm vượt tối đa: chặn, nêu lý do, không lưu.
  await page.getByLabel('Ghi nhớ của Em giả E2E Bình').fill('4');
  await page.getByLabel('Hiểu của Em giả E2E Bình').fill('4');
  await page.getByLabel('Vận dụng của Em giả E2E Bình').fill('2');
  await expect(page.getByText('Điểm Ghi nhớ phải từ 0 đến 3.')).toBeVisible();
  await page.getByLabel('Ghi nhớ của Em giả E2E Bình').fill('3');
  await page.getByLabel('Nhận xét chung', { exact: true }).first().fill('Làm bài tốt');
  await save.click();
  await expect(page.getByText('Đã lưu điểm kiểm tra').first()).toBeVisible();

  await page.reload();
  await expect(page.getByLabel('Vận dụng của Em giả E2E An')).toHaveValue('2.5');
  await expect(page.getByText('Đã chấm 2/2 em có mặt.', { exact: false })).toBeVisible();
  // Em vắng: không có ô điểm.
  await expect(page.getByText('Vắng: không nhập điểm, không tự tính 0.')).toBeVisible();
  await expect(page.getByLabel('Ghi nhớ của Em giả E2E Chi')).toHaveCount(0);
});

test('GV-04: bước Chấm điểm kiểm tra hiện tiến độ thật và mở màn GV-07K', async ({ page }) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}`);
  const step = page.getByRole('list', { name: 'Các bước của buổi' }).getByRole('listitem').nth(2);
  await expect(step).toContainText('Chấm điểm kiểm tra');
  await expect(step).toContainText('2/2 em có mặt đã chấm đủ');
  await step.getByRole('link', { name: 'Mở' }).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${sessionId}/cham-nhan-xet$|cham-kiem-tra$`));
});
