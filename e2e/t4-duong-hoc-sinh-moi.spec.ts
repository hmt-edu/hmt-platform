// T4: đường đi trọn của một học sinh MỚI bằng trình duyệt, một spec nối tiếp (máy tính, dữ liệu giả):
// lead → cơ hội → L8 → đơn hàng → trình, duyệt → phiếu thu → kế toán duyệt (ghi danh tự sinh) → xếp lớp → chốt buổi → giáo viên điểm danh, nhận xét → Done.
// Bước nào hiện chưa bấm được bằng giao diện hoặc chỉ để dựng dữ liệu thì dùng SQL qua pg và GHI RÕ bằng chữ "TẮT" trong tên bước hay chú thích.
// Dựng từng đoạn: đoạn 1 (lead đến đơn Nháp), đoạn 2 (trình, duyệt đơn, phiếu thu, kế toán duyệt, ghi danh Chờ xếp lớp), đoạn 3 (xếp lớp, chốt buổi, giáo viên điểm danh, Done, trừ giờ). Còn thiếu: nhận xét GV-07.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, enterAsAdmin, loginStaff, pickOption } from './helpers';
import { DB_URL } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dữ liệu giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Đường T4 làm trên máy tính.');
});

const SALE = 'sale.cs5';
const MANAGER = 'truongcs.cs5';
// Tài khoản kế toán riêng của bài này (ketoan.cs5 thuộc phieu-thu.spec): hai file không tranh thiết bị hai bước.
const ACCOUNTANT = 'ketoan2.cs5';
const TAG = `T4${Date.now().toString(36).slice(-5).toUpperCase()}`;
const PARENT = `Chị ${TAG}`;
const STUDENT = `Em ${TAG}`;
const PHONE = `09${String(Date.now()).slice(-8)}`;

const state = {
  leadId: '',
  oppId: '',
  orderId: '',
  orderCode: '',
  receiptUrl: '',
  classId: '',
  classCode: '',
  sessionId: '',
};

const stageBar = (page: Page) => page.getByRole('navigation', { name: 'Giai đoạn' });
const dialogOf = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name });

async function sql(text: string, args: unknown[] = []) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(text, args);
  } finally {
    await db.end();
  }
}

test('1. Sale tạo lead (TS-03) bằng giao diện', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto('/crm/lead/moi');
  await expect(page.getByRole('heading', { level: 2, name: 'Lead mới' })).toBeVisible();
  await page.getByLabel('Họ tên', { exact: true }).fill(PARENT);
  await page.getByLabel('Số điện thoại', { exact: true }).fill(PHONE);
  await pickOption(page, page.getByRole('combobox', { name: 'Source', exact: true }), 'Website');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/lead\/[0-9a-f-]{36}$/);
  state.leadId = page.url().split('/').pop() ?? '';
});

test('2. TẮT: đưa lead sang C4C bằng SQL (các bước C1 đến C4 đã có bài riêng ở lead.spec)', async () => {
  await sql(`update app.lead set stage_code = 'C4', substage_code = 'C4C' where id = $1`, [
    state.leadId,
  ]);
});

test('3. Tạo cơ hội từ lead (TS-06)', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/lead/${state.leadId}`);
  await page.getByRole('button', { name: 'Tạo cơ hội' }).click();
  await dialogOf(page, 'Tạo cơ hội từ lead').getByRole('button', { name: 'Tạo cơ hội' }).click();
  await expect(page).toHaveURL(/\/crm\/co-hoi\/[0-9a-f-]{36}$/);
  state.oppId = page.url().split('/').pop() ?? '';
  await expect(stageBar(page).getByRole('button', { name: /^L1/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
});

test('4. Nhập tên và năm sinh học sinh (bắt buộc từ L5, R-CRM-03)', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/co-hoi/${state.oppId}`);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Tên học sinh').first().fill(STUDENT);
  await page.getByLabel('Năm sinh', { exact: true }).fill('2012');
  await page.getByRole('button', { name: 'Lưu' }).click();
  await expect(page.getByText('Đã lưu.').first()).toBeVisible();
});

