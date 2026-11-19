// Cụm Ghi danh: GD-01 danh sách, GD-02 bản ghi, GD-04 sổ giờ, GD-06 hàng chờ, GD-03 xếp lớp. Máy tính (màn Đào tạo ưu tiên máy tính). Dữ liệu giả dựng bằng ghi-danh-seed.ts.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { DB_URL } from './bao-gia-seed';
import { seedGhiDanh, type GhiDanhSeed } from './ghi-danh-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ghi danh giả).');
test.describe.configure({ mode: 'serial' });
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Đào tạo chỉ có bản máy tính.');
});

let seed: GhiDanhSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedGhiDanh(testInfo.project.name);
});

test('GD-01: danh sách ghi danh có đủ cột, tìm theo tên học sinh, mở bản ghi', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/ghi-danh');
  await expect(page.getByRole('heading', { level: 1, name: 'Ghi danh' })).toBeVisible();
  await page.getByRole('searchbox').fill(seed.learning.student);
  const table = page.getByRole('table', { name: 'Ghi danh' });
  await expect(table.getByRole('link', { name: seed.learning.code })).toBeVisible();
  const row = table.getByRole('row', { name: new RegExp(seed.learning.code) });
  await expect(row).toContainText('Đang học');
  await expect(row).toContainText(seed.classCode);
  await expect(row).toContainText('24');
  await expectAccessible(page);
  await table.getByRole('link', { name: seed.learning.code }).click();
  await expect(page.getByRole('heading', { level: 2, name: seed.learning.code })).toBeVisible();
});

test('GD-02, GD-04: bản ghi nêu quỹ giờ và lớp; Sổ giờ nêu dòng cấp giờ', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/ghi-danh/${seed.learning.id}`);
  await expect(page.getByRole('heading', { level: 2, name: seed.learning.code })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Quỹ giờ và lớp' })).toBeVisible();
  await expect(page.getByText('24 giờ')).toBeVisible();
  await expect(page.getByRole('table', { name: 'Dòng xếp lớp' })).toContainText(seed.classCode);
  // Không có nút "Tạo phiếu thu tái tục thủ công" (TT-03 đã bỏ) và ghi danh Đang học không có nút Xếp lớp.
  await expect(page.getByRole('button', { name: /tái tục/i })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xếp lớp', exact: true })).toHaveCount(0);
  // GD-02 (canvas GD02): ba tab «Quỹ giờ và lớp | Sổ giờ | Ticket liên quan»; tab Sổ giờ có bảng xem nhanh và nút mở sổ đầy đủ.
  await expect(page.getByRole('tab', { name: /^Ticket liên quan/ })).toBeVisible();
  await page.getByRole('tab', { name: 'Sổ giờ', exact: true }).click();
  await expect(page.getByRole('table', { name: 'Sổ giờ gần đây' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Mở sổ giờ đầy đủ' })).toBeVisible();
  await page.getByRole('button', { name: 'Sổ giờ', exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ghi-danh/${seed.learning.id}/so-gio$`));
  const ledger = page.getByRole('table', { name: 'Sổ giờ' });
  await expect(ledger).toContainText('Cấp từ phiếu thu');
  await expect(ledger).toContainText('+24');
});

test('GD-06, GD-03: hàng chờ chỉ có ghi danh Chờ xếp lớp; xếp một lớp lẻ thì rời hàng chờ', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/cho-xep-lop');
  await expect(page.getByRole('heading', { level: 1, name: 'Hàng chờ xếp lớp' })).toBeVisible();
  await page.getByRole('searchbox').fill(seed.tag);
  const table = page.getByRole('table', { name: 'Hàng chờ xếp lớp' });
  await expect(table.getByRole('link', { name: seed.waiting.code })).toBeVisible();
  // Ghi danh Đang học không vào hàng chờ (R-GD-05).
  await expect(table.getByRole('link', { name: seed.learning.code })).toHaveCount(0);
  await expect(table.getByRole('row', { name: new RegExp(seed.waiting.code) })).toContainText(
    'Chưa có lớp',
  );
  await table
    .getByRole('row', { name: new RegExp(seed.waiting.code) })
    .getByRole('button', { name: 'Xếp lớp' })
    .click();
  const dialog = page.getByRole('dialog', { name: 'Xếp lớp cho ghi danh' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('radio', { name: 'Một lớp lẻ' }).click();
  await dialog.getByRole('radio', { name: new RegExp(seed.classCode) }).check();
  await expect(dialog.getByRole('button', { name: 'Xếp lớp', exact: true })).toBeEnabled();
  await dialog.getByRole('button', { name: 'Xếp lớp', exact: true }).click();
  await expect(page.getByText('Đã xếp lớp.', { exact: true })).toBeVisible();
  await expect(table.getByRole('link', { name: seed.waiting.code })).toHaveCount(0);
  // Sang danh sách: ghi danh đã Đã xếp lớp.
  await page.goto('/crm/ghi-danh');
  await page.getByRole('searchbox').fill(seed.waiting.student);
  await expect(
    page
      .getByRole('table', { name: 'Ghi danh' })
      .getByRole('row', { name: new RegExp(seed.waiting.code) }),
  ).toContainText('Đã xếp lớp');
});
