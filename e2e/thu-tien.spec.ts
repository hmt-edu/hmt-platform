// Ngày dựng theo GIỜ VIỆT NAM (cùng múi giờ với hàm công nợ) để bài không lệch quanh nửa đêm: CI chạy lúc 17:00 UTC là 00:00 giờ Việt Nam.
// Cụm Thu tiền: TC-08 Khoản tiền vào, TC-13 Công nợ (chỉ đọc). Dữ liệu giả dựng bằng SQL trực tiếp rồi dọn sau bài; Trưởng cơ sở CS5 xem trong cơ sở mình (cơ sở bật Bán hàng).
// Luật R-TIEN-01 (khoản tiền vào tự sinh, chỉ đọc), R-TIEN-07 (lịch đợt, quá hạn, sắp đến hạn), R-TIEN-26 (khoản âm là khoản đảo).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import {
  PASSWORD,
  enterAs,
  enterAsAdmin,
  expectAccessible,
  isPhone,
  pickOption,
  showAllColumns,
} from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

const MANAGER = 'truongcs.cs5';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
const mark = (project: string) => `E2ETC${tag(project)}`;

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
  const orders = `(select id from app.sales_order where code like $1)`;
  await db.query(`delete from app.money_in where order_id in ${orders}`, [`${m}-%`]);
  await db.query(`delete from app.receipt where order_id in ${orders}`, [`${m}-%`]);
  await db.query(`delete from app.sales_order_installment where order_id in ${orders}`, [`${m}-%`]);
  await db.query('delete from app.sales_order where code like $1', [`${m}-%`]);
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
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả thu tiền', '0900303001', $2) returning id",
        [`${m}-P`, branch],
      )
    ).rows[0]!.id;
    // O1: đợt 1 = 1.500.000 hạn 14 ngày trước, đợt 2 = 1.200.000 hạn 30 ngày sau; tiền vào ròng 1.200.000 (1.000.000 + 500.000 − 300.000 đảo).
    // O2: hai đợt 500.000, hạn sau 2 và 10 ngày, chưa đóng.
    const orders: [string, number, [number, number, number][]][] = [
      [
        `${m}-O1`,
        2700000,
        [
          [1, 1500000, -14],
          [2, 1200000, 30],
        ],
      ],
      [
        `${m}-O2`,
        1000000,
        [
          [1, 500000, 2],
          [2, 500000, 10],
        ],
      ],
    ];
    for (const [code, total, installments] of orders) {
      const order = (
        await db.query<{ id: string }>(
          `insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount)
           values ($1, $2, gen_random_uuid(), $3, 'DA_DUYET', (now() at time zone 'Asia/Ho_Chi_Minh')::date, $4) returning id`,
          [code, branch, parent, total],
        )
      ).rows[0]!.id;
      for (const [seq, amount, shift] of installments) {
        await db.query(
          `insert into app.sales_order_installment (order_id, branch_id, seq, due_days, amount, due_date)
           values ($1, $2, $3, 0, $4, (now() at time zone 'Asia/Ho_Chi_Minh')::date + $5::int)`,
          [order, branch, seq, amount, shift],
        );
      }
    }
    const moneyIn: [string, number, number][] = [
      [`${m}-O1`, 1000000, 5],
      [`${m}-O1`, 500000, 4],
      [`${m}-O1`, -300000, 2],
    ];
    let n = 0;
    for (const [orderCode, amount, ago] of moneyIn) {
      n += 1;
      const receipt = (
        await db.query<{ id: string }>(
          `insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, status_code, amount, payment_method_code, search_text)
           select $1, o.id, o.parent_id, o.branch_id, o.branch_id, 'DA_DUYET', abs($2::bigint), 'TIEN_MAT',
                  app.fold_text($1 || ' ' || o.code || ' phu huynh gia thu tien 0900303001')
             from app.sales_order o where o.code = $3 returning id`,
          [`PT-${m}-${n}`, amount, orderCode],
        )
      ).rows[0]!.id;
      // Khoản âm là khoản đảo (TC-09): không có phiếu thu, trỏ về khoản gốc số 1, có lý do.
      await db.query(
        `insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount, created_at, reversal_of, reason_code)
         select $1, case when $3::bigint > 0 then $2::uuid end, o.id, o.parent_id, o.branch_id, $3, now() - make_interval(days => $4::int),
                case when $3::bigint < 0 then (select id from app.money_in where code = $6) end,
                case when $3::bigint < 0 then 'NHAP_SAI_SO_TIEN' end
           from app.sales_order o where o.code = $5`,
        [`KTV-${m}-${n}`, receipt, amount, ago, orderCode, `KTV-${m}-1`],
      );
    }
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, mark(testInfo.project.name)));
});

async function search(page: Page, text: string) {
  await page.getByRole('searchbox').fill(text);
}

