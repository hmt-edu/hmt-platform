// Nút «Tạo phiếu» ở chi tiết ticket nhóm con Bảo lưu mới (phiếu Bảo lưu, CSN-06b): hộp thoại mở được, để trống thì báo lỗi từng ô tại chỗ (kiểm sớm ở giao diện). Dữ liệu giả dựng bằng hàm nghiệp vụ với quyền Admin (bật AFTERSALE cho CS5, phụ huynh, học sinh, ticket).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, isPhone } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ticket giả).');
test.describe.configure({ mode: 'serial' });

let ticketTitle = '';

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  ticketTitle = `Ticket E2E BL ${tag}`;
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
        `PHE2EBL${tag}`,
        `Phụ huynh E2E BL ${tag}`,
        `09${tag.slice(-6)}${testInfo.project.name === 'dien-thoai' ? '8' : '7'}1`,
      ],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2EBL${tag}`, `PHE2EBL${tag}`, `Học sinh E2E BL ${tag}`],
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
    await db.query(
      `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
         'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', 'DN_01_01',
         'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3)))`,
      [ticketTitle, `PHE2EBL${tag}`, `HSE2EBL${tag}`],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
});

test('CSKH mở hộp thoại tạo phiếu Bảo lưu và thấy lỗi từng ô khi để trống', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(ticketTitle);
  await (
    isPhone(page)
      ? page
          .getByRole('list', { name: 'Ticket' })
          .getByRole('listitem')
          .filter({ hasText: ticketTitle })
          .first()
      : page.getByRole('cell', { name: ticketTitle, exact: true })
  ).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Tạo phiếu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu Bảo lưu, tiếp tục học' });
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(dialog.getByText('Chọn ghi danh.')).toBeVisible();
  await expect(dialog.getByText('Chọn lý do.')).toBeVisible();
  await expect(dialog.getByText('Nhập số tháng bảo lưu (từ 1).')).toBeVisible();
  await expect(dialog.getByText('Nhập lý do của phiếu.')).toBeVisible();
});
