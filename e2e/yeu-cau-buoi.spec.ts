// BUOI-08 Tạo yêu cầu buổi củng cố, BUOI-10 danh sách và duyệt (lát đầu, R-BUOI-04, R-BUOI-10). Máy tính. Dữ liệu giả: bật cờ YEU_CAU_BUOI ở CS5 (mặc định tắt),
// dựng một lớp Đại số khối 9 CS5 đã duyệt bằng hàm nghiệp vụ (giáo viên gv.cs5). CSKH tạo và gửi; Trưởng cơ sở duyệt hoặc từ chối.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DB_URL } from './bao-gia-seed';
import { DOMAIN, PASSWORD, enterAs, expectAccessible, pickOption } from './helpers';

// G21: yêu cầu trùng giờ giáo viên thì hộp «Trùng giờ, vẫn duyệt?» hiện trước khi duyệt (cảnh báo, không chặn): bấm «Vẫn duyệt» để đi tiếp.
async function acceptClashIfAny(page: Page): Promise<void> {
  const go = page.getByRole('button', { name: 'Vẫn duyệt' });
  if (await go.isVisible({ timeout: 1500 }).catch(() => false)) await go.click();
}

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lớp giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Đào tạo chỉ có bản máy tính.');
});

let classCode = '';
let classId = '';
const TAG = `YC${Date.now().toString(36).slice(-5).toUpperCase()}`;
const STUDENT_A = `Em ${TAG} A`;
const inDays = (n: number) =>
  new Date(Date.now() + n * 86_400_000).toLocaleDateString('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
  });

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

