// A-26-11 menu đợt 1: màn đã gộp thành tab không còn dòng menu riêng; vào qua tab của mục cha, đường dẫn cũ vẫn mở đúng.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, openCrmMenu } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD');

test('Chờ xếp lớp là tab của Ghi danh; đường dẫn cũ vẫn mở', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  const menu = await openCrmMenu(page);
  await menu.getByRole('button', { name: 'Đào tạo', exact: true }).click();
  await expect(menu.getByRole('link', { name: 'Hàng chờ xếp lớp' })).toHaveCount(0);
  await menu.getByRole('link', { name: 'Ghi danh', exact: true }).click();

  const tabs = page.getByRole('navigation', { name: 'Các màn cùng mục' });
  await tabs.getByRole('link', { name: 'Chờ xếp lớp' }).click();
  await expect(page).toHaveURL(/\/crm\/cho-xep-lop$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Hàng chờ xếp lớp' })).toBeVisible();

  await page.goto('/crm/cho-xep-lop');
  await expect(tabs.getByRole('link', { name: 'Chờ xếp lớp' })).toHaveAttribute(
    'aria-current',
    'page',
  );
});
