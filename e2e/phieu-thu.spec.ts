// TC-02, TC-03 Phiếu thu: Sale tạo phiếu nháp từ đơn Đã duyệt, sửa, trình; Trưởng cơ sở duyệt (chuyển Kế toán); huỷ phiếu. Máy tính (điện thoại chỉ đọc, Đ248).
// Dữ liệu giả dựng bằng don-hang-seed.ts (seedOrders).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import {
  PASSWORD,
  DOMAIN,
  enterAs,
  enterAsAdmin,
  expectAccessible,
  isPhone,
  pickOption,
  showAllTimeline,
} from './helpers';
import { DB_URL, clearMark, receiptSetupOf, seedOrders, type SeededOrders } from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededOrders;
let receiptUrl = '';
let receipt2Url = '';

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  seeded = await seedOrders(setup);
  await setManager(setup.sale, setup.manager);
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await clearMark(setup.mark);
  await setManager(setup.sale, null);
});

/** Gán (hoặc bỏ) Quản lý trực tiếp của tài khoản giả: phiếu thu đi qua bước quản lý nên người lập cần có quản lý (R-HT-06). */
async function setManager(account: string, manager: string | null) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `update app.user_account set manager_id = (select id from app.user_account where login_name = $2)
        where login_name = $1`,
      [`${account}@${DOMAIN}`, manager === null ? null : `${manager}@${DOMAIN}`],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Phiếu thu chỉ ghi trên máy tính (Đ248).');
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await page.getByRole('table', { name: 'Đơn hàng' }).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

// Q-138: hộp "Tạo phiếu thu" gợi ý số tiền từ phần "còn thu được" của tab Thanh toán (tải bất đồng bộ). Chờ dữ liệu đó về trước khi bấm
// "Tạo phiếu thu", để bài không chập chờn khi dữ liệu về chậm (anh muốn người dùng tự điền số tiền nên không đổi mã màn).
async function openOrderForReceipt(page: Page, account: string, code: string) {
  const loaded = page.waitForResponse((r) => r.url().includes('order_payment_summary') && r.ok());
  await openOrder(page, account, code);
  await loaded;
}

