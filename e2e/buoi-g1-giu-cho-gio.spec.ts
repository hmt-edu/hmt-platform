// G1 (thẻ A31, Soát S14, R-GIO-03): chốt danh sách tính giờ đã «giữ chỗ» ở buổi Đã chốt chưa Done. Máy tính. Dữ liệu giả: lớp Đại số 9 CS5 đã duyệt (4 buổi), em A còn 1,5 giờ,
// em B còn 10 giờ. CSKH chốt buổi 1 rồi buổi 2 qua giao diện: em A vào buổi 1 nhưng bị loại khỏi buổi 2 (Hết giờ), em B vào cả hai; buổi 2 không phải kẹt khi Done.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Đào tạo chỉ có bản máy tính.');
});

const TAG = `G1${Date.now().toString(36).slice(-5).toUpperCase()}`;
const STUDENT_A = `Em ${TAG} A`;
const STUDENT_B = `Em ${TAG} B`;
let sessions: string[] = [];

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

test.beforeAll(async () => {
  sessions = await withDb(async (db) => {
    await db.query('begin');
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const ids = await db.query<{ admin: string; gv: string }>(
      `select (select id from auth.users where email = $1) as admin, (select id from auth.users where email = $2) as gv`,
      [`quantri.cs5@${DOMAIN}`, `gv.cs5@${DOMAIN}`],
    );
    const { admin, gv } = ids.rows[0] ?? { admin: '', gv: '' };
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const created = await db.query<{ id: string }>(
      `select app.create_class(jsonb_build_object('branch_id', ${branch},
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 4,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) ->> 'id' as id`,
      [gv],
    );
    const classId = created.rows[0]?.id ?? '';
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [classId, step]);
    await db.query('reset role');
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PH${TAG}`, `Phụ huynh ${TAG}`, `09${String(Date.now()).slice(-8)}`],
    );
    for (const [i, [name, hours]] of (
      [
        [STUDENT_A, 1.5],
        [STUDENT_B, 10],
      ] as const
    ).entries()) {
      const st = await db.query<{ id: string }>(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2011, ${branch}) returning id`,
        [`HS${TAG}${i + 1}`, `PH${TAG}`, name],
      );
      const e = await db.query<{ id: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
         values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', 'DANG_HOC', $4)
         returning id`,
        [`GD${TAG}${i + 1}`, st.rows[0]?.id, `PH${TAG}`, hours],
      );
      await db.query(
        `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values ($1, ${branch}, 'CAP_MUA', $2)`,
        [e.rows[0]?.id, hours],
      );
      await db.query(
        `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, current_date)`,
        [e.rows[0]?.id, classId],
      );
    }
    const list = await db.query<{ id: string }>(
      'select id from app.class_session where class_id = $1 order by session_no',
      [classId],
    );
    await db.query('commit');
    return list.rows.map((r) => r.id);
  });
});

async function closeSession(page: import('@playwright/test').Page, id: string) {
  await page.goto(`/crm/buoi-hoc/${id}`);
  await page.getByRole('button', { name: 'Chốt danh sách' }).click();
  // Hộp xác nhận (alertdialog): nút xác nhận là nút «Chốt danh sách» thứ hai trên màn.
  await page.getByRole('button', { name: 'Chốt danh sách', exact: true }).last().click();
  await expect(page.getByText('Đã chốt danh sách').first()).toBeVisible();
}

test('G1: chốt buổi 1 rồi buổi 2, em còn 1,5 giờ vào buổi 1 nhưng bị loại khỏi buổi 2 vì buổi 1 đã giữ chỗ (R-GIO-03)', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await closeSession(page, sessions[0] ?? '');
  await expect(page.getByText(STUDENT_A).first()).toBeVisible();
  await expect(page.getByText(STUDENT_B).first()).toBeVisible();

  await closeSession(page, sessions[1] ?? '');
  await expect(page.getByText(STUDENT_B).first()).toBeVisible();
  await expect(page.getByText(`${STUDENT_A}: Hết giờ`)).toBeVisible();
});
