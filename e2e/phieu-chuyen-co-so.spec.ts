// CS-07 Chuyển cơ sở (migration 568, R-GD-10, R-CS-07): ticket → phiếu Chuyển lớp, loại «Chuyển cơ sở» → trình → quản lý cơ sở ĐI duyệt → quản lý cơ sở ĐẾN thấy phiếu
// (chỉ khi tới lượt), chọn lớp mới và buổi bắt đầu, duyệt → thực hiện. Kiểm: cơ sở đích KHÔNG thấy phiếu trước lượt; sau thực hiện ghi danh nằm ở lớp của cơ sở đích, giờ giữ nguyên.
// Dữ liệu giả dựng bằng SQL và hàm nghiệp vụ với quyền Admin (hai lớp đã duyệt ở CS5 và CS1, một ghi danh Đang học 5 giờ ở lớp CS5); mã có dấu riêng mỗi lần chạy; dọn sau bài.
// Chỉ máy tính (phiếu nghiệp vụ ghi dữ liệu).
import { expect, test, type Browser, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, pickOption, showAllTimeline } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp, ghi danh và ticket giả).');
test.describe.configure({ mode: 'serial' });
test.skip(({ isMobile }) => isMobile, 'Phiếu nghiệp vụ ghi dữ liệu chỉ kiểm trên máy tính.');

let tag = '';
let ticketTitle = '';
let srcClassCode = '';
let destClassCode = '';
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

/** Gọi hàm với quyền của một tài khoản giả (như giao diện): đặt claims rồi chuyển sang vai trò authenticated. */
async function asUser(db: pg.Client, account: string) {
  const id =
    (
      await db.query<{ id: string }>('select id from auth.users where email = $1', [
        `${account}@${DOMAIN}`,
      ])
    ).rows[0]?.id ?? '';
  await db.query(
    `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
       'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
    [id],
  );
  await db.query('set local role authenticated');
}

const enrollment = () =>
  withDb(async (db) => {
    const r = await db.query<{ cls: string | null; hours: string }>(
      `select (select c.code from app.enrollment_class ec join app.class c on c.id = ec.class_id where ec.enrollment_id = e.id and ec.end_date is null limit 1) as cls,
              coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::text as hours
         from app.enrollment e where e.code = $1`,
      [`GDE2ECCS${tag}`],
    );
    return r.rows[0];
  });

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  ticketTitle = `Ticket E2E CCS ${tag}`;
  await withDb(async (db) => {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, b.id, true from app.branch b, (values ('AFTERSALE'), ('VAN_HANH_LOP'), ('CHUYEN_LOP')) v (m) where b.code in ('CS1', 'CS5')
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const monday = `(date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date`;
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, (select id from app.branch where code = 'CS5'))`,
      [`PHE2ECCS${tag}`, `Phụ huynh E2E CCS ${tag}`, `09${tag.slice(-6)}51`],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, (select id from app.branch where code = 'CS5'))`,
      [`HSE2ECCS${tag}`, `PHE2ECCS${tag}`, `Học sinh E2E CCS ${tag}`],
    );
    await db.query(
      `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
       select $1, s.id, s.parent_id, s.branch_id, 'DAI' from app.student s where s.code = $2`,
      [`GDE2ECCS${tag}`, `HSE2ECCS${tag}`],
    );
    await asUser(db, 'quantri.cs5');
    const mkClass = async (branch: string) => {
      const created = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = $1),
           'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
           'start_date', ${monday}, 'total_sessions', 6,
           'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', ${monday})))) as r) x`,
        [branch],
      );
      const cls = created.rows[0];
      if (!cls) throw new Error('Không tạo được lớp giả.');
      for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
        await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
      return cls;
    };
    const src = await mkClass('CS5');
    const dest = await mkClass('CS1');
    srcClassCode = src.code;
    destClassCode = dest.code;
    // Xếp ghi danh vào lớp CS5 (Đang học), rồi có 5 giờ đầu kỳ.
    await db.query(
      `select app.assign_enrollment_class(e.id, $2::uuid, ${monday}) from app.enrollment e where e.code = $1`,
      [`GDE2ECCS${tag}`, src.id],
    );
    await db.query('reset role');
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
       select e.id, e.branch_id, 'DAU_KY', 5 from app.enrollment e where e.code = $1`,
      [`GDE2ECCS${tag}`],
    );
    await asUser(db, 'cskh.cs5');
    await db.query(
      `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
         'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', 'DN_01_04',
         'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3)))`,
      [ticketTitle, `PHE2ECCS${tag}`, `HSE2ECCS${tag}`],
    );
    await db.query('reset role');
    await db.query('commit');
  });
});

