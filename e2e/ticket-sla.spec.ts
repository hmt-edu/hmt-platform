// CSN-09 Cấu hình SLA: Admin sửa hạn xử lý, thấy «n thay đổi chưa lưu», số không hợp lệ chặn nút Lưu, lưu xong tải lại vẫn còn; CSKH không có menu.
// Dùng Admin giả quantri.cs1 (chưa file bài nào khác dùng). Trả giá trị về như cũ sau khi thử.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, enterAsAdmin } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

const FIELD = 'Xử lý xong, Khiếu nại Thường';

test('Admin sửa hạn xử lý Khiếu nại Thường rồi lưu; tải lại vẫn còn', async ({ page }) => {
  await enterAsAdmin(page, 'quantri.cs1');
  await page.goto('/crm/cau-hinh/sla-ticket');
  await expect(page.getByRole('heading', { level: 1, name: 'Cấu hình SLA' })).toBeVisible();
  const field = page.getByRole('textbox', { name: FIELD });
  const original = await field.inputValue();
  const next = String(Number(original) + 5);
  const save = page.getByRole('button', { name: 'Lưu', exact: true });
  await expect(save).toBeDisabled();
  // Số không hợp lệ: nút Lưu vẫn mờ.
  await field.fill('0');
  await expect(save).toBeDisabled();
  await field.fill(next);
  await expect(page.getByText('1 thay đổi chưa lưu')).toBeVisible();
  await save.click();
  await expect(page.getByText('Đã lưu cấu hình SLA.', { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole('textbox', { name: FIELD })).toHaveValue(next);
  // Trả về như cũ.
  await page.getByRole('textbox', { name: FIELD }).fill(original);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu cấu hình SLA.', { exact: true })).toBeVisible();
});

test('Nhóm ticket: Admin thêm nhóm và nhóm con; thiếu tên thì báo tại ô', async ({
  page,
}, testInfo) => {
  const tag = `E2E${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  await enterAsAdmin(page, 'quantri.cs1');
  await page.goto('/crm/cau-hinh/nhom-ticket');
  await expect(page.getByRole('heading', { level: 1, name: 'Cấu hình ticket' })).toBeVisible();
  await page.getByRole('button', { name: 'Thêm nhóm', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Thêm nhóm' });
  await dialog.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(dialog.getByText('Nhập tên.')).toBeVisible();
  await dialog.getByLabel('Mã').fill(tag);
  await dialog.getByLabel('Tên').fill(`Nhóm thử ${tag}`);
  await dialog.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByRole('heading', { name: `Nhóm thử ${tag}` })).toBeVisible();
  const section = page.getByRole('region', { name: `Nhóm thử ${tag}` });
  await section.getByRole('button', { name: 'Thêm nhóm con' }).click();
  const sub = page.getByRole('dialog', { name: 'Thêm nhóm con' });
  await sub.getByLabel('Mã').fill(`${tag}_A`);
  await sub.getByLabel('Tên').fill(`Nhóm con ${tag}`);
  await sub.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(section.getByText(`Nhóm con ${tag}`)).toBeVisible();
});

test('CSKH vào trang SLA thì không được lưu', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/cau-hinh/sla-ticket');
  await expect(
    page.getByText(/Bạn không có quyền|không tìm thấy|chỉ xem được/i).first(),
  ).toBeVisible();
});
