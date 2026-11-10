// QT-18 Nhập dữ liệu (màn Nhập, chỉ Admin): chọn loại, tải file CSV, xem trước từng dòng, nạp thật, tải dòng lỗi. Dữ liệu giả.
// Nạp Phụ huynh chạy thật (hàm DB). Nạp Người dùng cần Edge Function `import-users`, không chạy ở môi trường kiểm thử: chỉ kiểm bước tải file.
import { readFileSync } from 'node:fs';
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

const stamp = Date.now().toString().slice(-7);
const csv = [
  'ma_cu,ho_ten,sdt,sdt_2,ho_ten_2,dia_chi,co_so',
  `NAPTEST${stamp}A,Chị Nạp Một,09${stamp}1,,,,CS5`,
  `NAPTEST${stamp}B,Chị Nạp Hai,09${stamp}2,,,,CS5`,
  `NAPTEST${stamp}C,Chị Nạp Ba,09${stamp}2,,,,CS5`,
  `NAPTEST${stamp}D,Chị Nạp Bốn,091,,,,CS5`,
].join('\n');

test('Nhập Phụ huynh: xem trước đếm đúng, lọc, nạp thật, tải dòng lỗi; nạp lại cùng file ra toàn bỏ qua', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/nhap-du-lieu');
  await expect(page.getByRole('heading', { level: 1, name: 'Nhập dữ liệu' })).toBeVisible();
  // Q-209: bảng đủ 8 loại theo thứ tự nạp; loại chưa có hàm nạp là "Sắp có", nút Nhập khoá; loại sẵn sàng có Tải file mẫu.
  const kinds = page.getByRole('table', { name: 'Loại dữ liệu nạp' });
  await expect(kinds.getByRole('row')).toHaveCount(9);
  await expect(page.getByRole('button', { name: 'Nhập lớp' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Nhập ghi danh' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Tải file mẫu phụ huynh' })).toBeEnabled();
  await expectAccessible(page);
  await page.getByRole('button', { name: 'Nhập phụ huynh' }).click();
  const dialog = page.getByRole('dialog', { name: 'Nhập phụ huynh từ file' });
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: 'phu-huynh.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from(csv, 'utf8'),
  });
  await expect(dialog.getByText('phu-huynh.csv · 4 dòng · 7 cột')).toBeVisible();
  await dialog.getByRole('button', { name: 'Tiếp' }).click();

  // Hai hợp lệ, một trùng SĐT với dòng trước, một lỗi (SĐT thiếu số).
  const tiles = dialog.getByRole('button', { pressed: false });
  await expect(tiles.filter({ hasText: 'dòng hợp lệ' })).toContainText('2');
  await expect(tiles.filter({ hasText: 'dòng trùng' })).toContainText('1');
  await expect(tiles.filter({ hasText: 'dòng lỗi' })).toContainText('1');
  const table = dialog.getByRole('table', { name: 'Kết quả từng dòng' });
  await expect(table.getByRole('row')).toHaveCount(5);
  await tiles.filter({ hasText: 'dòng lỗi' }).click();
  await expect(table.getByRole('row')).toHaveCount(2);
  // Không in họ tên hay SĐT: chỉ chữ cái đầu.
  await expect(dialog.getByText('Chị Nạp')).toHaveCount(0);
  await expect(dialog.getByText(`09${stamp}`)).toHaveCount(0);

  await dialog.getByRole('button', { name: 'Nạp', exact: true }).click();
  const done = page.getByRole('dialog', { name: 'Đã nạp phụ huynh' });
  await expect(done.getByText(/dòng trùng bỏ qua/)).toContainText(
    '2 dòng đã nạp, 1 dòng trùng bỏ qua, 1 dòng lỗi',
  );
  const download = page.waitForEvent('download');
  await done.getByRole('button', { name: /Tải dòng lỗi và trùng \(2\)/ }).click();
  const path = await (await download).path();
  const errorFile = readFileSync(path, 'utf8');
  expect(errorFile).toContain('dong,ma_cu,ho_ten,sdt,sdt_2,ho_ten_2,dia_chi,co_so,ket_qua,ly_do');
  expect(errorFile).toContain(`NAPTEST${stamp}D`);
  expect(errorFile).toContain('Lỗi');
  expect(errorFile).toContain('Trùng');
  await done.getByRole('button', { name: 'Xong' }).click();

  // Nạp lại đúng file: không còn dòng hợp lệ, không ghi đè.
  await page.getByRole('button', { name: 'Nhập phụ huynh' }).click();
  const again = page.getByRole('dialog', { name: 'Nhập phụ huynh từ file' });
  await again.getByLabel('Chọn file CSV').setInputFiles({
    name: 'phu-huynh.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from(csv, 'utf8'),
  });
  await again.getByRole('button', { name: 'Tiếp' }).click();
  await expect(
    again.getByRole('button', { pressed: false }).filter({ hasText: 'dòng hợp lệ' }),
  ).toContainText('0');
  await expect(again.getByText('Chưa có dòng hợp lệ nào để nạp.')).toBeVisible();
  await expect(again.getByRole('button', { name: 'Nạp', exact: true })).toBeDisabled();
});