test('5. Chuyển cơ hội lên L8 (bỏ qua test có lý do, R-CRM-14, R-CRM-16)', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/co-hoi/${state.oppId}`);
  await stageBar(page).getByRole('button', { name: /^L8/ }).click();
  const l8 = dialogOf(page, /Chuyển sang L8/);
  await pickOption(page, l8.getByRole('combobox', { name: 'Lý do bỏ qua test' }), /^Lý do khác$/);
  await l8.getByLabel(/^Ghi chú/).fill('Đường T4: bỏ qua test (dữ liệu giả)');
  await pickOption(page, l8.getByRole('combobox', { name: 'Sub-stage' }), /L8A/);
  await l8.getByRole('checkbox').check();
  await l8.getByRole('button', { name: 'Chuyển L8' }).click();
  await expect(stageBar(page).getByRole('button', { name: /^L8/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
});

test('6. Tạo đơn hàng từ cơ hội L8 bằng giao diện UI-O4', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/co-hoi/${state.oppId}`);
  await page.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo đơn hàng' })).toBeVisible();
  await page.getByRole('button', { name: 'Gói dòng 1' }).click();
  await page
    .getByRole('dialog', { name: 'Chọn gói' })
    .getByRole('button', { name: /LC-TOAN-K09/ })
    .first()
    .click();
  await page.getByLabel('Số lượng dòng 1').fill('10');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]{36}$/);
  state.orderId = page.url().split('/').pop() ?? '';
  const heading = page.getByRole('heading', { level: 2, name: /^DH-/ });
  await expect(heading).toBeVisible();
  state.orderCode = (await heading.textContent())?.trim() ?? '';
  expect(state.orderCode).toMatch(/^DH-/);
});

