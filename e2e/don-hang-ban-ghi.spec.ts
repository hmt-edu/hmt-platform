// BH-05 Đơn hàng (bản ghi), P5a-UI-O2a (xem): đủ các tình trạng Nháp, Đã trình, Đã duyệt, Nháp bị từ chối (khối "Đơn bị từ chối"), Huỷ;
// khung "chưa có quản lý trực tiếp"; tab Dòng đơn, Thanh toán, Ghi danh; Đã thu, Còn phải thu "—" (Đ269); mở từ BH-06 và từ báo giá.
// Dữ liệu giả dựng bằng don-hang-seed.ts (seedOrderRecords). Ảnh chụp máy tính: mặc định ra thư mục tạm; SO_SANH_GHI_VAO_REPO=1 thì ghi vào docs/anh-chup/bh05/.
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone, shotPath, showAllTimeline } from './helpers';
import {
  DB_URL,
  clearMark,
  recordSetupOf,
  seedOrderRecords,
  type SeededRecords,
} from './don-hang-seed';

// Không có việc gì khác để làm thì «Hành động» chỉ còn mục In (BH-12).
async function expectOnlyPrint(page: Page) {
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem')).toHaveText(['In']);
  await page.keyboard.press('Escape');
}

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng đơn hàng giả).');
test.describe.configure({ mode: 'serial' });

let seeded: SeededRecords;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seedOrderRecords(recordSetupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(recordSetupOf(testInfo.project.name).mark);
});

/** Mở bản ghi đơn từ danh sách BH-06 (bấm mã đơn). */
async function openOrder(page: Page, account: string, mark: string, code: string) {
  await enterAs(page, account);
  await page.goto('/crm/don-hang');
  await expect(page.getByRole('heading', { level: 1, name: 'Đơn hàng' })).toBeVisible();
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Đơn hàng' })
    : page.getByRole('table', { name: 'Đơn hàng' });
  await list.getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
  void mark;
}

async function shot(page: Page, name: string) {
  if (isPhone(page)) return;
  await page.screenshot({ path: shotPath('bh05', `${name}.png`), fullPage: true });
}

test('Mở đơn từ BH-06; Nháp: thông tin chung, chưa có quản lý trực tiếp thì Trưởng cơ sở duyệt (R-V2-12), nút Trình không bị mờ', async ({
  page,
}, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.orders.nhap);
  await expect(page.getByRole('heading', { level: 1, name: 'Đơn hàng' })).toBeVisible();
  await expect(
    // R-V2-12 (Q-114): người lập chưa có quản lý trực tiếp, cơ sở có Trưởng cơ sở nên vẫn trình được, Trưởng cơ sở duyệt.
    page.getByText('Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp'),
  ).toBeVisible();
  // Q-77: MỘT dòng cạnh nút Trình, không còn khối vàng "Cần xử lý trước khi trình". R-V2-12: không còn ca chặn nên nút không mờ.
  await expect(page.getByText('Cần xử lý trước khi trình')).toHaveCount(0);
  await expect(page.getByText(/Chưa có quản lý trực tiếp để duyệt/)).toHaveCount(0);
  if (isPhone(page)) {
    await expect(page.getByRole('button', { name: 'Trình duyệt' })).toHaveCount(0);
  } else {
    await expect(page.getByRole('button', { name: 'Trình duyệt' })).not.toHaveAttribute(
      'aria-disabled',
      'true',
    );
  }
  await expect(
    page.getByRole('button', { name: 'Stage chỉ đọc, đổi bằng nút bên dưới.' }),
  ).toBeVisible();
  // Khối thông tin: nhãn "Người duyệt" (không dùng "Quản lý cơ sở", "Trưởng cơ sở"), không có Hình thức thanh toán, Cơ sở thu tiền.
  // So canvas BH05: ba khối Thông tin chung, Người xử lý và cơ sở, Thanh toán (tiêu đề khối riêng).
  for (const name of ['Thông tin chung', 'Người xử lý và cơ sở', 'Thanh toán']) {
    await expect(page.getByRole('heading', { level: 3, name, exact: true })).toBeVisible();
  }
  await expect(page.getByText('Điều khoản thanh toán')).toBeVisible();
  await expect(page.getByText('Hình thức thanh toán')).toHaveCount(0);
  await expect(page.getByText('Cơ sở thu tiền')).toHaveCount(0);
  // Tổng niêm yết, Tổng chiết khấu, Thành tiền do máy chủ trả; Đã thu, Còn phải thu là "—" (Đ269).
  await expect(page.getByText('Tổng niêm yết')).toBeVisible();
  await expect(page.getByText('Tổng ưu đãi')).toBeVisible();
  await expect(
    page.locator('dl', { has: page.getByText('Tổng niêm yết') }).getByText('Thành tiền'),
  ).toBeVisible();
  const paid = page
    .locator('dt', { hasText: /^Đã thu$/ })
    .locator('xpath=following-sibling::dd[1]');
  await expect(paid).toHaveText('—');
  const due = page
    .locator('dt', { hasText: /^Còn phải thu$/ })
    .locator('xpath=following-sibling::dd[1]');
  await expect(due).toHaveText('—');
  // Không có nút Sửa (PR sửa Nháp là UI-O3); không có hộp trình duyệt tự cài.
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toHaveCount(0);
  await expectAccessible(page);
  await shot(page, 'bh05-nhap-chua-ql');
});

