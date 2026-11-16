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

test('CSKH vào trang SLA thì không được lưu', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/cau-hinh/sla-ticket');
  await expect(
    page.getByText(/Bạn không có quyền|không tìm thấy|chỉ xem được/i).first(),
  ).toBeVisible();
});