test('7. Sale chọn điều khoản thanh toán cho đơn Nháp rồi Lưu (UI-O3)', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/don-hang/${state.orderId}`);
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option').first().click();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu đơn.').first()).toBeVisible();
});

test('8. Sale trình duyệt đơn (R-TIEN-35: em đủ họ tên, năm sinh)', async ({ page }) => {
  await enterAs(page, SALE);
  await page.goto(`/crm/don-hang/${state.orderId}`);
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  await expect(page.getByText('Đã trình đơn.').first()).toBeVisible();
});

test('9. Trưởng cơ sở duyệt đơn (BH-07)', async ({ page }) => {
  await enterAs(page, MANAGER);
  await page.goto(`/crm/don-hang/${state.orderId}`);
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  await dialogOf(page, 'Duyệt đơn hàng')
    .getByRole('button', { name: 'Duyệt', exact: true })
    .click();
  await expect(page.getByText('Đã duyệt đơn hàng.').first()).toBeVisible();
  await expect(page.getByText('Đã duyệt · khoá').first()).toBeVisible();
});

test('10. Sale tạo phiếu thu từ đơn Đã duyệt (thu đủ cả đơn), trình quản lý (TC-03)', async ({
  page,
}) => {
  await enterAs(page, SALE);
  // Hộp Tạo phiếu thu gợi ý số tiền từ tab Thanh toán (tải bất đồng bộ): chờ dữ liệu về trước khi bấm.
  const loaded = page.waitForResponse((r) => r.url().includes('order_payment_summary') && r.ok());
  await page.goto(`/crm/don-hang/${state.orderId}`);
  await loaded;
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = dialogOf(page, 'Tạo phiếu thu');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  // Số tiền điền sẵn theo đợt tới hạn đầu tiên (T2-04); bài này đi đường thu đủ cả đơn để ghi danh sinh ra ở bước 12.
  await expect(dialog.getByLabel('Số tiền')).not.toHaveValue('');
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  let total: string;
  try {
    const r = await db.query<{ t: string }>(
      `select total_amount::text as t from app.sales_order where id = $1::uuid`,
      [state.orderId],
    );
    total = r.rows[0]?.t ?? '';
  } finally {
    await db.end();
  }
  await dialog.getByLabel('Số tiền').fill(total);
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  state.receiptUrl = new URL(page.url()).pathname;
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ .*duyệt/).first()).toBeVisible();
});

test('11. Trưởng cơ sở duyệt phiếu thu, chuyển Kế toán (TC-05)', async ({ page }) => {
  await enterAs(page, MANAGER);
  await page.goto(state.receiptUrl);
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});

test('12. Kế toán duyệt phiếu thu: sinh khoản tiền vào, ghi danh Chờ xếp lớp, cơ hội tự lên L8C (R-CRM-17)', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto(state.receiptUrl);
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText('Đã duyệt phiếu thu, tiền đã ghi nhận.').first()).toBeVisible();
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    const money = await db.query<{ n: string }>(
      `select count(*)::text as n from app.money_in where order_id = $1::uuid`,
      [state.orderId],
    );
    expect(money.rows[0]?.n).toBe('1');
    const enr = await db.query<{ status_code: string }>(
      `select e.status_code from app.enrollment e where e.order_id = $1::uuid`,
      [state.orderId],
    );
    expect(enr.rows.length).toBeGreaterThan(0);
    expect(enr.rows.every((r) => r.status_code === 'CHO_XEP_LOP')).toBe(true);
    const opp = await db.query<{ substage_code: string }>(
      `select substage_code from app.opportunity where id = $1::uuid`,
      [state.oppId],
    );
    expect(opp.rows[0]?.substage_code).toBe('L8C');
  } finally {
    await db.end();
  }
});

// ---------- Đoạn 3: xếp lớp, buổi, điểm danh, Done ----------
test('13. TẮT: dựng lớp Đại số khối 9 CS5 đã duyệt, giáo viên gv.cs5 (lớp chưa nằm trong luồng bấm tay của đoạn này; hàm tạo lớp có bài riêng)', async () => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const ids = await db.query<{ admin: string; gv: string }>(
      `select (select id from auth.users where email = $1) as admin, (select id from auth.users where email = $2) as gv`,
      [`quantri.cs5@${DOMAIN}`, `gv.cs5@${DOMAIN}`],
    );
    const { admin, gv } = ids.rows[0] ?? { admin: '', gv: '' };
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const created = await db.query<{ id: string; code: string }>(
      `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'),
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'total_sessions', 6,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) as r) x`,
      [gv],
    );
    const cls = created.rows[0];
    if (!cls) throw new Error('Không tạo được lớp giả.');
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
    await db.query('commit');
    state.classId = cls.id;
    state.classCode = cls.code;
  } finally {
    await db.end();
  }
});

test('14. CSKH xếp lớp cho ghi danh trong hàng chờ (GD-06, GD-03)', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/cho-xep-lop');
  await page.getByRole('searchbox').fill(STUDENT);
  const table = page.getByRole('table', { name: 'Hàng chờ xếp lớp' });
  const row = table.getByRole('row').filter({ hasText: STUDENT });
  await expect(row).toHaveCount(1);
  await row.getByRole('button', { name: 'Xếp lớp' }).click();
  const dialog = dialogOf(page, 'Xếp lớp cho ghi danh');
  await dialog.getByRole('radio', { name: 'Một lớp lẻ' }).click();
  await dialog.getByRole('radio', { name: new RegExp(state.classCode) }).check();
  await dialog.getByRole('button', { name: 'Xếp lớp', exact: true }).click();
  await expect(page.getByText('Đã xếp lớp.', { exact: true })).toBeVisible();
  await expect(table.getByRole('row').filter({ hasText: STUDENT })).toHaveCount(0);
});

// Ngày của (bây giờ − 1 giờ) theo giờ Việt Nam: buổi 00:00–00:30 luôn đã kết thúc khi bài 18 chạy, kể cả quanh nửa đêm giờ Việt Nam (17:00–17:30 UTC).
test('15. TẮT: đưa buổi 1 của lớp về hôm nay (đã kết thúc) và ngày vào lớp về hôm nay để vào danh sách buổi', async () => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    const s = await db.query<{ id: string }>(
      `update app.class_session set session_date = ((now() - interval '1 hour') at time zone 'Asia/Ho_Chi_Minh')::date, start_time = '00:00', end_time = '00:30'
        where class_id = $1::uuid and session_no = 1 returning id`,
      [state.classId],
    );
    state.sessionId = s.rows[0]?.id ?? '';
    expect(state.sessionId).not.toBe('');
    await db.query(
      `update app.enrollment_class set start_date = ((now() - interval '1 hour') at time zone 'Asia/Ho_Chi_Minh')::date where class_id = $1::uuid`,
      [state.classId],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
});

test('16. CSKH chốt danh sách buổi (BUOI-02): em mới có trong danh sách', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${state.sessionId}`);
  await page.getByRole('button', { name: 'Chốt danh sách' }).click();
  await page
    .getByRole('alertdialog', { name: 'Chốt danh sách buổi này?' })
    .getByRole('button', { name: 'Chốt danh sách' })
    .click();
  await expect(page.getByText('Đã chốt danh sách').first()).toBeVisible();
  await expect(page.getByRole('cell', { name: new RegExp(STUDENT) })).toBeVisible();
});

