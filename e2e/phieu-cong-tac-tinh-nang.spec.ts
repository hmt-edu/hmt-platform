// C-23-09: công tắc tính năng của phiếu nghiệp vụ (CLAUDE.md: kiểm cả ở giao diện và hàm DB) và lỗi hiện trong hộp «Thực hiện phiếu?».
// 1) Phân hệ Bảo lưu TẮT ở CS5: ticket không cho «Tạo phiếu», có câu «Tính năng … chưa bật ở cơ sở này».
// 2) BẬT: tạo, gửi duyệt, duyệt được; rồi tắt trong DB khi trang đang mở: bấm Thực hiện thì hộp hiện lỗi từ DB (không nuốt lỗi), hộp không đóng.
// 3) Tải lại trang khi vẫn tắt: nút Thực hiện bị khoá kèm câu rõ ràng.
// Dữ liệu giả dựng bằng SQL và hàm nghiệp vụ với quyền Admin; mã có dấu riêng mỗi lần chạy; cuối bài trả công tắc về bật.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, pickOption } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ticket giả).');
test.describe.configure({ mode: 'serial' });
test.skip(({ isMobile }) => isMobile, 'Bài ghi dữ liệu và đổi công tắc chỉ kiểm trên máy tính.');

let tag = '';
let title = '';
let taskUrl = '';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

const setFlag = (module: string, enabled: boolean) =>
  withDb((db) =>
    db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select $1, id, $2 from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = excluded.enabled`,
      [module, enabled],
    ),
  );

async function openTicket(page: Page) {
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(title);
  await page.getByRole('cell', { name: title, exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  title = `Ticket E2E CT ${tag}`;
  await setFlag('AFTERSALE', true);
  await setFlag('BAO_LUU', false);
  await withDb(async (db) => {
    await db.query('begin');
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PHE2ECT${tag}`, `Phụ huynh E2E CT ${tag}`, `09${tag.slice(-6)}91`],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2ECT${tag}`, `PHE2ECT${tag}`, `Học sinh E2E CT ${tag}`],
    );
    await db.query(
      `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
       select $1, s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code = $2`,
      [`GDE2ECT${tag}`, `HSE2ECT${tag}`],
    );
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
       select e.id, e.branch_id, 'DAU_KY', 5 from app.enrollment e where e.code = $1`,
      [`GDE2ECT${tag}`],
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
      [title, `PHE2ECT${tag}`, `HSE2ECT${tag}`],
    );
    await db.query('commit');
  });
});

test.afterAll(async () => {
  await setFlag('BAO_LUU', true);
});

test('Phân hệ Bảo lưu tắt: ticket không cho Tạo phiếu, có câu «chưa bật ở cơ sở này»', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await openTicket(page);
  await expect(page.getByRole('button', { name: 'Tạo phiếu' })).toBeDisabled();
  await expect(
    page.getByText('Tính năng Bảo lưu, tiếp tục học chưa bật ở cơ sở này.'),
  ).toBeVisible();
});

test('Bật lại: tạo, gửi duyệt, duyệt; tắt giữa chừng thì hộp Thực hiện hiện lỗi từ DB, không nuốt', async ({
  browser,
  page,
}) => {
  test.setTimeout(150_000);
  await setFlag('BAO_LUU', true);
  await enterAs(page, 'cskh.cs5');
  await openTicket(page);
  await page.getByRole('button', { name: 'Tạo phiếu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu Bảo lưu, tiếp tục học' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Bảo lưu mới');
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Ghi danh' }),
    new RegExp(`GDE2ECT${tag}`),
  );
  await pickOption(page, dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }), /thi|bận/i);
  await dialog.getByLabel(/Số tháng/).fill('2');
  await dialog.getByLabel('Lý do', { exact: true }).fill('Lý do E2E công tắc');
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  taskUrl = page.url();
  await page.getByRole('button', { name: /Trình duyệt|Gửi duyệt/ }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
  const context = await browser.newContext();
  try {
    const manager = await context.newPage();
    await enterAs(manager, 'truongcs.cs5');
    await manager.goto(taskUrl);
    await manager.getByRole('button', { name: 'Duyệt', exact: true }).click();
    const approve = manager.getByRole('dialog', { name: 'Duyệt phiếu' });
    await approve.getByLabel('Ghi chú').fill('Đồng ý');
    await approve.getByRole('button', { name: 'Duyệt', exact: true }).click();
    await expect(manager.getByText('Chờ duyệt → Đã duyệt.')).toBeVisible();
  } finally {
    await context.close();
  }
  // Công tắc đã nạp (bật) trong trang CSKH đang mở; tắt trong DB rồi bấm Thực hiện: DB từ chối, hộp phải hiện lý do.
  await page.goto(taskUrl);
  await expect(page.getByRole('button', { name: 'Thực hiện', exact: true })).toBeEnabled();
  await setFlag('BAO_LUU', false);
  await page.getByRole('button', { name: 'Thực hiện', exact: true }).click();
  const confirm = page.getByRole('alertdialog');
  await confirm.getByRole('button', { name: 'Thực hiện', exact: true }).click();
  await expect(confirm.getByText(/chưa bật ở cơ sở/)).toBeVisible();
  await expect(confirm).toBeVisible();
});

test('Tải lại khi vẫn tắt: nút Thực hiện bị khoá, có câu rõ ràng', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(taskUrl);
  await expect(
    page.getByText('Tính năng Bảo lưu, tiếp tục học chưa bật ở cơ sở này.'),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thực hiện', exact: true })).toBeDisabled();
});
