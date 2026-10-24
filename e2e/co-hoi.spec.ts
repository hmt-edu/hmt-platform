// P3d-2: màn Cơ hội (TS-07 danh sách, Kanban; TS-08 bản ghi; TS-09 chuyển giai đoạn; TS-06 tạo từ lead) và ô "Gắn với" cơ hội ở Lịch hẹn.
// Dữ liệu giả dựng bằng hàm nghiệp vụ (xem co-hoi-seed.ts), tìm bằng dấu riêng của từng dự án.
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone, pickChip, pickOption } from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded } from './co-hoi-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng cơ hội giả).');
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

async function openRecord(page: Page, account: string, id: string) {
  await login(page, account);
  await page.goto(`/crm/co-hoi/${id}`);
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
}

const stageBar = (page: Page) => page.getByRole('navigation', { name: 'Giai đoạn' });
const toastText = (page: Page, text: string | RegExp) => page.getByText(text).first();
const dialogOf = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name });

test('Danh sách: không có Tạo, Nhập; có Group By, Kanban; bấm dòng mở cơ hội', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/co-hoi');
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  const list = isPhone(page)
    ? page.getByRole('list', { name: 'Cơ hội' })
    : page.getByRole('table', { name: 'Cơ hội' });
  await expect(list.getByText(seeded.opportunity.fresh.code).first()).toBeVisible();
  await expect(list.getByText(seeded.opportunity.skip.code).first()).toBeVisible();
  // Cơ hội chỉ tạo từ trang Lead; nhập file để P3f.
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Nhập', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Group By' })).toBeVisible();
  await expectAccessible(page);
  await list.getByRole('link', { name: 'Em Mới' }).first().click();
  await expect(page).toHaveURL(new RegExp(`/crm/co-hoi/${seeded.opportunity.fresh.id}$`));
});

test('Kanban: đủ tám cột L1 đến L8, cơ hội đúng cột', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto('/crm/co-hoi');
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  for (const stage of ['L1', 'L5', 'L6', 'L8']) {
    await expect(page.getByRole('heading', { name: new RegExp(`^${stage} `) })).toBeVisible();
  }
  await expect(page.getByText(seeded.opportunity.fresh.code).first()).toBeVisible();
  await expect(page.getByText(/^Cơ hội chỉ đi tới/)).toBeVisible();
});

test('Trang Cơ hội: thanh giai đoạn, sáu nút liên kết, nút chưa dùng được mờ, tab Kiểm tra đầu vào', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.gated.id);
  const crumbs = page.getByRole('navigation', { name: 'Đường dẫn' });
  await expect(crumbs.getByRole('link', { name: 'Cơ hội' })).toHaveAttribute('href', '/crm/co-hoi');
  await expect(stageBar(page).getByRole('button', { name: /^L5/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  await expect(page.getByRole('button', { name: 'Lịch hẹn: 0' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Kiểm tra: 1' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Báo giá: 0' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Đơn hàng: 0' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Phụ huynh: 1' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Lead gốc: 1' })).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Tạo báo giá' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Tạo đơn hàng' })).toBeDisabled();
  // Cơ hội ở L5 và người dùng có quyền tạo phiếu: nút dùng được (P3e-2).
  await expect(page.getByRole('button', { name: 'Tạo lịch Test' })).toBeEnabled();
  await expect(page.getByRole('button', { name: /^Đính kèm \(\d+\)$/ })).toHaveCount(0);
  // Nhóm con L5 do hệ thống gắn: ô khoá.
  await expect(page.getByLabel('Sub-stage')).toHaveAttribute('readonly', '');
  // Tab phiếu: mã phiếu là liên kết sang màn Phiếu kiểm tra (P3e-2).
  // Một phiếu duy nhất: nút "Kiểm tra" mở thẳng phiếu (P3e-2); tab bên dưới vẫn liệt kê phiếu.
  await page.getByRole('tab', { name: /Kiểm tra đầu vào/ }).click();
  await expect(page.getByRole('tab', { name: /Kiểm tra đầu vào \(1\)/ })).toHaveAttribute(
    'aria-selected',
    'true',
  );
  await expect(page.getByRole('link', { name: /^PKT\d+$/ })).toBeVisible();
  await expectAccessible(page);
});

test('Chuyển giai đoạn bình thường: L1 sang L2, chọn nhóm con, ghi chú; giai đoạn đã qua bị khoá', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.fresh.id);
  await stageBar(page).getByRole('button', { name: /^L2/ }).click();
  const dialog = dialogOf(page, /Chuyển sang L2/);
  await expect(dialog).toBeVisible();
  await expect(dialog.getByText(/Giai đoạn đã qua bị khoá/)).toBeVisible();
  await pickOption(page, dialog.getByRole('combobox', { name: 'Sub-stage' }), /L2A/);
  await dialog.getByLabel('Ghi chú').fill(`Gọi lần 1 ${setup.mark}`);
  await dialog.getByRole('button', { name: 'Chuyển giai đoạn' }).click();
  await expect(toastText(page, /Đã chuyển sang L2/)).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^L2/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  // Đi tới, không lùi: L1 đã qua, bấm không mở hộp.
  await stageBar(page).getByRole('button', { name: /^L1/ }).click({ force: true });
  await expect(dialogOf(page, /Chuyển sang/)).toHaveCount(0);
  // L6 do hệ thống chuyển.
  // aria-disabled nhưng vẫn bấm được để báo lý do (như bước đã qua).
  await stageBar(page).getByRole('button', { name: /^L6/ }).click({ force: true });
  await expect(toastText(page, /L6 do hệ thống chuyển/)).toBeVisible();
  // Ghi chú của hộp nằm trong cột ghi chú và hoạt động.
  await expect(page.getByText(`Gọi lần 1 ${setup.mark}`).first()).toBeVisible();
});

test('R-CRM-03: thiếu tên học sinh thì chặn L5, nêu ô thiếu, "Đi tới ô cần điền" mở chế độ Sửa', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.nostudent.id);
  await stageBar(page).getByRole('button', { name: /^L5/ }).click();
  const dialog = dialogOf(page, /Chuyển sang L5/);
  await expect(dialog.getByText(/Từ L5 bắt buộc có/)).toBeVisible();
  await expect(dialog.getByText('Tên học sinh (đang trống)')).toBeVisible();
  await expect(dialog.getByText('Năm sinh học sinh (đang trống)')).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Chuyển giai đoạn' })).toBeDisabled();
  await dialog.getByRole('button', { name: 'Đi tới ô cần điền' }).click();
  await expect(page.getByRole('button', { name: 'Lưu' })).toBeVisible();
  await expect(page.getByText(/bắt buộc có tên học sinh/)).toBeVisible();
});

