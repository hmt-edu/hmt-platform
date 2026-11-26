// Phiếu nghiệp vụ (CSN-07): Trưởng cơ sở TỪ CHỐI phiếu (lý do bắt buộc, nút mờ cho tới khi có lý do); CSKH HUỶ phiếu Nháp của mình (lý do bắt buộc). Trạng thái và dòng thời gian đúng.
// Dữ liệu giả dựng bằng hàm nghiệp vụ với quyền Admin: bật AFTERSALE cho CS5, phụ huynh, học sinh, ticket DN_04_01 và một phiếu Nháp. Mã có dấu riêng mỗi lần chạy.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, isPhone, showAllTimeline } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phiếu giả).');
test.describe.configure({ mode: 'serial' });

let rejectCode = '';
let cancelCode = '';

// Máy tính là bảng (bấm ô mã phiếu), điện thoại là danh sách thẻ; không bấm nhầm chip lọc «Tìm: …».
const openTask = async (page: Page, taskCode: string) => {
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
        `PHE2ETC${tag}`,
        `Phụ huynh E2E TC ${tag}`,
        `09${tag.slice(-6)}${testInfo.project.name === 'dien-thoai' ? '6' : '5'}1`,
      ],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2ETC${tag}`, `PHE2ETC${tag}`, `Học sinh E2E TC ${tag}`],
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
    const makeTask = async (suffix: string, school: string) => {
      const ticket = await db.query<{ r: { id: string } }>(
        `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
           'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', 'DN_04_01',
           'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3))) as r`,
        [`Ticket E2E TC ${suffix} ${tag}`, `PHE2ETC${tag}`, `HSE2ETC${tag}`],
      );
      const task = await db.query<{ r: { id: string; code: string } }>(
        `select app.create_ticket_task($1::uuid, 'CAP_NHAT_HO_SO', 'Phụ huynh báo đổi trường',
           jsonb_build_object('entity', 'STUDENT', 'changes', jsonb_build_object('school', $2::text))) as r`,
        [ticket.rows[0]?.r.id, school],
      );
      return task.rows[0]?.r ?? { id: '', code: '' };
    };
    const toReject = await makeTask('TC', 'Trường từ chối');
    await db.query('select app.submit_ticket_task($1::uuid)', [toReject.id]);
    rejectCode = toReject.code;
    cancelCode = (await makeTask('HUY', 'Trường huỷ')).code;
    await db.query('commit');
  } finally {
    await db.end();
  }
});

test('Trưởng cơ sở từ chối phiếu: lý do bắt buộc, phiếu sang Từ chối', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/phieu-nghiep-vu');
  await openTask(page, rejectCode);
  await page.getByRole('button', { name: 'Từ chối', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Từ chối phiếu' });
  await expect(dialog.getByRole('button', { name: 'Từ chối', exact: true })).toBeDisabled();
  await dialog.getByLabel('Lý do').fill('Thiếu giấy tờ.');
  await dialog.getByRole('button', { name: 'Từ chối', exact: true }).click();
  await showAllTimeline(page);
  await expect(page.getByText('Chờ duyệt → Từ chối.')).toBeVisible();
  await expect(page.getByText('Thiếu giấy tờ.').first()).toBeVisible();
});

test('CSKH huỷ phiếu Nháp của mình: lý do bắt buộc, phiếu sang Đã huỷ', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/phieu-nghiep-vu');
  await openTask(page, cancelCode);
  await page.getByRole('button', { name: 'Huỷ phiếu', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Huỷ phiếu' });
  await expect(dialog.getByRole('button', { name: 'Huỷ phiếu', exact: true })).toBeDisabled();
  await dialog.getByLabel('Lý do').fill('Nhập nhầm.');
  await dialog.getByRole('button', { name: 'Huỷ phiếu', exact: true }).click();
  await showAllTimeline(page);
  await expect(page.getByText('Nháp → Đã huỷ.')).toBeVisible();
});
