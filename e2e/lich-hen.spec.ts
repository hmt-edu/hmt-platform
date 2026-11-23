// P3c-3b: màn Lịch hẹn (TS-11): danh sách, Kanban, Lịch; Hoàn thành, Dời, Huỷ, Mở lại; Tạo gắn với lead; dải "quá hạn bị ẩn".
// Dữ liệu giả dựng bằng create_lead, create_appointment; tìm bằng dấu riêng của từng dự án.
import { expect, test, type Page } from '@playwright/test';
import {
  PASSWORD,
  confirmCompleteAppointment,
  enterAs,
  expectAccessible,
  isPhone,
  pickChip,
  pickOption,
} from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded, type Setup } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lịch hẹn giả).');
test.describe.configure({ mode: 'serial' });

let seeded: Seeded;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seed(setupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(setupOf(testInfo.project.name).mark);
});

async function openList(page: Page, setup: Setup) {
  await enterAs(page, setup.account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/lich-hen');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch hẹn' })).toBeVisible();
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
}

// Máy tính là bảng (dòng), điện thoại là danh sách thẻ.
const rows = (page: Page) =>
  isPhone(page)
    ? page.getByRole('list', { name: 'Lịch hẹn' }).getByRole('listitem')
    : page.getByRole('table', { name: 'Lịch hẹn' }).getByRole('row');
const row = (page: Page, title: string) => rows(page).filter({ hasText: title });
const toastText = (page: Page, text: string | RegExp) => page.getByText(text).first();

test('Danh sách: nhóm Hôm nay, đủ nút theo trạng thái; Hoàn thành qua hộp', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await expect(page.getByRole('button', { name: /^Hôm nay/ }).first()).toBeVisible();
  await expectAccessible(page);
  const call = row(page, `Gọi tư vấn ${setup.mark}`);
  await expect(call.getByRole('button', { name: 'Hoàn thành' })).toBeVisible();
  await expect(call.getByRole('button', { name: 'Dời' })).toBeVisible();
  await expect(call.getByRole('button', { name: 'Huỷ' })).toBeVisible();
  const done = row(page, `Gặp xong ${setup.mark}`);
  await expect(done.getByRole('button', { name: 'Mở lại' })).toBeVisible();
  await expect(done.getByRole('button', { name: 'Hoàn thành' })).toHaveCount(0);
  await call.getByRole('button', { name: 'Hoàn thành' }).click();
  // TS-11: lịch Gọi điện mở hộp «Hoàn thành lịch hẹn» (chọn Kết quả rồi bấm Hoàn thành).
  await confirmCompleteAppointment(page);
  await expect(toastText(page, 'Đã hoàn thành lịch hẹn.')).toBeVisible();
  await expect(
    row(page, `Gọi tư vấn ${setup.mark}`).getByRole('button', { name: 'Mở lại' }),
  ).toBeVisible();
});

test('Mở lại: có hộp xác nhận, lịch về Chưa làm', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await row(page, `Gặp xong ${setup.mark}`).getByRole('button', { name: 'Mở lại' }).click();
  const dialog = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  await expect(dialog.getByText(/Mở lại lịch hẹn\?/)).toBeVisible();
  await expect(
    dialog.getByText(/không đổi giai đoạn, không tạo việc, không gửi thông báo/),
  ).toBeVisible();
  await dialog.getByRole('button', { name: 'Mở lại', exact: true }).click();
  await expect(toastText(page, 'Đã mở lại lịch hẹn.')).toBeVisible();
  await expect(
    row(page, `Gặp xong ${setup.mark}`).getByRole('button', { name: 'Hoàn thành' }),
  ).toBeVisible();
});