test('Đã trình: chờ người duyệt đã chốt; Đã duyệt · khoá: nút Tạo phiếu thu (máy tính); Ghi danh mờ', async ({
  page,
}, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.orders.dtrinh);
  await expect(
    page.getByText(/Đơn đã trình, chờ .+ duyệt\. Trong lúc chờ không sửa được dòng\./),
  ).toBeVisible();
  await expect(page.getByText('Người duyệt: chưa có')).toHaveCount(0);
  await expectAccessible(page);
  await shot(page, 'bh05-da-trinh');
  await openOrder(page, setup.sale, setup.mark, seeded.orders.dduyet);
  await expect(page.getByText('Đã duyệt · khoá').first()).toBeVisible();
  // B2: Sale có quyền Tạo phiếu thu và CS5 bật Bán hàng nên nút bật trên máy tính; điện thoại chỉ đọc (Đ248) nên ẩn.
  if (isPhone(page)) {
    await expect(page.getByRole('button', { name: 'Tạo phiếu thu' })).toHaveCount(0);
  } else {
    await expect(page.getByRole('button', { name: 'Tạo phiếu thu' })).toBeEnabled();
  }
  // Nút số «Phiếu thu» khi không đúng một phiếu: mở danh sách lọc theo đơn này, không phải mọi phiếu.
  if (!isPhone(page)) {
    const orderUrl = page.url();
    await page.getByRole('button', { name: /^Phiếu thu/ }).click();
    await expect(page).toHaveURL(/\/crm\/phieu-thu\?don=[0-9a-f-]{36}&ma=/);
    await expect(page.getByText(`Đơn hàng: ${seeded.orders.dduyet}`)).toBeVisible();
    await page.goto(orderUrl);
  }
  // Đơn Đã duyệt: Sale lập không phải người duyệt đã chốt nên không có mục Huỷ đơn (R-TIEN-38).
  await expectOnlyPrint(page);
  await expect(page.getByText(/Đơn đã duyệt và khoá/)).toBeVisible();
  await shot(page, 'bh05-da-duyet');
});

test('BH-12: In từ menu Hành động; bản in đơn Đã duyệt ghi đúng tình trạng, đủ khối', async ({
  page,
}, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.orders.dduyet);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/don-hang\/[0-9a-f-]+\/in$/);
  const sheet = page.getByRole('article', { name: 'ĐƠN HÀNG' });
  await expect(sheet.getByText(seeded.orders.dduyet, { exact: true })).toBeVisible();
  await expect(sheet.getByText('ĐÃ DUYỆT', { exact: true })).toBeVisible();
  await expect(sheet.getByText('Phụ huynh xác nhận')).toBeVisible();
  await expect(sheet.getByText('Bằng chữ')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tải PDF' })).toBeVisible();
  await expectAccessible(page);
});

