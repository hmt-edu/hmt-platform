// GD-05 Điều chỉnh giờ ở bản ghi ghi danh: chỉ Trưởng cơ sở (Ghi danh · Duyệt), bắt buộc lý do; bớt quá quỹ giờ bị chặn (R-GD-18); sổ giờ chỉ thêm dòng (R-GD-04).
// Máy tính (màn Đào tạo chỉ có bản máy tính). Dữ liệu giả dựng bằng ghi-danh-seed.ts (ghi danh Đang học, quỹ 24 giờ).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, pickOption } from './helpers';
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

test('GD-05: CSKH không có nút Điều chỉnh giờ (thiếu quyền Ghi danh · Duyệt)', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/ghi-danh/${seed.learning.id}`);
  await expect(page.getByRole('heading', { level: 2, name: seed.learning.code })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Điều chỉnh giờ' })).toHaveCount(0);
});

test('GD-05 (G2): Trưởng cơ sở bớt quá trần thì bị chặn, cộng giờ cần Kế toán, bớt giờ kèm lý do thì sổ giờ có dòng Điều chỉnh', async ({
  page,
}) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto(`/crm/ghi-danh/${seed.learning.id}`);
  await page.getByRole('button', { name: 'Điều chỉnh giờ' }).click();
  const dialog = page.getByRole('dialog', { name: 'Điều chỉnh giờ' });
  const save = dialog.getByRole('button', { name: 'Thêm dòng điều chỉnh' });
  await expect(save).toBeDisabled();
  await dialog.getByLabel(/Số giờ/).fill('-1000');
  await pickOption(
    page,
    dialog.getByRole('combobox', { name: 'Lý do' }),
    'Sửa sai danh sách/điểm danh',
  );
  await expect(save).toBeEnabled();
  await save.click();
  // G2 (b): trần mỗi lần là tham số hours_adjust_max_per_call (mặc định 20 giờ), kiểm trước quỹ.
  await expect(dialog.getByText(/Mỗi lần chỉ điều chỉnh tối đa/)).toBeVisible();
  // G2 (c): cộng giờ cần Kế toán · Duyệt, Trưởng cơ sở bị chặn.
  await dialog.getByLabel(/Số giờ/).fill('2');
  await save.click();
  await expect(
    dialog.getByText('Bạn không có quyền thực hiện thao tác này ở cơ sở này.'),
  ).toBeVisible();
  // Bớt giờ trong trần và trong quỹ thì được.
  await dialog.getByLabel(/Số giờ/).fill('-2');
  await save.click();
  // Thông báo hiện cả ở khung toast và vùng đọc màn hình của Radix (chữ khớp 2 phần tử, strict mode): lấy phần tử đầu.
  await expect(page.getByText(/Đã điều chỉnh giờ/).first()).toBeVisible();
  await page.getByRole('button', { name: 'Sổ giờ', exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ghi-danh/${seed.learning.id}/so-gio$`));
  await expect(page.getByRole('table', { name: 'Sổ giờ' })).toContainText('Điều chỉnh');
});
