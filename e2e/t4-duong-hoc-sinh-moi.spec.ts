// T4: đường đi trọn của một học sinh MỚI bằng trình duyệt, một spec nối tiếp (máy tính, dữ liệu giả):
// lead → cơ hội → L8 → đơn hàng → trình, duyệt → phiếu thu → kế toán duyệt (ghi danh tự sinh) → xếp lớp → chốt buổi → giáo viên điểm danh, nhận xét → Done.
// Bước nào hiện chưa bấm được bằng giao diện hoặc chỉ để dựng dữ liệu thì dùng SQL qua pg và GHI RÕ bằng chữ "TẮT" trong tên bước hay chú thích.
// Dựng từng đoạn: đoạn 1 (lead đến đơn Nháp), đoạn 2 (trình, duyệt đơn, phiếu thu, kế toán duyệt, ghi danh Chờ xếp lớp); đoạn sau thêm dần.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, pickOption } from './helpers';
import { DB_URL } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dữ liệu giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Đường T4 làm trên máy tính.');
});

const SALE = 'sale.cs5';
const MANAGER = 'truongcs.cs5';
const ACCOUNTANT = 'ketoan.cs5';
const TAG = `T4${Date.now().toString(36).slice(-5).toUpperCase()}`;
const PARENT = `Chị ${TAG}`;
const STUDENT = `Em ${TAG}`;
const PHONE = `09${String(Date.now()).slice(-8)}`;

const state = { leadId: '', oppId: '', orderId: '', orderCode: '', receiptUrl: '' };

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

test('10. Sale tạo phiếu thu từ đơn Đã duyệt (số tiền gợi ý = còn thu được), trình quản lý (TC-03)', async ({
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
  await expect(dialog.getByLabel('Số tiền')).not.toHaveValue('');
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
  await expect(page.getByText(/Quản lý đã duyệt, chờ Kế toán duyệt/)).toBeVisible();
});

test('12. Kế toán duyệt phiếu thu: sinh khoản tiền vào, ghi danh Chờ xếp lớp, cơ hội tự lên L8C (R-CRM-17)', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await enterAsAdmin(page, ACCOUNTANT);
  await page.goto(state.receiptUrl);
  await page.getByRole('button', { name: 'Duyệt phiếu thu' }).click();
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