test('Sale tạo phiếu thu nháp từ đơn Đã duyệt, sửa ghi chú, trình quản lý', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await openOrderForReceipt(page, setup.sale, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await expect(dialog.getByRole('button', { name: 'Tạo phiếu nháp' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await expect(dialog.getByLabel('Số tiền')).not.toHaveValue('');
  await dialog.getByLabel('Số tiền').fill('1000000');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receiptUrl = new URL(page.url()).pathname;
  await expect(page.getByRole('heading', { level: 2, name: /^PT-/ })).toBeVisible();
  await expect(page.getByText('1.000.000 đ').first()).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByRole('textbox', { name: 'Ghi chú', exact: true }).fill('Thu đợt đầu');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu phiếu thu.').first()).toBeVisible();
  await expect(page.getByText('Thu đợt đầu')).toBeVisible();
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ quản lý duyệt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình quản lý' })).toHaveCount(0);
  // Cột phải chuẩn "Ghi chú & hoạt động" (Q-52): sự kiện của phiếu là các mục dòng thời gian, không còn nhãn "Lịch sử xử lý".
  const timeline = page.getByRole('region', { name: 'Ghi chú & hoạt động' });
  // Dòng thời gian mặc định tab Ghi chú: sự kiện hệ thống xem ở «Tất cả».
  await timeline.getByRole('button', { name: 'Tất cả', exact: true }).click();
  await expect(timeline.getByText('Tạo phiếu thu', { exact: true })).toBeVisible();
  await expect(timeline.getByText('Trình quản lý duyệt', { exact: true })).toBeVisible();
  await expect(page.getByText('Lịch sử xử lý')).toHaveCount(0);
  // Bản in biên nhận (TC-07): nhãn CHỜ DUYỆT, số tiền, số điện thoại chỉ che ở bản in.
  await page.getByRole('button', { name: 'In biên nhận' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}\/in$/);
  const sheet = page.getByRole('article', { name: 'BIÊN NHẬN' });
  await expect(sheet.getByText('CHỜ DUYỆT')).toBeVisible();
  await expect(sheet.getByText('1.000.000 đ')).toBeVisible();
  await expect(sheet.getByText(/\d{4} \*\*\* \d{3}/)).toBeVisible();
  await expectAccessible(page);
});

test('Trưởng cơ sở duyệt phiếu: chuyển Kế toán, không còn nút Duyệt cho quản lý', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.manager);
  await page.goto(receiptUrl);
  await expect(
    page.getByText('Phiếu chờ').or(page.getByText(/Đã trình, chờ quản lý duyệt/)),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' })).toHaveCount(0);
});

test('Phiếu bị kế toán từ chối (Q-49, Q-58): Trình lại hỏi xác nhận có dòng "đi từ bước quản lý"; Sửa thì Lưu, Huỷ ở tiêu đề và nút trình khoá', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  // Dựng "kế toán từ chối" bằng cơ sở dữ liệu: phiếu về Nháp, sự kiện Từ chối từ bước Chờ kế toán (chưa có sự kiện Sửa sau đó).
  const id = receiptUrl.split('/').pop() ?? '';
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `update app.receipt set status_code = 'NHAP', approval_route = null, assigned_approver_id = null, submitted_at = null, submitted_by = null
        where id = $1::uuid`,
      [id],
    );
    await db.query(
      `insert into app.receipt_event (receipt_id, branch_id, event_code, from_status, to_status, note)
       select id, branch_id, 'TU_CHOI', 'CHO_KE_TOAN', 'NHAP', 'Sai chứng từ' from app.receipt where id = $1::uuid`,
      [id],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
  await enterAs(page, setup.sale);
  await page.goto(receiptUrl);
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Trình lại' }).click();
  const dialog = page.getByRole('alertdialog', { name: /^Trình lại phiếu thu PT-/ });
  await expect(dialog.getByText('Phiếu thu chưa sửa từ lần bị từ chối. Vẫn trình?')).toBeVisible();
  await expect(dialog.getByText(/\(Kế toán\), lý do Sai chứng từ/)).toBeVisible();
  await expect(dialog.getByText(/Trình lại sẽ đi từ bước quản lý duyệt\./)).toBeVisible();
  await dialog.getByRole('button', { name: 'Quay lại sửa' }).click();
  await expect(dialog).toHaveCount(0);
  // Q-77: không còn khối đỏ "Phiếu bị từ chối"; lý do từ chối nằm ở dòng thời gian bên phải.
  await expect(page.getByRole('status').filter({ hasText: 'Phiếu bị từ chối' })).toHaveCount(0);
  await showAllTimeline(page);
  await expect(page.getByRole('complementary').getByText(/Sai chứng từ/)).toBeVisible();
  // Đang sửa: Lưu (nút chính), Huỷ, Hành động ở tiêu đề; nút Trình lại khoá kèm lời nhắc.
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Huỷ', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình lại' })).toBeDisabled();
  await expect(page.getByText('Lưu hoặc Huỷ rồi mới trình quản lý.')).toBeVisible();
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
});

test('Người lập huỷ phiếu chưa duyệt: chọn lý do, phiếu về Huỷ và chỉ còn xem', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.sale);
  await page.goto(receiptUrl);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ phiếu thu' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Huỷ phiếu thu' })).toBeVisible();
  await dialog.getByLabel('Lý do huỷ').click();
  await page.getByRole('option', { name: 'Sai số tiền' }).click();
  await dialog.getByRole('button', { name: 'Huỷ phiếu thu' }).click();
  await expect(page.getByText(/Phiếu đã huỷ: Sai số tiền/)).toBeVisible();
  // Canvas TC02_huy: «Lý do huỷ» là một dòng của khối thông tin.
  await expect(page.locator('dt', { hasText: /^Lý do huỷ$/ })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toHaveCount(0);
  void isPhone;
});

// Q-100, TC-05: Kế toán duyệt phiếu thu. Phiếu thứ hai (số tiền nhỏ, phiếu đầu đã huỷ ở bài trên) đi hết đường: Sale trình, Trưởng cơ sở duyệt, rồi
// Kế toán duyệt thì hệ thống sinh khoản tiền vào (R-TIEN-01); Admin cũng có nút Duyệt (R-HT-01, 26/11). Kế toán và Admin giả riêng của file này.
const ACCOUNTANT = 'ketoan.cs5';
const ADMIN = 'quantri.cs1';
const SECOND_AMOUNT = '200000';

