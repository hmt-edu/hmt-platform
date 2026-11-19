// C40 (R-CS-02, R-GD-09): ticket → phiếu nghiệp vụ Bảo lưu → trình → Trưởng cơ sở duyệt → thực hiện, rồi Gia hạn bảo lưu và Tiếp tục học.
// Kiểm giờ còn lại KHÔNG đổi và tình trạng ghi danh sau mỗi bước (Bảo lưu → vẫn Bảo lưu khi gia hạn → Chờ xếp lớp khi tiếp tục học, không tự xếp lớp).
// Dữ liệu giả dựng bằng SQL (một ghi danh Đang học 5 giờ) và hàm nghiệp vụ với quyền Admin; ba ticket (bảo lưu, gia hạn, tiếp tục), mã có dấu riêng mỗi lần chạy.
// Chuyển lớp chưa có trong bài này (cần lớp đã duyệt đủ điều kiện, dựng nặng): báo trong PR.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, isPhone, pickOption } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ghi danh và ticket giả).');
test.describe.configure({ mode: 'serial' });
// Bài chỉ ghi trên máy tính (như TC-09): điện thoại không thêm giá trị và tránh hai dự án ghi cùng ghi danh.
test.skip(({ isMobile }) => isMobile, 'Phiếu nghiệp vụ ghi dữ liệu chỉ kiểm trên máy tính.');

let tag = '';
const titles = { hold: '', extend: '', resume: '' };

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
    new RegExp(`GDE2E${tag}`),
  );
  await pickOption(page, dialog.getByRole('combobox', { name: /Lý do \(danh mục\)/ }), /thi|bận/i);
  if (months !== null) await dialog.getByLabel(/Số tháng/).fill(months);
  await dialog.getByLabel('Lý do', { exact: true }).fill(`Lý do E2E ${mode}`);
  await dialog.getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-nghiep-vu\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  await expect(page.getByText('Trình duyệt. Nháp → Chờ duyệt.')).toBeVisible();
  const taskUrl = page.url();
  await enterAs(page, 'truongcs.cs5');
  await page.goto(taskUrl);
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  const approve = page.getByRole('dialog', { name: 'Duyệt phiếu' });
  await approve.getByLabel('Ghi chú').fill('Đồng ý');
  await approve.getByRole('button', { name: 'Duyệt', exact: true }).click();
  await expect(page.getByText('Chờ duyệt → Đã duyệt.')).toBeVisible();
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
  titles.hold = `Ticket E2E BL1 ${tag}`;
  titles.extend = `Ticket E2E BL2 ${tag}`;
  titles.resume = `Ticket E2E BL3 ${tag}`;
  await withDb(async (db) => {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, (values ('AFTERSALE'), ('BAO_LUU')) v (m) where b.code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [`PHE2EBLT${tag}`, `Phụ huynh E2E BLT ${tag}`, `09${tag.slice(-6)}41`],
    );
    await db.query(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
      [`HSE2EBLT${tag}`, `PHE2EBLT${tag}`, `Học sinh E2E BLT ${tag}`],
    );
    // Ghi danh Đang học có 5 giờ (dòng sổ giờ đầu kỳ); không cần lớp: bảo lưu không đòi lớp.
    await db.query(
      `insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
       select $1, s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code = $2`,
      [`GDE2E${tag}`, `HSE2EBLT${tag}`],
    );
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
       select e.id, e.branch_id, 'DAU_KY', 5 from app.enrollment e where e.code = $1`,
      [`GDE2E${tag}`],
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
      [titles.extend, 'DN_01_01'],
      [titles.resume, 'DN_01_02'],
    ] as const) {
      await db.query(
        `select app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', (select id from app.branch where code = 'CS5'),
           'title', $1::text, 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN', 'category_code', $4::text,
           'parent_id', (select id from app.parent where code = $2), 'student_id', (select id from app.student where code = $3)))`,
        [title, `PHE2EBLT${tag}`, `HSE2EBLT${tag}`, category],
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
    await db.query(`delete from app.hour_ledger where enrollment_id in ${enr}`, [`GDE2E${tag}`]);
    await db.query(`delete from app.enrollment_hold where enrollment_id in ${enr}`, [
      `GDE2E${tag}`,
    ]);
    await db.query('delete from app.enrollment where code = $1', [`GDE2E${tag}`]);
    await db.query('commit');
  });
});

test('Bảo lưu mới: phiếu duyệt và thực hiện → ghi danh Bảo lưu, giờ giữ nguyên', async ({
  page,
}) => {
  await runTask(page, titles.hold, 'Bảo lưu mới', '2');
  expect(await enrollmentState(`GDE2E${tag}`)).toEqual({ status: 'BAO_LUU', hours: '5.00' });
});

test('Gia hạn bảo lưu: nối tiếp bản đang chạy, ghi danh vẫn Bảo lưu, giờ giữ nguyên', async ({
  page,
}) => {
  await runTask(page, titles.extend, 'Gia hạn bảo lưu', '1');
  expect(await enrollmentState(`GDE2E${tag}`)).toEqual({ status: 'BAO_LUU', hours: '5.00' });
  const holds = await withDb(
    async (db) =>
      (
        await db.query<{ kind: string; status: string }>(
          `select kind_code as kind, status_code as status from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id
          where e.code = $1 order by h.created_at`,
          [`GDE2E${tag}`],
        )
      ).rows,
  );
  expect(holds.some((h) => h.kind === 'GIA_HAN' && h.status === 'DANG_BAO_LUU')).toBe(true);
});

test('Tiếp tục học: bảo lưu kết thúc, ghi danh về hàng chờ xếp lớp, giờ giữ nguyên', async ({
  page,
}) => {
  await runTask(page, titles.resume, 'Tiếp tục học', null);
  expect(await enrollmentState(`GDE2E${tag}`)).toEqual({ status: 'CHO_XEP_LOP', hours: '5.00' });
});