test.beforeAll(async () => {
  const made = await withDb(async (db) => {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('YEU_CAU_BUOI')) f (m) where code = 'CS5'
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
         'start_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'total_sessions', 4,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) as r) x`,
      [gv],
    );
    const cls = created.rows[0];
    if (!cls) throw new Error('Không tạo được lớp giả.');
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
    await db.query('reset role');
    // Hai em đang học trong lớp (ghi danh Đang học, quỹ 24 giờ) để chọn em yếu ở yêu cầu bổ trợ. Dữ liệu giả.
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PH${TAG}`, `Phụ huynh ${TAG}`, `09${String(Date.now()).slice(-8)}`],
    );
    for (const [i, name] of [STUDENT_A, `Em ${TAG} B`].entries()) {
      const st = await db.query<{ id: string }>(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2011, ${branch}) returning id`,
        [`HS${TAG}${i + 1}`, `PH${TAG}`, name],
      );
      const e = await db.query<{ id: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
         values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', 'DANG_HOC', 24)
         returning id`,
        [`GD${TAG}${i + 1}`, st.rows[0]?.id, `PH${TAG}`],
      );
      await db.query(
        `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, (now() at time zone 'Asia/Ho_Chi_Minh')::date)`,
        [e.rows[0]?.id, cls.id],
      );
      await db.query(
        `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values ($1, ${branch}, 'CAP_MUA', 24)`,
        [e.rows[0]?.id],
      );
    }
    await db.query('commit');
    return { id: cls.id, code: cls.code };
  });
  classCode = made.code;
  classId = made.id;
});
test.afterAll(async () => {
  // Trả cờ về mặc định tắt cho các bài khác (không có dòng cờ = tắt).
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'YEU_CAU_BUOI'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
});

async function createRequest(page: import('@playwright/test').Page, day: number) {
  await page.goto('/crm/yeu-cau-buoi/tao-cung-co');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Tạo yêu cầu buổi củng cố' }),
  ).toBeVisible();
  await page.getByLabel('Tìm lớp').fill(classCode);
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Lớp', exact: true }),
    new RegExp(classCode),
  );
  await page.getByLabel('Ngày buổi củng cố').fill(inDays(day));
  await page.getByLabel('Giờ bắt đầu').fill('20:00');
  await page.getByLabel('Giờ kết thúc').fill('21:30');
}

test('BUOI-08: form trắng báo lỗi tại ô; CSKH gửi duyệt thì về danh sách, yêu cầu Chờ duyệt (không có nút Duyệt)', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/yeu-cau-buoi/tao-cung-co');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page.getByText('Chọn lớp.')).toBeVisible();
  await expect(page.getByText('Chọn ngày buổi củng cố.')).toBeVisible();
  await expectAccessible(page);
  await createRequest(page, 10);
  // Giờ kết thúc không sau giờ bắt đầu thì báo tại ô.
  await page.getByLabel('Giờ kết thúc').fill('19:00');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page.getByText('Giờ kết thúc phải sau giờ bắt đầu.')).toBeVisible();
  await page.getByLabel('Giờ kết thúc').fill('21:30');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page).toHaveURL(/\/crm\/yeu-cau-buoi$/);
  const row = page.getByRole('row').filter({ hasText: 'Cả lớp' }).first();
  await expect(row).toContainText('Chờ duyệt');
  await expect(row).toContainText(/YB-CS5-\d{4}-\d{4}/);
  await expect(row).toContainText('chỉ Trưởng cơ sở duyệt'); // khung BUOI10_cskh
  await expect(row).toContainText(classCode); // cột Lớp
  await expect(page.getByRole('button', { name: 'Duyệt', exact: true })).toHaveCount(0);
});

test('BUOI-10: Trưởng cơ sở Duyệt thì buổi củng cố được chèn vào lịch và mở được', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await expect(page.getByRole('heading', { level: 1, name: 'Yêu cầu buổi' })).toBeVisible();
  await page.getByRole('button', { name: 'Duyệt', exact: true }).first().click();
  await acceptClashIfAny(page);
  await expect(page.getByText(/^Đã duyệt YB-CS5-/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Tất cả' }).click();
  await expect(page.getByRole('row').filter({ hasText: 'Đã duyệt' }).first()).toBeVisible();
  await page.getByRole('link', { name: 'Mở buổi' }).first().click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Buổi củng cố').first()).toBeVisible();
});

test('BUOI-08: CSKH tạo và gửi thêm một yêu cầu để thử Từ chối', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await createRequest(page, 11);
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page).toHaveURL(/\/crm\/yeu-cau-buoi$/);
  await expect(page.getByRole('row').filter({ hasText: 'Chờ duyệt' }).first()).toBeVisible();
});

// Thẻ mới cho Trưởng cơ sở: cùng một thẻ thì phiên CSKH còn trong bộ nhớ, đổi tài khoản không đổi được.
test('BUOI-10: Từ chối chọn lý do từ danh mục; yêu cầu thành Từ chối', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await page.getByRole('button', { name: 'Từ chối', exact: true }).first().click();
  const dialog = page.getByRole('dialog', { name: 'Từ chối yêu cầu buổi' });
  await expect(dialog.getByRole('button', { name: 'Từ chối' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Lý do' }), 'Không xếp được lịch');
  await dialog.getByLabel('Ghi chú').fill('Phòng kín lịch tối đó');
  await dialog.getByRole('button', { name: 'Từ chối' }).click();
  await expect(page.getByText(/^Đã từ chối YB-CS5-/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Tất cả' }).click();
  await expect(page.getByRole('row').filter({ hasText: 'Từ chối' }).first()).toContainText(
    'Phòng kín lịch tối đó',
  );
});

test('BUOI-09: từ bản ghi lớp mở Yêu cầu bổ trợ; form báo lỗi; CSKH chọn em, giáo viên rồi gửi duyệt', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/lop/${classId}`);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Yêu cầu bổ trợ' }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/yeu-cau-buoi/tao-bo-tro\\?lop=${classId}$`));
  await expect(
    page.getByRole('heading', { level: 1, name: 'Tạo yêu cầu học bổ trợ' }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page.getByText('Chọn ít nhất một học sinh cần bổ trợ.')).toBeVisible();
  await expect(page.getByText('Chọn giáo viên.')).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('checkbox', { name: new RegExp(STUDENT_A) }).check();
  await page.getByLabel('Ngày', { exact: true }).fill(inDays(12));
  await page.getByLabel('Giờ bắt đầu').fill('20:00');
  await page.getByLabel('Giờ kết thúc').fill('21:00');
  await pickOption(page, page.getByRole('combobox', { name: 'Giáo viên' }), /Giáo viên CS5/);
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page).toHaveURL(/\/crm\/yeu-cau-buoi$/);
  const row = page.getByRole('row').filter({ hasText: 'Bổ trợ' }).first();
  await expect(row).toContainText(STUDENT_A);
  await expect(row).toContainText('Chờ duyệt');
});

test('BUOI-09: Trưởng cơ sở duyệt thì buổi Bổ trợ được chèn, giáo viên là người được chọn', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await page
    .getByRole('row')
    .filter({ hasText: 'Bổ trợ' })
    .getByRole('button', { name: 'Duyệt', exact: true })
    .first()
    .click();
  await acceptClashIfAny(page);
  await expect(page.getByText(/^Đã duyệt YB-CS5-/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Tất cả' }).click();
  await page
    .getByRole('row')
    .filter({ hasText: 'Bổ trợ' })
    .getByRole('link', { name: 'Mở buổi' })
    .first()
    .click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Học bổ trợ').first()).toBeVisible();
  await expect(page.getByText('Giáo viên CS5').first()).toBeVisible();
});

test('BUOI-07: từ bản ghi lớp mở Yêu cầu học bù; lý do bắt buộc; CSKH gửi duyệt, Trưởng cơ sở duyệt thì sinh buổi Học bù mới', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/lop/${classId}`);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Yêu cầu học bù' }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/yeu-cau-buoi/tao-hoc-bu\\?lop=${classId}$`));
  await expect(page.getByRole('heading', { level: 1, name: 'Tạo yêu cầu học bù' })).toBeVisible();
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page.getByText('Nhập lý do học bù.')).toBeVisible();
  await expect(page.getByText('Chọn ít nhất một học sinh học bù.')).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('checkbox', { name: new RegExp(STUDENT_A) }).check();
  await page.getByLabel('Ngày', { exact: true }).fill(inDays(13));
  await page.getByLabel('Giờ bắt đầu').fill('20:00');
  await page.getByLabel('Giờ kết thúc').fill('21:00');
  await page.getByLabel('Lý do học bù').fill('Nghỉ ốm buổi trước');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page).toHaveURL(/\/crm\/yeu-cau-buoi$/);
  await expect(page.getByRole('row').filter({ hasText: 'Học bù' }).first()).toContainText(
    STUDENT_A,
  );
});

