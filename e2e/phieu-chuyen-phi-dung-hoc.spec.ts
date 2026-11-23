// C-23-08: e2e CS-10 Chuyển phí (xem trước, đơn nhận, chặn âm) và CS-14 Dừng học (trang phiếu, ngày dừng, giữ số dư / hoàn tiền).
// Dữ liệu giả dựng bằng SQL (đơn, dòng đơn, ghi danh có 10 giờ mua, 400.000 đ mỗi giờ) và ticket bằng hàm nghiệp vụ với quyền Admin; mã có dấu riêng mỗi lần chạy.
// Không sửa logic: chỉ kiểm giao diện nối đúng hàm DB đã có (migration 567, 618, 621). Chạy trên máy tính (bài ghi dữ liệu).
import { expect, test, type Browser, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, pickOption } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ghi danh và ticket giả).');
test.describe.configure({ mode: 'serial' });
test.skip(({ isMobile }) => isMobile, 'Phiếu nghiệp vụ ghi dữ liệu chỉ kiểm trên máy tính.');

const HOURS = 10;
const UNIT = 400_000; // đ mỗi giờ, giá sau chiết khấu chụp lúc mua
let tag = '';
const titles = { fee: '', stopKeep: '', stopRefund: '' };

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

const enrollmentStatus = (code: string) =>
  withDb(async (db) => {
    const r = await db.query<{ status: string }>(
      'select status_code as status from app.enrollment where code = $1',
      [code],
    );
    return r.rows[0]?.status ?? '';
  });

const balanceOfParent = () =>
  withDb(async (db) => {
    const r = await db.query<{ total: string }>(
      `select coalesce(sum(b.amount), 0)::text as total from app.customer_balance_entry b
         join app.parent p on p.id = b.parent_id where p.code = $1`,
      [`PHE2EFD${tag}`],
    );
    return Number(r.rows[0]?.total ?? 0);
  });

