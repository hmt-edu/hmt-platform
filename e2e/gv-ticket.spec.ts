// GV-14 Tạo ticket từ cổng giáo viên + ticket lớp tôi (R-CS-10, AS-05; sau cờ AFTERSALE tắt mặc định). Máy tính và iPhone. Dữ liệu giả: bật cờ ở CS5, dựng một lớp
// Đại số 9 CS5 đã duyệt (giáo viên gv.cs5) có hai học sinh giả đang học. Giáo viên tạo ticket nhóm «Học sinh nghỉ nhiều» (bắt buộc lớp, học sinh), rồi thấy ở danh sách lớp.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil, pickOption } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp giả).');
test.describe.configure({ mode: 'serial' });

const TAG = `TK${Date.now().toString(36).slice(-5).toUpperCase()}`;
const STUDENT = `Em ${TAG} A`;
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

test.beforeAll(async () => {
  classCode = await withDb(async (db) => {
    await db.query('begin');
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('AFTERSALE')) f (m) where code = 'CS5'
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
    const created = await db.query<{ id: string; code: string }>(
      `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', ${branch},
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'total_sessions', 4,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) as r) x`,
      [gv],
    );
    const cls = created.rows[0];
    if (!cls) throw new Error('Không tạo được lớp giả.');
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
    await db.query('reset role');
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PH${TAG}`, `Phụ huynh ${TAG}`, `09${String(Date.now()).slice(-8)}`],
    );
    for (const [i, name] of [STUDENT, `Em ${TAG} B`].entries()) {
      const st = await db.query<{ id: string }>(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2011, ${branch}) returning id`,
        [`HS${TAG}${i + 1}`, `PH${TAG}`, name],
      );
      const e = await db.query<{ id: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
         values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', 'DANG_HOC', 24)
         returning id`,
        [`GD${TAG}${i + 1}`, st.rows[0]?.id, `PH${TAG}`],
      );
      await db.query(
        `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, (now() at time zone 'Asia/Ho_Chi_Minh')::date)`,
        [e.rows[0]?.id, cls.id],
      );
    }
    await db.query('commit');
    return cls.code;
  });
});

test.afterAll(async () => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'AFTERSALE'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
});

test('GV-14: từ Lớp mở Ticket; form trắng báo lỗi; tạo ticket Học sinh nghỉ nhiều thì hiện ở danh sách lớp tôi', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto('/gv/lop');
  await page.getByRole('link', { name: 'Ticket của lớp tôi' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Ticket của lớp tôi' })).toBeVisible();
  await page.getByRole('link', { name: 'Tạo ticket' }).first().click();
  await expect(page.getByRole('heading', { level: 1, name: 'Tạo ticket' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo ticket' }).click();
  await expect(page.getByText('Chọn nhóm.')).toBeVisible();
  await expect(page.getByText('Chọn nhóm con.')).toBeVisible();
  await expect(page.getByText('Mô tả là bắt buộc.')).toBeVisible();
  await expectAccessible(page);
  await pickOption(page, page.getByRole('combobox', { name: 'Nhóm', exact: true }), /^Học sinh$/);
  await pickOption(page, page.getByRole('combobox', { name: 'Nhóm con' }), /Học sinh nghỉ nhiều/);
  await expect(page.getByTestId('tinh-chat')).toHaveText('Cần hỗ trợ');
  await page.getByRole('button', { name: 'Tạo ticket' }).click();
  await expect(page.getByText('Nhóm con này bắt buộc chọn lớp.')).toBeVisible();
  await expect(page.getByText('Nhóm con này bắt buộc chọn học sinh.')).toBeVisible();
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Lớp', exact: true }),
    new RegExp(classCode),
  );
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Học sinh', exact: true }),
    new RegExp(STUDENT),
  );
  await page.getByLabel('Tiêu đề').fill(`Nghỉ nhiều ${TAG}`);
  await page.getByLabel('Mô tả').fill('Em nghỉ ba buổi liền không báo trước.');
  await page.getByRole('button', { name: 'Tạo ticket' }).click();
  await expect(page).toHaveURL(/\/gv\/ticket$/);
  const item = page.getByRole('listitem').filter({ hasText: `Nghỉ nhiều ${TAG}` });
  await expect(item).toBeVisible();
  await expect(item).toContainText('Ticket giáo viên');
  await expect(item).toContainText(classCode);
  await expect(item).toContainText(STUDENT);
  await expect(item).toContainText('Mới');
});

test('GV-14: cờ tắt thì báo phân hệ chưa bật', async ({ page }) => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'AFTERSALE'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto('/gv/ticket');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});
