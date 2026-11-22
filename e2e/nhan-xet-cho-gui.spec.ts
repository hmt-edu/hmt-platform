// CS-16 Nhận xét chờ gửi phụ huynh (migration 622): CSKH mở được màn, thấy hai chip; giáo viên không có mục này ở cổng CRM.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');

test('CS-16: CSKH mở Nhận xét chờ gửi, có ô tìm kiếm, không báo thiếu quyền; trang đạt kiểm truy cập', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs1');
  await page.goto('/crm/nhan-xet-cho-gui');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Nhận xét chờ gửi phụ huynh' }),
  ).toBeVisible();
  await expect(page.getByPlaceholder('Tìm tên em hoặc mã lớp…')).toBeVisible();
  await expect(page.getByText('Bạn không có quyền xem trang này')).toHaveCount(0);
  await expectAccessible(page);
});