test('TC-08: sổ Khoản tiền vào không có nút Tạo, hiện khoản thu và khoản đảo, tìm theo mã đơn', async ({
  page,
}, testInfo) => {
  const m = mark(testInfo.project.name);
  await enterAs(page, MANAGER);
  await page.goto('/crm/khoan-tien-vao');
  await expect(page.getByRole('heading', { level: 1, name: 'Khoản tiền vào' })).toBeVisible();
  await search(page, `${m}-O1`);
  await expect(page.getByText('1–3 / 3')).toBeVisible();
  await expect(page.getByText(`KTV-${m}-1`).first()).toBeVisible();
  await expect(page.getByText(`Hoàn tác của KTV-${m}-1`).first()).toBeVisible();
  await expect(page.getByText('Tổng số tiền (theo bộ lọc): 1.200.000 đ')).toBeVisible();
  // Sổ chỉ đọc: không có nút Tạo (R-TIEN-01).
  await expect(page.getByRole('button', { name: /^Tạo/ })).toHaveCount(0);
  // TC-09, R-HT-01: Trưởng cơ sở không có nút Hoàn tác khoản tiền (chỉ Kế toán).
  await expect(page.getByRole('button', { name: 'Hoàn tác khoản tiền' })).toHaveCount(0);
  await expectAccessible(page);
});

// TC-09, R-TIEN-26, R-HT-01: Kế toán hoàn tác một khoản tiền (thêm khoản âm trỏ về khoản gốc, lý do bắt buộc); khoản đã hoàn tác không còn nút (chặn hoàn tác hai lần).
// Cờ money_reversal_enabled tắt mặc định: bài bật rồi trả lại như cũ. Bài đứng sau TC-08 trong cùng bộ dữ liệu (serial).
test('TC-13: công nợ theo đợt, quá hạn và sắp đến hạn; đợt đã đóng đủ không hiện', async ({
  page,
}, testInfo) => {
  const m = mark(testInfo.project.name);
  await enterAs(page, MANAGER);
  await page.goto('/crm/cong-no');
  await expect(page.getByRole('heading', { level: 1, name: 'Công nợ' })).toBeVisible();
  await search(page, m);
  // O1 đợt 1 (còn 300.000, quá hạn 14 ngày), O1 đợt 2 (1.200.000), O2 đợt 1 (sắp đến hạn), O2 đợt 2.
  await expect(page.getByText('1–4 / 4')).toBeVisible();
  await showAllColumns(page);
  await expect(page.getByText('Quá hạn 14 ngày').first()).toBeVisible();
  await expect(page.getByText('Sắp đến hạn').first()).toBeVisible();
  await expect(page.getByText('Tổng còn nợ (theo bộ lọc): 2.500.000 đ')).toBeVisible();
  const where = isPhone(page) ? page.getByRole('list') : page.getByRole('table');
  await expect(where.getByText('300.000').first()).toBeVisible();
  await expectAccessible(page);
});

// TC-09 chạy SAU TC-13: hoàn tác thêm một khoản âm vào đơn O1 (+500.000 còn nợ) nên bài công nợ (TC-13) phải đo xong trước, không thì tổng còn nợ lệch (bài serial theo thứ tự trong file).
test('TC-09: Kế toán hoàn tác khoản tiền, khoản đã hoàn tác không hoàn tác lại', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name === 'dien-thoai',
    'Hoàn tác khoản tiền chỉ ghi trên máy tính (Đ248).',
  );
  const m = mark(testInfo.project.name);
  const flag = async (value: string): Promise<string> =>
    withDb(async (db) => {
      const before =
        (
          await db.query<{ value: string }>(
            "select value from app.setting_def where key = 'money_reversal_enabled'",
          )
        ).rows[0]?.value ?? 'false';
      await db.query("update app.setting_def set value = $1 where key = 'money_reversal_enabled'", [
        value,
      ]);
      return before;
    });
  const before = await flag('true');
  try {
    await enterAsAdmin(page, 'ketoan.cs5');
    await page.goto('/crm/khoan-tien-vao');
    await search(page, `${m}-O1`);
    // Không đếm nút trên cả danh sách: lúc trang vừa mở, danh sách chưa lọc còn lẫn khoản của các bài chạy song song (thu nợ đầu kỳ, phiếu thu…),
    // đếm trước khi bộ lọc có hiệu lực làm số nút lệch (gốc lỗi chập chờn 19/11). Chỉ kiểm đúng dòng của bài này.
    const origin = new RegExp(`^KTV-${m}-2\\b`);
    const row = page.getByRole('row', { name: origin });
    await expect(row).toHaveCount(1);
    // Cột «Hoàn tác» nằm ngoài 8 cột mặc định (#570): bật mọi cột rồi mới tìm nút.
    await showAllColumns(page);
    const reverseButton = row.getByRole('button', { name: 'Hoàn tác khoản tiền' });
    await expect(reverseButton).toHaveCount(1);
    await reverseButton.click();
    const dialog = page.getByRole('alertdialog', { name: 'Hoàn tác khoản tiền' });
    await pickOption(page, dialog.getByRole('combobox'), 'Nhập sai số tiền');
    await dialog.getByRole('button', { name: 'Hoàn tác', exact: true }).click();
    await expect(page.getByText('Đã hoàn tác khoản tiền.').first()).toBeVisible();
    // Khoản âm mới trỏ về khoản gốc; khoản gốc không còn nút Hoàn tác (không đảo hai lần).
    await expect(page.getByText(`Hoàn tác của KTV-${m}-2`).first()).toBeVisible();
    await expect(page.getByRole('row', { name: origin })).toHaveCount(1);
    await expect(
      page.getByRole('row', { name: origin }).getByRole('button', { name: 'Hoàn tác khoản tiền' }),
    ).toHaveCount(0);
  } finally {
    await flag(before);
  }
});
