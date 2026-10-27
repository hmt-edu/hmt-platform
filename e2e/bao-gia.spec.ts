// BH-01 Báo giá (danh sách), P5a-UI-1: cột theo canvas, lọc, tìm, Xuất theo quyền, mục menu theo công tắc Bán hàng.
// Dữ liệu giả dựng bằng hàm nghiệp vụ (xem bao-gia-seed.ts), tìm bằng dấu riêng của từng dự án.
import { readFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone } from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng báo giá giả).');
test.describe.configure({ mode: 'serial' });

let seeded: Seeded;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seed(setupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(setupOf(testInfo.project.name).mark);
});

async function openQuotes(page: Page, account: string, mark: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/bao-gia');
  await expect(page.getByRole('heading', { level: 1, name: 'Báo giá' })).toBeVisible();
  await page.getByRole('searchbox').fill(mark);
  // Tìm kiếm chờ một nhịp rồi mới gọi máy chủ: đợi tới khi chỉ còn bốn báo giá của dự án.
  await expect(page.getByText('1–5 / 5')).toBeVisible();
}

function list(page: Page) {
  return isPhone(page)
    ? page.getByRole('list', { name: 'Báo giá' })
    : page.getByRole('table', { name: 'Báo giá' });
}

async function pickFilters(page: Page, labels: string[], uncheck: string[] = []) {
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  for (const label of uncheck) await page.getByLabel(label, { exact: true }).uncheck();
  for (const label of labels) await page.getByLabel(label, { exact: true }).check();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
}

test('Sale CS5: danh sách đủ cột theo canvas, không có Tạo, không có Xuất', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  const rows = list(page);
  await expect(rows.getByText(seeded.code.draft)).toBeVisible();
  await expect(rows.getByText(seeded.code.sent)).toBeVisible();
  // Cột Học sinh hiện đủ hai em của báo giá Nháp (canvas BH01).
  await expect(rows.getByText(seeded.students.draft.join(', '))).toBeVisible();
  // Tình trạng, nhãn quá hạn do máy chủ tính.
  await expect(rows.getByText('Nháp').first()).toBeVisible();
  await expect(rows.getByText('Đã gửi').first()).toBeVisible();
  await expect(rows.getByText('Từ chối').first()).toBeVisible();
  await expect(rows.getByText('Quá hạn 3 ngày')).toBeVisible();
  // R-TIEN-02: danh sách không có nút Tạo; Đ105: Sale không có nút Xuất.
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xuất', exact: true })).toHaveCount(0);
  await expectAccessible(page);
});

test('Tìm theo mã và lọc nhanh Tình trạng', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  await page.getByRole('searchbox').fill(seeded.code.rejected);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.parent.rejected)).toBeVisible();
  await page.getByRole('searchbox').fill(setup.mark);
  await expect(page.getByText('1–5 / 5')).toBeVisible();
  await pickFilters(page, ['Nháp']);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.code.draft)).toBeVisible();
});

test('Lọc nhanh Đã chuyển đơn: chỉ báo giá đã lên đơn; Đã gửi không lẫn báo giá đã lên đơn; chọn cả hai thì HOẶC', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  await pickFilters(page, ['Đã chuyển đơn']);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toBeVisible();
  await expect(list(page).getByText(seeded.code.sent)).toHaveCount(0);
  // Đã gửi chỉ gồm báo giá chưa chuyển hết (Đ243): Đã gửi và Quá hạn, không có báo giá đã chuyển đơn.
  await pickFilters(page, ['Đã gửi'], ['Đã chuyển đơn']);
  await expect(page.getByText('1–2 / 2')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toHaveCount(0);
  // Chọn thêm Đã chuyển đơn: nối bằng HOẶC, đủ ba báo giá.
  await pickFilters(page, ['Đã chuyển đơn']);
  await expect(page.getByText('1–3 / 3')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toBeVisible();
});

test('Trưởng cơ sở có nút Xuất; file CSV có BOM và báo giá trong phạm vi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.manager, setup.mark);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^bao-gia-\d{4}-\d{2}-\d{2}\.csv$/);
  const text = readFileSync(await file.path(), 'utf8');
  expect(text.startsWith('﻿Mã,Tình trạng')).toBe(true);
  expect(text).toContain(seeded.code.sent);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Công tắc Bán hàng: CS1 chưa bật thì không có mục Báo giá và mở thẳng đường dẫn thì báo chưa bật', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/bao-gia');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});

async function openRecord(page: Page, account: string, mark: string, code: string) {
  await openQuotes(page, account, mark);
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await list(page).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Báo giá' })).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('BH-02 chỉ đọc: báo giá Nháp hai em, tổng tiền, không có nút Sửa', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  const grid = page.getByRole(isPhone(page) ? 'list' : 'table', { name: 'Gói học' });
  await expect(grid.getByText('Em Nháp Một')).toBeVisible();
  await expect(grid.getByText('Em Nháp Hai')).toBeVisible();
  await expect(grid.getByText('Offline').first()).toBeVisible();
  await expect(grid.getByText('10 giờ')).toBeVisible();
  await expect(grid.getByText('5 giờ')).toBeVisible();
  await expect(page.getByText('Tổng thành tiền')).toBeVisible();
  await expect(page.locator('b', { hasText: '3.300.000 đ' })).toBeVisible();
  await expect(page.getByText('Chưa thấy em? Thêm em ở cơ hội.')).toHaveCount(0);
  // Phần sửa Nháp chưa dựng (chờ khuôn của Design): không có nút Sửa.
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toHaveCount(0);
  await expectAccessible(page);
});