test.afterAll(async () => {
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const enr = '(select id from app.enrollment where code = $1)';
    const code = [`GDE2ECCS${tag}`];
    await db.query(`delete from app.hour_ledger where enrollment_id in ${enr}`, code);
    await db.query(`delete from app.enrollment_class where enrollment_id in ${enr}`, code);
    await db.query(
      `delete from app.ticket_task_event where task_id in (select t.id from app.ticket_task t join app.ticket k on k.id = t.ticket_id where k.title = $1)`,
      [ticketTitle],
    );
    await db.query(
      `delete from app.ticket_task where ticket_id in (select id from app.ticket where title = $1)`,
      [ticketTitle],
    );
    await db.query('delete from app.enrollment where code = $1', code);
    await db.query('commit');
  });
});

/** Đăng nhập một tài khoản ở ngữ cảnh riêng (không dùng chung phiên với tài khoản khác). */
async function inOwnContext<T>(browser: Browser, account: string, run: (page: Page) => Promise<T>) {
  const context = await browser.newContext();
  try {
    const page = await context.newPage();
    await enterAs(page, account);
    return await run(page);
  } finally {
    await context.close();
  }
}

test('CSKH cơ sở đi: tạo phiếu Chuyển cơ sở từ ticket và trình duyệt', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(ticketTitle);
  await page.getByRole('cell', { name: ticketTitle, exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Tạo phiếu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu Chuyển lớp' });
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Ghi danh' }),
    new RegExp(`GDE2ECCS${tag}`),
  );
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }),
    'Chuyển chỗ ở, đổi cơ sở',
  );
  await pickOption(page, dialog.getByRole('combobox', { name: 'Loại chuyển' }), 'Chuyển cơ sở');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Cơ sở mới' }), /CS1/);
  await dialog.getByLabel('Lý do', { exact: true }).fill('Lý do E2E chuyển cơ sở');
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  taskUrl = page.url();
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await showAllTimeline(page);
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.', { exact: true })).toBeVisible();
});

test('Cơ sở đích KHÔNG thấy phiếu trước khi cơ sở đi duyệt', async ({ browser }) => {
  await inOwnContext(browser, 'truongcs.cs1', async (page) => {
    await page.goto('/crm/phieu-chuyen-co-so-den');
    await expect(page.getByText('Chưa có phiếu chuyển cơ sở nào chờ bạn')).toBeVisible();
  });
});

test('Quản lý cơ sở đi duyệt cấp 1', async ({ browser }) => {
  await inOwnContext(browser, 'truongcs.cs5', async (page) => {
    await page.goto(taskUrl);
    await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
    const approve = page.getByRole('dialog', { name: 'Duyệt phiếu' });
    await approve.getByLabel('Ghi chú').fill('Đồng ý chuyển đi');
    await approve.getByRole('button', { name: 'Duyệt', exact: true }).click();
    await expect(page.getByText(/Chờ duyệt/).first()).toBeVisible();
  });
});

test('Cơ sở đích nhận phiếu: chọn lớp mới và buổi bắt đầu rồi duyệt', async ({ browser }) => {
  await inOwnContext(browser, 'truongcs.cs1', async (page) => {
    await page.goto('/crm/phieu-chuyen-co-so-den');
    await page
      .getByRole('cell', { name: new RegExp(`E2E CCS ${tag}`) })
      .first()
      .click();
    await expect(page).toHaveURL(/\/crm\/phieu-chuyen-co-so-den\/[0-9a-f-]{36}$/);
    // Chưa chọn lớp thì chưa Duyệt được.
    await expect(page.getByRole('button', { name: 'Duyệt', exact: true })).toBeDisabled();
    await pickOption(page, page.getByRole('combobox', { name: 'Lớp ở cơ sở mới' }), destClassCode);
    await pickOption(page, page.getByRole('combobox', { name: 'Hiệu lực từ buổi' }), /Buổi 1/);
    await page.getByRole('button', { name: 'Lưu lớp' }).click();
    await expect(page.getByText('Đã lưu lớp mới.', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
    const approve = page.getByRole('dialog', { name: 'Duyệt phiếu' });
    await approve.getByLabel('Ghi chú duyệt').fill('Nhận em');
    await approve.getByRole('button', { name: 'Duyệt', exact: true }).click();
    await expect(page.getByText('Đã cập nhật phiếu.', { exact: true })).toBeVisible();
  });
});

test('Thực hiện: ghi danh sang lớp của cơ sở đích, giờ giữ nguyên', async ({ browser }) => {
  expect(await enrollment()).toEqual({ cls: srcClassCode, hours: '5.00' });
  await inOwnContext(browser, 'truongcs.cs5', async (page) => {
    await page.goto(taskUrl);
    await page.getByRole('button', { name: 'Thực hiện', exact: true }).click();
    await page
      .getByRole('alertdialog')
      .getByRole('button', { name: 'Thực hiện', exact: true })
      .click();
    await showAllTimeline(page);
    await expect(
      page.getByText('Thực hiện phiếu. Đã duyệt → Đã thực hiện.', { exact: true }),
    ).toBeVisible();
  });
  expect(await enrollment()).toEqual({ cls: destClassCode, hours: '5.00' });
});
