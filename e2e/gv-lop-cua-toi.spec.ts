// GV-10 Lớp của tôi (cổng giáo viên). Dữ liệu giả: lớp của gv.cs5 do gv-diem-danh-seed.ts dựng; lớp của người khác dựng ngay trong bài (chỉ trợ giảng tg.cs5 được phân công).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, expectAccessible, loginStaff } from './helpers';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
let myClass = '';
let otherClass = '';

// Lớp chỉ giao cho trợ giảng tg.cs5 (gv.cs5 không được phân công): tạo bằng hàm nghiệp vụ, đăng nhập giả là Admin hai bước.
async function seedOtherClass(): Promise<string> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    const id = async (key: string) =>
      (
        await db.query<{ id: string }>('select id from auth.users where email = $1', [
          `${key}@${DOMAIN}`,
        ])
      ).rows[0]?.id ?? '';
    const [ta, admin] = [await id('tg.cs5'), await id('quantri.cs5')];
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const created = await db.query<{ cls: string }>(
      `select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'), 'year_code', '2627',
         'subject_code', 'TOAN', 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 2, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', current_date) + interval '15 days')::date, 'teacher_id', $1::uuid)))) ->> 'id' as cls`,
      [ta],
    );
    await db.query('reset role');
    await db.query('commit');
    return created.rows[0]?.cls ?? '';
  } catch (e) {
    await db.query('rollback').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    myClass =
      (
        await db.query<{ c: string }>('select class_id as c from app.class_session where id = $1', [
          seed.chot,
        ])
      ).rows[0]?.c ?? '';
  } finally {
    await db.end();
  }
  otherClass = await seedOtherClass();
});

const link = (id: string) => `a[href="/gv/lop/${id}"]`;

test('GV-10: giáo viên thấy lớp của mình (sĩ số, buổi tiếp theo), không thấy lớp của người khác', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lop');
  await expect(page.getByRole('heading', { level: 1, name: 'Lớp của tôi' })).toBeVisible();
  const mine = page.locator(link(myClass));
  await expect(mine).toBeVisible();
  await expect(mine).toContainText(/Sĩ số \d+/);
  await expect(mine).toContainText(/Buổi tiếp theo: |Chưa có buổi sắp tới/);
  await expect(page.locator(link(otherClass))).toHaveCount(0);
  await expectAccessible(page);
});

test('GV-10: trợ giảng thấy lớp được phân công cho mình', async ({ page }) => {
  await loginStaff(page, 'tg.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lop');
  await expect(page.locator(link(otherClass))).toBeVisible();
});

test('GV-10: bấm lớp dẫn tới trang lớp (GV-11)', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lop');
  await page.locator(link(myClass)).click();
  await expect(page).toHaveURL(new RegExp(`/gv/lop/${myClass}$`));
});