test('Phiếu thứ hai: Sale tạo và trình quản lý', async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  const setup = receiptSetupOf(testInfo.project.name);
  await openOrderForReceipt(page, setup.sale, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await dialog.getByLabel('Số tiền').fill(SECOND_AMOUNT);
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receipt2Url = new URL(page.url()).pathname;
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ quản lý duyệt/)).toBeVisible();
});

// Thẻ mới cho Trưởng cơ sở: cùng một thẻ thì phiên Sale còn trong bộ nhớ, đổi tài khoản không đè được.
test('Phiếu thứ hai: Trưởng cơ sở duyệt chuyển Kế toán', async ({ page }, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.manager);
  await page.goto(receipt2Url);
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});

test('Admin có nút Duyệt phiếu thu ở bước Kế toán (R-HT-01)', async ({ page }) => {
  await enterAsAdmin(page, ADMIN);
  await page.goto(receipt2Url);
  await expect(page.getByRole('heading', { level: 2, name: /^PT-/ })).toBeVisible();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
  // Chỉ kiểm có nút, không bấm: bài sau dùng lại phiếu này cho Kế toán duyệt.
  await expect(page.getByRole('button', { name: 'Duyệt phiếu thu' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' })).toHaveCount(0);
});

test('Kế toán duyệt phiếu: phiếu Đã duyệt và khoá, sinh đúng một khoản tiền vào cùng số tiền', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto(receipt2Url);
  await expect(page.getByRole('heading', { level: 2, name: /^PT-/ })).toBeVisible();
  const receiptId = receipt2Url.split('/').pop() ?? '';
  const moneyIn = async () => {
    const db = new pg.Client({ connectionString: DB_URL });
    await db.connect();
    try {
      const r = await db.query<{ n: string; total: string }>(
        'select count(*)::text as n, coalesce(sum(amount), 0)::text as total from app.money_in where receipt_id = $1::uuid',
        [receiptId],
      );
      return r.rows[0];
    } finally {
      await db.end();
    }
  };
  // Trước khi duyệt chưa có khoản tiền vào.
  expect((await moneyIn())?.n).toBe('0');
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText('Đã duyệt phiếu thu, tiền đã ghi nhận.').first()).toBeVisible();
  await expect(page.getByText(/Phiếu đã duyệt và khoá\. Tiền đã ghi nhận \(.+\)\./)).toBeVisible();
  // So canvas TC02_duyet: phiếu Đã duyệt hiện «Duyệt bởi» kèm ngày.
  await expect(page.getByText('Duyệt bởi', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt phiếu thu' })).toHaveCount(0);
  const after = await moneyIn();
  expect(after?.n).toBe('1');
  expect(after?.total).toBe(SECOND_AMOUNT);
});

// R-V2-12 (Q-114, Q-117): Sale chưa có quản lý trực tiếp vẫn gửi được phiếu thu; phiếu đi tới Trưởng cơ sở rồi Kế toán.
let receipt3Url = '';

test('R-V2-12: Sale chưa có quản lý gửi phiếu thu, phiếu chờ Trưởng cơ sở', async ({
  page,
}, testInfo) => {
  test.setTimeout(90_000);
  const setup = receiptSetupOf(testInfo.project.name);
  await setManager(setup.sale, null);
  await openOrderForReceipt(page, setup.sale, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Tạo phiếu thu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo phiếu thu' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Hình thức' }), 'Tiền mặt');
  await dialog.getByLabel('Số tiền').fill('100000');
  await dialog.getByRole('button', { name: 'Tạo phiếu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/phieu-thu\/[0-9a-f-]{36}$/);
  receipt3Url = new URL(page.url()).pathname;
  await page.getByRole('button', { name: 'Trình quản lý' }).click();
  await expect(page.getByText(/Đã trình, chờ Trưởng cơ sở duyệt/)).toBeVisible();
});

test('R-V2-12: Trưởng cơ sở duyệt phiếu chờ Trưởng cơ sở, chuyển Kế toán', async ({
  page,
}, testInfo) => {
  const setup = receiptSetupOf(testInfo.project.name);
  await enterAs(page, setup.manager);
  await page.goto(receipt3Url);
  await page.getByRole('button', { name: 'Duyệt (chuyển Kế toán)' }).click();
  await page.getByRole('dialog').getByRole('checkbox').check();
  await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận duyệt' }).click();
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});
