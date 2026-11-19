// CH-08 Chiến dịch marketing (anh Trường chốt 19/11): mọi vai trò vào được cổng CRM đều mở màn và tạo được chiến dịch. Dùng tài khoản giả sale.cs5;
// tên chiến dịch có dấu thời gian nên không trùng giữa các lần chạy.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test('sale.cs5: mở Chiến dịch marketing, tạo chiến dịch, tên trùng bị báo, tìm thấy trong danh sách', async ({
  page,
}) => {
  const name = `Chiến dịch thử ${Date.now().toString(36)}`;
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/cau-hinh/chien-dich');
  await expect(page.getByRole('heading', { level: 1, name: 'Chiến dịch marketing' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo chiến dịch' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo chiến dịch' });
  await dialog.getByLabel('Tên chiến dịch').fill(name);
  await dialog.getByRole('button', { name: 'Tạo', exact: true }).click();
  await expect(dialog).toBeHidden();
  await page.getByLabel('Tìm chiến dịch').fill(name);
  await expect(page.getByRole('cell', { name })).toBeVisible();
  // Tạo lại cùng tên: báo trùng, hộp vẫn mở.
  await page.getByRole('button', { name: 'Tạo chiến dịch' }).click();
  await dialog.getByLabel('Tên chiến dịch').fill(name.toUpperCase());
  await dialog.getByRole('button', { name: 'Tạo', exact: true }).click();
  await expect(dialog.getByText('Đã có chiến dịch trùng tên này.')).toBeVisible();
});
