// Phiếu nghiệp vụ A1 (CSN-05, CSN-06): CSKH mở phiếu Cập nhật hồ sơ (Nháp) và trình duyệt; Trưởng cơ sở duyệt rồi thực hiện; trạng thái và dòng thời gian đúng.
// Dữ liệu giả dựng bằng hàm nghiệp vụ với quyền Admin: bật AFTERSALE cho CS5, phụ huynh, học sinh, ticket DN_04_01 và một phiếu Nháp. Mã có dấu riêng mỗi lần chạy.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, isPhone } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phiếu giả).');
test.describe.configure({ mode: 'serial' });

let taskCode = '';

// Máy tính là bảng (bấm ô mã phiếu), điện thoại là danh sách thẻ; không bấm nhầm chip lọc «Tìm: …».
const openTask = async (page: Page) => {
  await page.getByPlaceholder(/Tìm mã phiếu/).fill(taskCode);
  await (
    isPhone(page)
      ? page
          .getByRole('list', { name: 'Phiếu nghiệp vụ' })
          .getByRole('listitem')
          .filter({ hasText: taskCode })
          .first()
      : page.getByRole('cell', { name: taskCode, exact: true })
  ).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
};

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [
        `PHE2EPN${tag}`,
        `Phụ huynh E2E PN ${tag}`,
        `09${tag.slice(-6)}${testInfo.project.name === 'dien-thoai' ? '6' : '5'}1`,
      ],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2EPN${tag}`, `PHE2EPN${tag}`, `Học sinh E2E PN ${tag}`],
    );
    const admin =
      (
        await db.query<{ id: string }>('select id from auth.users where email = $1', [
          `quantri.cs5@${DOMAIN}`,
        ])
      ).rows[0]?.id ?? '';
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const ticket = await db.query<{ r: { id: string } }>(
      `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
         'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', 'DN_04_01',
         'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3))) as r`,
      [`Ticket E2E PN ${tag}`, `PHE2EPN${tag}`, `HSE2EPN${tag}`],
    );
    const task = await db.query<{ r: { code: string } }>(
      `select app.create_ticket_task($1::uuid, 'CAP_NHAT_HO_SO', 'Phụ huynh báo đổi trường',
         '{"entity":"STUDENT","changes":{"school":"Trường E2E"}}'::jsonb) as r`,
      [ticket.rows[0]?.r.id],
    );
    taskCode = task.rows[0]?.r.code ?? '';
    await db.query('commit');
  } finally {
    await db.end();
  }
});

test('CSKH mở phiếu Nháp và trình duyệt', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/phieu-nghiep-vu');
  await expect(page.getByRole('heading', { level: 1, name: 'Phiếu nghiệp vụ' })).toBeVisible();
  await openTask(page);
  await expect(page.getByText('Trường E2E').first()).toBeVisible();
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
});

test('Trưởng cơ sở duyệt rồi thực hiện phiếu', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/phieu-nghiep-vu');
  await openTask(page);
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Duyệt phiếu' });
  await dialog.getByLabel('Ghi chú').fill('Đồng ý');
  await dialog.getByRole('button', { name: 'Duyệt', exact: true }).click();
  await expect(page.getByText('Chờ duyệt → Đã duyệt.')).toBeVisible();
  await page.getByRole('button', { name: 'Thực hiện', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Thực hiện', exact: true })
    .click();
  await expect(page.getByText('Thực hiện phiếu. Đã duyệt → Đã thực hiện.')).toBeVisible();
});