test('R-CRM-12: còn phiếu dang dở thì chặn L7, nêu mã phiếu, nút mở phiếu dùng được', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.gated.id);
  await stageBar(page).getByRole('button', { name: /^L7/ }).click();
  const dialog = dialogOf(page, /Chuyển sang L7/);
  await expect(dialog.getByText(/Cơ hội còn phiếu kiểm tra đang dở/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: /^Mở phiếu PKT/ })).toBeEnabled();
  await expect(dialog.getByRole('button', { name: 'Chuyển giai đoạn' })).toBeDisabled();
});

test('R-CRM-14, 16: bỏ qua test bắt lý do; L8 bắt nhóm con và xác nhận không hoàn tác', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.skip.id);
  await stageBar(page).getByRole('button', { name: /^L7/ }).click();
  const skip = dialogOf(page, /Chuyển sang L7/);
  await expect(skip.getByText(/chưa có phiếu kiểm tra/)).toBeVisible();
  await expect(skip.getByRole('button', { name: 'Chuyển giai đoạn' })).toBeDisabled();
  // Lý do "Khác" bắt ghi chú.
  await pickOption(page, skip.getByRole('combobox', { name: 'Lý do bỏ qua test' }), /^Khác$/);
  await expect(skip.getByRole('button', { name: 'Chuyển giai đoạn' })).toBeDisabled();
  await skip.getByLabel('Ghi chú').fill('Đã test ở trung tâm khác');
  await skip.getByRole('button', { name: 'Chuyển giai đoạn' }).click();
  await expect(toastText(page, /Đã chuyển sang L7/)).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^L7/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  // L8: lý do bỏ qua (chưa có phiếu), nhóm con, xác nhận.
  await stageBar(page).getByRole('button', { name: /^L8/ }).click();
  const l8 = dialogOf(page, /Chuyển sang L8/);
  await expect(l8.getByText(/^Chuyển L8 không hoàn tác được\./)).toBeVisible();
  await expect(l8.getByRole('button', { name: 'Chuyển L8' })).toBeDisabled();
  await pickOption(page, l8.getByRole('combobox', { name: 'Lý do bỏ qua test' }), /^Khác$/);
  await l8.getByLabel(/^Ghi chú/).fill('Đã test ở trung tâm khác');
  await pickOption(page, l8.getByRole('combobox', { name: 'Sub-stage' }), /L8A/);
  await expect(l8.getByRole('button', { name: 'Chuyển L8' })).toBeDisabled();
  await l8.getByRole('checkbox').check();
  await l8.getByRole('button', { name: 'Chuyển L8' }).click();
  await expect(toastText(page, /Đã chuyển sang L8/)).toBeVisible();
  await expect(stageBar(page).getByRole('button', { name: /^L8/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
});

test('Sửa thông tin học sinh rồi Lưu; Huỷ không lưu', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.fresh.id);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Trường học').fill('THCS Thử nghiệm');
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  await expect(page.getByText('THCS Thử nghiệm')).toHaveCount(0);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Trường học').fill('THCS Thử nghiệm');
  await page.getByRole('button', { name: 'Lưu' }).click();
  await expect(toastText(page, 'Đã lưu.')).toBeVisible();
  await expect(page.getByText('THCS Thử nghiệm').first()).toBeVisible();
});