test('BUOI-07: Trưởng cơ sở duyệt yêu cầu học bù thì buổi Học bù mới mở được', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await page
    .getByRole('row')
    .filter({ hasText: 'Học bù' })
    .getByRole('button', { name: 'Duyệt', exact: true })
    .first()
    .click();
  await acceptClashIfAny(page);
  await expect(page.getByText(/^Đã duyệt YB-CS5-/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Tất cả' }).click();
  await page
    .getByRole('row')
    .filter({ hasText: 'Học bù' })
    .getByRole('link', { name: 'Mở buổi' })
    .first()
    .click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Học bù').first()).toBeVisible();
});

test('BUOI-07, BUOI-09: Sale chỉ xem lớp, không có mục Yêu cầu học bù, Yêu cầu bổ trợ (thiếu quyền Buổi học · Tạo)', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs5');
  await page.goto(`/crm/lop/${classId}`);
  await expect(page.getByText(classCode).first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toHaveCount(0);
});

test('A25: yêu cầu học bù chọn Buổi kiểm tra: lỗi tổng ba nhóm, rồi gửi duyệt', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/yeu-cau-buoi/tao-hoc-bu?lop=${classId}`);
  await page.getByRole('checkbox', { name: new RegExp(STUDENT_A) }).check();
  await page.getByLabel('Ngày', { exact: true }).fill(inDays(15));
  await page.getByLabel('Giờ bắt đầu').fill('20:00');
  await page.getByLabel('Giờ kết thúc').fill('21:00');
  await page.getByLabel('Lý do học bù').fill('Thi bù giữa kỳ');
  await page.getByRole('checkbox', { name: 'Buổi kiểm tra' }).check();
  await expect(page.getByText(/Kiểm tra bù \(thi bù\) không trừ giờ/)).toBeVisible();
  await page.getByLabel('Phạm vi kiến thức').fill('Phương trình bậc nhất');
  await page.getByLabel('Điểm tối đa', { exact: true }).fill('10');
  await pickOption(page, page.getByRole('combobox', { name: 'Cách nhập điểm' }), /3 nhóm/);
  await page.getByLabel('Điểm tối đa · Ghi nhớ').fill('3');
  await page.getByLabel('Điểm tối đa · Hiểu').fill('3');
  await page.getByLabel('Điểm tối đa · Vận dụng').fill('3');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(
    page.getByText(/Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi/),
  ).toBeVisible();
  await page.getByLabel('Điểm tối đa · Vận dụng').fill('4');
  await page.getByRole('button', { name: 'Gửi duyệt' }).click();
  await expect(page).toHaveURL(/\/crm\/yeu-cau-buoi$/);
});

test('A25: Trưởng cơ sở duyệt yêu cầu học bù loại Kiểm tra thì buổi sinh ra là loại Kiểm tra (thi bù)', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await page
    .getByRole('row')
    .filter({ hasText: 'Học bù' })
    .getByRole('button', { name: 'Duyệt', exact: true })
    .first()
    .click();
  await acceptClashIfAny(page);
  await expect(page.getByText(/^Đã duyệt YB-CS5-/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Tất cả' }).click();
  await page
    .getByRole('row')
    .filter({ hasText: 'Học bù' })
    .getByRole('link', { name: 'Mở buổi' })
    .first()
    .click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\/[0-9a-f-]{36}$/);
  await expect(page.getByText('Kiểm tra', { exact: true }).first()).toBeVisible();
});

test('Cờ tắt: mục Yêu cầu buổi ẩn khỏi menu và mở thẳng báo chưa bật', async ({ page }) => {
  await withDb((db) =>
    db.query(
      `update app.feature_flag set enabled = false where module_code = 'YEU_CAU_BUOI'
         and branch_id = (select id from app.branch where code = 'CS5')`,
    ),
  );
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/yeu-cau-buoi');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
  await expect(page.getByRole('heading', { level: 1, name: 'Yêu cầu buổi' })).toHaveCount(0);
});
