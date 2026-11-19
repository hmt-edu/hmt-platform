// GV-12: màn Cần làm của giáo viên. Dữ liệu giả dựng bằng SQL rồi dọn sau bài: lớp có hai buổi đã qua, đều Đã chốt (chưa Done).
// Buổi 1 có giao BTVN, ba em có mặt; buổi 2 em Bình vắng → bài BTVN của Bình là Nộp sau (suy từ điểm danh). Kiểm: buổi chưa hoàn tất hiện kèm hạn,
// bài Nộp sau hiện đúng em, bấm Mở tới GV-04 (buổi) và GV-08 (chấm BTVN). Chỉ đọc: màn không đổi dữ liệu.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng buổi học giả).');
test.describe.configure({ mode: 'serial' });

const MARK = 'E2EGV12';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
const classCode = (project: string) => `${MARK}-${tag(project)}`;
let lastSession = '';

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
  const code = classCode(project);
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const sessions = `(select id from app.class_session where class_id in (select id from app.class where code = $1))`;
  await db.query(`delete from app.homework_result where session_id in ${sessions}`, [code]);
  await db.query(`delete from app.session_attendance where session_id in ${sessions}`, [code]);
  await db.query(`delete from app.session_content where session_id in ${sessions}`, [code]);
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
  const code = classCode(project);
  await withDb(async (db) => {
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
         values ($1, $2, '2627', 'TOAN', 'K08', 'CB', 'A', (now() at time zone 'Asia/Ho_Chi_Minh')::date - 10, 3) returning id`,
        [code, branch],
      )
    ).rows[0]!.id;
    const session = async (no: number, daysAgo: number) =>
      (
        await db.query<{ id: string }>(
          `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
           values ($1, $2, $3, (now() at time zone 'Asia/Ho_Chi_Minh')::date - ${daysAgo}, '08:00', '09:30', $4, 'DA_CHOT') returning id`,
          [cls, branch, no, teacher],
        )
      ).rows[0]!.id;
    const first = await session(1, 6);
    lastSession = await session(2, 3);
    await db.query(
      "insert into app.session_content (session_id, branch_id, homework_text) values ($1, $2, 'Bài 1 đến bài 5')",
      [first, branch],
    );
    const parent = (
      await db.query<{ id: string }>(
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả E2E', '0900000012', $2) returning id",
        [`${code}-P`, branch],
      )
    ).rows[0]!.id;
    const plan: [string, string, string][] = [
      ['A', 'Em giả E2E An', 'CO_MAT'],
      ['B', 'Em giả E2E Bình', 'VANG_KHONG_PHEP'],
      ['C', 'Em giả E2E Chi', 'CO_MAT'],
    ];
    for (const [key, name, second] of plan) {
      const student = (
        await db.query<{ id: string }>(
          'insert into app.student (code, parent_id, full_name, birth_year, branch_id) values ($1, $2, $3, 2012, $4) returning id',
          [`${code}-${key}`, parent, name, branch],
        )
      ).rows[0]!.id;
      for (const [sid, status] of [
        [first, 'CO_MAT'],
        [lastSession, second],
      ] as const) {
        await db.query(
          `insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
           values ($1, $2, $3, $4, $5)`,
          [sid, cls, branch, student, status],
        );
      }
    }
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, testInfo.project.name));
});

test('GV-12: buổi chưa hoàn tất kèm hạn và bài Nộp sau chờ cập nhật; Mở tới GV-04 và GV-08', async ({
  page,
}, testInfo) => {
  const code = classCode(testInfo.project.name);
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto('/gv/viec-can-lam');
  await expect(page.getByRole('heading', { level: 1, name: 'Cần làm' })).toBeVisible();

  const open = page.getByRole('list', { name: 'Buổi chưa hoàn tất' });
  const sessionRow = open.getByRole('listitem').filter({ hasText: `${code} · Buổi 2` });
  await expect(sessionRow).toBeVisible();
  await expect(sessionRow.getByTestId('gv12-deadline')).toHaveText(/^(Quá hạn|Còn) \d+ giờ$/);
  await expect(open.getByRole('listitem').filter({ hasText: `${code} · Buổi 1` })).toBeVisible();

  const late = page.getByRole('list', { name: 'Bài Nộp sau chờ cập nhật' });
  const lateRow = late.getByRole('listitem').filter({ hasText: code });
  await expect(lateRow).toContainText('1 bài');
  await expect(lateRow).toContainText('Buổi 1');
  await expect(lateRow).toContainText('Em giả E2E Bình');
  await expect(lateRow).not.toContainText('Em giả E2E An');
  await expectAccessible(page);

  await sessionRow.getByRole('link', { name: 'Mở' }).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${lastSession}$`));
  await page.goto('/gv/viec-can-lam');
  await late
    .getByRole('listitem')
    .filter({ hasText: code })
    .getByRole('link', { name: 'Mở' })
    .click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${lastSession}/cham-btvn$`));
});
