// GV-03 Lịch dạy (cổng giáo viên). Dữ liệu giả dựng bằng gv-diem-danh-seed.ts (hai buổi hôm nay của gv.cs5, một buổi hôm nay của người khác).
// Máy tính: lịch cả tuần; điện thoại: dải 7 ngày + danh sách của ngày chọn (mặc định hôm nay). Chỉ buổi của mình (R-GV-08).
import { expect, test } from '@playwright/test';
import { PASSWORD, expectAccessible, loginStaff } from './helpers';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
});

const link = (id: string) => `a[href="/gv/buoi/${id}"]`;

test('GV-03: thấy buổi của mình, không thấy buổi của giáo viên khác', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lich-day');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch dạy' })).toBeVisible();
  await expect(page.locator(link(seed.chot))).toBeVisible();
  await expect(page.locator(link(seed.nhap))).toBeVisible();
  await expect(page.locator(link(seed.khac))).toHaveCount(0);
  await expect(page.locator(link(seed.chot))).toContainText('Buổi chính');
  await expectAccessible(page);
});

test('GV-03: bấm buổi dẫn tới các bước của buổi (GV-04)', async ({ page }) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lich-day');
  await page.locator(link(seed.chot)).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${seed.chot}$`));
});

test('GV-03: đổi tuần: tuần sau không có buổi hôm nay, quay lại Tuần này thấy lại', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lich-day');
  await expect(page.locator(link(seed.chot))).toBeVisible();
  await page.getByRole('button', { name: 'Tuần sau' }).click();
  await expect(page.locator(link(seed.chot))).toHaveCount(0);
  await page.getByRole('button', { name: 'Tuần này' }).click();
  await expect(page.locator(link(seed.chot))).toBeVisible();
});

test('GV-03: lịch tháng: bấm Tháng thấy buổi hôm nay; đổi tháng; bấm số ngày sang tuần của ngày đó', async ({
  page,
}) => {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto('/gv/lich-day');
  await page.getByRole('button', { name: 'Tháng', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Tháng', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  // Buổi của mình có trong tháng này, buổi của giáo viên khác thì không (R-GV-08).
  await expect(page.locator(link(seed.chot))).toBeVisible();
  await expect(page.locator(link(seed.khac))).toHaveCount(0);
  // Tháng sau không có buổi hôm nay; quay lại Tháng này thấy lại.
  await page.getByRole('button', { name: 'Tháng sau' }).click();
  await expect(page.locator(link(seed.chot))).toHaveCount(0);
  await page.getByRole('button', { name: 'Tháng này' }).click();
  await expect(page.locator(link(seed.chot))).toBeVisible();
  await expectAccessible(page);
  // Bấm buổi dẫn tới các bước của buổi (GV-04).
  await page.locator(link(seed.chot)).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${seed.chot}$`));
});
