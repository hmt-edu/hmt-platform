// GV-09: hộp «Hoàn tất buổi» ở GV-04. Dữ liệu giả dựng bằng SQL rồi dọn sau bài: một lớp, một buổi hôm nay Đã chốt, ba em, một em chưa điểm danh.
// Thiếu điểm danh 1 em → hộp liệt kê em đó, nút Hoàn tất khoá. Đủ việc → hiện dấu Đúng hạn / Trễ hạn (hai ca dùng phản hồi session_overview đã sửa,
// vì «đủ hết» cần cả chấm nhận xét; hạn là hạn thật của máy chủ). Màn không đổi tình trạng buổi (R-GV-08).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng buổi học giả).');
test.describe.configure({ mode: 'serial' });

const MARK = 'E2EGV09';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
let session = '';

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
  await db.query(`delete from app.session_attendance where session_id in ${sessions}`, [code]);
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
         values ($1, $2, '2627', 'TOAN', 'K08', 'CB', 'A', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 3) returning id`,
        [code, branch],
      )
    ).rows[0]!.id;
    session = (
      await db.query<{ id: string }>(
        `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
         values ($1, $2, 1, (now() at time zone 'Asia/Ho_Chi_Minh')::date, '18:00', '19:30', $3, 'DA_CHOT') returning id`,
        [cls, branch, teacher],
      )
    ).rows[0]!.id;
    const parent = (
      await db.query<{ id: string }>(
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả E2E', '0900000009', $2) returning id",
        [`${code}-P`, branch],
      )
    ).rows[0]!.id;
    const plan: [string, string, string | null][] = [
      ['A', 'Em giả E2E An', 'CO_MAT'],
      ['B', 'Em giả E2E Bình', 'CO_MAT'],
      ['C', 'Em giả E2E Chi', null],
    ];
    for (const [key, name, status] of plan) {
      const student = (
        await db.query<{ id: string }>(
          'insert into app.student (code, parent_id, full_name, birth_year, branch_id) values ($1, $2, $3, 2012, $4) returning id',
          [`${code}-${key}`, parent, name, branch],
        )
      ).rows[0]!.id;
      await db.query(
        `insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
         values ($1, $2, $3, $4, $5)`,
        [session, cls, branch, student, status],
      );
    }
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, testInfo.project.name));
});

/** Sửa phản hồi session_overview: mọi bước đủ, đặt hạn hoàn tất (giờ ISO). */
async function overviewComplete(page: Page, deadline: string) {
  await page.route('**/rpc/session_overview', async (route) => {
    const response = await route.fetch();
    const body = (await response.json()) as Record<string, unknown>;
    await route.fulfill({
      response,
      json: {
        ...body,
        attendance_marked: body.attendance_total,
        has_content: true,
        content_lines: 1,
        homework_text: 'BTVN',
        grading_present: 2,
        grading_done: 2,
        grading_missing: [],
        prev_homework_state: 'DAU_LOP',
        homework_present: 0,
        homework_done: 0,
        homework_missing: [],
        pending_reason: null,
        deadline_at: deadline,
      },
    });
  });
}

test('GV-09: thiếu điểm danh 1 em: hộp liệt kê em đó, Hoàn tất khoá, Đi tới mở màn điểm danh', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${session}`);
  await page.getByRole('button', { name: 'Hoàn tất', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Hoàn tất buổi' });
  await expect(dialog).toBeVisible();
  await expectAccessible(page);
  const missing = dialog.getByRole('list', { name: 'Việc còn thiếu' });
  const attendance = missing.getByRole('listitem').filter({ hasText: '1 em chưa điểm danh' });
  await expect(attendance).toContainText('Em giả E2E Chi');
  await expect(attendance).not.toContainText('Em giả E2E An');
  // Hai em có mặt chưa chấm nhận xét: mục chấm liệt kê họ, không liệt kê em chưa điểm danh.
  const grading = missing.getByRole('listitem').filter({ hasText: '2 em có mặt chưa chấm đủ' });
  await expect(grading).toContainText('Em giả E2E An');
  await expect(grading).toContainText('Em giả E2E Bình');
  await expect(dialog.getByRole('button', { name: 'Hoàn tất', exact: true })).toBeDisabled();
  await dialog.getByRole('link', { name: 'Đi tới' }).first().click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${session}/diem-danh$`));
  // Màn không đổi tình trạng buổi (R-GV-08).
  const status = await withDb(
    async (db) =>
      (
        await db.query<{ status_code: string }>(
          'select status_code from app.class_session where id = $1',
          [session],
        )
      ).rows[0]!.status_code,
  );
  expect(status).toBe('DA_CHOT');
});

test('GV-09: đủ việc trước hạn: hiện Đúng hạn', async ({ page }) => {
  await overviewComplete(page, new Date(Date.now() + 5 * 3_600_000).toISOString());
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${session}`);
  await page.getByRole('button', { name: 'Hoàn tất', exact: true }).click();
  const stamp = page.getByTestId('gv09-stamp');
  await expect(stamp).toHaveText('Đúng hạn');
  await expect(page.getByRole('link', { name: 'Hoàn tất', exact: true })).toBeVisible();
});

test('GV-09: đủ việc sau hạn: hiện Trễ hạn (3 giờ 1 phút làm tròn thành 4 giờ)', async ({
  page,
}) => {
  await overviewComplete(page, new Date(Date.now() - (3 * 3_600_000 + 60_000)).toISOString());
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${session}`);
  await page.getByRole('button', { name: 'Hoàn tất', exact: true }).click();
  await expect(page.getByTestId('gv09-stamp')).toHaveText('Trễ hạn 4 giờ');
});
