// Cụm Lớp: LOP-03 tạo lớp, LOP-01 danh sách và tìm, LOP-02 hồ sơ, LOP-05 Trình, LOP-06 Huỷ, LOP-08 lịch tuần.
// Dùng Trưởng cơ sở CS5 giả; bật công tắc VAN_HANH_LOP cho CS5 bằng SQL trước bài (cờ bật ở production bằng migration, Q-262).
// Lớp tạo trong bài có mã cũ riêng của từng dự án (máy tính, điện thoại) để tìm đúng lớp của mình; không xoá lớp (huỷ là đổi tình trạng).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

test.beforeAll(async () => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
  } finally {
    await db.end();
  }
});

const legacy = (project: string) =>
  `E2ELOP-${project === 'dien-thoai' ? 'DT' : 'MT'}-${Date.now().toString(36).toUpperCase()}`;

test('LOP-03 tạo lớp, LOP-01 tìm, LOP-02 hồ sơ, LOP-05 Trình, LOP-06 Huỷ', async ({
  page,
}, testInfo) => {
  // Một bài dài (tạo, tìm, Trình, Huỷ) nên cho thời gian gấp ba mặc định.
  test.setTimeout(90_000);
  const mark = legacy(testInfo.project.name);
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/lop/tao');
  await expect(page.getByRole('heading', { level: 1, name: 'Tạo lớp mới' })).toBeVisible();
  await expectAccessible(page);

  // Nút Lưu nháp khi còn thiếu: báo từng trường.
  await page.getByRole('button', { name: 'Lưu nháp' }).click();
  await expect(page.getByText('Chọn môn học.')).toBeVisible();

  const year = new Date().getFullYear();
  await page
    .getByLabel('Năm học')
    .selectOption(`${String(year).slice(2)}${String(year + 1).slice(2)}`);
  await page.getByLabel('Mã lớp cũ (Sheet)').fill(mark);
  await page.getByLabel('Môn học').selectOption({ label: 'Toán' });
  await page.getByLabel('Khối').selectOption({ index: 5 });
  await page.getByLabel('Phân loại').selectOption({ label: 'Cơ bản' });
  await page.getByLabel('Trình độ').selectOption({ index: 1 });
  // A50: Khung chương trình và Bài bắt đầu là ô chọn (lấy từ khung ở CH-05), không còn ô gõ chữ; chưa có khung khớp thì chỉ còn «— Chọn —».
  await expect(page.getByLabel('Khung chương trình')).toBeVisible();
  await expect(page.getByLabel('Bài bắt đầu')).toBeDisabled();
  await page.getByLabel('Tổng số buổi').fill('12');
  await page.getByLabel('Ngày khai giảng').fill('2027-01-05');
  // Một khung giờ Thứ 3 (ngày 05/01/2027 là Thứ 3).
  await page.getByRole('button', { name: 'Thêm khung giờ' }).nth(1).click();
  await page.getByRole('button', { name: 'Lưu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/lop\/[0-9a-f-]{36}$/);
  const recordUrl = page.url();
  await expect(page.getByText(/CS5-\d{4}-/).first()).toBeVisible();
  await expect(page.getByText('Nháp').first()).toBeVisible();
  // Chi tiết lớp theo khuôn chung: Time Table 7 tab theo thứ; Học sinh và Buổi học là tab có bảng riêng.
  await expect(page.getByRole('tab', { name: /^Thứ 3/ })).toBeVisible();
  await expect(page.getByRole('tab', { name: /^Học sinh/ })).toBeVisible();
  await expect(page.getByRole('tab', { name: /^Buổi học/ })).toBeVisible();

  // LOP-01: tìm theo mã cũ (R-LOP-15).
  await page.goto('/crm/lop');
  await expect(page.getByRole('heading', { level: 1, name: 'Lớp' })).toBeVisible();
  await page.getByPlaceholder('Tìm mã lớp hoặc mã cũ…').fill(mark);
  await expect(page.getByRole('link', { name: /^CS5-/ }).first()).toBeVisible();
  await expect(page.getByText(`mã cũ ${mark}`).first()).toBeVisible();

  // LOP-05 Trình, LOP-06 Huỷ ngay trên lớp vừa tạo.
  await page.goto(recordUrl);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Trình' }).click();
  await page.getByRole('button', { name: 'Trình', exact: true }).click();
  await expect(page.getByText('Trình xong.').first()).toBeVisible();
  await expect(page.getByText('Đã trình').first()).toBeVisible();

  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ lớp' }).click();
  await page.getByRole('button', { name: 'Huỷ lớp' }).last().click();
  await expect(page.getByText('Huỷ lớp xong.').first()).toBeVisible();
});

test('LOP-08: lịch tuần cơ sở mở được, đổi tuần', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/lich-tuan');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch tuần cơ sở' })).toBeVisible();
  await page.getByRole('button', { name: 'Tuần sau' }).click();
  await page.getByRole('button', { name: 'Theo giáo viên' }).click();
  await expect(page.getByRole('button', { name: 'Theo giáo viên' })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expectAccessible(page);
});
