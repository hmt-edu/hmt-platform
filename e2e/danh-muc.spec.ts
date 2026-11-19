// QT-06, QT-07 Danh mục (canvas bổ sung v2 `1794108604-3066`): danh sách danh mục (tìm theo tên), danh mục Mở (thêm có câu lỗi, đổi tên, đổi thứ tự ▲▼,
// Ngừng, Dùng lại), danh mục Khoá (chỉ đổi tên: Giai đoạn cơ hội, R-V2-42), Chỉ xem (Tỉnh, phường: Q-110), danh mục nhiều cấp (thêm con).
// Chỉ bản máy tính (Quản trị không có bản điện thoại). Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài).
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAsAdmin, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

async function sql<T = unknown>(query: string, params: unknown[] = []): Promise<T[]> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return (await db.query(query, params)).rows as T[];
  } finally {
    await db.end();
  }
}

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/danh-muc');
  await expect(page.getByRole('heading', { level: 1, name: 'Danh mục' })).toBeVisible();
}

const nav = (page: Page) => page.getByRole('navigation', { name: 'Danh sách danh mục' });
const pick = (page: Page, name: RegExp) => nav(page).getByRole('button', { name }).click();
const panel = (page: Page) => page.getByRole('region', { name: 'Các mục của danh mục' });

test('Cột trái: danh mục kèm nhãn Mở, Khoá, Chỉ xem; tìm theo tên không dấu; Lịch sử thay đổi mờ', async ({
  page,
}) => {
  await open(page);
  await expect(page.getByRole('button', { name: 'Lịch sử thay đổi' })).toBeDisabled();
  await expect(nav(page).getByText(/^\d+$/).first()).toBeVisible();
  const stage = nav(page).getByRole('button', { name: /^Giai đoạn cơ hội/ });
  await expect(stage).toContainText('Khoá');
  await expect(stage).toContainText('chỉ đổi tên');
  await expect(nav(page).getByRole('button', { name: /^Loại hoạt động/ })).toContainText('Mở');
  await expect(nav(page).getByRole('button', { name: /^Tỉnh, phường/ })).toContainText('Chỉ xem');
  await nav(page).getByRole('textbox', { name: 'Tìm danh mục' }).fill('tinh');
  await expect(nav(page).getByRole('button', { name: /^Tỉnh, phường/ })).toBeVisible();
  await expect(nav(page).getByRole('button', { name: /^Loại hoạt động/ })).toHaveCount(0);
  await expectAccessible(page);
});

test('Danh mục Loại buổi (E23): có cột Form nhận xét chỉ đọc (Form điểm cho Kiểm tra) và đạt kiểm trợ năng', async ({
  page,
}) => {
  await open(page);
  await pick(page, /^Loại buổi/);
  const table = panel(page).getByRole('table');
  await expect(table.getByRole('columnheader', { name: 'Form nhận xét' })).toBeVisible();
  await expect(table.getByRole('row', { name: /KIEM_TRA/ })).toContainText('Form điểm');
  await expect(table.getByRole('row', { name: /CHINH/ })).toContainText('9 tiêu chí');
  await expectAccessible(page);
});

test('Danh mục Loại buổi (A25): có hai loại kiểm tra mới, Sửa form mở hộp (chưa đổi thì chưa lưu được)', async ({
  page,
}) => {
  await open(page);
  await pick(page, /^Loại buổi/);
  const table = panel(page).getByRole('table');
  await expect(table.getByRole('row', { name: /KT_GIUA_KY/ })).toContainText('Form điểm');
  await expect(table.getByRole('row', { name: /KT_CUOI_KY/ })).toContainText('Form điểm');
  await table
    .getByRole('row', { name: /KT_CUOI_KY/ })
    .getByRole('button', { name: 'Sửa form' })
    .click();
  const dialog = page.getByRole('dialog', { name: /Sửa form nhận xét/ });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByText('Đổi form chỉ áp dụng cho buổi tạo sau.')).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Lưu form' })).toBeDisabled();
  await expectAccessible(page);
});