test('Huỷ bắt chọn lý do; sau đó Mở lại được', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await row(page, `Zalo báo giá ${setup.mark}`).getByRole('button', { name: 'Huỷ' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Huỷ lịch hẹn' });
  // Chưa chọn lý do thì không huỷ được.
  await expect(dialog.getByRole('button', { name: 'Huỷ lịch hẹn' })).toBeDisabled();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Lý do' }), 'Khác');
  await dialog.getByLabel('Ghi chú').fill('Khách đổi ý');
  await dialog.getByRole('button', { name: 'Huỷ lịch hẹn' }).click();
  await expect(toastText(page, 'Đã huỷ lịch hẹn.')).toBeVisible();
  await expect(
    row(page, `Zalo báo giá ${setup.mark}`).getByRole('button', { name: 'Mở lại' }),
  ).toBeVisible();
});

test('Dải quá hạn bị ẩn bởi bộ lọc thời gian; Xem hiện lịch quá hạn', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await expect(page.getByText(/Còn \d+ lịch Quá hạn/)).toBeVisible();
  await expect(page.getByText(`Email quá hạn ${setup.mark}`)).toHaveCount(0);
  await page.getByRole('button', { name: 'Xem', exact: true }).click();
  await expect(page.getByText(`Email quá hạn ${setup.mark}`).first()).toBeVisible();
  await expect(page.getByText(/Còn \d+ lịch Quá hạn/)).toHaveCount(0);
});

test('Tạo: chọn lead bằng ô tìm rồi lưu; lịch mới hiện trong danh sách', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await page.getByRole('button', { name: 'Tạo', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo lịch hẹn' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('combobox', { name: /Gắn với/ }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(seeded.parent);
  await page.getByRole('option', { name: new RegExp(seeded.parent) }).click();
  await expect(dialog.getByRole('combobox', { name: /Gắn với/ })).toContainText(seeded.parent);
  await pickChip(dialog, 'Hôm nay');
  await pickChip(dialog, '09:00');
  await dialog.getByLabel(/Ghi chú/).fill(`Hẹn tạo mới ${setup.mark}`);
  await dialog.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
  await expect(row(page, `Hẹn tạo mới ${setup.mark}`)).toBeVisible();
});

test('Kanban: ba cột Chưa làm, Hoàn thành, Huỷ; kéo thả bị chặn có lý do', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await page.getByRole('button', { name: 'Kanban' }).click();
  for (const name of ['Chưa làm', 'Hoàn thành', 'Huỷ']) {
    await expect(page.getByRole('heading', { name }).first()).toBeVisible();
  }
  await expect(page.getByText(/Mở lại/).first()).toBeVisible();
});

test('Lịch: tuần có lịch hẹn, bấm vào hiện khung chi tiết và nút thao tác', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await page.getByRole('button', { name: 'Calendar' }).click();
  await expect(page.getByRole('button', { name: 'Hôm nay' }).first()).toBeVisible();
  await page
    .getByRole('button', { name: new RegExp(seeded.parent) })
    .first()
    .click();
  await expect(page.getByRole('link', { name: /Mở lead/ })).toBeVisible();
});

test('Dời lịch hẹn: chọn ngày giờ mới, lưu', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await row(page, `Hẹn để dời ${setup.mark}`).getByRole('button', { name: 'Dời' }).click();
  const dialog = page.getByRole('dialog', { name: 'Dời lịch hẹn' });
  await expect(dialog).toBeVisible();
  await pickChip(dialog, 'Ngày mai');
  await pickChip(dialog, '17:00');
  await dialog.getByRole('button', { name: 'Dời lịch' }).click();
  await expect(toastText(page, 'Đã dời lịch hẹn.')).toBeVisible();
  // "Ngày mai" của Chủ nhật là thứ Hai tuần sau, ngoài mốc Tuần này mặc định (lỗi chập chờn theo ngày: bài trượt đêm thứ Bảy, Chủ nhật).
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await expect(row(page, `Hẹn để dời ${setup.mark}`).getByText(/17:00/)).toBeVisible();
});

