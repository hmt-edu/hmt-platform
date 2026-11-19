// C42 (R-CS-06, R-CS-08, R-GD-09): đường CSKH: tạo khiếu nại bằng giao diện → nâng cấp lên Quản lý cơ sở rồi Ban giám đốc (CS-13, lý do bắt buộc) → Bảo lưu → Tiếp tục học.
// Kiểm: nâng cấp hiện «Mức nâng cấp» và dòng thời gian, nâng quá mức bị khoá nút; Bảo lưu rồi Tiếp tục học: giờ còn lại giữ nguyên, ghi danh về hàng chờ xếp lớp, không tự xếp lớp.
// Dữ liệu giả có dấu riêng mỗi lần chạy (mã GDC42…), dọn sau bài; không dùng chung với bài khác.
import { expect, test, type Browser, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, isPhone, pickOption } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ghi danh và ticket giả).');
test.describe.configure({ mode: 'serial' });
// Bài chỉ ghi trên máy tính (như TC-09): điện thoại không thêm giá trị và tránh hai dự án ghi cùng ghi danh.
test.skip(({ isMobile }) => isMobile, 'Phiếu nghiệp vụ ghi dữ liệu chỉ kiểm trên máy tính.');

let tag = '';
const titles = { complaint: '', hold: '', resume: '' };
let parentName = '';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

const enrollmentState = (code: string) =>
  withDb(async (db) => {
    const r = await db.query<{ status: string; hours: string }>(
      `select e.status_code as status, coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::text as hours
         from app.enrollment e where e.code = $1`,
      [code],
    );
    return r.rows[0];
  });

async function openTicket(page: Page, title: string) {
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(title);
  await (
    isPhone(page)
      ? page
          .getByRole('list', { name: 'Ticket' })
          .getByRole('listitem')
          .filter({ hasText: title })
          .first()
      : page.getByRole('cell', { name: title, exact: true })
  ).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
}

// CSKH tạo phiếu từ ticket theo hình thức đã chọn, trình duyệt; Trưởng cơ sở duyệt và thực hiện.
async function runTask(
  browser: Browser,
  page: Page,
  title: string,
  mode: 'Bảo lưu mới' | 'Gia hạn bảo lưu' | 'Tiếp tục học',
  months: string | null,
) {
  await enterAs(page, 'cskh.cs5');
  await openTicket(page, title);
  await page.getByRole('button', { name: 'Tạo phiếu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu Bảo lưu, tiếp tục học' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), mode);
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Ghi danh' }),
    new RegExp(`GDC42${tag}`),
  );
  await pickOption(page, dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }), /thi|bận/i);
  if (months !== null) await dialog.getByLabel(/Số tháng/).fill(months);
  await dialog.getByLabel('Lý do', { exact: true }).fill(`Lý do E2E ${mode}`);
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
  const taskUrl = page.url();
  // Trưởng cơ sở đăng nhập ở ngữ cảnh riêng (không dùng chung phiên với CSKH).
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
    await manager.getByRole('button', { name: 'Thực hiện', exact: true }).click();
    await manager
      .getByRole('alertdialog')
      .getByRole('button', { name: 'Thực hiện', exact: true })
      .click();
    await expect(manager.getByText('Thực hiện phiếu. Đã duyệt → Đã thực hiện.')).toBeVisible();
  } finally {
    await context.close();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  titles.complaint = `Khiếu nại E2E C42 ${tag}`;
  titles.hold = `Ticket E2E C42 BL ${tag}`;
  titles.resume = `Ticket E2E C42 TT ${tag}`;
  parentName = `Phụ huynh E2E BLT ${tag}`;
  await withDb(async (db) => {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, (values ('AFTERSALE'), ('BAO_LUU')) v (m) where b.code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PHC42${tag}`, `Phụ huynh E2E BLT ${tag}`, `09${tag.slice(-6)}51`],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSC42${tag}`, `PHC42${tag}`, `Học sinh E2E BLT ${tag}`],
    );
    // Ghi danh Đang học có 5 giờ (dòng sổ giờ đầu kỳ); không cần lớp: bảo lưu không đòi lớp.
    await db.query(
      `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
       select $1, s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code = $2`,
      [`GDC42${tag}`, `HSC42${tag}`],
    );
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
       select e.id, e.branch_id, 'DAU_KY', 5 from app.enrollment e where e.code = $1`,
      [`GDC42${tag}`],
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
    for (const [title, category] of [
      [titles.hold, 'DN_01_01'],
      [titles.resume, 'DN_01_02'],
    ] as const) {
      await db.query(
        `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
           'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', $4::text,
           'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3)))`,
        [title, `PHC42${tag}`, `HSC42${tag}`, category],
      );
    }
    await db.query('commit');
  });
});

