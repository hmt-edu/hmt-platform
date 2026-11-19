// A40 (hàng chung): đường đi trọn của MỘT học sinh giả trên DB local: ghi danh có 3 giờ → xếp lớp → chốt danh sách buổi (giao diện CRM) → giáo viên điểm danh → nhận xét → Done → trừ giờ.
// Kiểm số giờ còn lại ở từng bước (R-GIO-01, 03, 04): chưa Done thì chưa trừ; Done trừ đúng giờ buổi một lần; Done lần hai bị chặn, không trừ hai lần. Dữ liệu giả; máy tính.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp, học sinh giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Đường đi trọn chạy ở bản máy tính.');
});

const TAG = `DD${Date.now().toString(36).slice(-5).toUpperCase()}`;
const STUDENT = `Em ${TAG} Đường đi`;
const START_HOURS = 3; // allow-number: giờ cấp cho học sinh giả của bài này
const SESSION_HOURS = 1.5; // allow-number: buổi 18:00–19:30
let classId = '';
let enrollmentId = '';
let sessionIds: string[] = [];

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

async function actAs(db: pg.Client, login: string, aal: 'aal1' | 'aal2') {
  await db.query('reset role');
  await db.query(
    `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', u.id,
       'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', $2::text))) -> 'claims')::text, true)
       from app.user_account u where u.login_name = $1`,
    [`${login}@${DOMAIN}`, aal],
  );
  await db.query('set local role authenticated');
}

async function balance(): Promise<number> {
  return withDb(async (db) =>
    Number(
      (
        await db.query<{ b: string }>('select app.enrollment_hours_balance($1::uuid) as b', [
          enrollmentId,
        ])
      ).rows[0]?.b,
    ),
  );
}

test.beforeAll(async () => {
  await withDb(async (db) => {
    await db.query('begin');
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const gv = (
      await db.query<{ id: string }>('select id from auth.users where email = $1', [
        `gv.cs5@${DOMAIN}`,
      ])
    ).rows[0]?.id;
    await actAs(db, 'quantri.cs5', 'aal2');
    const created = await db.query<{ id: string }>(
      `select app.create_class(jsonb_build_object('branch_id', ${branch},
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 4,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) ->> 'id' as id`,
      [gv],
    );
    classId = created.rows[0]?.id ?? '';
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [classId, step]);
    await db.query('reset role');
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PH${TAG}`, `Phụ huynh ${TAG}`, `09${String(Date.now()).slice(-8)}`],
    );
    const st = await db.query<{ id: string }>(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2011, ${branch}) returning id`,
      [`HS${TAG}`, `PH${TAG}`, STUDENT],
    );
    const e = await db.query<{ id: string }>(
      `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
       values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', 'DANG_HOC', $4)
       returning id`,
      [`GD${TAG}`, st.rows[0]?.id, `PH${TAG}`, START_HOURS],
    );
    enrollmentId = e.rows[0]?.id ?? '';
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values ($1, ${branch}, 'CAP_MUA', $2)`,
      [enrollmentId, START_HOURS],
    );
    await db.query(
      `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, current_date - 30)`,
      [enrollmentId, classId],
    );
    // Dời buổi 1 về hôm qua để Done được (buổi chưa diễn ra thì chưa Done).
    await db.query(
      `update app.class_session set session_date = current_date - 1 where class_id = $1 and session_no = 1`,
      [classId],
    );
    const list = await db.query<{ id: string }>(
      'select id from app.class_session where class_id = $1 order by session_no',
      [classId],
    );
    sessionIds = list.rows.map((r) => r.id);
    await db.query('commit');
  });
});

test('Đường đi trọn: ghi danh 3 giờ, chốt danh sách, điểm danh, nhận xét, Done trừ đúng một buổi', async ({
  page,
}) => {
  const first = sessionIds[0] ?? '';
  await test.step('Ghi danh còn đủ 3 giờ trước khi có buổi nào Done', async () => {
    expect(await balance()).toBe(START_HOURS);
  });

  await test.step('CSKH chốt danh sách buổi 1 trên giao diện: em vào danh sách, chưa trừ giờ', async () => {
    await enterAs(page, 'cskh.cs5');
    await page.goto(`/crm/buoi-hoc/${first}`);
    await page.getByRole('button', { name: 'Chốt danh sách' }).click();
    await page.getByRole('button', { name: 'Chốt danh sách', exact: true }).last().click();
    await expect(page.getByText('Đã chốt danh sách').first()).toBeVisible();
    await expect(page.getByText(STUDENT).first()).toBeVisible();
    expect(await balance()).toBe(START_HOURS);
  });

  await test.step('Giáo viên điểm danh Có mặt, nhận xét xong; vẫn chưa trừ giờ', async () => {
    await withDb(async (db) => {
      await db.query('begin');
      await actAs(db, 'gv.cs5', 'aal1');
      await db.query(
        `select app.set_attendance_teacher($1::uuid, jsonb_build_array(jsonb_build_object('student_id',
           (select id from app.student where code = $2), 'status_code', 'CO_MAT')))`,
        [first, `HS${TAG}`],
      );
      await db.query('reset role');
      // Nhận xét 9 tiêu chí mức 3 và một dòng nội dung buổi (điều kiện Done, R-GIO-06), dựng thẳng như bài pgTAP D1c.
      await db.query(
        `insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
         select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
           from app.class_session s join app.class c on c.id = s.class_id
           join lateral app.review_criteria_for_subject(c.subject_code) rc on true where s.id = $1 on conflict do nothing`,
        [first],
      );
      await db.query(
        `insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
         select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
           from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
          where sa.session_id = $1 and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON') on conflict do nothing`,
        [first],
      );
      await db.query(
        `insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
         select s.id, s.branch_id, 1, 'Nội dung buổi giả' from app.class_session s where s.id = $1 on conflict do nothing`,
        [first],
      );
      await db.query('commit');
    });
    expect(await balance()).toBe(START_HOURS);
  });

  await test.step('Done buổi 1: trừ đúng 1,5 giờ một lần (R-GIO-01), buổi sang Done', async () => {
    await withDb((db) => db.query('select app.mark_session_done($1::uuid)', [first]));
    expect(await balance()).toBe(START_HOURS - SESSION_HOURS);
    const status = await withDb(
      async (db) =>
        (
          await db.query<{ status_code: string }>(
            'select status_code from app.class_session where id = $1',
            [first],
          )
        ).rows[0]?.status_code,
    );
    expect(status).toBe('DONE');
  });

  await test.step('Done lần hai bị chặn, giờ không bị trừ hai lần', async () => {
    await expect(
      withDb((db) => db.query('select app.mark_session_done($1::uuid)', [first])),
    ).rejects.toThrow();
    expect(await balance()).toBe(START_HOURS - SESSION_HOURS);
  });

  await test.step('Màn buổi hiện tình trạng Done', async () => {
    await page.goto(`/crm/buoi-hoc/${first}`);
    await expect(page.getByText('Done', { exact: true }).first()).toBeVisible();
  });
});