test('Nhập Người dùng: file thiếu cột bắt buộc bị chặn ngay ở bước tải file, nêu tên cột', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/nhap-du-lieu');
  await page.getByRole('button', { name: 'Nhập người dùng' }).click();
  const dialog = page.getByRole('dialog', { name: 'Nhập người dùng từ file' });
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: 'nguoi-dung.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('username,ho_ten,ghi_chu\nannv,Nguyễn Văn An,x\n', 'utf8'),
  });
  await expect(dialog.getByText(/File thiếu cột bắt buộc/)).toContainText(
    'vai_tro, co_so_truy_cap',
  );
  await expect(dialog.getByText(/cột không thuộc loại này/)).toContainText('ghi_chu');
  await expect(dialog.getByRole('button', { name: 'Tiếp' })).toBeDisabled();
});

// Nạp Cơ hội chạy thật (hàm DB). Người phụ trách tra theo tên đăng nhập (legacy_ref của tài khoản): gán trước cho tài khoản giả sale.cs5.
test('Nhập Cơ hội: báo cáo theo giai đoạn, dòng thiếu thông tin em vẫn nạp có dấu, dòng lỗi báo đúng; nạp lại ra toàn bỏ qua', async ({
  page,
}) => {
  const db = new pg.Client({ connectionString: process.env.DB_URL ?? '' });
  await db.connect();
  try {
    await db.query(
      `update app.user_account set legacy_ref = 'sale.cs5.e2e' where login_name = $1`,
      [`sale.cs5@${DOMAIN}`],
    );
  } finally {
    await db.end();
  }
  const co = (n: number, extra: Record<string, string> = {}) => {
    const base: Record<string, string> = {
      ma_cu: `09${stamp}${n}`,
      ngay_tao: '2026-09-15',
      ho_ten_ph: `Chị Cơ Hội ${n}`,
      sdt_ph: `09${stamp}${n}`,
      sdt_2: '',
      danh_sach_em: 'Em Thử',
      nam_sinh: '2013',
      khoi: '7',
      truong: 'THCS Thử',
      dia_chi: '',
      nhu_cau: 'Học Toán',
      nguon_goc: 'Marketing',
      nguon: 'Hotline',
      medium: '',
      co_so: 'CS5',
      nguoi_phu_trach: 'sale.cs5.e2e',
      nguoi_phu_trach_goc: '',
      tinh_trang_cu: 'Đã hẹn',
      giai_doan: 'L2',
      nhom_con: '',
      ghi_chu: '',
      ...extra,
    };
    return Object.values(base).join(',');
  };
  const header =
    'ma_cu,ngay_tao,ho_ten_ph,sdt_ph,sdt_2,danh_sach_em,nam_sinh,khoi,truong,dia_chi,nhu_cau,nguon_goc,nguon,medium,co_so,nguoi_phu_trach,nguoi_phu_trach_goc,tinh_trang_cu,giai_doan,nhom_con,ghi_chu';
  const file = [
    header,
    co(1), // L2 hợp lệ
    co(2, { giai_doan: 'L5', danh_sach_em: '', nam_sinh: '' }), // L5 thiếu thông tin em: vẫn nạp, có dấu
    co(3, { nguoi_phu_trach: 'khong.co.tai.khoan' }), // lỗi: người phụ trách
  ].join('\n');
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/nhap-du-lieu');
  await page.getByRole('button', { name: 'Nhập cơ hội' }).click();
  const dialog = page.getByRole('dialog', { name: 'Nhập cơ hội từ file' });
  await dialog.getByLabel('Chọn file CSV').setInputFiles({
    name: 'co-hoi.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from(file, 'utf8'),
  });
  await dialog.getByRole('button', { name: 'Tiếp' }).click();
  const tiles = dialog.getByRole('button', { pressed: false });
  await expect(tiles.filter({ hasText: 'dòng hợp lệ' })).toContainText('2');
  await expect(tiles.filter({ hasText: 'dòng lỗi' })).toContainText('1');
  const report = dialog.getByLabel('Báo cáo cơ hội');
  await expect(report).toContainText('L2: 1');
  await expect(report).toContainText('L5: 1');
  await expect(report.getByText(/dòng thiếu thông tin em/)).toContainText('1');
  // Không in họ tên, SĐT; cảnh báo nêu rõ thiếu thông tin em.
  await expect(dialog.getByText('Chị Cơ Hội')).toHaveCount(0);
  await expect(dialog.getByText(/Thiếu thông tin em \(dữ liệu cũ\)/)).toBeVisible();
  await dialog.getByRole('button', { name: 'Nạp', exact: true }).click();
  const done = page.getByRole('dialog', { name: 'Đã nạp cơ hội' });
  await expect(done.getByText(/dòng trùng bỏ qua/)).toContainText(
    '2 dòng đã nạp, 0 dòng trùng bỏ qua, 1 dòng lỗi',
  );
  await expect(done.getByLabel('Báo cáo cơ hội')).toContainText('L5: 1');
  await done.getByRole('button', { name: 'Xong' }).click();
  // Nạp lại đúng file: hai dòng đã nạp báo trùng, còn dòng lỗi vẫn lỗi.
  await page.getByRole('button', { name: 'Nhập cơ hội' }).click();
  const again = page.getByRole('dialog', { name: 'Nhập cơ hội từ file' });
  await again.getByLabel('Chọn file CSV').setInputFiles({
    name: 'co-hoi.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from(file, 'utf8'),
  });
  await again.getByRole('button', { name: 'Tiếp' }).click();
  await expect(
    again.getByRole('button', { pressed: false }).filter({ hasText: 'dòng hợp lệ' }),
  ).toContainText('0');
  await expect(
    again.getByRole('button', { pressed: false }).filter({ hasText: 'dòng trùng' }),
  ).toContainText('2');
});
