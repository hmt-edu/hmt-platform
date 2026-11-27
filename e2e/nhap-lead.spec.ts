// P3f-2: hộp Nhập lead từ file (TS-04): tải CSV, ghép cột, xem trước, nhập. File thử dựng ngay trong bài (dữ liệu giả, có BOM,
// dấu ";" như Excel tiếng Việt). Lead nhập được tìm bằng dấu riêng của từng dự án rồi dọn.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { clearMark } from './co-hoi-seed';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dọn lead giả).');
test.describe.configure({ mode: 'serial' });

const SETUPS = {
  'may-tinh': { mark: 'E2ENLMT', account: 'sale.cs5', phone: 410 },
  'dien-thoai': { mark: 'E2ENLDT', account: 'cskh.cs5', phone: 420 },
} as const;
const setupOf = (project: string) => SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

async function clean(mark: string) {
  await clearMark(mark);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    // Nhật ký nhập chỉ thêm, không xoá được qua đường thường: dọn bằng quyền chủ DB trong giao dịch giả lập.
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query('delete from app.lead_import_log where file_name like $1', [`%${mark}%`]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => clean(setupOf(testInfo.project.name).mark));
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => clean(setupOf(testInfo.project.name).mark));

const phoneOf = (base: number, i: number) =>
  `0${String(((Date.now() % 1e6) * 1000 + base + i) % 1e9).padStart(9, '0')}`;

const BOM = String.fromCharCode(0xfeff);

/** CSV giả: dòng 2, 3 hợp lệ; dòng 4 trùng SĐT dòng 2; dòng 5 SĐT sai; dòng 6 thiếu tên phụ huynh. Có cột thừa "Mã nội bộ". */
function csv(mark: string, base: number): { name: string; content: string; phones: string[] } {
  const p = [0, 1, 2, 3].map((i) => phoneOf(base, i));
  const lines = [
    'Họ tên phụ huynh;Số điện thoại;Tên học sinh;Nguồn;Kênh;Ghi chú KH;Mã nội bộ',
    `Chị ${mark} Một;${p[0]};Em A;FACEBOOK_ADS;FACEBOOK_ADS_LEAD_FORM;Hỏi lớp 9;X1`,
    `Chị ${mark} Hai;${p[1]};;FACEBOOK_ADS;FACEBOOK_ADS_LEAD_FORM;;X2`,
    `Chị ${mark} Trùng;${p[0]};;FACEBOOK_ADS;FACEBOOK_ADS_LEAD_FORM;;X3`,
    `Chị ${mark} Sai;0903 22 44;;FACEBOOK_ADS;FACEBOOK_ADS_LEAD_FORM;;X4`,
    `;${p[2]};;FACEBOOK_ADS;FACEBOOK_ADS_LEAD_FORM;;X5`,
  ];
  return {
    name: `leads-${mark}.csv`,
    content: `${BOM}${lines.join('\r\n')}\r\n`,
    phones: p.map(String),
  };
}