test('BH-02: cột Đơn nêu mã và trạng thái đơn; báo giá chưa lên đơn hiện dấu gạch', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.converted);
  const grid = page.getByRole(isPhone(page) ? 'list' : 'table', { name: 'Gói học' });
  await expect(grid.getByText(seeded.orderCode)).toBeVisible();
  await expect(grid.getByText('Nháp', { exact: true })).toBeVisible();
  // Báo giá đã lên đơn: không còn nút Từ chối (đã có đơn đang sống).
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toHaveCount(0);
  await page.goto('/crm/bao-gia');
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await expect(page.getByText(seeded.orderCode)).toHaveCount(0);
  await expectAccessible(page);
});

test('BH-02 chỉ đọc: Từ chối nêu lý do, Quá hạn nêu nhãn, Đã gửi nêu ngày gửi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.rejected);
  await expect(page.locator('b', { hasText: 'Lý do từ chối' })).toBeVisible();
  await expect(page.getByText(/Giá chưa đúng/).first()).toBeVisible();
  await page.goto('/crm/bao-gia');
  await openRecord(page, setup.sale, setup.mark, seeded.code.overdue);
  await expect(page.getByText('Đã quá hạn 3 ngày')).toBeVisible();
  await expect(page.getByText(/^Đã gửi cho phụ huynh ngày/)).toBeVisible();
});

test('BH-02: ghi chú gắn vào báo giá; báo giá không có thì báo không tìm thấy', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  const note = `Phụ huynh hẹn trả lời ${setup.mark}`;
  await page.getByPlaceholder(/Viết ghi chú/).fill(note);
  await page.getByRole('button', { name: 'Gửi ghi chú' }).click();
  await expect(page.getByText(note)).toBeVisible();
  // Mở trực tiếp một báo giá không tồn tại: báo không tìm thấy.
  await page.goto('/crm/bao-gia/00000000-0000-0000-0000-000000000000');
  await expect(page.getByRole('heading', { name: 'Không tìm thấy báo giá' })).toBeVisible();
});

test('BH-02: Sale bấm Gửi báo giá Nháp thì thành Đã gửi, hết nút Gửi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Gửi', exact: true }).click();
  await expect(page.getByText('Đã gửi báo giá.').first()).toBeVisible();
  await expect(page.getByText(/^Đã gửi cho phụ huynh ngày/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Gửi', exact: true })).toHaveCount(0);
  // Báo giá Đã gửi (chưa lên đơn) có nút Từ chối.
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toBeVisible();
});

test('BH-02: Từ chối báo giá qua hộp BH-04, bắt chọn lý do; xong hiện lý do', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await page.getByRole('button', { name: 'Từ chối', exact: true }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Từ chối báo giá' })).toBeVisible();
  // Chưa chọn lý do thì chưa xác nhận được.
  await expect(dialog.getByRole('button', { name: 'Xác nhận' })).toBeDisabled();
  await expectAccessible(page);
  await dialog.getByRole('combobox').click();
  // Lý do chỉ áp dụng cho phiếu thu (Sai số tiền) không hiện ở báo giá.
  await expect(page.getByRole('option', { name: 'Sai số tiền' })).toHaveCount(0);
  await page.getByRole('option', { name: 'Không đúng chính sách' }).click();
  await dialog.getByRole('button', { name: 'Xác nhận' }).click();
  await expect(page.getByText('Đã từ chối báo giá.').first()).toBeVisible();
  await expect(page.locator('b', { hasText: 'Lý do từ chối' })).toBeVisible();
  await expect(page.getByRole('alertdialog')).toHaveCount(0);
});

test('BH-02: menu Hành động có In (mờ, chưa làm) và Huỷ báo giá; có đơn đang xử lý thì hộp báo lỗi và không đóng', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.converted);
  await page.getByRole('button', { name: 'Hành động' }).click();
  const printItem = page.getByRole('menuitem', { name: /^In/ });
  await expect(printItem).toHaveAttribute('aria-disabled', 'true');
  await expect(printItem).toContainText('Có khi làm BH-03');
  await page.getByRole('menuitem', { name: 'Huỷ báo giá' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Huỷ báo giá' })).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Đóng' })).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Xác nhận huỷ' }).click();
  await expect(
    dialog.getByText('Báo giá đã có đơn đang xử lý, không huỷ được. Huỷ đơn trước.'),
  ).toBeVisible();
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Đóng' }).click();
  await expect(dialog).toHaveCount(0);
});

test('BH-02: Huỷ báo giá Từ chối có ghi chú; sau huỷ chỉ còn xem, hết mục Huỷ', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.rejected);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ báo giá' }).click();
  const dialog = page.getByRole('alertdialog');
  await dialog.getByLabel('Ghi chú').fill('Phụ huynh không quay lại');
  await dialog.getByRole('button', { name: 'Xác nhận huỷ' }).click();
  await expect(page.getByText('Đã huỷ báo giá.').first()).toBeVisible();
  await expect(page.getByText(/Báo giá đã huỷ: Phụ huynh không quay lại/)).toBeVisible();
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'Huỷ báo giá' })).toHaveCount(0);
  await expect(page.getByRole('menuitem', { name: /^In/ })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('button', { name: 'Gửi', exact: true })).toHaveCount(0);
});