test('Nháp bị từ chối: lý do và ghi chú nằm ở dòng thời gian (không còn khối đỏ); hai dòng đơn; tab Thanh toán và Ghi danh', async ({
  page,
}, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.rejected);
  // Q-77: bỏ khối đỏ "Đơn bị từ chối"; lý do từ chối nằm ở dòng thời gian bên phải.
  await expect(page.getByRole('status').filter({ hasText: 'Đơn bị từ chối' })).toHaveCount(0);
  await showAllTimeline(page);
  await expect(page.getByRole('complementary').getByText('Từ chối').first()).toBeVisible();
  await expect(
    page.getByRole('complementary').getByText(/Chiết khấu dòng 2 chưa có văn bản phê duyệt/),
  ).toBeVisible();
  await expect(page.getByText('Nháp · bị từ chối').first()).toBeVisible();
  // Q-89: hàng tab không có thanh cuộn dọc (overflow-y hidden), chỉ cuộn ngang khi tab không vừa.
  const tabOverflowY: string = await page.evaluate(
    "getComputedStyle(document.querySelector('[role=tablist]')).overflowY",
  );
  expect(tabOverflowY).toBe('hidden');
  await expect(page.getByRole('tab', { name: /Dòng đơn/ })).toContainText('2');
  await expect(page.getByText(/Toán/).first()).toBeVisible();
  await shot(page, 'bh05-tu-choi');
  await page.getByRole('tab', { name: 'Thanh toán' }).click();
  await expect(page.getByText('Chưa có phiếu thu.')).toBeVisible();
  await page.getByRole('tab', { name: 'Ghi danh' }).click();
  await expect(page.getByText(/Ghi danh sinh khi tiền đã vào đủ cọc tối thiểu/)).toBeVisible();
  // Không còn khối "Lịch sử xử lý" cuối trang (Q-48): sự kiện nằm ở dòng thời gian bên phải.
  await expect(page.getByText('Lịch sử xử lý')).toHaveCount(0);
  const timeline = page.getByRole('region', { name: 'Ghi chú & hoạt động' });
  // Dòng thời gian mặc định tab Ghi chú: sự kiện hệ thống xem ở «Tất cả».
  await timeline.getByRole('button', { name: 'Tất cả', exact: true }).click();
  await expect(timeline.getByText('Từ chối', { exact: true })).toBeVisible();
});

test('Huỷ: nêu lý do huỷ, chỉ còn xem', async ({ page }, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.cancelled);
  await expect(page.getByText(/Đơn đã huỷ: .*Phụ huynh đổi ý/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình duyệt' })).toHaveCount(0);
  await shot(page, 'bh05-huy');
});

test('Ghi chú đơn: viết và đọc lại qua SALES_ORDER; nguồn đơn mở được từ báo giá và về báo giá', async ({
  page,
}, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.orders.nhap);
  await page.getByPlaceholder(/Viết ghi chú/).fill('Phụ huynh hẹn trả lời thứ sáu');
  await page.getByRole('button', { name: 'Gửi ghi chú' }).click();
  await expect(page.getByText('Phụ huynh hẹn trả lời thứ sáu')).toBeVisible();
  // Smart button Báo giá mở báo giá nguồn; ở báo giá, mã đơn bấm được quay lại đơn.
  await page
    .getByRole('button', { name: /Báo giá/ })
    .first()
    .click();
  await expect(page.getByRole('heading', { level: 1, name: 'Báo giá' })).toBeVisible();
  await page.getByRole('link', { name: seeded.orders.nhap }).last().click();
  await expect(page.getByRole('heading', { level: 2, name: seeded.orders.nhap })).toBeVisible();
});

test('Đơn không có: báo không tìm thấy', async ({ page }, testInfo) => {
  const setup = recordSetupOf(testInfo.project.name);
  await enterAs(page, setup.sale);
  await page.goto('/crm/don-hang/00000000-0000-0000-0000-000000000000');
  await expect(page.getByRole('heading', { name: 'Không tìm thấy đơn hàng' })).toBeVisible();
});

test('Trình: đơn thiếu năm sinh bị chặn và chỉ đúng em (R-TIEN-35); đơn chưa chọn điều khoản bị chặn bằng câu máy chủ', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc: không có nút Trình (Đ248).');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.thieuEm);
  await expect(page.getByText(/Mỗi học sinh cần họ tên và năm sinh trước khi trình/)).toBeVisible();
  await page.getByRole('button', { name: 'Trình duyệt' }).click({ force: true }); // aria-disabled (Q-77): vẫn bấm được để máy chủ nêu lý do
  const notice = page.getByRole('status').filter({ hasText: 'Chưa trình được' });
  await expect(notice).toContainText('Dòng 1: thiếu năm sinh của em');
  // Chỉ đúng dòng: ô học sinh của dòng 1 nêu "cần sửa"; đơn vẫn Nháp.
  await expect(page.getByText('Dòng 1: cần sửa, xem thông báo phía trên')).toBeVisible();
  await expect(page.getByText('Nháp').first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình duyệt' })).not.toHaveAttribute(
    'disabled',
    /.*/,
  );
  await expectAccessible(page);
  await shot(page, 'bh05-trinh-thieu-em');
  // Đơn chưa chọn điều khoản: máy chủ chặn, câu tiếng Việt hiện thẳng.
  await openOrder(page, setup.sale, setup.mark, seeded.orders.nhap);
  await page.getByRole('button', { name: 'Trình duyệt' }).click({ force: true }); // aria-disabled (Q-77): vẫn bấm được để máy chủ nêu lý do
  await expect(
    page.getByRole('status').filter({ hasText: 'Chọn điều khoản thanh toán trước khi trình đơn.' }),
  ).toBeVisible();
  await shot(page, 'bh05-trinh-loi');
});