async function openImport(page: Page, account: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/lead');
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  await page.getByRole('button', { name: 'Nhập', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Nhập lead từ file' });
  await expect(dialog).toBeVisible();
  return dialog;
}

test('Nhập CSV: tải file, ghép cột (báo cột thừa), xem trước đếm đúng, lọc theo ô đếm, nhập rồi thấy lead mới', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const file = csv(setup.mark, setup.phone);
  const dialog = await openImport(page, setup.account);
  // Bước 1: chưa có file thì Tiếp mờ.
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
  const downloading = page.waitForEvent('download');
  await dialog.getByRole('button', { name: 'Tải file mẫu' }).click();
  expect((await downloading).suggestedFilename()).toBe('mau-nhap-lead.csv');
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: file.name,
    mimeType: 'text/csv',
    buffer: Buffer.from(file.content, 'utf8'),
  });
  await expect(dialog.getByText(`${file.name} · 5 dòng · 7 cột`)).toBeVisible();
  await dialog.getByRole('button', { name: 'Tiếp' }).click();
  // Bước 2: đoán cột theo tên; "Mã nội bộ" chưa ghép nên báo không nhập.
  await expect(dialog.getByText(/1 cột chưa ghép/)).toContainText('Mã nội bộ');
  await expect(dialog.getByText('Chưa ghép', { exact: true })).toHaveCount(1);
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Tiếp' }).click();
  // Bước 3: hai hợp lệ, một trùng SĐT, hai lỗi.
  const tiles = dialog.getByRole('button', { pressed: false });
  await expect(tiles.filter({ hasText: 'dòng hợp lệ' })).toContainText('2');
  await expect(tiles.filter({ hasText: 'dòng trùng SĐT' })).toContainText('1');
  await expect(tiles.filter({ hasText: 'dòng lỗi' })).toContainText('2');
  const table = dialog.getByRole('table', { name: 'Kết quả từng dòng' });
  await expect(table.getByRole('row')).toHaveCount(6);
  await tiles.filter({ hasText: 'dòng lỗi' }).click();
  await expect(table.getByRole('row')).toHaveCount(3);
  await expect(table.getByText('Nhập họ tên phụ huynh.')).toBeVisible();
  await dialog.getByRole('button', { name: /dòng lỗi/ }).click();
  await expect(table.getByRole('row')).toHaveCount(6);
  // Nhập: chỉ hai dòng hợp lệ được tạo.
  await dialog.getByRole('button', { name: 'Nhập', exact: true }).click();
  await expect(
    page.getByText('Đã nhập 2 lead. Bỏ qua 1 dòng trùng SĐT, 2 dòng lỗi.').first(),
  ).toBeVisible();
  await expect(dialog).toBeHidden();
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await expect(page.getByText(`Chị ${setup.mark} Một`).first()).toBeVisible();
  await expect(page.getByText(`Chị ${setup.mark} Hai`).first()).toBeVisible();
  await expect(page.getByText(`Chị ${setup.mark} Trùng`)).toHaveCount(0);
});

test('File dấu phẩy, thiếu cột bắt buộc: báo ở bước ghép cột, ghép tay xong mới Tiếp được', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const dialog = await openImport(page, setup.account);
  const content =
    `Tên;Cột lạ\n`.replace(';', ',').replace('\n', '\n') +
    `Chị ${setup.mark} Ba,${phoneOf(setup.phone, 9)}\n`;
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: `thieu-${setup.mark}.csv`,
    mimeType: 'text/csv',
    buffer: Buffer.from(content, 'utf8'),
  });
  await dialog.getByRole('button', { name: 'Tiếp' }).click();
  await expect(dialog.getByText(/Chưa ghép cột bắt buộc: SĐT/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
  await dialog.getByRole('combobox', { name: 'Trường cho cột Cột lạ' }).click();
  await page.getByRole('option', { name: 'SĐT', exact: true }).click();
  await expect(dialog.getByText(/Chưa ghép cột bắt buộc/)).toHaveCount(0);
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeEnabled();
});

test('File quá số dòng tối đa (500): chặn ngay ở bước tải file, nêu số dòng', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const dialog = await openImport(page, setup.account);
  const rows = Array.from(
    { length: 501 },
    (_, i) => `Chị ${setup.mark} ${i},0900${String(i).padStart(6, '0')}`,
  );
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: `nhieu-${setup.mark}.csv`,
    mimeType: 'text/csv',
    buffer: Buffer.from(`Họ tên,SĐT\n${rows.join('\n')}\n`, 'utf8'),
  });
  await expect(dialog.getByText(/File có 501 dòng, tối đa 500 dòng mỗi lần nhập/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
});

test('File hỏng (ngoặc kép không đóng) và file trống: báo lỗi tiếng Việt, không vào bước ghép cột', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const dialog = await openImport(page, setup.account);
  const input = dialog.getByLabel('Chọn file CSV');
  await input.setInputFiles({
    name: 'hong.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('a,b\n"x,y\n', 'utf8'),
  });
  await expect(dialog.getByText(/chưa đóng ngoặc kép/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
  await input.setInputFiles({
    name: 'trong.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('', 'utf8'),
  });
  await expect(dialog.getByText(/File trống/)).toBeVisible();
});