test('Lịch hẹn của cơ hội: tạo từ trang Cơ hội, nút "Lịch hẹn" mở danh sách đã lọc; Lịch hẹn tạo được gắn cơ hội', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, seeded.opportunity.fresh.id);
  await page.getByRole('button', { name: 'Lên lịch hẹn' }).click();
  const dialog = dialogOf(page, 'Tạo lịch hẹn');
  await expect(dialog.getByLabel('Gắn với')).toHaveValue(new RegExp(seeded.opportunity.fresh.code));
  await pickChip(dialog, 'Ngày mai');
  await pickChip(dialog, '09:00');
  await dialog.getByLabel(/Ghi chú/).fill(`Hẹn cơ hội ${setup.mark}`);
  await dialog.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
  await expect(page.getByText(`Hẹn cơ hội ${setup.mark}`).first()).toBeVisible();
  await page.getByRole('button', { name: 'Lịch hẹn: 1' }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen\?co-hoi=/);
  await expect(
    page.getByText(new RegExp(`^Cơ hội: ${seeded.opportunity.fresh.code}`)).first(),
  ).toBeVisible();
  await expect(page.getByText(`Hẹn cơ hội ${setup.mark}`).first()).toBeVisible();
  // Bỏ chip: về danh sách chung.
  await page.getByRole('button', { name: /^Bỏ điều kiện: Cơ hội: CO/ }).click();
  await expect(page).toHaveURL(/\/crm\/lich-hen$/);
  // Tạo ở màn Lịch hẹn: ô "Gắn với" chọn được cơ hội.
  await page.getByRole('button', { name: 'Tạo', exact: true }).click();
  const create = dialogOf(page, 'Tạo lịch hẹn');
  await create.getByRole('combobox', { name: /Gắn với/ }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill(seeded.opportunity.skip.code);
  await page
    .getByRole('option', { name: new RegExp(`Cơ hội ${seeded.opportunity.skip.code}`) })
    .click();
  await expect(create.getByRole('combobox', { name: /Gắn với/ })).toContainText(
    seeded.opportunity.skip.code,
  );
  await pickChip(create, 'Ngày mai');
  await pickChip(create, '10:00');
  await create.getByLabel(/Ghi chú/).fill(`Hẹn gắn cơ hội ${setup.mark}`);
  await create.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
});

test('Tạo cơ hội từ lead: hộp xác nhận; tạo xong mở cơ hội L1; tạo lần hai có cảnh báo và mở cơ hội cũ', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await login(page, setup.account);
  await page.goto(`/crm/lead/${seeded.lonelyLeadId}`);
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo cơ hội' }).click();
  const dialog = dialogOf(page, 'Tạo cơ hội từ lead');
  await expect(dialog.getByText(/bắt đầu ở giai đoạn L1/)).toBeVisible();
  await expect(dialog.getByText(/đã có .* cơ hội/)).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Tạo cơ hội' }).click();
  await expect(toastText(page, /Đã tạo cơ hội CO\d+/)).toBeVisible();
  await expect(page).toHaveURL(/\/crm\/co-hoi\/[0-9a-f-]+$/);
  await expect(stageBar(page).getByRole('button', { name: /^L1/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  // Về Lead: nút "Cơ hội: 1" mở thẳng cơ hội; Tạo cơ hội lần hai phải xác nhận.
  await page.getByRole('button', { name: 'Lead gốc: 1' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  await page.getByRole('button', { name: 'Cơ hội: 1' }).click();
  await expect(page).toHaveURL(/\/crm\/co-hoi\/[0-9a-f-]+$/);
  await page.getByRole('button', { name: 'Lead gốc: 1' }).click();
  await page.getByRole('button', { name: 'Tạo cơ hội' }).click();
  const again = dialogOf(page, 'Tạo cơ hội từ lead');
  await expect(again.getByText(/Lead này đã có 1 cơ hội đang dùng/)).toBeVisible();
  await expect(again.getByRole('button', { name: 'Vẫn tạo thêm' })).toBeDisabled();
  await again.getByRole('button', { name: 'Mở cơ hội cũ' }).click();
  await expect(page).toHaveURL(/\/crm\/co-hoi\/[0-9a-f-]+$/);
});
