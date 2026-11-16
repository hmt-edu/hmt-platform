// Kiểm truy cập âm tính (CHUNG-16, R-HT quản trị chỉ Admin): người không có quyền Quản trị mở thẳng đường dẫn các màn Quản trị
// phải thấy trang «Bạn không có quyền xem trang này», không thấy dữ liệu, không có mục Quản trị trong menu.
// Bổ sung cho auth.spec (chỉ thử màn Người dùng) và nhận xét của Tester ở #43 (ma trận quyền chưa có bài người không phải Admin).
// Dùng tài khoản giả không cần hai bước: sale.cs5, cskh.cs5, truongcs.cs5. Không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, openCrmMenu } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

const ACCOUNTS = ['sale.cs5', 'cskh.cs5', 'truongcs.cs5'];
const ADMIN_PAGES = [
  'quan-tri/ma-tran-quyen',
  'quan-tri/tham-so',
  'quan-tri/cong-tac',
  'quan-tri/danh-muc',
  'quan-tri/nguoi-dung',
  'quan-tri/nhap-du-lieu',
];

for (const account of ACCOUNTS) {
  test(`${account}: mở thẳng các màn Quản trị thì báo không có quyền, menu không có mục Quản trị`, async ({
    page,
  }) => {
    await enterAs(page, account);
    for (const slug of ADMIN_PAGES) {
      await page.goto(`/crm/${slug}`);
      await expect(
        page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
        `${account} mở ${slug}`,
      ).toBeVisible();
    }
    await page.goto('/crm');
    const menu = await openCrmMenu(page);
    await expect(menu.getByRole('button', { name: 'Quản trị', exact: true })).toHaveCount(0);
  });
}
