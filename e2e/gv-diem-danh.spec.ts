// GV-05 Điểm danh (cổng giáo viên). Dữ liệu giả dựng bằng gv-diem-danh-seed.ts. Điện thoại và máy tính cùng một luồng.
import { expect, test } from '@playwright/test';
import { PASSWORD, expectAccessible, loginStaff } from './helpers';
import type { Page } from '@playwright/test';
import { markAsAssistant, seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
});

const open = (id: string) => `/gv/buoi/${id}/diem-danh`;

// Đăng nhập giáo viên và chờ vào xong cổng rồi mới mở địa chỉ khác (mở sớm thì phiên chưa kịp lưu, bị đưa về trang đăng nhập).
async function enterTeacher(page: Page, sessionId: string) {
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await page.goto(open(sessionId));
}

test('GV-05: Còn lại: Có mặt rồi Lưu; tải lại vẫn còn; không tự lưu', async ({ page }) => {
  await enterTeacher(page, seed.chot);
  await expect(page.getByRole('heading', { level: 1, name: 'Điểm danh' })).toBeVisible();
  await expect(page.getByText('Đã điểm danh 0/3')).toBeVisible();
  await expectAccessible(page);
  await page.getByRole('button', { name: /^Còn lại: / }).click();
  await expect(page.getByText('Đã điểm danh 3/3')).toBeVisible();
  await expect(page.getByText('Chưa lưu', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Lưu điểm danh' }).click();
  await expect(page.getByText('Đã lưu điểm danh', { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText('Đã điểm danh 3/3')).toBeVisible();
  await expect(page.getByText('Chưa lưu', { exact: true })).toHaveCount(0);
});

test('GV-05: đổi em đã chấm nhận xét sang Vắng thì hỏi trước; Giữ nguyên thì không đổi', async ({
  page,
}) => {
  await enterTeacher(page, seed.chot);
  const group = page.getByRole('radiogroup', { name: `Trạng thái của ${seed.names[0]}` });
  await group.getByRole('radio', { name: 'Vắng có phép' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Đổi sang Vắng?' });
  await expect(dialog).toContainText('Điểm đã nhập của em này sẽ không được tính');
  await dialog.getByRole('button', { name: 'Giữ nguyên' }).click();
  await expect(group.getByRole('radio', { name: 'Vắng có phép' })).not.toBeChecked();
  await group.getByRole('radio', { name: 'Vắng có phép' }).click();
  await page
    .getByRole('alertdialog', { name: 'Đổi sang Vắng?' })
    .getByRole('button', { name: 'Đổi sang Vắng' })
    .click();
  await expect(group.getByRole('radio', { name: 'Vắng có phép' })).toBeChecked();
  // Em chưa có điểm đổi sang Vắng thì không hỏi.
  const other = page.getByRole('radiogroup', { name: `Trạng thái của ${seed.names[1]}` });
  await other.getByRole('radio', { name: 'Vắng không phép' }).click();
  await expect(other.getByRole('radio', { name: 'Vắng không phép' })).toBeChecked();
  await expect(page.getByRole('alertdialog')).toHaveCount(0);
});

test('GV-05: rời màn khi chưa lưu thì hỏi', async ({ page }) => {
  await enterTeacher(page, seed.chot);
  await page
    .getByRole('radiogroup', { name: `Trạng thái của ${seed.names[2]}` })
    .getByRole('radio', { name: 'Đi muộn' })
    .click();
  await page.getByRole('link', { name: 'Lịch dạy' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Chưa lưu thay đổi' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Ở lại để lưu' }).click();
  await expect(page).toHaveURL(new RegExp(`${seed.chot}/diem-danh$`));
});

test('GV-05: hai người cùng sửa một ô thì hỏi Giữ của tôi hoặc Lấy của người kia (R-GV-09)', async ({
  page,
}) => {
  await enterTeacher(page, seed.chot);
  const group = page.getByRole('radiogroup', { name: `Trạng thái của ${seed.names[2]}` });
  await group.getByRole('radio', { name: 'Vắng không phép' }).click();
  // Trợ giảng vừa sửa ô này (giả bằng cơ sở dữ liệu) trong lúc giáo viên đang mở màn.
  await markAsAssistant(seed.chot, seed.names[2], 'DI_MUON');
  await page.getByRole('button', { name: 'Lưu điểm danh' }).click();
  const dialog = page.getByRole('dialog', { name: /^Có ô vừa được .* sửa$/ });
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText(seed.names[2]);
  await dialog.getByRole('button', { name: 'Giữ của tôi' }).click();
  await expect(page.getByText('Đã lưu điểm danh', { exact: true })).toBeVisible();
  await page.reload();
  await expect(
    page
      .getByRole('radiogroup', { name: `Trạng thái của ${seed.names[2]}` })
      .getByRole('radio', { name: 'Vắng không phép' }),
  ).toBeChecked();
});

test('GV-05: buổi chưa chốt danh sách; buổi của người khác không xem được', async ({ page }) => {
  await enterTeacher(page, seed.nhap);
  await expect(page.getByText('Buổi chưa chốt danh sách.')).toBeVisible();
  await expect(page.getByText('Chưa có danh sách để điểm danh')).toBeVisible();
  await page.goto(open(seed.khac));
  await expect(page.getByText('Bạn không xem được buổi này')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Về trang Hôm nay' })).toBeVisible();
});
