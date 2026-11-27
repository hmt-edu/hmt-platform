// KH-08 Lên khối đầu năm học: Admin xem trước từng em (khối cũ → khối mới, lớp 12 tốt nghiệp), loại trừ một em; Sale không vào được.
// Bài KHÔNG bấm «Xác nhận» (chạy đợt đổi khối mọi em đang học trong DB). Máy tính. Học sinh giả riêng, dọn ở cuối bài.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { enterAs, enterAsAdmin, PASSWORD } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

const CODE_A = 'HS991801';
const CODE_B = 'HS991802';

async function sql(query: string, params: unknown[] = []) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(query, params);
  } finally {
    await db.end();
  }
}

/** Dọn dữ liệu giả: bảng nghiệp vụ chặn xoá (khung chung), nên xoá trong một giao dịch tắt trigger. */
async function purge(statements: [string, unknown[]?][]) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    for (const [q, p] of statements) await db.query(q, p ?? []);
    await db.query('commit');
  } finally {
    await db.end();
  }
}

async function cleanup() {
  await purge([
    ["delete from app.enrollment where code in ('GDE2EKH081', 'GDE2EKH082')"],
    ['delete from app.student where code in ($1, $2)', [CODE_A, CODE_B]],
    ["delete from app.parent where code = 'PHE2EKH08'"],
  ]);
}

test.beforeAll(async () => {
  await cleanup();
  await sql(
    `insert into app.parent (code, full_name, phone, branch_id) values ('PHE2EKH08', 'Phụ huynh E2E KH08', '0991801801', (select id from app.branch where code = 'CS5'))`,
  );
  await sql(
    `insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
     select c.code, (select id from app.parent where code = 'PHE2EKH08'), c.name, 2010, (select id from app.branch where code = 'CS5'), c.grade
       from (values ($1, 'Em Lớp Tám E2E', 8), ($2, 'Em Lớp Mười Hai E2E', 12)) as c (code, name, grade)`,
    [CODE_A, CODE_B],
  );
  await sql(
    `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
     select 'GDE2EKH08' || right(s.code, 1), s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code in ($1, $2)`,
    [CODE_A, CODE_B],
  );
});

test.afterAll(cleanup);

test('Admin: xem trước khối cũ và khối mới, lớp 12 tốt nghiệp, loại trừ một em', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/len-khoi-dau-nam');
  await expect(page.getByRole('heading', { level: 1, name: 'Lên khối đầu năm học' })).toBeVisible();
  await page
    .getByRole('main')
    .getByPlaceholder(/Tìm tên học sinh/)
    .fill('HS9918');
  const a = page.getByRole('row', { name: new RegExp(CODE_A) });
  const b = page.getByRole('row', { name: new RegExp(CODE_B) });
  await expect(a.getByText('Khối 9')).toBeVisible();
  await expect(b.getByText('Tốt nghiệp')).toBeVisible();
  await a.getByRole('checkbox').check();
  await page.getByRole('button', { name: 'Loại trừ khỏi đợt' }).click();
  await expect(a.getByText('Loại trừ', { exact: true })).toBeVisible();
  await expect(page.getByTestId('promotion-summary')).toContainText('loại trừ 1 học sinh');
});

test('Nhân viên không phải Admin: không vào được màn Lên khối', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/len-khoi-dau-nam');
  await expect(page.getByRole('heading', { level: 1, name: 'Lên khối đầu năm học' })).toHaveCount(
    0,
  );
});
