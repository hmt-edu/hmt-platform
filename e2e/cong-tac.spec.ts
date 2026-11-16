// QT-10 Công tắc tính năng theo cơ sở: bảng phân hệ × cơ sở, bật rồi tắt qua hộp xác nhận. Chỉ bản máy tính (Quản trị không có bản điện thoại).
// Admin giả quantri.cs5 (hai bước thiết lập ngay trong bài). Dùng phân hệ Báo cáo ở CS1 (không có màn nào kiểm) rồi trả về như cũ sau bài.
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

async function sql<T = unknown>(query: string): Promise<T[]> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return (await db.query(query)).rows as T[];
  } finally {
    await db.end();
  }
}

// Trả công tắc Báo cáo ở CS1 về Tắt (đặt enabled = false; công tắc không cho xoá).
async function restore() {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query("select set_config('hmt.migration', 'on', false)");
    await db.query(
      "update app.feature_flag set enabled = false where module_code = 'BAO_CAO' and branch_id = (select id from app.branch where code = 'CS1')",
    );
  } finally {
    await db.end();
  }
}
test.beforeAll(restore);
test.afterAll(restore);

async function open(page: Page) {
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/cong-tac');
  await expect(page.getByRole('heading', { level: 1, name: 'Công tắc tính năng' })).toBeVisible();
}

test('Bảng phân hệ × năm cơ sở; Bán hàng đang bật ở CS5', async ({ page }) => {
  await open(page);
  const table = page.getByRole('table', { name: /Công tắc tính năng theo phân hệ/ });
  for (const cs of ['CS1', 'CS2', 'CS3', 'CS4', 'CS5']) {
    await expect(table.getByRole('columnheader', { name: cs })).toBeVisible();
  }
  await expect(table.getByRole('button', { name: /^Bán hàng ở CS5: đang bật/ })).toBeVisible();
  await expectAccessible(page);
});

test('Bật Báo cáo ở CS1 qua hộp xác nhận, rồi tắt lại; DB đổi đúng', async ({ page }) => {
  test.setTimeout(90_000);
  await open(page);
  await page.getByRole('button', { name: /^Báo cáo ở CS1: đang tắt/ }).click();
  const confirm = page.getByRole('alertdialog');
  await expect(confirm.getByText('Bật phân hệ cho cơ sở')).toBeVisible();
  await confirm.getByRole('button', { name: 'Bật', exact: true }).click();
  await expect(page.getByText('Đã bật phân hệ.').first()).toBeVisible();
  const on = await sql<{ enabled: boolean }>(
    "select enabled from app.feature_flag where module_code = 'BAO_CAO' and branch_id = (select id from app.branch where code = 'CS1')",
  );
  expect(on[0]?.enabled).toBe(true);
  await page.getByRole('button', { name: /^Báo cáo ở CS1: đang bật/ }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Tắt', exact: true }).click();
  await expect(page.getByText('Đã tắt phân hệ.').first()).toBeVisible();
});