async function openTicket(page: Page, title: string) {
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(title);
  await page.getByRole('cell', { name: title, exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
}

// Trưởng cơ sở và Kế toán duyệt hai cấp (ngữ cảnh riêng), người tạo thực hiện.
async function approveAndExecute(browser: Browser, page: Page, taskUrl: string) {
  for (const account of ['truongcs.cs5', 'ketoan.cs5']) {
    const context = await browser.newContext();
    try {
      const approver = await context.newPage();
      await enterAs(approver, account);
      await approver.goto(taskUrl);
      await approver.getByRole('button', { name: 'Duyệt', exact: true }).click();
      const dialog = approver.getByRole('dialog', { name: 'Duyệt phiếu' });
      await dialog.getByLabel('Ghi chú').fill('Đồng ý');
      await dialog.getByRole('button', { name: 'Duyệt', exact: true }).click();
      await expect(approver.getByText(/Duyệt\..*Đồng ý/).first()).toBeVisible();
    } finally {
      await context.close();
    }
  }
  await page.goto(taskUrl);
  await page.getByRole('button', { name: 'Thực hiện', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Thực hiện', exact: true })
    .click();
  await expect(page.getByText('Thực hiện phiếu. Đã duyệt → Đã thực hiện.')).toBeVisible();
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  titles.fee = `Ticket E2E CP ${tag}`;
  titles.stopKeep = `Ticket E2E DH1 ${tag}`;
  titles.stopRefund = `Ticket E2E DH2 ${tag}`;
  await withDb(async (db) => {
    await db.query('begin');
    // Dựng thẳng bảng (bỏ kiểm khoá ngoại cho cơ hội giả): chỉ để có đơn, dòng đơn, ghi danh và sổ giờ cho hàm tính.
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, (values ('AFTERSALE'), ('DUNG_HOC')) v (m) where b.code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PHE2EFD${tag}`, `Phụ huynh E2E FD ${tag}`, `09${tag.slice(-6)}71`],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2EFD${tag}`, `PHE2EFD${tag}`, `Học sinh E2E FD ${tag}`],
    );
    await db.query(
      `insert into app.opportunity (code, lead_id, parent_id, branch_id, owner_id, source_type_code, source_code)
       select $1, gen_random_uuid(), p.id, p.branch_id, gen_random_uuid(), 'MARKETING', 'FACEBOOK_ADS' from app.parent p where p.code = $2`,
      [`CHE2EFD${tag}`, `PHE2EFD${tag}`],
    );
    const mkOrder = async (code: string, total: number) =>
      db.query(
        `insert into app.sales_order (code, branch_id, parent_id, priced_on, opportunity_id, total_amount)
         select $1, p.branch_id, p.id, (now() at time zone 'Asia/Ho_Chi_Minh')::date, o.id, $3 from app.parent p, app.opportunity o where p.code = $2 and o.code = $4`,
        [code, `PHE2EFD${tag}`, total, `CHE2EFD${tag}`],
      );
    // Hai đơn nhận: lớn (đủ trừ số dư chuyển) và nhỏ (nhỏ hơn giá trị chuyển → chặn âm).
    await mkOrder(`DHE2EBIG${tag}`, 5_000_000);
    await mkOrder(`DHE2ESML${tag}`, 1_000_000);
    // Ba ghi danh nguồn: chuyển phí, dừng học giữ số dư, dừng học hoàn tiền; mỗi cái 10 giờ mua × 400.000 đ.
    for (const k of ['A', 'B', 'C']) {
      await mkOrder(`DHE2ESRC${k}${tag}`, HOURS * UNIT);
      await db.query(
        `insert into app.sales_order_line (order_id, branch_id, line_no, package_id, package_code, package_name, package_type_code,
           delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total, student_id)
         select o.id, o.branch_id, 1, k.id, k.code, k.name, k.package_type_code, 'OFFLINE', 'GIO', $2, $3, $4, $4, s.id
           from app.sales_order o, app.sales_package k, app.student s where o.code = $1 and k.code = 'LC-TOAN-K09' and s.code = $5`,
        [`DHE2ESRC${k}${tag}`, HOURS, UNIT, HOURS * UNIT, `HSE2EFD${tag}`],
      );
      // Đã thu đủ: phiếu thu → khoản tiền vào → chia về dòng đơn (hàm tính hoàn phí/số dư đọc số đã đóng từ đây).
      await db.query(
        `insert into app.receipt (code, parent_id, branch_id, collect_branch_id, amount, payment_method_code, order_id)
         select $1, o.parent_id, o.branch_id, o.branch_id, o.total_amount, 'TIEN_MAT', o.id from app.sales_order o where o.code = $2`,
        [`PTE2ESRC${k}${tag}`, `DHE2ESRC${k}${tag}`],
      );
      await db.query(
        `insert into app.money_in (code, parent_id, branch_id, amount, order_id, receipt_id)
         select $1, o.parent_id, o.branch_id, o.total_amount, o.id, r.id from app.sales_order o, app.receipt r where o.code = $2 and r.code = $3`,
        [`KTE2ESRC${k}${tag}`, `DHE2ESRC${k}${tag}`, `PTE2ESRC${k}${tag}`],
      );
      await db.query(
        `insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
         select m.id, l.id, l.branch_id, l.line_total from app.money_in m, app.sales_order_line l join app.sales_order o on o.id = l.order_id
          where m.code = $1 and o.code = $2`,
        [`KTE2ESRC${k}${tag}`, `DHE2ESRC${k}${tag}`],
      );
      await db.query(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code, order_id, order_line_id)
         select $1, s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC', l.order_id, l.id
           from app.student s, app.sales_order_line l join app.sales_order o on o.id = l.order_id
          where s.code = $2 and o.code = $3`,
        [`GDE2EFD${k}${tag}`, `HSE2EFD${tag}`, `DHE2ESRC${k}${tag}`],
      );
      await db.query(
        `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
         select e.id, e.branch_id, 'CAP_MUA', $2 from app.enrollment e where e.code = $1`,
        [`GDE2EFD${k}${tag}`, HOURS],
      );
    }
    await db.query('commit');
    await db.query('begin');
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
      [titles.fee, 'DN_02_02'],
      [titles.stopKeep, 'DN_01_06'],
      [titles.stopRefund, 'DN_01_06'],
    ] as const) {
      await db.query(
        `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
           'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', $4::text,
           'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3)))`,
        [title, `PHE2EFD${tag}`, `HSE2EFD${tag}`, category],
      );
    }
    await db.query('commit');
  });
});

test.afterAll(async () => {
  await withDb(async (db) => {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const enr = `(select id from app.enrollment where code like $1)`;
    await db.query(`delete from app.hour_ledger where enrollment_id in ${enr}`, [`GDE2EFD_${tag}`]);
    await db.query(
      'delete from app.customer_balance_entry where parent_id in (select id from app.parent where code = $1)',
      [`PHE2EFD${tag}`],
    );
    await db.query('commit');
  });
});

async function openCreateTask(page: Page, title: string, dialogName: string, enrollment: string) {
  await enterAs(page, 'cskh.cs5');
  await openTicket(page, title);
  await page.getByRole('button', { name: 'Tạo phiếu' }).click();
  const dialog = page.getByRole('dialog', { name: dialogName });
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Ghi danh' }),
    new RegExp(enrollment),
  );
  return dialog;
}

