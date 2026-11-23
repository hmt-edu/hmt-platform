// P3e-2: màn Phiếu kiểm tra (TS-16 danh sách, Kanban, Lịch; TS-17 bản ghi; TS-15 tạo từ cơ hội), mở khoá từ trang Cơ hội và Lịch hẹn.
// Dữ liệu giả dựng bằng hàm nghiệp vụ (xem phieu-seed.ts), tìm bằng dấu riêng của từng dự án.
import { expect, test, type Locator, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone, pickChip, pickOption } from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded } from './phieu-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phiếu giả).');
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

async function login(page: Page, account: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
}

async function openTest(page: Page, account: string, id: string) {
  await login(page, account);
  await page.goto(`/crm/phieu-kiem-tra/${id}`);
  await expect(page.getByRole('heading', { level: 1, name: 'Phiếu kiểm tra' })).toBeVisible();
}

const stageBar = (page: Page) => page.getByRole('navigation', { name: 'Giai đoạn' });
// Nút hành động nằm sau thanh trạng thái, cũng tên "Hoàn thành".
const completeButton = (page: Page) =>
  page.getByRole('button', { name: 'Hoàn thành', exact: true }).last();
const toastText = (page: Page, text: string | RegExp) => page.getByText(text).first();
const dialogOf = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name });
const actionMenu = async (page: Page, item: string | RegExp) => {
  await page.getByRole('button', { name: 'Hành động', exact: true }).click();
  await page.getByRole('menuitem', { name: item }).click();
};
/** Mở ô chọn rồi chọn mục đầu tiên (danh mục thật, tên có thể đổi). */
async function pickFirst(page: Page, combobox: Locator) {
  await expect(async () => {
    if ((await combobox.getAttribute('aria-expanded')) !== 'true') await combobox.click();
    await page.getByRole('option').first().click({ timeout: 2000 });
  }).toPass({ timeout: 10000 });
}

test('Danh sách: không có Tạo, có Group By, tìm theo dấu; tên học sinh mở phiếu', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/phieu-kiem-tra');
  await expect(page.getByRole('heading', { level: 1, name: 'Kiểm tra đầu vào' })).toBeVisible();
  // Tuần này là mặc định; phiếu dựng giả có thể ở tuần sau, nên bỏ mốc thời gian rồi tìm theo dấu.
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Kiểm tra đầu vào' })
    : page.getByRole('table', { name: 'Kiểm tra đầu vào' });
  await expect(list.getByText(seeded.test.edit.code).first()).toBeVisible();
  await expect(list.getByText(seeded.test.review.code).first()).toBeVisible();
  // Phiếu chỉ tạo từ trang Cơ hội.
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Group By' })).toBeVisible();
  await expectAccessible(page);
  await list.getByRole('link', { name: seeded.student.edit }).first().click();
  await expect(page).toHaveURL(new RegExp(`/crm/phieu-kiem-tra/${seeded.test.edit.id}$`));
});

test('Group By trạng thái: mở nhóm chỉ ra đúng phiếu của nhóm (lỗi cũ: nhóm nào cũng ra mọi phiếu)', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/phieu-kiem-tra');
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await page.getByRole('button', { name: 'Group By', exact: true }).click();
  await page.getByRole('button', { name: /^Trạng thái/ }).click();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Kiểm tra đầu vào' })
    : page.getByRole('table', { name: 'Kiểm tra đầu vào' });
  const review = page.getByRole('button', { name: /^Chờ giáo viên chấm \(\d+\)$/ });
  await expect(review).toBeVisible();
  await review.click();
  await expect(list.getByText(seeded.test.review.code).first()).toBeVisible();
  // Phiếu Nháp không lẫn vào nhóm Chờ giáo viên chấm.
  await expect(list.getByText(seeded.test.edit.code)).toHaveCount(0);
});

test('Kanban: năm cột trạng thái; Bắt đầu test ở thẻ đưa phiếu sang Đang test', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/phieu-kiem-tra');
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  for (const name of ['Nháp', 'Đang test', 'Chờ giáo viên chấm', 'Hoàn thành', 'Huỷ']) {
    await expect(page.getByRole('heading', { name, exact: true }).first()).toBeVisible();
  }
  await expect(page.getByText(/^Phiếu đổi trạng thái bằng nút/)).toBeVisible();
  const card = page.getByRole('listitem').filter({ hasText: seeded.test.kanban.code });
  await card.getByRole('button', { name: 'Bắt đầu test' }).click();
  await expect(toastText(page, 'Đã bắt đầu test.')).toBeVisible();
  await expect(card.getByRole('button', { name: 'Nộp bài' })).toBeVisible();
});

