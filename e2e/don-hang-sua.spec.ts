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

test('Đơn bị từ chối (Q-49, Q-58): Sửa đơn ở thanh tiêu đề, nút chuyển giai đoạn là Trình lại; trình khi chưa sửa thì hỏi lại, không chặn', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.records.rejected);
  // Q-77: không còn khối đỏ "Đơn bị từ chối"; trạng thái ở thẻ Nháp · bị từ chối.
  await expect(page.getByRole('status').filter({ hasText: 'Đơn bị từ chối' })).toHaveCount(0);
  await expect(page.getByText('Nháp · bị từ chối').first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa đơn' }).first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toBeVisible();
  await expect(page.getByText(/Nhánh khác: Từ chối/)).toBeVisible();
  // Đơn của Sale chưa có quản lý nên nút mờ (aria-disabled, Q-77) nhưng vẫn bấm được: Playwright coi aria-disabled là chưa bật nên ép bấm.
  await page.getByRole('button', { name: 'Trình lại' }).click({ force: true });
  const dialog = page.getByRole('alertdialog', { name: /^Trình lại đơn DH-/ });
  await expect(dialog.getByText('Đơn chưa sửa từ lần bị từ chối. Vẫn trình?')).toBeVisible();
  await expect(dialog.getByText(/Lần từ chối: .*Không chặn: bấm Vẫn trình/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Vẫn trình' })).toBeVisible();
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
  // Q-163 (khung BH05_nhap_xem): Đơn Xem cũng có câu trần dưới bảng (đơn chưa vượt trần: chữ thường, không hộp vàng).
  const capText =
    /^Ưu đãi cộng dồn; giờ tặng quy ra % tính vào trần \d+%\. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được\.$/;
  await expect(page.getByText(capText)).toBeVisible();
  await expect(page.getByRole('status').filter({ hasText: capText })).toHaveCount(0);
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  // Q-49: đang sửa thì thanh tiêu đề có Lưu (nút chính), Huỷ, Hành động; nút trình khoá kèm "Lưu hoặc Huỷ rồi mới trình duyệt".
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Huỷ', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hành động' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình lại' })).toBeDisabled();
  await expect(page.getByText('Lưu hoặc Huỷ rồi mới trình duyệt.')).toBeVisible();
  // Q-50: bảng giữ đủ cột như khi xem (kể cả Mã lớp, Ngày vào lớp để trống chờ Đào tạo); chưa đổi gì thì chưa có dòng "Chưa tính lại".
  const grid = page.getByRole('table', { name: 'Dòng đơn đang sửa' });
  for (const name of [
    'Học sinh',
    'Sản phẩm',
    'Hình thức',
    'Mã lớp',
    'Ngày vào lớp',
    'Số lượng',
    'Đơn giá',
    'Ưu đãi',
    'Tổng %',
    'Giảm',
    'Thành tiền',
  ])
    await expect(grid.getByRole('columnheader', { name, exact: true })).toBeVisible();
  await expect(page.getByText('Chưa tính lại, bấm Lưu để cập nhật.')).toHaveCount(0);
  // Khung BH05_chip_*: câu trần luôn hiện dưới bảng khi sửa (hộp vàng chỉ khi bản đã lưu vượt trần).
  await expect(
    page.getByText(
      /^Ưu đãi cộng dồn; giờ tặng quy ra % tính vào trần \d+%\. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được\.$/,
    ),
  ).toBeVisible();
  // Quy tắc lưới một dòng một hàng: tên học sinh, sản phẩm, tiêu đề cột không xuống dòng (bảng cuộn ngang).
  for (const row of await grid.getByRole('row').all()) {
    expect((await row.boundingBox())?.height ?? 999).toBeLessThan(110);
  }
  const hours = page.getByLabel('Số giờ dòng 1');
  await expect(hours).toBeVisible();
  await hours.fill('0');
  await expect(page.getByText('Nhập số lượng lớn hơn 0.')).toBeVisible();
  await hours.fill('9');
  // Q-50, Q-56: đổi số giờ thì dòng "Chưa tính lại" hiện ngay trên bảng; giao diện không tính tiền.
  await expect(page.getByText('Chưa tính lại, bấm Lưu để cập nhật.')).toBeVisible();
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
  // Dòng thời gian mặc định tab Ghi chú: sự kiện hệ thống xem ở «Tất cả».
  await timeline.getByRole('button', { name: 'Tất cả', exact: true }).click();
  await expect(timeline.getByText('Sửa đơn', { exact: true })).toBeVisible();
  await expect(timeline.getByText(/dòng 1 .*số giờ .* → 9/)).toBeVisible();
  await expect(timeline.getByText(/điều khoản thanh toán .* → .*Chia ba đợt/)).toBeVisible();
  await expect(timeline.getByText(/Tổng tiền: .* đ/).first()).toBeVisible();
  await expect(
    page.getByText(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/),
  ).toHaveCount(0);
  // Đã sửa sau lần từ chối: không còn dòng nhắc "chưa sửa".
  // Q-77: đơn của Sale chưa có quản lý nên nút mờ (aria-disabled) nhưng không bị khoá thật (không có thuộc tính disabled).
  await expect(page.getByRole('button', { name: 'Trình lại' })).not.toHaveAttribute(
    'disabled',
    /.*/,
  );
  await expect(page.getByText('Chưa tính lại, bấm Lưu để cập nhật.')).toHaveCount(0);
});

test('Thêm dòng khi sửa (Q-67): chọn gói, em, số lượng; Lưu thì máy chủ tính giá và nhật ký ghi "thêm dòng N (mã gói)"', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  test.setTimeout(90_000);
  const setup = editSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, seeded.records.rejected);
  await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
  await page.getByRole('button', { name: 'Thêm dòng' }).click();
  const dialog = page.getByRole('dialog', { name: 'Chọn gói' });
  await dialog
    .getByRole('button', { name: /LC-TOAN-K09/ })
    .first()
    .click();
  await expect(dialog).toHaveCount(0);
  // Dòng mới chưa có giá: chọn em và số lượng, Lưu bị khoá tới khi hợp lệ (lỗi tại chỗ).
  await expect(page.getByText('Chọn học sinh.')).toBeVisible();
  await page.getByRole('combobox', { name: 'Học sinh dòng mới 1' }).click();
  await page.getByRole('option').first().click();
  await expect(page.getByText('Nhập số lượng lớn hơn 0.')).toBeVisible();
  await page.getByLabel('Số lượng dòng mới 1').fill('3');
  // Q-69: chọn chiết khấu ngay lúc thêm (loại, %), một lần Lưu là xong; máy chủ tính.
  await page.getByRole('combobox', { name: 'Thêm chính sách ưu đãi dòng mới 1' }).click();
  await page.getByRole('option', { name: 'Giảm thương lượng' }).click();
  await page.getByLabel('Giá trị Giảm thương lượng dòng mới 1').fill('5');
  await expect(page.getByText('Chưa tính lại, bấm Lưu để cập nhật.')).toBeVisible();
  // Chip Ưu đãi linh hoạt (R-V2-45, Q-151): vượt hạn mức 5% thì chữ đỏ dưới chip và Lưu mờ; bỏ chip (✕) thì Lưu mở lại.
  await page.getByRole('combobox', { name: 'Thêm chính sách ưu đãi dòng mới 1' }).click();
  await page.getByRole('option', { name: 'Ưu đãi linh hoạt' }).click();
  await page.getByLabel('Giá trị Ưu đãi linh hoạt dòng mới 1').fill('9');
  await expect(page.getByText('Ưu đãi linh hoạt tối đa 5%')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Bỏ Ưu đãi linh hoạt khỏi dòng mới 1' }).click();
  await expect(page.getByText('Ưu đãi linh hoạt tối đa 5%')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeEnabled();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu đơn.').first()).toBeVisible();
  const timeline = page.getByRole('region', { name: 'Ghi chú & hoạt động' });
  // Dòng thời gian mặc định tab Ghi chú: sự kiện hệ thống xem ở «Tất cả».
  await timeline.getByRole('button', { name: 'Tất cả', exact: true }).click();
  await expect(
    timeline.getByText(/thêm dòng \d+ \(LC-TOAN-K09\): số giờ 3, ưu đãi 5%/),
  ).toBeVisible();
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
  // Dòng thời gian mặc định tab Ghi chú: sự kiện hệ thống xem ở «Tất cả».
  await timeline.getByRole('button', { name: 'Tất cả', exact: true }).click();
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

// Q-72, Q-73: lưới dòng là bảng MỘT HÀNG MỘT DÒNG, chữ không xuống hàng, cột không vừa thì cuộn ngang trong khung; trang không tràn ngang.
// Gốc lỗi cũ: chữ sr-only của cột "Bỏ dòng" thoát khỏi vùng cuộn, ở 1280 cả trang tràn 90px.
for (const width of [1440, 1280]) {
  test(`Lưới dòng đơn ${width}px: không tràn trang, chữ không xuống hàng, cuộn ngang trong khung (xem và sửa)`, async ({
    page,
  }, testInfo) => {
    test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
    test.setTimeout(90_000);
    const setup = editSetupOf(testInfo.project.name);
    await page.setViewportSize({ width, height: 900 });
    await openOrder(page, setup.sale, seeded.records.rejected);
    const pageOverflow = () =>
      page.evaluate<number>(
        'document.documentElement.scrollWidth - document.documentElement.clientWidth',
      );
    // Xem: bảng "Dòng đơn" nằm trong vùng cuộn, mỗi dòng một hàng (cao dưới 70px), tên em và sản phẩm không xuống hàng.
    expect(await pageOverflow()).toBeLessThanOrEqual(0);
    const view = page.getByRole('table', { name: 'Dòng đơn' });
    for (const row of await view
      .getByRole('row')
      .all()
      .then((r) => r.slice(1))) {
      expect((await row.boundingBox())?.height ?? 999).toBeLessThan(70);
    }
    await page.getByRole('button', { name: 'Sửa đơn' }).first().click();
    const grid = page.getByRole('table', { name: 'Dòng đơn đang sửa' });
    await expect(grid).toBeVisible();
    expect(await pageOverflow()).toBeLessThanOrEqual(0);
    // Cột cuối (Thành tiền) có thể nằm ngoài khung nhưng cuộn tới được; khung cuộn không rộng hơn thẻ chứa nó.
    await grid
      .getByRole('columnheader', { name: 'Thành tiền', exact: true })
      .scrollIntoViewIfNeeded();
    expect(await pageOverflow()).toBeLessThanOrEqual(0);
  });
}
