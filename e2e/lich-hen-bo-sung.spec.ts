// Lịch hẹn bổ sung (QĐ-Đ6, Đ33 đến Đ38): Xuất, Group By ở máy chủ, chọn hàng loạt kèm Giao việc, lịch "Theo người".
// Máy tính: Trưởng cơ sở (có Xuất, Giao việc). Điện thoại: CSKH (không có Xuất, Giao việc: các nút đó phải ẩn).
// Dữ liệu giả dựng bằng create_lead, create_appointment (xem lich-hen-seed.ts), dấu riêng để không đụng bài khác.
import { readFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, isPhone, pickOption } from './helpers';
import { DB_URL, clearMark, seed, type Setup } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lịch hẹn giả).');
test.describe.configure({ mode: 'serial' });

const SETUPS: Record<string, Setup> = {
  'may-tinh': { mark: 'E2ELBMT', account: 'truongcs.cs5', phone: 910 },
  'dien-thoai': { mark: 'E2ELBDT', account: 'cskh.cs5', phone: 920 },
};
const setupOf = (project: string): Setup => SETUPS[project] ?? SETUPS['may-tinh']!;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  await seed(setupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(setupOf(testInfo.project.name).mark);
});

async function openList(page: Page, setup: Setup) {
  await enterAs(page, setup.account);
  await page.goto('/crm/lich-hen');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch hẹn' })).toBeVisible();
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
}

const rows = (page: Page) =>
  isPhone(page)
    ? page.getByRole('list', { name: 'Lịch hẹn' }).getByRole('listitem')
    : page.getByRole('table', { name: 'Lịch hẹn' }).getByRole('row');
const row = (page: Page, title: string) => rows(page).filter({ hasText: title });

test('Quyền: Trưởng cơ sở có Xuất và chọn hàng loạt; CSKH không có', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toBeVisible();
  const canBulk = testInfo.project.name !== 'dien-thoai';
  await expect(page.getByRole('button', { name: 'Xuất', exact: true })).toHaveCount(
    canBulk ? 1 : 0,
  );
  if (canBulk) {
    await expect(page.getByRole('checkbox', { name: /^Chọn Gọi/ }).first()).toBeVisible();
  } else {
    await expect(page.getByRole('checkbox', { name: /^Chọn /, includeHidden: false })).toHaveCount(
      0,
    );
  }
});

test('Xuất: tải file CSV theo bộ lọc đang xem (Trưởng cơ sở)', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'CSKH không có quyền Xuất.');
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toBeVisible();
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^lich-hen-\d{4}-\d{2}-\d{2}\.csv$/);
  const path = await file.path();
  const text = readFileSync(path, 'utf8');
  expect(text).toContain('Loại hồ sơ');
  expect(text).toContain(`Gọi tư vấn ${setup.mark}`);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Group By trạng thái ở máy chủ: số đếm theo nhóm, mở nhóm mới tải đúng dòng của nhóm', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await page.getByRole('button', { name: 'Group By', exact: true }).click();
  await page.getByRole('button', { name: /^Trạng thái/ }).click();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
  const open = page.getByRole('button', { name: /^Chưa làm \(\d+\)$/ });
  const done = page.getByRole('button', { name: /^Hoàn thành \(1\)$/ });
  await expect(open).toBeVisible();
  await expect(done).toBeVisible();
  // Nhóm đóng: chưa có dòng nào.
  await expect(row(page, `Gặp xong ${setup.mark}`)).toHaveCount(0);
  await done.click();
  await expect(row(page, `Gặp xong ${setup.mark}`)).toBeVisible();
  // Dòng của nhóm Hoàn thành không lẫn lịch Chưa làm (lỗi cũ: mở nhóm ra toàn bộ dòng).
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toHaveCount(0);
  await open.click();
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toBeVisible();
});

test('Giao việc hàng loạt: giao phần hợp lệ, nêu lý do lịch bị bỏ (Hoàn thành không giao được)', async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'CSKH không có quyền Giao việc.');
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toBeVisible();
  await page
    .getByRole('checkbox', { name: new RegExp(`^Chọn .*Gọi tư vấn ${setup.mark}`) })
    .check();
  await page
    .getByRole('checkbox', { name: new RegExp(`^Chọn .*Zalo báo giá ${setup.mark}`) })
    .check();
  await page.getByRole('checkbox', { name: new RegExp(`^Chọn .*Gặp xong ${setup.mark}`) }).check();
  await expect(page.getByText('Đã chọn 3')).toBeVisible();
  await page.getByRole('button', { name: 'Assign', exact: true }).first().click();
  const dialog = page.getByRole('dialog', { name: /^Assign lịch hẹn/ });
  await expect(dialog).toBeVisible();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Cơ sở' }), /CS5/);
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Nhân sự phụ trách' }),
    /^Sale CS5 \(giả\)/,
  );
  await dialog.getByRole('button', { name: 'Assign', exact: true }).click();
  // Kết quả: giao 2 trên 3, lý do bị bỏ hiện rõ.
  const result = page.getByRole('alertdialog', { name: 'Đã giao 2 trên 3 lịch hẹn' });
  await expect(result).toBeVisible();
  await expect(result.getByText('Chỉ giao được lịch hẹn chưa làm', { exact: false })).toBeVisible();
  await expect(result.getByText('1 lịch hẹn', { exact: true })).toBeVisible();
  await result.getByRole('button', { name: 'Đã hiểu' }).click();
  // Người phụ trách của hai lịch đã giao đổi; lịch Hoàn thành giữ nguyên.
  await expect(row(page, `Gọi tư vấn ${setup.mark}`)).toContainText('Sale CS5 (giả)');
  await expect(row(page, `Zalo báo giá ${setup.mark}`)).toContainText('Sale CS5 (giả)');
  await expect(row(page, `Gặp xong ${setup.mark}`)).toContainText('Trưởng CS5 (giả)');
});

test('Lịch "Theo người", chế độ Ngày: chỉ người có lịch hẹn trong ngày, xếp theo tên; không có "Theo phòng"', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await page.getByRole('button', { name: 'Calendar', exact: true }).click();
  await page.getByRole('button', { name: 'Ngày', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Theo phòng', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Theo người', exact: true }).click();
  // Tiêu đề cột người (không lẫn với tên ở menu tài khoản).
  const column = (name: string) =>
    page
      .locator('b.text-body.font-semibold')
      .filter({ hasText: new RegExp(`^${name.replace(/[()]/g, '\\$&')}$`) });
  const owner = testInfo.project.name === 'dien-thoai' ? 'CSKH CS5 (giả)' : 'Trưởng CS5 (giả)';
  await expect(column(owner)).toBeVisible();
  if (testInfo.project.name !== 'dien-thoai') {
    // Sau bài giao việc: hai lịch của Sale CS5 hiện ở cột thứ hai (xếp theo tên: Sale trước Trưởng).
    await expect(column('Sale CS5 (giả)')).toBeVisible();
    const headers = await page.locator('b.text-body.font-semibold').allTextContents();
    expect(headers.indexOf('Sale CS5 (giả)')).toBeLessThan(headers.indexOf('Trưởng CS5 (giả)'));
  }
});