test('Lịch: tháng có phiếu, bấm vào hiện khung chi tiết và nút Mở phiếu', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/phieu-kiem-tra');
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await page.getByRole('button', { name: 'Calendar', exact: true }).click();
  await page.getByRole('button', { name: 'Tháng', exact: true }).click();
  await page
    .getByRole('button', { name: new RegExp(seeded.student.edit) })
    .first()
    .click();
  await expect(
    page.getByRole('link', { name: new RegExp(`^Mở phiếu ${seeded.test.edit.code}`) }),
  ).toBeVisible();
});

test('Trang phiếu Chờ giáo viên chấm: thanh trạng thái chỉ đọc, sáu nút liên kết, kết quả; điểm sai bị chặn', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openTest(page, setup.account, seeded.test.review.id);
  await expect(stageBar(page).getByRole('button', { name: /^Chờ giáo viên chấm/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  await expect(page.getByRole('button', { name: /^Stage chỉ đọc/ })).toBeVisible();
  // Bước khác bị khoá: bấm báo lý do, không đổi.
  await stageBar(page)
    .getByRole('button', { name: /^Hoàn thành/ })
    .click({ force: true });
  await expect(toastText(page, /Đổi trạng thái bằng nút bên dưới/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lịch hẹn 1' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Báo giá 0' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Học sinh 1' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Cơ hội gốc 1' })).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Lead gốc 1' })).toBeEnabled();
  await expect(completeButton(page)).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Gợi ý lớp' })).toHaveCount(0);
  await page.getByRole('button', { name: 'Nhập kết quả' }).click();
  const dialog = dialogOf(page, 'Nhập kết quả');
  await dialog.getByLabel(/^Điểm/).fill('11');
  await expect(dialog.getByText(/Điểm từ 0 đến 10/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Lưu kết quả' })).toBeDisabled();
  await expectAccessible(page);
});

test('Nhập kết quả thay giáo viên rồi Hoàn thành; sau đó lùi về Nháp bắt buộc lý do (R-CRM-21)', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openTest(page, setup.account, seeded.test.review.id);
  await page.getByRole('button', { name: 'Nhập kết quả' }).click();
  const dialog = dialogOf(page, 'Nhập kết quả');
  await dialog.getByLabel(/^Điểm/).fill('7,5');
  await dialog.getByLabel(/^Nhận xét/).fill('Nắm chắc Đại số, yếu Hình.');
  await pickOption(page, dialog.getByRole('combobox', { name: 'Giáo viên chấm' }), /Giáo viên CS5/);
  await dialog.getByRole('button', { name: 'Lưu kết quả' }).click();
  await expect(toastText(page, 'Đã lưu kết quả.')).toBeVisible();
  await expect(page.getByText('7,5', { exact: true }).first()).toBeVisible();
  // Người nhập không phải giáo viên chấm: ghi "nhập thay" (R-CRM-11).
  await expect(page.getByText('nhập thay').first()).toBeVisible();
  await completeButton(page).click();
  await expect(toastText(page, 'Đã hoàn thành phiếu.')).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^Hoàn thành/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  await expect(page.getByRole('button', { name: 'Gợi ý lớp' })).toBeDisabled();
  // Lùi từ Hoàn thành về Nháp: bắt lý do.
  await actionMenu(page, /Lùi về Nháp/);
  const back = dialogOf(page, 'Đưa về Nháp');
  await expect(back.getByRole('button', { name: 'Đưa về Nháp' })).toBeDisabled();
  await back.getByLabel(/^Lý do/).fill('Nhập nhầm điểm');
  await back.getByRole('button', { name: 'Đưa về Nháp' }).click();
  await expect(toastText(page, 'Đã đưa phiếu về Nháp.')).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^Nháp/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
});

test('Phiếu Nháp: Đổi lịch, Sửa phòng và tên đề, Huỷ chọn lý do, Mở lại cần lý do', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openTest(page, setup.account, seeded.test.edit.id);
  await page.getByRole('button', { name: 'Đổi lịch' }).click();
  const move = dialogOf(page, 'Đổi lịch test');
  await pickChip(move, 'Ngày kia');
  await pickChip(move, '17:00');
  await move.getByRole('button', { name: 'Đổi lịch' }).click();
  await expect(toastText(page, 'Đã đổi lịch test.')).toBeVisible();
  await expect(page.getByText(/17:00/).first()).toBeVisible();
  // Sửa tên đề.
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Đề test').fill('Toán 9 cơ bản – đề 2');
  await page.getByRole('button', { name: 'Lưu' }).click();
  await expect(toastText(page, 'Đã lưu.')).toBeVisible();
  await expect(page.getByText('Toán 9 cơ bản – đề 2').first()).toBeVisible();
  // Huỷ bắt chọn lý do.
  await actionMenu(page, 'Huỷ phiếu');
  const cancel = page.getByRole('alertdialog', { name: 'Huỷ phiếu kiểm tra' });
  await expect(cancel.getByRole('button', { name: 'Huỷ phiếu' })).toBeDisabled();
  await pickFirst(page, cancel.getByRole('combobox', { name: 'Lý do' }));
  await cancel.getByLabel('Ghi chú').fill('Phụ huynh báo bận');
  await cancel.getByRole('button', { name: 'Huỷ phiếu' }).click();
  await expect(toastText(page, 'Đã huỷ phiếu.')).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Phiếu đã huỷ. Mở lại để đưa về Nháp.' }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Mở lại', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Mở lại', exact: true }).click();
  const reopen = dialogOf(page, 'Mở lại phiếu');
  await expect(reopen.getByRole('button', { name: 'Mở lại', exact: true })).toBeDisabled();
  await reopen.getByLabel(/^Lý do/).fill('Phụ huynh đổi ý');
  await reopen.getByRole('button', { name: 'Mở lại', exact: true }).click();
  await expect(toastText(page, 'Đã mở lại phiếu về Nháp.')).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^Nháp/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
});

test('Từ trang phiếu: nút "Lịch hẹn" mở danh sách lịch của phiếu (chip Phiếu), mã phiếu là liên kết', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openTest(page, setup.account, seeded.test.edit.id);
  await page.getByRole('button', { name: /^Lịch hẹn \d+$/ }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen\?phieu=/);
  await expect(
    page.getByText(new RegExp(`^Phiếu: ${seeded.test.edit.code}`)).first(),
  ).toBeVisible();
  await expect(page.getByRole('link', { name: seeded.test.edit.code }).first()).toBeVisible();
  await page.getByRole('button', { name: /^Bỏ điều kiện: Phiếu: PKT/ }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen$/);
});