test.afterAll(async () => {
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const enr = `(select id from app.enrollment where code = $1)`;
    await db.query(`delete from app.hour_ledger where enrollment_id in ${enr}`, [`GDC42${tag}`]);
    await db.query(`delete from app.enrollment_hold where enrollment_id in ${enr}`, [
      `GDC42${tag}`,
    ]);
    await db.query('delete from app.enrollment where code = $1', [`GDC42${tag}`]);
    await db.query('commit');
  });
});

test('Khiếu nại: CSKH tạo, nâng cấp lên Quản lý cơ sở rồi Ban giám đốc, hết bậc thì khoá nút', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/ticket/moi');
  await page.getByLabel('Loại').click();
  await page.getByRole('option', { name: 'Khiếu nại' }).click();
  await page.getByLabel('Tiêu đề').fill(titles.complaint);
  await page.getByLabel('Kênh').click();
  await page.getByRole('option', { name: 'Gọi điện' }).click();
  await pickOption(page, page.getByRole('combobox', { name: 'Phụ huynh' }), parentName);
  await page.getByLabel('Nhóm', { exact: true }).click();
  await page.getByRole('option', { name: 'Học sinh trong lớp' }).click();
  await page.getByLabel('Nhóm con').click();
  await page.getByRole('option', { name: 'Bắt nạt' }).click();
  await page.getByLabel('Mô tả').fill('Mô tả giả cho bài kiểm thử C42.');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Chưa nâng cấp')).toBeVisible();
  // Lý do bắt buộc: nút mờ khi để trống.
  await page.getByRole('button', { name: 'Nâng cấp', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Nâng cấp khiếu nại' });
  await expect(dialog.getByRole('button', { name: 'Nâng cấp lên Quản lý cơ sở' })).toBeDisabled();
  await dialog.getByLabel('Lý do nâng cấp').fill('Quá hạn phản hồi.');
  await dialog.getByRole('button', { name: 'Nâng cấp lên Quản lý cơ sở' }).click();
  await expect(page.getByText('Quản lý cơ sở', { exact: true })).toBeVisible();
  await expect(page.getByText(/Nâng cấp lên Quản lý cơ sở: Quá hạn phản hồi/)).toBeVisible();
  await page.getByRole('button', { name: 'Nâng cấp', exact: true }).click();
  const second = page.getByRole('dialog', { name: 'Nâng cấp khiếu nại' });
  await second.getByLabel('Lý do nâng cấp').fill('Phụ huynh dọa báo chí.');
  await second.getByRole('button', { name: 'Nâng cấp lên Ban giám đốc' }).click();
  await expect(page.getByText('Ban giám đốc', { exact: true })).toBeVisible();
  // Hết bậc: không còn nút Nâng cấp.
  await expect(page.getByRole('button', { name: 'Nâng cấp', exact: true })).toHaveCount(0);
});

test('Bảo lưu mới: phiếu duyệt và thực hiện → ghi danh Bảo lưu, giờ giữ nguyên', async ({
  browser,
  page,
}) => {
  await runTask(browser, page, titles.hold, 'Bảo lưu mới', '2');
  expect(await enrollmentState(`GDC42${tag}`)).toEqual({ status: 'BAO_LUU', hours: '5.00' });
});

test('Tiếp tục học: bảo lưu kết thúc, ghi danh về hàng chờ xếp lớp, giờ giữ nguyên', async ({
  browser,
  page,
}) => {
  await runTask(browser, page, titles.resume, 'Tiếp tục học', null);
  expect(await enrollmentState(`GDC42${tag}`)).toEqual({ status: 'CHO_XEP_LOP', hours: '5.00' });
});
