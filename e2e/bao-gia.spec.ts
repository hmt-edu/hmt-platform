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
  await expect(page.getByText('1–4 / 4')).toBeVisible();
}

function list(page: Page) {
  return isPhone(page)
    ? page.getByRole('list', { name: 'Báo giá' })
    : page.getByRole('table', { name: 'Báo giá' });
}

async function pickFilters(page: Page, labels: string[]) {
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
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
  await expect(page.getByText('1–4 / 4')).toBeVisible();
  await pickFilters(page, ['Nháp']);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.code.draft)).toBeVisible();
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
