// GD-07 Sắp hết giờ (dự báo chỉ đọc, sau cờ SAP_HET_GIO tắt mặc định; ĐỀ XUẤT docs/spec/de-xuat-luat-a.md). Máy tính. Dữ liệu giả: bật cờ ở CS5, một em còn 2 giờ ở một lớp CS5 đã duyệt.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng học sinh giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(
    testInfo.project.name === 'dien-thoai',
    'Chạy bản máy tính (điện thoại là thẻ cùng dữ liệu).',
  );
});

const TAG = `SH${Date.now().toString(36).slice(-5).toUpperCase()}`;
const STUDENT = `Em ${TAG}`;
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
    const cls = await db.query<{ id: string; code: string }>(
      `select id, code from app.class where branch_id = ${branch} and status_code = 'DA_DUYET' order by code limit 1`,
    );
    const c = cls.rows[0];
    if (!c) {
      await db.query('rollback');
      return '';
    }
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
       values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', 'DANG_HOC', 24)
       returning id`,
      [`GD${TAG}`, st.rows[0]?.id, `PH${TAG}`],
    );
    await db.query(
      `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, current_date)`,
      [e.rows[0]?.id, c.id],
    );
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values ($1, ${branch}, 'CAP_MUA', 2)`,
      [e.rows[0]?.id],
    );
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('SAP_HET_GIO')) f (m) where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    await db.query('commit');
    return c.code;
  });
});

test.afterAll(async () => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'SAP_HET_GIO'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
});

test('GD-07: em còn 2 giờ hiện ở danh sách với tình trạng Sắp hết giờ; lọc và tìm', async ({
  page,
}) => {
  test.skip(classCode === '', 'Không có lớp CS5 đã duyệt để gắn học sinh giả.');
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/sap-het-gio');
  await expect(page.getByRole('heading', { level: 1, name: 'Sắp hết giờ' })).toBeVisible();
  await page.getByLabel('Tìm tên học sinh hoặc mã lớp').fill(STUDENT);
  const row = page.getByRole('row').filter({ hasText: STUDENT });
  await expect(row).toBeVisible();
  await expect(row).toContainText('Sắp hết giờ');
  await expect(row).toContainText(classCode);
  await expect(row).toContainText('2');
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Hết giờ', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: STUDENT })).toHaveCount(0);
  await page.getByRole('button', { name: 'Sắp hết giờ', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: STUDENT })).toBeVisible();
});

test('GD-07: cờ tắt thì báo phân hệ chưa bật', async ({ page }) => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'SAP_HET_GIO'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/sap-het-gio');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});