test('Danh mục Mở: thêm mục (câu lỗi, rồi thêm được), đổi tên, ▲▼, Ngừng rồi Dùng lại', async ({
  page,
}) => {
  test.setTimeout(120_000);
  const code = `E2E${Date.now() % 1_000_000}`;
  await open(page);
  await pick(page, /^Loại hoạt động/);
  await expect(
    panel(page).getByRole('heading', { level: 2, name: 'Loại hoạt động' }),
  ).toBeVisible();
  // Hộp Thêm mục: mã sai dạng báo ngay ở ô, mã trùng báo câu của máy chủ, tên trống khoá nút.
  await panel(page).getByRole('button', { name: 'Thêm mục' }).click();
  const add = page.getByRole('dialog', { name: 'Thêm mục · Loại hoạt động' });
  await add.getByLabel('Mã', { exact: true }).fill('MÃ CÓ DẤU');
  await add.getByLabel('Tên hiển thị').fill('Thử lỗi');
  await expect(add.getByText(/Mã chỉ gồm chữ viết hoa không dấu/).first()).toBeVisible();
  await expect(add.getByRole('button', { name: 'Thêm mục' })).toBeDisabled();
  await add.getByLabel('Mã', { exact: true }).fill('ZALO');
  await add.getByRole('button', { name: 'Thêm mục' }).click();
  await expect(add.getByText('Mã ZALO đã có trong danh mục này.')).toBeVisible();
  await add.getByLabel('Mã', { exact: true }).fill(code.toLowerCase());
  await add.getByLabel('Tên hiển thị').fill('Mục thử e2e');
  await add.getByRole('button', { name: 'Thêm mục' }).click();
  await expect(page.getByText(`Đã thêm mục ${code}.`).first()).toBeVisible();
  const row = panel(page).getByRole('row').filter({ hasText: code });
  await expect(row).toContainText('Mục thử e2e');
  await expect(row).toContainText('Đang dùng');
  // Đổi tên: mã bị khoá, lưu tên mới.
  await row.getByRole('button', { name: 'Đổi tên' }).click();
  const rename = page.getByRole('dialog', { name: `Đổi tên hiển thị · ${code}` });
  await expect(rename.getByLabel('Mã', { exact: true })).toBeDisabled();
  await rename.getByLabel('Tên hiển thị').fill('Mục thử e2e (đổi tên)');
  await rename.getByRole('button', { name: 'Lưu tên' }).click();
  await expect(row).toContainText('Mục thử e2e (đổi tên)');
  // ▲▼: mục mới ở cuối nên ▼ mờ; ▲ đổi chỗ với mục kề trên, kiểm bằng DB.
  await expect(row.getByRole('button', { name: `Chuyển ${code} xuống` })).toBeDisabled();
  const order = async () =>
    (
      await sql<{ code: string }>(
        "select code from app.catalog_item where catalog_code = 'ACTIVITY_TYPE' order by sort_order, id",
      )
    ).map((r) => r.code);
  const before = await order();
  await row.getByRole('button', { name: `Chuyển ${code} lên` }).click();
  await expect(page.getByText('Đã đổi thứ tự.').first()).toBeVisible();
  const after = await order();
  expect(after.indexOf(code)).toBe(before.indexOf(code) - 1);
  await expect(panel(page).getByRole('row').nth(1)).toBeVisible();
  // Ngừng: hỏi lại, rồi Dùng lại.
  await row.getByRole('button', { name: 'Ngừng' }).click();
  const stop = page.getByRole('alertdialog', { name: /^Ngừng mục "Mục thử e2e \(đổi tên\)"\?/ });
  await expect(stop.getByText(/không hiện ở ô chọn mới/)).toBeVisible();
  await stop.getByRole('button', { name: 'Ngừng mục' }).click();
  await expect(row).toContainText('Ngừng');
  await expect(row.getByRole('button', { name: 'Dùng lại' })).toBeVisible();
  await expect(row.getByRole('button', { name: 'Đổi tên' })).toHaveCount(0);
  await row.getByRole('button', { name: 'Dùng lại' }).click();
  await expect(row).toContainText('Đang dùng');
  await expectAccessible(page);
  // Dọn: mục thử không xoá được (chỉ Ngừng), để Ngừng.
  await row.getByRole('button', { name: 'Ngừng' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Ngừng mục' }).click();
  await expect(row).toContainText('Ngừng');
});

test('Danh mục Khoá (Giai đoạn cơ hội): chỉ Đổi tên; không Thêm, Ngừng, ▲▼ (R-V2-42, Q-122)', async ({
  page,
}) => {
  test.setTimeout(90_000);
  await open(page);
  await pick(page, /^Giai đoạn cơ hội/);
  await expect(
    panel(page).getByRole('heading', { level: 2, name: 'Giai đoạn cơ hội' }),
  ).toBeVisible();
  await expect(panel(page).getByText('Khoá: chỉ đổi tên hiển thị.')).toBeVisible();
  // Q-132: nhóm con L3A là số 1 dưới L3 (đếm lại từ 1 trong từng giai đoạn).
  const l3a = panel(page)
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: 'L3A', exact: true }) });
  await expect(l3a.getByRole('cell').nth(2)).toHaveText('1');
  await expect(panel(page).getByRole('button', { name: /^Thêm/ })).toHaveCount(0);
  await expect(panel(page).getByRole('button', { name: 'Ngừng' })).toHaveCount(0);
  await expect(panel(page).getByRole('button', { name: /^Dùng lại/ })).toHaveCount(0);
  await expect(panel(page).getByRole('button', { name: /Chuyển .* (lên|xuống)/ })).toHaveCount(0);
  // Cả 8 giai đoạn và 62 nhóm con đều có nút Đổi tên (kể cả nhóm con đã Ngừng L5P, L5Q).
  await expect(panel(page).getByRole('button', { name: 'Đổi tên' })).toHaveCount(70);
  const row = panel(page).getByRole('row').filter({ hasText: 'L5Q' });
  await expect(row).toContainText('Ngừng');
  const original =
    (
      await sql<{ name: string }>(
        "select name from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5Q'",
      )
    )[0]?.name ?? '';
  await row.getByRole('button', { name: 'Đổi tên' }).click();
  const rename = page.getByRole('dialog', { name: 'Đổi tên hiển thị · L5Q' });
  await rename.getByLabel('Tên hiển thị').fill(`${original} (thử)`);
  await rename.getByRole('button', { name: 'Lưu tên' }).click();
  await expect(row).toContainText(`${original} (thử)`);
  // Trả lại tên cũ.
  await row.getByRole('button', { name: 'Đổi tên' }).click();
  await page
    .getByRole('dialog', { name: 'Đổi tên hiển thị · L5Q' })
    .getByLabel('Tên hiển thị')
    .fill(original);
  await page
    .getByRole('dialog', { name: 'Đổi tên hiển thị · L5Q' })
    .getByRole('button', { name: 'Lưu tên' })
    .click();
  await expect(row).not.toContainText('(thử)');
  await expectAccessible(page);
});

