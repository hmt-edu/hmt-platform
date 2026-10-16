// PR 3: khuôn danh sách (K1), Kanban (K2), Calendar (K5) trên trang mẫu /dev/danh-sach (dữ liệu giả).
import { expect, test } from '@playwright/test';
import { PASSWORD, expectAccessible, isPhone, loginStaff } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test.beforeEach(async ({ page }) => {
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/dev/danh-sach');
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
});

test('K1: lọc nhanh (cùng nhóm HOẶC, khác nhóm VÀ), chip, xoá tất cả', async ({ page }) => {
  await expectAccessible(page);
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Cơ hội' })
    : page.getByRole('table', { name: 'Cơ hội' });
  await expect(list.getByText('Đặng Minh Châu')).toBeVisible();

  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await page.getByLabel('Tôi là sale').check();
  await page.getByLabel('Hôm nay').check();
  await page.getByLabel('Quá hạn chăm').check();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');

  // (Tôi là sale) VÀ (Hôm nay HOẶC Quá hạn chăm): chỉ còn các cơ hội của Trần Thu Hà có lịch hôm nay hoặc quá hạn.
  await expect(page.getByRole('button', { name: /Bỏ điều kiện: Của tôi/ })).toBeVisible();
  await expect(
    page.getByRole('button', { name: /Bỏ điều kiện: Lịch hẹn: Hôm nay hoặc Quá hạn chăm/ }),
  ).toBeVisible();
  await expect(list.getByText('Phạm Minh Khôi')).toHaveCount(0); // của Nguyễn Hoàng Long
  await expect(list.getByText('Vũ Gia Bảo')).toBeVisible(); // quá hạn, của Trần Thu Hà
  await expect(list.getByText('Lý Thanh Hương')).toHaveCount(0); // chưa có lịch hẹn

  await page.getByRole('button', { name: 'Xoá tất cả' }).click();
  await expect(page.getByRole('button', { name: /Bỏ điều kiện/ })).toHaveCount(0);
  await expect(list.getByText('Phạm Minh Khôi')).toBeVisible();
});

test('K1: Group By hai cấp, gập mở nhóm; Cột; Lọc nâng cao', async ({ page }) => {
  await page.getByRole('button', { name: 'Group By', exact: true }).click();
  await page.getByRole('button', { name: /^Stage/ }).click();
  await page.getByRole('button', { name: /^Source/ }).click();
  // Đủ hai cấp thì các trường còn lại mờ.
  await expect(page.getByRole('button', { name: /^Cơ sở/ })).toHaveAttribute(
    'aria-disabled',
    'true',
  );
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
  await expect(
    page.getByRole('button', { name: /Bỏ điều kiện: Group By: Stage › Source/ }),
  ).toBeVisible();

  const group = page.getByRole('button', {
    name: /L4 Khách hàng tiềm năng\(2\)|L4 Khách hàng tiềm năng \(2\)/,
  });
  await expect(group).toHaveAttribute('aria-expanded', 'true');
  await group.click();
  await expect(group).toHaveAttribute('aria-expanded', 'false');
  await expectAccessible(page);

  // Lọc nâng cao: Source là Website.
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await page.getByRole('button', { name: /Lọc nâng cao/ }).click();
  const dialog = page.getByRole('dialog', { name: 'Lọc nâng cao' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Thêm điều kiện' }).click();
  await expectAccessible(page);
  await dialog.getByRole('combobox', { name: 'Giá trị, điều kiện 1' }).click();
  await page.getByRole('option', { name: 'Website' }).click();
  await dialog.getByRole('button', { name: 'Áp dụng' }).click();
  await expect(page.getByRole('button', { name: /Bỏ điều kiện: Source là Website/ })).toBeVisible();
});

test('K2 Kanban: kéo thẻ chỉ đi tới; cột hệ thống không thả tay vào được', async ({ page }) => {
  await page.getByRole('button', { name: 'Kanban' }).click();
  const l4 = page.getByRole('region', { name: /^L4 Khách hàng tiềm năng/ });
  const card = l4.getByRole('listitem').filter({ hasText: 'CO000121' });
  await expect(card).toBeVisible();

  // Đi lùi bị chặn, báo lý do.
  await card.getByRole('button', { name: /Chuyển giai đoạn: Toán lớp 9 · Lê Gia Huy/ }).click();
  await page.getByRole('menuitem', { name: 'Chuyển sang L2 Chưa liên hệ được' }).click();
  await expect(page.getByText('Chỉ đi tới, không lùi giai đoạn.').first()).toBeVisible();

  // Cột hệ thống (L6) bị chặn.
  await card.getByRole('button', { name: /Chuyển giai đoạn/ }).click();
  await page.getByRole('menuitem', { name: 'Chuyển sang L6 Đã tham gia test' }).click();
  await expect(page.getByText(/do hệ thống tự chuyển/).first()).toBeVisible();

  // Đi tới được.
  await card.getByRole('button', { name: /Chuyển giai đoạn/ }).click();
  await page.getByRole('menuitem', { name: 'Chuyển sang L5 Đồng ý tham gia test' }).click();
  await expect(
    page.getByRole('region', { name: /^L5 Đồng ý tham gia test/ }).getByText('CO000121'),
  ).toBeVisible();
  await expectAccessible(page);
});

test('K5 Calendar: tuần, tháng, ngày; bấm sự kiện mở thao tác', async ({ page }) => {
  await page.getByRole('button', { name: 'Calendar' }).click();
  const modeGroup = page.getByRole('group', { name: 'Kiểu xem lịch' });
  await expect(modeGroup.getByRole('button', { name: 'Tuần' })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expectAccessible(page);

  await modeGroup.getByRole('button', { name: 'Tháng' }).click();
  await expect(page.getByRole('heading', { level: 2, name: /^Tháng \d+\/\d{4}$/ })).toBeVisible();
  await modeGroup.getByRole('button', { name: 'Ngày' }).click();
  await page
    .getByRole('group', { name: 'Nhóm lịch' })
    .getByRole('button', { name: 'Theo người' })
    .click();
  await expect(page.getByText('Trần Thu Hà').first()).toBeVisible();
  await page
    .getByRole('group', { name: 'Nhóm lịch' })
    .getByRole('button', { name: 'Tất cả' })
    .click();

  await modeGroup.getByRole('button', { name: 'Tuần' }).click();
  const event = page
    .getByRole('button', { name: /^(Gọi điện|Zalo|Gặp trực tiếp|Thu tiền): / })
    .first();
  await event.click();
  await expect(page.getByRole('button', { name: 'Hoàn thành', exact: true })).toBeVisible();
  await page.keyboard.press('Escape');
});
