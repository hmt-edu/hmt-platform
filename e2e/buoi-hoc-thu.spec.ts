// BUOI-06 Thêm học thử vào buổi (R-GD-11, R-GD-17; sau cờ HOC_THU tắt mặc định). Máy tính. Dữ liệu giả: bật cờ ở CS5, dựng một lớp Đại số 9 CS5 đã duyệt, chốt danh sách buổi 1,
// dựng một cơ hội L5 với một em bằng hàm nghiệp vụ (quyền Sale CS5). CSKH thêm em của cơ hội vào buổi làm học thử; cờ tắt thì không thấy nút.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, enterAs, expectAccessible, pickOption } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp, cơ hội giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Đào tạo chỉ có bản máy tính.');
});

const TAG = `HT${Date.now().toString(36).slice(-5).toUpperCase()}`;
const PARENT = `Chị ${TAG} hoc thu`;
const STUDENT = `Em ${TAG} Học Thử`;
let sessionId = '';

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

// Đăng nhập giả bằng claims (kiểu các bài dựng dữ liệu khác): aal2 cho Admin, aal1 cho Sale.
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

test.beforeAll(async () => {
  sessionId = await withDb(async (db) => {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('HOC_THU')) f (m) where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const gv = (
      await db.query<{ id: string }>('select id from auth.users where email = $1', [
        `gv.cs5@${DOMAIN}`,
      ])
    ).rows[0]?.id;
    await actAs(db, 'quantri.cs5', 'aal2');
    const created = await db.query<{ id: string }>(
      `select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'),
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'total_sessions', 4,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) ->> 'id' as id`,
      [gv],
    );
    const classId = created.rows[0]?.id ?? '';
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [classId, step]);
    const first = await db.query<{ id: string }>(
      'select id from app.class_session where class_id = $1 and session_no = 1',
      [classId],
    );
    const sid = first.rows[0]?.id ?? '';
    await db.query('select app.close_session($1::uuid)', [sid]);
    // Cơ hội L5 với một em (R-CRM-03), Sale CS5.
    await actAs(db, 'sale.cs5', 'aal1');
    const lead = await db.query<{ id: string }>(
      `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
         'student_name', $3::text, 'student_birth_year', 2012, 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
         'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
      [PARENT, `09${String(Date.now()).slice(-8)}`, STUDENT],
    );
    const leadId = lead.rows[0]?.id ?? '';
    await db.query(`select app.change_lead_stage($1::uuid, 'C4', 'C4C')`, [leadId]);
    const opp = await db.query<{ id: string }>(
      `select (app.create_opportunity($1::uuid)) ->> 'id' as id`,
      [leadId],
    );
    await db.query(`select app.change_opportunity_stage($1::uuid, 'L5')`, [opp.rows[0]?.id]);
    await db.query('reset role');
    await db.query('commit');
    return sid;
  });
});

test.afterAll(async () => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'HOC_THU'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
});

test('BUOI-06: CSKH thêm em của cơ hội L5 vào buổi Đã chốt làm học thử', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${sessionId}`);
  await page.getByRole('button', { name: 'Thêm học thử' }).click();
  const dialog = page.getByRole('dialog', { name: 'Thêm học thử' });
  await expect(dialog).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('combobox', { name: /Cơ hội/ }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(PARENT);
  await page
    .getByRole('option', { name: new RegExp(PARENT) })
    .first()
    .click();
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Học sinh của cơ hội' }),
    new RegExp(STUDENT),
  );
  await dialog.getByRole('button', { name: 'Thêm vào buổi' }).click();
  await expect(page.getByText(/Đã thêm học sinh học thử vào buổi/).first()).toBeVisible();
  const row = page.getByText(STUDENT).first();
  await expect(row).toBeVisible();
  await expect(page.getByText('Học thử', { exact: true }).first()).toBeVisible();
});

test('BUOI-06: Sale chỉ xem được buổi, không có nút Thêm học thử dù cờ bật (thiếu quyền Buổi học · Sửa)', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto(`/crm/buoi-hoc/${sessionId}`);
  await expect(page.getByRole('heading', { name: 'Danh sách và điểm danh' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm học thử' })).toHaveCount(0);
});

test('BUOI-06: cờ tắt thì không thấy nút Thêm học thử', async ({ page }) => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'HOC_THU'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${sessionId}`);
  await expect(page.getByRole('button', { name: 'Dời' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm học thử' })).toHaveCount(0);
});