test('Danh mục Chỉ xem (Tỉnh/Thành phố, Phường/Xã): không có nút sửa (Q-110)', async ({ page }) => {
  await open(page);
  await pick(page, /^Tỉnh, phường/);
  await expect(panel(page).getByRole('heading', { level: 2, name: 'Tỉnh, phường' })).toBeVisible();
  await expect(panel(page).getByText('Nạp từ file chuẩn, chỉ xem.')).toBeVisible();
  await expect(panel(page).getByRole('columnheader', { name: 'Cấp' })).toBeVisible();
  await expect(panel(page).getByRole('button')).toHaveCount(0);
  await expectAccessible(page);
});

test('Danh mục nhiều cấp (Loại nguồn): Thêm nguồn ở một loại, hộp có ô "Thuộc loại nguồn"', async ({
  page,
}) => {
  test.setTimeout(90_000);
  const code = `E2E${Date.now() % 1_000_000}`;
  await open(page);
  await pick(page, /^Nguồn lead/);
  await expect(panel(page).getByText(/Danh mục nhiều cấp/)).toBeVisible();
  // Q-132: số thứ tự hiển thị đếm lại từ 1 trong từng nhóm cùng cha (Cold Call dưới Telemarketing là 1, không phải số lưu trong DB).
  const coldCall = panel(page)
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: 'COLD_CALL', exact: true }) });
  await expect(coldCall.getByRole('cell').nth(2)).toHaveText('1');
  // Q-128: tên danh mục hiện "Nguồn lead" và dòng tóm tắt theo đơn vị từng tầng.
  await expect(nav(page).getByRole('button', { name: /^Nguồn lead/ })).toContainText(
    /\d+ loại · \d+ nguồn · \d+ kênh/,
  );
  const marketing = panel(page)
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: 'MARKETING', exact: true }) });
  await marketing.getByRole('button', { name: 'Thêm nguồn' }).click();
  const add = page.getByRole('dialog', { name: 'Thêm nguồn · Nguồn lead' });
  await expect(add.getByRole('combobox', { name: 'Thuộc loại nguồn' })).toContainText('MARKETING');
  await add.getByLabel('Mã', { exact: true }).fill(code);
  await add.getByLabel('Tên hiển thị').fill('Nguồn thử e2e');
  await add.getByRole('button', { name: 'Thêm nguồn' }).click();
  await expect(page.getByText(`Đã thêm nguồn ${code}.`).first()).toBeVisible();
  const row = panel(page).getByRole('row').filter({ hasText: code });
  await expect(row).toContainText('Nguồn thử e2e');
  const parent = (
    await sql<{ code: string }>(
      "select p.code from app.catalog_item c join app.catalog_item p on p.id = c.parent_id where c.catalog_code = 'SOURCE' and c.code = $1",
      [code],
    )
  )[0]?.code;
  expect(parent).toBe('MARKETING');
  await row.getByRole('button', { name: 'Ngừng' }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Ngừng mục' }).click();
  await expect(row).toContainText('Ngừng');
});

// E26: kiểm trợ năng (axe) cho hai màn Nhật ký của Quản trị, cùng tệp (cùng worker, nối tiếp) để không tranh thiết bị hai bước của quantri.cs5.
test('QT-11 Nhật ký thao tác: mở được và đạt kiểm trợ năng', async ({ page }) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/nhat-ky');
  await expect(page.getByRole('heading', { level: 1, name: 'Nhật ký thao tác' })).toBeVisible();
  await expect(page.getByRole('table').or(page.getByText('Chưa có dòng nhật ký'))).toBeVisible();
  await expectAccessible(page);
});

test('QT-12 Nhật ký đăng nhập và xuất file: mở được và đạt kiểm trợ năng', async ({ page }) => {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/nhat-ky-dang-nhap');
  await expect(page.getByRole('heading', { level: 1, name: /Nhật ký đăng nhập/ })).toBeVisible();
  await expectAccessible(page);
});
