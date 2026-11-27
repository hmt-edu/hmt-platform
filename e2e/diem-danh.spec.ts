// Màn «Điểm danh», tab Theo buổi: bấm trạng thái là tự lưu, chọn nhiều gán cùng lúc, đường cũ chuyển hướng. Máy tính (cổng CRM).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs } from './helpers';
import { seedAttendance, type AttendanceSeed } from './gv-diem-danh-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');
test.skip(({ isMobile }) => isMobile, 'Cổng CRM ưu tiên máy tính.');
test.describe.configure({ mode: 'serial' });

let seed: AttendanceSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedAttendance(testInfo.project.name);
});

test('Theo buổi: bấm một nút là lưu; chọn hai em gán cùng lúc', async ({ page }) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/diem-danh-trong-ngay');
  await expect(page).toHaveURL(/\/crm\/diem-danh$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Điểm danh' })).toBeVisible();

  // Nhiều bài khác cũng tạo buổi hôm nay: tìm đúng buổi của bài này qua đường dẫn, lật trang nếu cần.
  const card = page.locator(`div:has(> div > a[href="/crm/buoi-hoc/${seed.chot}"])`);
  const next = page.getByRole('button', { name: 'Trang sau' });
  await expect(page.getByRole('list', { name: /^Học sinh / }).first()).toBeVisible();
  while ((await card.count()) === 0 && (await next.isEnabled())) await next.click();
  const first = card.getByRole('group', { name: `Điểm danh ${seed.names[1]}` });
  await first.getByRole('button', { name: 'Đi muộn', exact: true }).click();
  await expect(first.getByRole('button', { name: 'Đi muộn', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );

  for (const name of [seed.names[0], seed.names[2]]) {
    await card.getByRole('checkbox', { name: `Chọn ${name}` }).check();
  }
  await page
    .getByText('Gán cùng lúc:')
    .locator('..')
    .getByRole('button', { name: 'Vắng có phép', exact: true })
    .click();
  for (const name of [seed.names[0], seed.names[2]]) {
    await expect(
      card
        .getByRole('group', { name: `Điểm danh ${name}` })
        .getByRole('button', { name: 'Vắng có phép', exact: true }),
    ).toHaveAttribute('aria-pressed', 'true');
  }
});
