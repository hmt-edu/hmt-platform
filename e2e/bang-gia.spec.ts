// CH-03 Bảng giá (theo gói): giá hiệu lực, chip Chưa có giá / Không bán, nhóm hiển thị, Thêm bảng giá mới (chọn tất cả theo bộ lọc, giá chung,
// giá riêng từng gói), Sale chỉ xem. Máy tính. Dữ liệu giả.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, expectAccessible, pickOption } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

const A = 'LC-SAT-K11';
const B = 'LC-SAT-K12';
const DV = 'DV-BGE2E';

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Cấu hình chỉ có bản máy tính.');
});

async function sql(query: string, params: unknown[] = []) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(query, params);
    await db.query('commit');
  } finally {
    await db.end();
  }
}
async function cleanup() {
  await sql(
    `delete from app.package_price where package_id in (select id from app.sales_package where code = any($1))`,
    [[A, B, DV]],
  );
  await sql(`delete from app.sales_package where code = any($1)`, [[A, B, DV]]);
}
test.beforeAll(async () => {
  await cleanup();
  await sql(
    `insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code) values
       ($1, 'Lớp chung SAT 11', 'LC', 'SAT', 'K11'), ($2, 'Lớp chung SAT 12', 'LC', 'SAT', 'K12')`,
    [A, B],
  );
  await sql(
    `insert into app.sales_package (code, name, package_type_code) values ($1, 'Dịch vụ thử giá', 'DV')`,
    [DV],
  );
});
test.afterAll(cleanup);

async function openList(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/cau-hinh/bang-gia');
  await expect(page.getByRole('heading', { level: 1, name: 'Bảng giá' })).toBeVisible();
}

test('Gói chưa có giá hiện chip Chưa có giá; dịch vụ không có online hiện Không bán; nhóm theo Loại, Môn, Khối', async ({
  page,
}) => {
  await openList(page);
  const table = page.getByRole('table', { name: 'Bảng giá' });
  await page.getByLabel('Tìm gói').fill('SAT');
  const row = table.getByRole('row', { name: new RegExp(A) });
  await expect(row.getByText('Chưa có giá')).toHaveCount(2);
  await expect(table.getByRole('button', { name: /Lớp chung/ }).first()).toBeVisible();
  await expect(table.getByRole('button', { name: /SAT/ }).first()).toBeVisible();
  await page.getByLabel('Tìm gói').fill(DV);
  const dv = table.getByRole('row', { name: new RegExp(DV) });
  await expect(dv.getByText('Chưa có giá')).toHaveCount(1);
  await expect(dv.getByText('Không bán', { exact: true })).toHaveCount(1);
  await expectAccessible(page);
});

test('Thêm bảng giá mới: chọn tất cả theo bộ lọc, giá chung, giá riêng một gói; lưu một lần', async ({
  page,
}) => {
  await openList(page);
  await page.getByRole('button', { name: 'Thêm bảng giá mới' }).click();
  const dialog = page.getByRole('dialog', { name: 'Thêm bảng giá mới' });
  await expect(dialog.getByRole('button', { name: 'Lưu bảng giá mới' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Môn' }), 'SAT');
  await dialog.getByRole('button', { name: 'Chọn tất cả theo bộ lọc' }).click();
  await expect(dialog.getByRole('button', { name: /Bỏ chọn \(2\)/ })).toBeVisible();
  await dialog.getByLabel('Giá offline chung').fill('250000');
  await dialog.getByLabel('Giá online chung').fill('200000');
  // Giá riêng gói B: offline 300.000 (online theo giá chung).
  await dialog.getByLabel(`Giá offline mới của ${B}`).fill('300000');
  await dialog.getByRole('button', { name: 'Lưu bảng giá mới' }).click();
  await expect(dialog).toHaveCount(0);
  await page.getByLabel('Tìm gói').fill('SAT');
  const table = page.getByRole('table', { name: 'Bảng giá' });
  await expect(table.getByRole('row', { name: new RegExp(A) })).toContainText('250.000 đ/giờ');
  await expect(table.getByRole('row', { name: new RegExp(A) })).toContainText('200.000 đ/giờ');
  await expect(table.getByRole('row', { name: new RegExp(B) })).toContainText('300.000 đ/giờ');
});

test('Giá hiệu lực theo ngày: ngày trước khi có giá thì quay về Chưa có giá; trùng ngày hiệu lực bị chặn', async ({
  page,
}) => {
  await openList(page);
  await page.getByRole('textbox', { name: 'Giá hiệu lực tại ngày' }).fill('01/01/2000');
  await page.getByLabel('Tìm gói').fill(A);
  await expect(page.getByRole('row', { name: new RegExp(A) }).getByText('Chưa có giá')).toHaveCount(
    2,
  );
  // Thêm lại giá cùng ngày hiệu lực hôm nay: DB chặn, hộp giữ nguyên và nêu lỗi.
  await page.getByRole('button', { name: 'Thêm bảng giá mới' }).click();
  const dialog = page.getByRole('dialog', { name: 'Thêm bảng giá mới' });
  await dialog.getByLabel('Tìm gói').fill(A);
  await dialog.getByLabel(`Chọn ${A}`).check();
  await dialog.getByLabel('Giá offline chung').fill('260000');
  await dialog.getByRole('button', { name: 'Lưu bảng giá mới' }).click();
  await expect(dialog.getByText(/đã có giá cho hình thức này từ ngày đó/)).toBeVisible();
});

test('Sale xem được bảng giá nhưng không có nút Thêm bảng giá mới', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/cau-hinh/bang-gia');
  await expect(page.getByRole('heading', { level: 1, name: 'Bảng giá' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thêm bảng giá mới' })).toHaveCount(0);
});