test('CS-10 Chuyển phí: xem trước bảng tính, chặn đơn nhận nhỏ hơn giá trị chuyển, đơn lớn hiện đóng thêm; thực hiện ra số dư', async ({
  browser,
  page,
}) => {
  test.setTimeout(180_000);
  const dialog = await openCreateTask(page, titles.fee, 'Tạo phiếu Chuyển phí', `GDE2EFDA${tag}`);
  const table = dialog.getByRole('table', { name: 'Bảng tính chuyển phí' });
  await expect(table).toBeVisible();
  // 10 giờ × 400.000 đ = 4.000.000 đ giá trị chuyển.
  await expect(table.getByRole('row', { name: /Giá trị chuyển/ })).toContainText('4.000.000');
  // Đơn nhận nhỏ (1.000.000 đ) < giá trị chuyển: chặn âm, hiện lý do ngay trong hộp thoại.
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Đơn nhận/ }),
    new RegExp(`DHE2ESML${tag}`),
  );
  await expect(dialog.getByText(/Giá trị chuyển lớn hơn giá trị đơn nhận/)).toBeVisible();
  // Đơn nhận lớn (5.000.000 đ): phụ huynh đóng thêm 1.000.000 đ.
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Đơn nhận/ }),
    new RegExp(`DHE2EBIG${tag}`),
  );
  await expect(table.getByRole('row', { name: /Phụ huynh đóng thêm/ })).toContainText('1.000.000');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Kiểu chuyển' }), 'Sang môn khác');
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }),
    'Lý do khác',
  );
  await dialog.getByLabel('Lý do', { exact: true }).fill('Lý do E2E chuyển phí');
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: /Trình duyệt|Gửi duyệt/ }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
  await approveAndExecute(browser, page, page.url());
  // Thực hiện: giữ thành số dư khách hàng, không tự hoàn tiền.
  expect(await balanceOfParent()).toBe(HOURS * UNIT);
  expect(await enrollmentStatus(`GDE2EFDA${tag}`)).not.toBe('DANG_HOC');
});

test('CS-14 Dừng học (Giữ số dư): trang phiếu hiện Ngày dừng và cách xử lý; thực hiện đóng ghi danh, số dư tăng', async ({
  browser,
  page,
}) => {
  test.setTimeout(180_000);
  const before = await balanceOfParent();
  const dialog = await openCreateTask(
    page,
    titles.stopKeep,
    'Tạo phiếu Dừng học',
    `GDE2EFDB${tag}`,
  );
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }),
    'Lý do khác',
  );
  await dialog.getByLabel('Ngày dừng').fill(new Date().toISOString().slice(0, 10));
  await pickOption(page, dialog.getByRole('combobox', { name: 'Xử lý tiền còn lại' }), /Giữ số dư/);
  await dialog.getByLabel('Lý do', { exact: true }).fill('Lý do E2E dừng học giữ số dư');
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Dừng học', { exact: true }).first()).toBeVisible();
  await expect(page.getByText('Ngày dừng', { exact: true })).toBeVisible();
  await expect(page.getByText(/Giữ số dư \(không trừ phí\)/)).toBeVisible();
  await page.getByRole('button', { name: /Trình duyệt|Gửi duyệt/ }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
  await approveAndExecute(browser, page, page.url());
  expect(await enrollmentStatus(`GDE2EFDB${tag}`)).not.toBe('DANG_HOC');
  expect(await balanceOfParent()).toBe(before + HOURS * UNIT);
});

test('CS-14 Dừng học (Hoàn tiền): trang phiếu hiện cách xử lý Hoàn tiền; không tự cộng số dư', async ({
  page,
}) => {
  test.setTimeout(120_000);
  const before = await balanceOfParent();
  const dialog = await openCreateTask(
    page,
    titles.stopRefund,
    'Tạo phiếu Dừng học',
    `GDE2EFDC${tag}`,
  );
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }),
    'Lý do khác',
  );
  await dialog.getByLabel('Ngày dừng').fill(new Date().toISOString().slice(0, 10));
  await pickOption(page, dialog.getByRole('combobox', { name: 'Xử lý tiền còn lại' }), /Hoàn tiền/);
  await dialog.getByLabel('Lý do', { exact: true }).fill('Lý do E2E dừng học hoàn tiền');
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  await expect(page.getByText(/Hoàn tiền \(sang phiếu Hoàn học phí\)/)).toBeVisible();
  expect(await balanceOfParent()).toBe(before);
});
