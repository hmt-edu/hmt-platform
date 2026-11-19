// Quản trị viên vào được mọi màn để xem (anh Trường chốt 21/11/2026): Hàng chờ kế toán duyệt, Ticket, Tổng quan Ban giám đốc không còn bị chặn.
import { expect, test } from '@playwright/test';
import { enterAsAdmin } from './helpers';

test('Quản trị viên mở Hàng chờ kế toán duyệt, Ticket, Tổng quan Ban giám đốc (không báo «Không có quyền»)', async ({
  page,
}) => {
  await enterAsAdmin(page, 'quantri.cs5');
  for (const path of ['/crm/cho-ke-toan-duyet', '/crm/ticket', '/crm/bao-cao/tong-quan']) {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText('Bạn không có quyền xem trang này')).toHaveCount(0);
    await expect(page.getByText('Phân hệ chưa bật ở cơ sở này')).toHaveCount(0);
  }
});
