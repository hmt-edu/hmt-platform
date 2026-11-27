// A-26-11 menu đợt 1: màn đã gộp thành tab không còn dòng menu riêng; vào qua tab của mục cha, đường dẫn cũ vẫn mở đúng.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, openCrmMenu } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD');

test('Không còn màn Hàng chờ xếp lớp: menu Ghi danh không có tab; đường dẫn cũ mở danh sách đã lọc', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  const menu = await openCrmMenu(page);
  await menu.getByRole('button', { name: 'Đào tạo', exact: true }).click();
  await expect(menu.getByRole('link', { name: 'Hàng chờ xếp lớp' })).toHaveCount(0);
  await menu.getByRole('link', { name: 'Ghi danh', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Ghi danh' })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Các màn cùng mục' })).toHaveCount(0);

  await page.goto('/crm/cho-xep-lop');
  await expect(page).toHaveURL(/\/crm\/ghi-danh\?loc=cho-xep-lop$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Ghi danh' })).toBeVisible();
});
