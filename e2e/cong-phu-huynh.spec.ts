// Cổng Phụ huynh /ph (F-23-43), điện thoại 390×844: đăng nhập bằng số điện thoại, 5 màn, phụ huynh chỉ thấy con mình.
// Dữ liệu giả: một phụ huynh có hai con (chip chọn con) và một phụ huynh khác có một con (không được thấy). Dọn sau bài.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { PASSWORD } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phụ huynh, học sinh giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'dien-thoai', 'Cổng Phụ huynh ưu tiên điện thoại.');
});

const TAG = `PHE${Date.now().toString(36).slice(-5).toUpperCase()}`;
const PHONE = `0991${String(Date.now()).slice(-6)}`;
const OTHER_PHONE = `0992${String(Date.now()).slice(-6)}`;
// Mã phụ huynh chỉ gồm chữ số sau PH (ràng buộc user_account.parent_code, migration 616).
const DIGITS = String(Date.now()).slice(-9);
const CODE = `PH${DIGITS}`;
const OTHER_CODE = `PH${String(Number(DIGITS) + 1).padStart(9, '0')}`;
const CHILD_A = `Em ${TAG} An`;
const CHILD_B = `Em ${TAG} Bình`;
const STRANGER = `Em ${TAG} Lạ`;
const EMAIL = `${CODE.toLowerCase()}@phuhuynh.hoamatoan.edu.vn`;

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

async function cleanup() {
  await withDb(async (db) => {
    const codes = [CODE, OTHER_CODE];
    // Bảng nghiệp vụ không cho xoá: dọn bằng phiên "replica" (bỏ trigger chặn xoá) trong một giao dịch, xoá con trước cha.
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      'delete from app.user_role where user_id in (select id from app.user_account where parent_code = any($1))',
      [codes],
    );
    await db.query(
      'delete from auth.users where id in (select id from app.user_account where parent_code = any($1))',
      [codes],
    );
    await db.query('delete from app.user_account where parent_code = any($1)', [codes]);
    await db.query(
      'delete from app.student where parent_id in (select id from app.parent where code = any($1))',
      [codes],
    );
    await db.query('delete from app.parent where code = any($1)', [codes]);
    await db.query('commit');
  });
}

test.beforeAll(async () => {
  await cleanup();
  await withDb(async (db) => {
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, unnest(array['HOC_TAP', 'AFTERSALE']) m where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch}), ($4, $5, $6, ${branch})`,
      [CODE, `Phụ huynh ${TAG}`, PHONE, OTHER_CODE, `Phụ huynh khác ${TAG}`, OTHER_PHONE],
    );
    for (const [i, name] of [CHILD_A, CHILD_B].entries()) {
      await db.query(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2012, ${branch})`,
        [`HS${TAG}${i}`, CODE, name],
      );
    }
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2012, ${branch})`,
      [`HS${TAG}X`, OTHER_CODE, STRANGER],
    );
    const id = (
      await db.query<{ id: string }>(
        `insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                                 confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current,
                                 reauthentication_token, phone_change, phone_change_token, created_at, updated_at)
         values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', $1, crypt($2, gen_salt('bf')), now(),
                 '{"provider":"email","providers":["email"]}', '{}', '', '', '', '', '', '', '', '', now(), now()) returning id`,
        [EMAIL, PASSWORD],
      )
    ).rows[0]?.id;
    await db.query(
      `insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
       values (gen_random_uuid(), $1::uuid, ($1::uuid)::text, 'email', jsonb_build_object('sub', ($1::uuid)::text, 'email', $2::text), now(), now(), now())`,
      [id, EMAIL],
    );
    await db.query(
      `insert into app.user_account (id, display_name, login_name, branch_id, parent_code, is_locked, must_change_password)
       values ($1, $2, $3, ${branch}, $4, false, false)`,
      [id, `Phụ huynh ${TAG}`, EMAIL, CODE],
    );
    await db.query(`insert into app.user_role (user_id, role_code) values ($1, 'PARENT')`, [id]);
  });
});

test.afterAll(cleanup);

test('Phụ huynh đăng nhập bằng số điện thoại, vào cổng /ph, có chip hai con và không thấy con của người khác', async ({
  page,
}) => {
  await page.goto('/dang-nhap/phu-huynh');
  await page.getByLabel('Số điện thoại', { exact: true }).fill(PHONE);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/ph$/, { timeout: 20_000 });
  await expect(
    page.getByRole('heading', { level: 1, name: 'Xin chào quý phụ huynh' }),
  ).toBeVisible();
  await page.goto('/ph/hoc-phi');
  await expect(page.getByRole('heading', { level: 1, name: 'Học phí và giờ học' })).toBeVisible();
  const chips = page.getByRole('group', { name: 'Chọn con' });
  await expect(chips.getByRole('button', { name: CHILD_A })).toBeVisible();
  await expect(chips.getByRole('button', { name: CHILD_B })).toBeVisible();
  await expect(page.getByText(STRANGER)).toHaveCount(0);
});

test('Năm màn của cổng /ph mở được, màn trống hiện lời nhắn, không tràn ngang', async ({
  page,
}) => {
  await page.goto('/dang-nhap/phu-huynh');
  await page.getByLabel('Số điện thoại', { exact: true }).fill(PHONE);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/ph$/, { timeout: 20_000 });
  const screens: [string, string][] = [
    ['/ph/ket-qua', 'Kết quả của con'],
    ['/ph/hoc-phi', 'Học phí và giờ học'],
    ['/ph/lich', 'Lịch học của con'],
    ['/ph/de-nghi', 'Đề nghị của tôi'],
  ];
  for (const [path, title] of screens) {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
    const overflow = await page.evaluate<number>(
      'document.documentElement.scrollWidth - document.documentElement.clientWidth',
    );
    expect(overflow, `${path} không tràn ngang`).toBeLessThanOrEqual(0);
  }
  await expect(page.getByText('Chưa có đề nghị nào')).toBeVisible();
});

test('Gửi đề nghị: nút Gửi mờ khi thiếu nhóm và nội dung', async ({ page }) => {
  await page.goto('/dang-nhap/phu-huynh');
  await page.getByLabel('Số điện thoại', { exact: true }).fill(PHONE);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/ph$/, { timeout: 20_000 });
  await page.goto('/ph/de-nghi/moi');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Gửi đề nghị hoặc khiếu nại' }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Gửi', exact: true })).toBeDisabled();
});
