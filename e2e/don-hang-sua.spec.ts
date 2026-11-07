// UI-O3 Sửa đơn Nháp (anh chốt 06/11: B1, Q-29, Q-31): đơn bị từ chối có "Sửa đơn" là nút chính, "Trình duyệt" phụ kèm nhắc lý do; trình khi chưa sửa thì hỏi lại;
// sửa số giờ, điều khoản, bỏ dòng; đơn chuyển từ báo giá cũng sửa được và nhật ký ghi "Đơn đã sửa so với báo giá"; dòng thời gian hiện tên điều khoản,
// không hiện mã nội bộ. Máy tính (điện thoại chỉ đọc, Đ248). Dữ liệu giả dựng bằng don-hang-seed.ts.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, expectAccessible, isPhone } from './helpers';
import {
  DB_URL,
  clearMark,
  editSetupOf,
  seedOrderRecords,
  type SeededRecords,
} from './don-hang-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededRecords;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seedOrderRecords(editSetupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(editSetupOf(testInfo.project.name).mark);
});

async function openOrder(page: Page, account: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Đơn hàng' })
    : page.getByRole('table', { name: 'Đơn hàng' });
  await list.getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('Điện thoại chỉ đọc: không có nút Sửa đơn', async ({ page }, testInfo) => {
  test.skip(!isPhone(page), 'Chỉ kiểm bản điện thoại.');
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.records.rejected);
  await expect(page.getByRole('button', { name: 'Sửa đơn' })).toHaveCount(0);
});

test('Đơn bị từ chối: "Sửa đơn" là nút chính, Trình duyệt phụ kèm nhắc lý do; trình khi chưa sửa thì hỏi lại', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.records.rejected);
  await expect(page.getByRole('status').filter({ hasText: 'Đơn bị từ chối' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa đơn' }).first()).toBeVisible();
  await expect(page.getByText(/Lý do từ chối chưa sửa/)).toBeVisible();
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Trình lại đơn chưa sửa' });
  await expect(dialog.getByText('Đơn chưa sửa từ lần bị từ chối. Vẫn trình?')).toBeVisible();
  await dialog.getByRole('button', { name: 'Quay lại sửa' }).click();
  await expect(dialog).toHaveCount(0);
  await expectAccessible(page);
});

test('Sửa đơn bị từ chối: đổi số giờ, chọn điều khoản, lưu; dòng thời gian hiện tên điều khoản; sau khi sửa Trình duyệt thành nút chính', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.records.rejected);
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  const hours = page.getByLabel('Số giờ dòng 1');
  await expect(hours).toBeVisible();
  await hours.fill('0');
  await expect(page.getByText('Nhập số lượng lớn hơn 0.')).toBeVisible();
  await hours.fill('9');
  await page.getByLabel('Kiểu thanh toán').click();
  await page.getByRole('option', { name: /Chia ba đợt/ }).click();
  // Đơn có hai dòng: bỏ dòng 2 được; còn một dòng thì nút Bỏ dòng mờ (đơn cần ít nhất một dòng).
  await page.getByRole('button', { name: 'Bỏ dòng' }).nth(1).click();
  await expect(page.getByRole('button', { name: 'Bỏ dòng' })).toBeDisabled();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu đơn.').first()).toBeVisible();
  await expect(page.getByRole('tab', { name: /Dòng đơn/ })).toContainText('1');
  // Dòng thời gian bên phải (Q-51): một mục "Sửa đơn" cho lần lưu, mỗi thay đổi một dòng (giá trị cũ → mới, tên điều khoản, không mã nội bộ),
  // tổng tiền ở dòng cuối (cũ → mới khi sự kiện liền trước đã có ảnh chụp; đơn dựng sẵn trong seed thì chỉ số mới).
  const timeline = page.getByRole('region', { name: 'Ghi chú & hoạt động' });
  await expect(timeline.getByText('Sửa đơn', { exact: true })).toBeVisible();
  await expect(timeline.getByText(/dòng 1 .*số giờ .* → 9/)).toBeVisible();
  await expect(timeline.getByText(/điều khoản thanh toán .* → .*Chia ba đợt/)).toBeVisible();
  await expect(timeline.getByText(/Tổng tiền: .* đ/).first()).toBeVisible();
  await expect(
    page.getByText(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/),
  ).toHaveCount(0);
  // Đã sửa sau lần từ chối: không còn dòng nhắc "chưa sửa".
  await expect(page.getByText(/Lý do từ chối chưa sửa/)).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Trình duyệt' })).toBeVisible();
});

test('Đơn chuyển từ báo giá Nháp sửa được; bỏ dòng; nhật ký ghi "Đơn đã sửa so với báo giá"', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.orders.nhap);
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  await expect(page.getByText(/Đơn chuyển từ báo giá/)).toBeVisible();
  await page.getByLabel('Số giờ dòng 1').fill('11');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu đơn.').first()).toBeVisible();
  const timeline = page.getByRole('region', { name: 'Ghi chú & hoạt động' });
  await expect(timeline.getByText(/Sửa đơn \(đã sửa so với báo giá .*\)/)).toBeVisible();
  await expect(timeline.getByText(/dòng 1 .*số giờ .* → 11/)).toBeVisible();
});

test('Q-46: người duyệt mở hộp Duyệt thấy "Đơn đã sửa so với báo giá" kèm giá trị cũ, mới (chỉ để xem xét, không chặn)', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  // Đơn từ báo giá đã sửa ở bài trước (chạy tuần tự) được trình bằng cơ sở dữ liệu: tài khoản giả dùng chung không có quản lý trực tiếp,
  // người duyệt đã chốt là Trưởng cơ sở.
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `update app.sales_order set status_code = 'DA_TRINH', approval_route = 'QUAN_LY', submitted_at = now(),
              assigned_approver_id = (select id from app.user_account where login_name = $2) where code = $1`,
      [seeded.orders.nhap, `${setup.manager}@${DOMAIN}`],
    );
    await db.query('commit');
  } finally {
    await db.end();
  }
  await openOrder(page, setup.manager, seeded.orders.nhap);
  await page.getByRole('button', { name: 'Duyệt', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Duyệt đơn hàng' });
  await expect(dialog.getByText('Đơn đã sửa so với báo giá.')).toBeVisible();
  await expect(dialog.getByText(/dòng 1 .*số giờ .* → 11/)).toBeVisible();
  await expect(dialog.getByText(/không chặn duyệt/)).toBeVisible();
});

test('Đơn đã trình không có nút Sửa đơn', async ({ page }, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.orders.dtrinh);
  await expect(page.getByRole('button', { name: 'Sửa đơn' })).toHaveCount(0);
});
