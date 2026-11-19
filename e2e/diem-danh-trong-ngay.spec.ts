// BUOI-15 Điểm danh trong ngày (danh sách theo dõi chỉ đọc, sau cờ DIEM_DANH_TRONG_NGAY tắt mặc định; ĐỀ XUẤT docs/spec/de-xuat-luat-a.md). Máy tính.
// Dữ liệu giả: bật cờ ở CS5; dựng một lớp Đại số 9 CS5 đã duyệt có một buổi HÔM NAY (khung cùng thứ, ngày đầu là hôm nay), buổi Nháp nên chưa có danh sách.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, enterAs, expectAccessible } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(
    testInfo.project.name === 'dien-thoai',
    'Chạy bản máy tính (điện thoại là thẻ cùng dữ liệu).',
  );
});

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
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('DIEM_DANH_TRONG_NGAY')) f (m) where code = 'CS5'
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
    // Hôm nay theo giờ Việt Nam; khung cùng thứ trong tuần (1 là thứ Hai, 7 là Chủ nhật) để có đúng một buổi hôm nay.
    const created = await db.query<{ id: string; code: string }>(
      `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'),
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'total_sessions', 3,
         'slots', jsonb_build_array(jsonb_build_object('weekday', extract(isodow from (now() at time zone 'Asia/Ho_Chi_Minh')::date)::int,
           'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'teacher_id', $1::uuid)))) as r) x`,
      [gv],
    );
    const cls = created.rows[0];
    if (!cls) throw new Error('Không tạo được lớp giả.');
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
    await db.query('commit');
    return cls.code;
  });
});

test.afterAll(async () => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'DIEM_DANH_TRONG_NGAY'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
});

/** Danh sách phân trang ở máy chủ và các bài khác cũng dựng buổi hôm nay: lật trang tới khi thấy dòng của lớp (không giả định nó nằm trang đầu). */
async function rowOfClass(page: Page, code: string) {
  const row = page.getByRole('row').filter({ hasText: code });
  const next = page.getByRole('button', { name: 'Trang sau' });
  for (let i = 0; i < 20; i += 1) {
    if ((await row.count()) > 0) return row;
    if (!(await next.isEnabled())) break;
    await next.click();
    await page.waitForLoadState('networkidle');
  }
  return row;
}

test('BUOI-15: buổi hôm nay của lớp hiện ở danh sách, chưa có danh sách; lọc theo tình trạng ghi', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/diem-danh-trong-ngay');
  await expect(page.getByRole('heading', { level: 1, name: 'Điểm danh trong ngày' })).toBeVisible();
  const row = await rowOfClass(page, classCode);
  await expect(row).toBeVisible();
  await expect(row).toContainText('Chưa có danh sách');
  await expect(row).toContainText('18:00–19:30');
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Ghi đủ', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: classCode })).toHaveCount(0);
  await page.getByRole('button', { name: 'Tất cả', exact: true }).click();
  await (await rowOfClass(page, classCode)).getByRole('link', { name: 'Xem' }).click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\/[0-9a-f-]{36}$/);
});

test('BUOI-15: cờ tắt thì báo phân hệ chưa bật', async ({ page }) => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'DIEM_DANH_TRONG_NGAY'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/diem-danh-trong-ngay');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});