test('Trình thành công: CSKH có quản lý trực tiếp trình đơn, thành Đã trình chờ người duyệt; Trưởng cơ sở (người duyệt đã chốt) có mục Huỷ đơn, người lập thì không', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc: không có nút Trình (Đ248).');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, seeded.cskh, setup.mark, seeded.records.trinhDuoc);
  await expect(page.getByText(/Người duyệt: .+ · quản lý trực tiếp của/)).toBeVisible();
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  await expect(page.getByText('Đã trình đơn.').first()).toBeVisible();
  await expect(page.getByText(/Đơn đã trình, chờ .+ duyệt\./)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trình duyệt' })).toHaveCount(0);
  await shot(page, 'bh05-sau-trinh');
  // Người lập (CSKH) không huỷ được đơn Đã trình (R-TIEN-38): không có mục Huỷ đơn.
  await expectOnlyPrint(page);
});

// R-V2-12 (Q-114, Q-117): Sale chưa có quản lý trực tiếp vẫn trình được; đơn đi tới Trưởng cơ sở, người duyệt không chốt một người.
test('R-V2-12: Sale chưa có quản lý trình đơn, đơn chờ Trưởng cơ sở', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc: không có nút Trình (Đ248).');
  test.setTimeout(90_000);
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.truongCs);
  await expect(
    page.getByText('Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp'),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Trình duyệt' }).click();
  await expect(page.getByText('Đã trình đơn.').first()).toBeVisible();
  await expect(page.getByText('Đơn đã trình, chờ Trưởng cơ sở duyệt.')).toBeVisible();
});

// Thẻ mới cho Trưởng cơ sở: cùng một thẻ thì phiên Sale còn trong bộ nhớ, đổi tài khoản không đè được.
test('R-V2-12: Trưởng cơ sở cùng cơ sở thấy đơn chờ Trưởng cơ sở và có nút Duyệt', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.manager, setup.mark, seeded.records.truongCs);
  await expect(page.getByText('Đơn đã trình, chờ Trưởng cơ sở duyệt.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duyệt', exact: true })).toBeVisible();
});

test('Người duyệt đã chốt (Trưởng cơ sở) có mục Huỷ đơn trên đơn Đã trình (R-TIEN-38)', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.manager, setup.mark, seeded.records.trinhDuoc);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'Huỷ đơn' })).toBeVisible();
});

test('Huỷ đơn Nháp: hộp có lý do từ danh mục, "Khác" bắt ghi chú; xong đơn thành Huỷ và chỉ còn xem; người khác không có mục Huỷ', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc: không có mục Huỷ đơn (Đ248).');
  // Đăng nhập, mở hộp, kiểm trợ năng, chụp ảnh và huỷ trong một bài: dài hơn mức mặc định.
  test.setTimeout(90_000);
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.huy);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ đơn' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Huỷ đơn hàng' })).toBeVisible();
  await expectAccessible(page);
  await shot(page, 'bh05-hop-huy');
  // "Khác" mà không ghi chú: không xác nhận được.
  await dialog.getByLabel('Lý do').click();
  await page.getByRole('option', { name: 'Khác', exact: true }).click();
  await expect(dialog.getByRole('button', { name: 'Xác nhận huỷ' })).toBeDisabled();
  await dialog.getByLabel('Lý do').click();
  await page.getByRole('option', { name: /Khách đổi ý/ }).click();
  await dialog.getByRole('button', { name: 'Xác nhận huỷ' }).click();
  await expect(page.getByText('Đã huỷ đơn.').first()).toBeVisible();
  await expect(page.getByText(/Đơn đã huỷ: Khách đổi ý/)).toBeVisible();
  await expectOnlyPrint(page);
  await shot(page, 'bh05-sau-huy');
});

test('Điện thoại: đơn chỉ đọc, không có nút Trình và mục Huỷ đơn (Đ248)', async ({
  page,
}, testInfo) => {
  test.skip(!isPhone(page), 'Chỉ áp cho điện thoại.');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, setup.sale, setup.mark, seeded.records.thieuEm);
  await expect(page.getByRole('button', { name: 'Trình duyệt' })).toHaveCount(0);
  await expectOnlyPrint(page);
});

test('Đơn Nháp chỉ người lập huỷ (R-TIEN-38): CSKH không phải người lập nên không có mục Huỷ đơn', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Điện thoại chỉ đọc (Đ248).');
  const setup = recordSetupOf(testInfo.project.name);
  await openOrder(page, seeded.cskh, setup.mark, seeded.records.thieuEm);
  await expectOnlyPrint(page);
});
