// Thẻ D26 (Code D): TC-10, TC-11 Phiếu chi và TC-14 Số dư khách hàng, cỡ máy tính và điện thoại. Chỉ xem: không có nút Tạo, số tiền do máy chủ trả,
// nút «Ghi nhận đã chi» chỉ Kế toán (Trưởng cơ sở không thấy). Dữ liệu giả dựng bằng SQL (tắt kiểm khoá ngoại trong giao dịch dựng) rồi dọn sau bài.
// Luật R-TIEN-28, R-TIEN-33, R-TIEN-34, R-HT-01.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible, showAllColumns } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phiếu chi giả).');
test.describe.configure({ mode: 'serial' });

const MANAGER = 'truongcs.cs5';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
const mark = (project: string) => `E2EPC${tag(project)}`;

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, m: string) {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  await db.query('delete from app.payment_voucher where code = $1', [`PC-${m}`]);
  await db.query('delete from app.refund_request where ticket_ref = $1', [`DN-${m}`]);
  await db.query('delete from app.customer_balance_entry where note like $1', [`${m}%`]);
  await db.query('delete from app.parent where code = $1', [`${m}-P`]);
  await db.query('commit');
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const m = mark(testInfo.project.name);
  await withDb(async (db) => {
    await clear(db, m);
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const branch = (await db.query<{ id: string }>("select id from app.branch where code = 'CS5'"))
      .rows[0]!.id;
    const parent = (
      await db.query<{ id: string }>(
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả phiếu chi', '0900404001', $2) returning id",
        [`${m}-P`, branch],
      )
    ).rows[0]!.id;
    // Số dư: +1.000.000 (từ dừng học) và −200.000 (điều chỉnh) = 800.000.
    await db.query(
      `insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount, entry_date, note)
       values ($1, $2, 'TU_DUNG_HOC', 1000000, (now() at time zone 'Asia/Ho_Chi_Minh')::date, $3), ($1, $2, 'DIEU_CHINH', -200000, (now() at time zone 'Asia/Ho_Chi_Minh')::date, $4)`,
      [parent, branch, `${m} dừng học`, `${m} điều chỉnh`],
    );
    // Yêu cầu hoàn một phần 3 giờ: 594.000 trừ phí 10% = 534.600; phiếu chi đang Chờ chi.
    const refund = (
      await db.query<{ id: string }>(
        `insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, hours_refund, paid_amount, hours_used,
                                         unit_price_base, unit_price_net, base_amount, fee_percent, fee_amount, refund_amount, status_code, ticket_ref)
         values (gen_random_uuid(), gen_random_uuid(), $1, 'MOT_PHAN', 'KHAC', 3, 2200000, 2, 220000, 198000, 594000, 10, 59400, 534600, 'DA_DUYET', $2)
         returning id`,
        [branch, `DN-${m}`],
      )
    ).rows[0]!.id;
    await db.query(
      `insert into app.payment_voucher (code, refund_request_id, branch_id, parent_id, amount, status_code)
       values ($1, $2, $3, $4, 534600, 'CHO_CHI')`,
      [`PC-${m}`, refund, branch, parent],
    );
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, mark(testInfo.project.name)));
});

test('TC-10, TC-11: danh sách phiếu chi không có nút Tạo; bản ghi hiện bảng tính hoàn, Trưởng cơ sở không có nút ghi nhận chi', async ({
  page,
}, testInfo) => {
  const m = mark(testInfo.project.name);
  await enterAs(page, MANAGER);
  await page.goto('/crm/phieu-chi');
  await expect(page.getByRole('heading', { level: 1, name: 'Phiếu chi' })).toBeVisible();
  await page.getByRole('searchbox').fill(`PC-${m}`);
  await showAllColumns(page);
  await expect(page.getByText(`PC-${m}`).first()).toBeVisible();
  await expect(page.getByText('534.600').first()).toBeVisible();
  await expect(page.getByText('Chờ chi').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /^Tạo/ })).toHaveCount(0);
  await expectAccessible(page);
  await page
    .getByRole('link', { name: `PC-${m}` })
    .first()
    .click();
  // Tiêu đề bảng tính chỉ là chú thích ẩn của bảng (cỡ điện thoại hiện dạng thẻ): kiểm theo nội dung dòng tính.
  await expect(page.getByText('Phí xử lý').first()).toBeVisible();
  await expect(page.getByText('Số tiền hoàn').first()).toBeVisible();
  await expect(page.getByText('534.600').first()).toBeVisible();
  // R-HT-01, R-TIEN-34: chỉ Kế toán ghi nhận đã chi.
  await expect(page.getByRole('button', { name: 'Ghi nhận đã chi' })).toHaveCount(0);
  await expectAccessible(page);
});

test('TC-14: danh sách số dư khách hàng và lịch sử sổ của một phụ huynh', async ({
  page,
}, testInfo) => {
  const m = mark(testInfo.project.name);
  await enterAs(page, MANAGER);
  await page.goto('/crm/so-du-khach-hang');
  await expect(page.getByRole('heading', { level: 1, name: 'Số dư khách hàng' })).toBeVisible();
  await page.getByRole('searchbox').fill(`${m}-P`);
  await expect(page.getByText('Phụ huynh giả phiếu chi').first()).toBeVisible();
  await expect(page.getByText('800.000').first()).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('link', { name: 'Phụ huynh giả phiếu chi' }).first().click();
  await expect(page.getByText('Số dư hiện tại').first()).toBeVisible();
  await expect(page.getByText('Từ dừng học').first()).toBeVisible();
  await expect(page.getByText('Điều chỉnh').first()).toBeVisible();
  await expectAccessible(page);
});
