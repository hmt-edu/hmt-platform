// GV-11 Chi tiết lớp (cổng giáo viên). Dữ liệu giả: lớp của gv.cs5 dựng bằng gv-diem-danh-seed.ts (buổi hôm nay); lớp giao cho người khác dựng ngay trong bài.
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
    // BTVN giao ở buổi hôm nay (buổi 901) để thử tab BTVN. Dữ liệu giả.
    await db.query(
      `insert into app.session_content (session_id, branch_id, homework_text)
       select id, branch_id, 'Làm bài 1 đến 5 trang 10' from app.class_session where id = $1
       on conflict (session_id) do update set homework_text = excluded.homework_text`,
      [seed.chot],
    );
  } finally {
    await db.end();
  }
  otherClass = await seedOtherClass();
});

test('GV-11: mở lớp của mình thấy đủ bốn tab với dữ liệu đúng của lớp; không có nút chưa làm', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/lop/${myClass}`);
  for (const name of ['Học sinh', 'Lịch', 'Buổi', 'BTVN'])
    await expect(page.getByRole('tab', { name: new RegExp(`^${name}`) })).toBeVisible();
  // Tab Học sinh: dữ liệu giả không xếp học sinh vào lớp (chỉ có dòng điểm danh), nên trống và báo rõ.
  await expect(page.getByText('Lớp chưa có học sinh')).toBeVisible();
  await page.getByRole('tab', { name: /^Lịch/ }).click();
  await expect(page.getByText(/Thứ Hai 18:00–19:30/)).toBeVisible();
  await page.getByRole('tab', { name: /^Buổi/ }).click();
  await expect(page.getByText(/Buổi 901/)).toBeVisible();
  await expect(page.getByText(/Buổi 902/)).toBeVisible();
  await page.getByRole('tab', { name: /^BTVN/ }).click();
  await expect(page.getByText('Làm bài 1 đến 5 trang 10')).toBeVisible();
  await expect(page.getByRole('button', { name: /Yêu cầu bổ trợ|Tạo ticket/ })).toHaveCount(0);
  await expectAccessible(page);
});

test('GV-11: lớp của người khác: báo không có quyền, không lộ dữ liệu', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/lop/${otherClass}`);
  await expect(
    page.getByText('Bạn không có quyền xem lớp này hoặc lớp không tồn tại.'),
  ).toBeVisible();
  await expect(page.getByRole('tab', { name: /^Học sinh/ })).toHaveCount(0);
});

test('GV-11: từ danh sách GV-10 bấm lớp tới chi tiết', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lop');
  await page.locator(`a[href="/gv/lop/${myClass}"]`).click();
  await expect(page.getByRole('tab', { name: /^Học sinh/ })).toBeVisible();
});