test('17. Giáo viên điểm danh Có mặt và Lưu (GV-05)', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/buoi/${state.sessionId}/diem-danh`);
  await expect(page.getByRole('heading', { level: 1, name: 'Điểm danh' })).toBeVisible();
  await page.getByRole('button', { name: /^Còn lại: / }).click();
  await page.getByRole('button', { name: 'Lưu điểm danh' }).click();
  await expect(page.getByText('Đã lưu điểm danh', { exact: true })).toBeVisible();
});

test('17b. Giáo viên nhập nội dung buổi, BTVN để trống (GV-06, điều kiện Done R-GIO-06)', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(`/gv/buoi/${state.sessionId}/noi-dung`);
  await page.getByLabel('Dòng nội dung 1').fill('Phương trình bậc nhất (đường T4)');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu nội dung buổi').first()).toBeVisible();
});

test('18. TẮT: hệ thống tự Done buổi (hàm mark_session_done, pg_cron gọi); trừ giờ khỏi quỹ (R-GIO-01)', async () => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('select app.mark_session_done($1::uuid)', [state.sessionId]);
    const st = await db.query<{ status_code: string }>(
      'select status_code from app.class_session where id = $1::uuid',
      [state.sessionId],
    );
    expect(st.rows[0]?.status_code).toBe('DONE');
    const ledger = await db.query<{ hours: string }>(
      `select h.hours::text from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
        where e.order_id = $1::uuid and h.entry_type = 'TRU_BUOI' and h.session_id = $2::uuid`,
      [state.orderId, state.sessionId],
    );
    expect(ledger.rows.length).toBe(1);
    expect(Number(ledger.rows[0]?.hours)).toBeLessThan(0);
  } finally {
    await db.end();
  }
});

test('19. CSKH thấy buổi Hoàn thành ở BUOI-02 và dòng Trừ buổi ở sổ giờ (GD-04)', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/buoi-hoc/${state.sessionId}`);
  await expect(page.getByText('Hoàn thành').first()).toBeVisible();
  const enrollment = await (async () => {
    const db = new pg.Client({ connectionString: DB_URL });
    await db.connect();
    try {
      const r = await db.query<{ id: string }>(
        'select id from app.enrollment where order_id = $1::uuid limit 1',
        [state.orderId],
      );
      return r.rows[0]?.id ?? '';
    } finally {
      await db.end();
    }
  })();
  await page.goto(`/crm/ghi-danh/${enrollment}/so-gio`);
  await expect(page.getByRole('table', { name: 'Sổ giờ' })).toContainText('Trừ buổi');
});