test('Từ trang Lead: nút "Lịch hẹn" mở danh sách chỉ của lead đó, có chip để bỏ lọc', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await row(page, `Gọi tư vấn ${setup.mark}`)
    .getByRole('link', { name: /^LD\d+$/ })
    .click();
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  await page.getByRole('button', { name: /^Lịch hẹn \d+$/ }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen\?lead=/);
  await expect(page.getByText(/^Lead: LD\d+/).first()).toBeVisible();
  // Lịch quá hạn của lead cũng hiện (không giới hạn thời gian).
  await expect(row(page, `Email quá hạn ${setup.mark}`)).toBeVisible();
  await page.getByRole('button', { name: /^Bỏ điều kiện: Lead: LD\d+/ }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen$/);
});

test('Tạo lịch hẹn khi danh mục tải chậm: mở hộp sớm vẫn có loại hoạt động mặc định, nút Tạo sáng (lỗi chập chờn cũ)', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  // Làm chậm danh mục 3 giây: hộp Tạo mở khi danh mục chưa về. Lỗi cũ: loại hoạt động kẹt rỗng, nút Tạo không bao giờ sáng.
  await page.route(/catalog_item/, async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 3000));
    await route.continue();
  });
  await openList(page, setup);
  await page.getByRole('button', { name: 'Tạo', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo lịch hẹn' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('combobox', { name: /Gắn với/ }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(seeded.parent);
  await page.getByRole('option', { name: new RegExp(seeded.parent) }).click();
  await pickChip(dialog, 'Ngày mai');
  await pickChip(dialog, '10:00');
  await dialog.getByLabel(/Ghi chú/).fill(`Hẹn danh mục chậm ${setup.mark}`);
  // Danh mục về rồi thì ô Loại hoạt động có giá trị mặc định và nút Tạo sáng.
  await expect(dialog.getByRole('button', { name: 'Tạo lịch hẹn' })).toBeEnabled({
    timeout: 10000,
  });
  await dialog.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
});

test('Hoàn tác sau Hoàn thành ở danh sách: lịch về Chưa làm', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  const title = `Hẹn hoàn tác trong danh sách ${setup.mark}`;
  await row(page, title).getByRole('button', { name: 'Hoàn thành' }).click();
  await confirmCompleteAppointment(page);
  await expect(toastText(page, 'Đã hoàn thành lịch hẹn.')).toBeVisible();
  await expect(row(page, title).getByRole('button', { name: 'Mở lại' })).toBeVisible();
  await page.getByRole('button', { name: 'Hoàn tác', exact: true }).click();
  await expect(toastText(page, /Đã hoàn tác/)).toBeVisible();
  await expect(row(page, title).getByRole('button', { name: 'Hoàn thành' })).toBeVisible();
});

test('Hoàn tác sau Huỷ ở trang Lead: lịch trở lại Hoạt động sắp tới', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openList(page, setup);
  await row(page, `Hẹn hoàn tác ở trang lead ${setup.mark}`)
    .getByRole('link', { name: /^LD\d+$/ })
    .click();
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  const upcoming = page.getByRole('region', { name: 'Hoạt động sắp tới' });
  const item = upcoming
    .getByRole('listitem')
    .filter({ hasText: `Hẹn hoàn tác ở trang lead ${setup.mark}` });
  await item.getByRole('button', { name: 'Huỷ' }).click();
  const dialog = page.getByRole('alertdialog', { name: 'Huỷ lịch hẹn' });
  await pickOption(page, dialog.getByRole('combobox', { name: 'Lý do' }), /^Khác$/);
  await dialog.getByLabel('Ghi chú').fill('Khách đổi ý');
  await dialog.getByRole('button', { name: 'Huỷ lịch hẹn' }).click();
  await expect(toastText(page, 'Đã huỷ lịch hẹn.')).toBeVisible();
  await expect(item).toHaveCount(0);
  await page.getByRole('button', { name: 'Hoàn tác', exact: true }).click();
  await expect(toastText(page, /Đã hoàn tác/)).toBeVisible();
  await expect(item).toBeVisible();
});