test('Trang Cơ hội: mã phiếu bấm được, nút "Kiểm tra" mở thẳng phiếu, hộp chặn L7 có nút Mở phiếu', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto(`/crm/co-hoi/${seeded.opportunity.kanban.id}`);
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tạo lịch Test' })).toBeEnabled();
  // Còn phiếu dang dở: chặn L7, nút Mở phiếu mở trang phiếu.
  await page
    .getByRole('navigation', { name: 'Giai đoạn' })
    .getByRole('button', { name: /^L7/ })
    .click();
  const block = dialogOf(page, /Chuyển sang L7/);
  await block.getByRole('button', { name: /^Mở phiếu PKT/ }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/phieu-kiem-tra/${seeded.test.kanban.id}$`));
  await page.getByRole('button', { name: 'Cơ hội gốc 1' }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/co-hoi/${seeded.opportunity.kanban.id}$`));
  await page.getByRole('button', { name: 'Kiểm tra 1' }).click();
  await expect(page).toHaveURL(new RegExp(`/crm/phieu-kiem-tra/${seeded.test.kanban.id}$`));
});

test('Tạo phiếu từ cơ hội: chọn đủ ô, giờ nhắc tự điền, tạo xong mở phiếu Nháp', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto(`/crm/co-hoi/${seeded.opportunity.fresh.id}`);
  await page.getByRole('button', { name: 'Tạo lịch Test' }).click();
  const dialog = dialogOf(page, 'Tạo phiếu kiểm tra');
  await expect(dialog.getByRole('combobox', { name: 'Em' })).toContainText(seeded.student.fresh);
  await expect(dialog.getByRole('button', { name: 'Tạo phiếu' })).toBeDisabled();
  await pickFirst(page, dialog.getByRole('combobox', { name: 'Lớp' }));
  await pickFirst(page, dialog.getByRole('combobox', { name: 'Môn' }));
  await pickFirst(page, dialog.getByRole('combobox', { name: 'Hình thức test' }));
  await pickFirst(page, dialog.getByRole('combobox', { name: 'Cấp độ đề' }));
  await dialog.getByLabel('Đề test').fill('Toán cơ bản – đề 1');
  await pickChip(dialog, 'Ngày kia');
  await pickChip(dialog, '17:00');
  // Giờ nhắc tự điền (17:00 ngày hôm trước), nút Tạo sáng.
  await expect(dialog.getByLabel('Giờ nhắc')).toHaveValue('17:00');
  await expect(dialog.getByRole('button', { name: 'Tạo phiếu' })).toBeEnabled();
  await dialog.getByRole('button', { name: 'Tạo phiếu' }).click();
  await expect(toastText(page, /Đã tạo phiếu PKT\d+/)).toBeVisible();
  await expect(page).toHaveURL(/\/crm\/phieu-kiem-tra\/[0-9a-f-]+$/);
  await expect(stageBar(page).getByRole('button', { name: /^Nháp/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  await expect(page.getByRole('button', { name: 'Lịch hẹn 1' })).toBeVisible();
});
