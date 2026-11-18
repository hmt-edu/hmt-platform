// CH-05, CH-06 Khung chương trình: Admin tạo khung, tạo bản mới (sao chép bài), thêm, sửa, đổi thứ tự bài, ngừng; Trưởng cơ sở chỉ xem. Chỉ bản máy tính (Cấu hình không có bản điện thoại).
// Admin giả quantri2.cs5 (hai bước thiết lập ngay trong bài; mỗi Admin giả chỉ dùng ở một file bài). Khung thử: Lý · Khối 10 · Nâng cao · năm học kế tiếp, dọn sau bài.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, enterAsAdmin, expectAccessible, pickOption } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Cấu hình chỉ có bản máy tính.');
});

const YEAR = new Date().getFullYear() + 1;
const YEAR_CODE = `${String(YEAR % 100).padStart(2, '0')}${String((YEAR + 1) % 100).padStart(2, '0')}`;
const CODE = `LY-K10-NC-${YEAR_CODE}`;

// Khung và bài không xoá cứng; dọn bằng phiên "replica" (bỏ trigger) trong một giao dịch.
async function clean() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      'delete from app.curriculum_lesson where frame_id in (select id from app.curriculum_frame where code like $1)',
      [`${CODE}%`],
    );
    await db.query('delete from app.curriculum_frame where code like $1', [`${CODE}%`]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}
test.beforeAll(clean);
test.afterAll(clean);

test('CH-05: Admin tạo bản đầu của khung, mã không hậu tố; bản kế là -v2', async ({ page }) => {
  await enterAsAdmin(page, 'quantri2.cs5');
  await page.goto('/crm/cau-hinh/khung-chuong-trinh');
  await expect(page.getByRole('heading', { level: 1, name: 'Khung chương trình' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo bản mới' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo bản mới của khung chương trình' });
  await expect(dialog.getByRole('button', { name: 'Tạo bản mới' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Môn' }), /Vật lý/);
  await pickOption(page, dialog.getByRole('combobox', { name: 'Khối' }), /10/);
  await pickOption(page, dialog.getByRole('combobox', { name: 'Cấp độ' }), /Nâng cao/);
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Năm học' }),
    new RegExp(`${YEAR}–${YEAR + 1}`),
  );
  await expect(dialog.getByText(CODE, { exact: true })).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Tạo bản mới' }).click();
  await expect(page.getByRole('link', { name: CODE, exact: true })).toBeVisible();
});

test('CH-06: Admin thêm bài, sửa tên, đổi thứ tự; mã bài không đổi', async ({ page }) => {
  await enterAsAdmin(page, 'quantri2.cs5');
  await page.goto('/crm/cau-hinh/khung-chuong-trinh');
  await page.getByRole('link', { name: CODE, exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: CODE })).toBeVisible();
  await expect(page.getByText('Khung này chưa có bài nào')).toBeVisible();
  for (const name of ['Dao động điều hoà', 'Sóng cơ']) {
    await page.getByRole('button', { name: 'Thêm bài' }).click();
    const dialog = page.getByRole('dialog', { name: `Thêm bài vào ${CODE}` });
    await dialog.getByLabel('Tên bài').fill(name);
    await dialog.getByRole('button', { name: 'Thêm bài' }).click();
    await expect(page.getByRole('cell', { name, exact: true })).toBeVisible();
  }
  await expect(page.getByText(`${CODE}-B01`)).toBeVisible();
  await expect(page.getByText(`${CODE}-B02`)).toBeVisible();
  // Sửa tên bài 1 tại dòng.
  await page
    .getByRole('row', { name: /Dao động điều hoà/ })
    .getByRole('button', { name: 'Sửa' })
    .click();
  await page.getByLabel('Tên bài').fill('Dao động cơ');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByRole('cell', { name: 'Dao động cơ', exact: true })).toBeVisible();
  // Đưa bài B02 lên đầu: mã bài giữ nguyên, số «Bài N» đổi.
  await page.getByRole('button', { name: `Đưa ${CODE}-B02 lên` }).click();
  const first = page.getByRole('row').nth(1);
  await expect(first).toContainText(`${CODE}-B02`);
  await expect(first).toContainText('Bài 1');
});

test('CH-05: tạo bản mới sao chép toàn bộ bài; bản -v2 có đủ bài, mã bài đổi tiền tố', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri2.cs5');
  await page.goto('/crm/cau-hinh/khung-chuong-trinh');
  await page.getByRole('button', { name: 'Tạo bản mới' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo bản mới của khung chương trình' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Môn' }), /Vật lý/);
  await pickOption(page, dialog.getByRole('combobox', { name: 'Khối' }), /10/);
  await pickOption(page, dialog.getByRole('combobox', { name: 'Cấp độ' }), /Nâng cao/);
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Năm học' }),
    new RegExp(`${YEAR}–${YEAR + 1}`),
  );
  await expect(dialog.getByText(`${CODE}-v2`, { exact: true })).toBeVisible();
  await expect(dialog.getByText(/Sao chép 2 bài từ bản/)).toBeVisible();
  await dialog.getByRole('button', { name: 'Tạo bản mới' }).click();
  await page.getByRole('link', { name: `${CODE}-v2`, exact: true }).click();
  await expect(page.getByText(`${CODE}-v2-B01`)).toBeVisible();
  await expect(page.getByText(`${CODE}-v2-B02`)).toBeVisible();
});

test('CH-05: Admin Ngừng khung (có xác nhận); Trưởng cơ sở chỉ xem, không có Tạo bản mới, Ngừng, Thêm bài', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri2.cs5');
  await page.goto('/crm/cau-hinh/khung-chuong-trinh');
  await page
    .getByRole('row', { name: new RegExp(`${CODE}-v2`) })
    .getByRole('button', { name: 'Ngừng' })
    .click();
  await page.getByRole('button', { name: 'Ngừng khung' }).click();
  await expect(page.getByRole('row', { name: new RegExp(`${CODE}-v2`) })).toContainText('Ngừng');
  // Trưởng cơ sở (không đăng xuất Admin: dùng thẻ mới).
  const other = await page.context().browser()!.newContext();
  const p2 = await other.newPage();
  await enterAs(p2, 'truongcs.cs5');
  await p2.goto('/crm/cau-hinh/khung-chuong-trinh');
  await expect(p2.getByRole('heading', { level: 1, name: 'Khung chương trình' })).toBeVisible();
  await expect(p2.getByRole('button', { name: 'Tạo bản mới' })).toHaveCount(0);
  await expect(p2.getByRole('button', { name: 'Ngừng' })).toHaveCount(0);
  await p2.getByRole('link', { name: CODE, exact: true }).click();
  await expect(p2.getByText('Bạn chỉ xem được khung chương trình. Admin sửa.')).toBeVisible();
  await expect(p2.getByRole('button', { name: 'Thêm bài' })).toHaveCount(0);
  await other.close();
});
