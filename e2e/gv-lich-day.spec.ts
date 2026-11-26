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

test('GV-03: lịch tháng: bấm Tháng thấy ô hôm nay có buổi; đổi tháng; bấm số ngày sang tuần của ngày đó', async ({
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
  const todayDay = new Date()
    .toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' })
    .slice(8, 10);
  // Lưới tháng có thể hiện cả ngày cùng số của tháng trước/sau (vd. 26/10 và 26/11): chỉ lấy ô của tháng hiện tại.
  const todayMonth = new Date()
    .toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' })
    .slice(5, 7);
  const dayButton = page
    .getByRole('gridcell', { name: new RegExp(` ${todayDay}/${todayMonth}, `) })
    .getByRole('button', { name: `Xem tuần của ngày ${todayDay}` });
  // Ô hôm nay có ít nhất một buổi (mỗi ô chỉ hiện vài buổi đầu, phần còn lại ghi "+n buổi").
  const isNarrow = (page.viewportSize()?.width ?? 1280) < 640;
  if (!isNarrow) {
    await expect(page.getByRole('gridcell', { name: /, [1-9]\d* buổi$/ }).first()).toBeVisible();
  }
  // Đổi tháng: nhãn tháng đổi, Tháng này quay lại đúng tháng cũ (lớp dựng sẵn còn sinh buổi các tuần sau nên tháng sau không nhất thiết trống).
  const label = page.getByText(/^Tháng \d{2}\/\d{4}$/);
  const before = await label.textContent();
  await page.getByRole('button', { name: 'Tháng sau' }).click();
  await expect(label).not.toHaveText(before ?? '');
  await page.getByRole('button', { name: 'Tháng trước' }).click();
  await expect(label).toHaveText(before ?? '');
  await page.getByRole('button', { name: 'Tháng sau' }).click();
  await page.getByRole('button', { name: 'Tháng này' }).click();
  await expect(label).toHaveText(before ?? '');
  if (isNarrow) return;
  // Bấm số ngày hôm nay sang tuần của ngày đó: thấy buổi của mình, không thấy buổi của người khác (R-GV-08).
  await dayButton.click();
  await expect(page.getByRole('button', { name: 'Tuần', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expect(page.locator(link(seed.chot))).toBeVisible();
  await expect(page.locator(link(seed.khac))).toHaveCount(0);
  await expectAccessible(page);
});
