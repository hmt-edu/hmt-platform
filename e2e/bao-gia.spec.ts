// BH-01 Báo giá (danh sách), P5a-UI-1: cột theo canvas, lọc, tìm, Xuất theo quyền, mục menu theo công tắc Bán hàng.
// Dữ liệu giả dựng bằng hàm nghiệp vụ (xem bao-gia-seed.ts), tìm bằng dấu riêng của từng dự án.
import { readFileSync, writeFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone, shotPath } from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded } from './bao-gia-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng báo giá giả).');
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

async function openQuotes(page: Page, account: string, mark: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/bao-gia');
  await expect(page.getByRole('heading', { level: 1, name: 'Báo giá' })).toBeVisible();
  await page.getByRole('searchbox').fill(mark);
  // Tìm kiếm chờ một nhịp rồi mới gọi máy chủ: đợi tới khi chỉ còn bốn báo giá của dự án.
  await expect(page.getByText('1–5 / 5')).toBeVisible();
}

function list(page: Page) {
  return isPhone(page)
    ? page.getByRole('list', { name: 'Báo giá' })
    : page.getByRole('table', { name: 'Báo giá' });
}

async function pickFilters(page: Page, labels: string[], uncheck: string[] = []) {
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  for (const label of uncheck) await page.getByLabel(label, { exact: true }).uncheck();
  for (const label of labels) await page.getByLabel(label, { exact: true }).check();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
}

test('Sale CS5: danh sách đủ cột theo canvas, không có Tạo, không có Xuất', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  const rows = list(page);
  await expect(rows.getByText(seeded.code.draft)).toBeVisible();
  await expect(rows.getByText(seeded.code.sent)).toBeVisible();
  // Cột Học sinh hiện đủ hai em của báo giá Nháp (canvas BH01).
  await expect(rows.getByText(seeded.students.draft.join(', '))).toBeVisible();
  // Tình trạng, nhãn quá hạn do máy chủ tính.
  await expect(rows.getByText('Nháp').first()).toBeVisible();
  await expect(rows.getByText('Đã gửi').first()).toBeVisible();
  await expect(rows.getByText('Từ chối').first()).toBeVisible();
  await expect(rows.getByText('Quá hạn 3 ngày')).toBeVisible();
  // R-TIEN-02: danh sách không có nút Tạo; Đ105: Sale không có nút Xuất.
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xuất', exact: true })).toHaveCount(0);
  await expectAccessible(page);
});

test('Tìm theo mã và lọc nhanh Tình trạng', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  await page.getByRole('searchbox').fill(seeded.code.rejected);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.parent.rejected)).toBeVisible();
  await page.getByRole('searchbox').fill(setup.mark);
  await expect(page.getByText('1–5 / 5')).toBeVisible();
  await pickFilters(page, ['Nháp']);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.code.draft)).toBeVisible();
});

test('Lọc nhanh Đã chuyển đơn: chỉ báo giá đã lên đơn; Đã gửi không lẫn báo giá đã lên đơn; chọn cả hai thì HOẶC', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.sale, setup.mark);
  await pickFilters(page, ['Đã chuyển đơn']);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toBeVisible();
  await expect(list(page).getByText(seeded.code.sent)).toHaveCount(0);
  // Đã gửi chỉ gồm báo giá chưa chuyển hết (Đ243): Đã gửi và Quá hạn, không có báo giá đã chuyển đơn.
  await pickFilters(page, ['Đã gửi'], ['Đã chuyển đơn']);
  await expect(page.getByText('1–2 / 2')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toHaveCount(0);
  // Chọn thêm Đã chuyển đơn: nối bằng HOẶC, đủ ba báo giá.
  await pickFilters(page, ['Đã chuyển đơn']);
  await expect(page.getByText('1–3 / 3')).toBeVisible();
  await expect(list(page).getByText(seeded.code.converted)).toBeVisible();
});

test('Trưởng cơ sở có nút Xuất; file CSV có BOM và báo giá trong phạm vi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openQuotes(page, setup.manager, setup.mark);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^bao-gia-\d{4}-\d{2}-\d{2}\.csv$/);
  const text = readFileSync(await file.path(), 'utf8');
  expect(text.startsWith('﻿Mã,Tình trạng')).toBe(true);
  expect(text).toContain(seeded.code.sent);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Công tắc Bán hàng: CS1 chưa bật thì không có mục Báo giá và mở thẳng đường dẫn thì báo chưa bật', async ({
  page,
}) => {
  await enterAs(page, 'sale.cs1');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/bao-gia');
  await expect(page.getByText(/chưa bật/i).first()).toBeVisible();
});

async function openRecord(page: Page, account: string, mark: string, code: string) {
  await openQuotes(page, account, mark);
  await page.getByRole('searchbox').fill(code);
  await expect(page.getByText('1–1 / 1')).toBeVisible();
  await list(page).getByRole('link', { name: code }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Báo giá' })).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: code })).toBeVisible();
}

test('BH-02 chỉ đọc: báo giá Nháp hai em, tổng tiền, không có nút Sửa', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  const grid = page.getByRole('table', { name: 'Gói học' });
  await expect(grid.getByText('Em Nháp Một')).toBeVisible();
  await expect(grid.getByText('Em Nháp Hai')).toBeVisible();
  await expect(grid.getByText('Offline').first()).toBeVisible();
  // Q-76 (BH02_gui): số lượng và đơn vị là hai cột.
  await expect(
    grid.getByRole('row', { name: /Em Nháp Một/ }).getByRole('cell', { name: '10', exact: true }),
  ).toBeVisible();
  await expect(
    grid.getByRole('row', { name: /Em Nháp Hai/ }).getByRole('cell', { name: '5', exact: true }),
  ).toBeVisible();
  await expect(grid.getByRole('cell', { name: 'giờ', exact: true }).first()).toBeVisible();
  await expect(grid.getByRole('columnheader')).toHaveText([
    '#',
    'Học sinh',
    'Gói',
    'Hình thức',
    'Số lượng',
    'Đơn vị',
    'Giờ tặng',
    'Đơn giá',
    'Loại chiết khấu',
    '%',
    'Giảm',
    'Thành tiền',
  ]);
  await expect(page.getByText('Tổng thành tiền')).toBeVisible();
  await expect(page.locator('b', { hasText: '3.300.000 đ' })).toBeVisible();
  await expect(page.getByText('Chưa thấy em? Thêm em ở cơ hội.')).toHaveCount(0);
  // Đ248: điện thoại giữ bản chỉ đọc, ẩn nút Sửa; máy tính có nút Sửa.
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toHaveCount(
    isPhone(page) ? 0 : 1,
  );
  await expectAccessible(page);
});

function paper(page: Page) {
  return page.locator('.k13-paper');
}

async function shot(page: Page, testInfo: { project: { name: string } }, name: string) {
  if (testInfo.project.name === 'dien-thoai') return;
  // Chụp ở chế độ in: đúng tờ A4 như hộp in của trình duyệt sẽ thấy.
  await page.emulateMedia({ media: 'print' });
  await page.screenshot({
    path: shotPath('bh03', `${name}.png`),
    clip: { x: 0, y: 0, width: 794, height: 1123 },
  });
  await page.emulateMedia({ media: 'screen' });
}

/** Bản in đã mở: tiêu đề, số, nhãn (nếu có), cơ sở; hạn hiệu lực có ngày hay để trống. */
async function expectPrint(page: Page, code: string, want: { stamp: string | null; due: boolean }) {
  const sheet = paper(page);
  await expect(sheet.getByRole('heading', { level: 1, name: 'BẢNG HỌC PHÍ' })).toBeVisible();
  await expect(sheet.getByText(code, { exact: true })).toBeVisible();
  await expect(sheet.getByRole('heading', { level: 2 })).toContainText('Hoà Ma Toán · ');
  for (const stamp of ['BẢN NHÁP', 'ĐÃ TỪ CHỐI', 'ĐÃ HUỶ']) {
    if (stamp === want.stamp) await expect(sheet.getByText(stamp, { exact: true })).toBeVisible();
    else await expect(sheet.getByText(stamp, { exact: true })).toHaveCount(0);
  }
  await expect(sheet.locator('.k13-blank')).toHaveCount(want.due ? 0 : 1);
  // Hai dòng tổng do máy chủ trả (migration 062): niêm yết trừ chiết khấu bằng thành tiền, trình duyệt không cộng.
  await expect(sheet.getByText('Tổng niêm yết')).toBeVisible();
  await expect(sheet.getByText('Tổng chiết khấu')).toBeVisible();
  await expect(sheet.getByText('Bằng chữ')).toBeVisible();
  await expect(sheet.getByText(/đồng$/)).toBeVisible();
  // Khuôn: không in điện thoại cơ sở và khẩu hiệu.
  await expect(sheet.getByText(/Hotline|Điện thoại cơ sở|Tel/i)).toHaveCount(0);
}

test('BH-03: In từ menu Hành động; bản in Đã gửi có đủ khối, nút In ẩn trên điện thoại, In và Tải PDF cùng mở hộp in', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/bao-gia\/[0-9a-f-]+\/in$/);
  await expectPrint(page, seeded.code.sent, { stamp: null, due: true });
  await expect(paper(page).getByText('Kính gửi phụ huynh', { exact: false })).toBeVisible();
  await expect(paper(page).getByText('Phụ huynh xác nhận')).toBeVisible();
  await expect(paper(page).getByText(/^In ngày \d{2}\/\d{2}\/\d{4}$/)).toBeVisible();
  await expect(page.getByText('Chọn “Lưu thành PDF” để tải')).toBeVisible();
  await page.evaluate('window.printed = 0; window.print = () => { window.printed += 1; };');
  await page.getByRole('button', { name: 'Tải PDF' }).click();
  const inButton = page.getByRole('button', { name: 'In', exact: true });
  if (isPhone(page)) {
    await expect(inButton).toHaveCount(0);
  } else {
    await inButton.click();
    expect(await page.evaluate('window.printed')).toBe(2);
  }
  await expectAccessible(page);
  await shot(page, testInfo, 'bh03-da-gui');
});

test('BH-03: Nháp để trống hạn và có nhãn BẢN NHÁP; Từ chối có nhãn ĐÃ TỪ CHỐI; quá hạn nêu số ngày', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expectPrint(page, seeded.code.draft, { stamp: 'BẢN NHÁP', due: false });
  await shot(page, testInfo, 'bh03-nhap');
  await openRecord(page, setup.sale, setup.mark, seeded.code.overdue);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expectPrint(page, seeded.code.overdue, { stamp: null, due: true });
  await expect(paper(page).getByText(/Đã quá hạn \d+ ngày/)).toBeVisible();
  // Báo giá này có chính sách chiết khấu: tổng chiết khấu hiện số tiền giảm, có dấu trừ.
  await expect(paper(page).locator('.k13-tr', { hasText: 'Tổng chiết khấu' })).toContainText(
    /− [\d.]+/,
  );
  await shot(page, testInfo, 'bh03-qua-han');
  await openRecord(page, setup.sale, setup.mark, seeded.code.rejected);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expectPrint(page, seeded.code.rejected, { stamp: 'ĐÃ TỪ CHỐI', due: true });
  await shot(page, testInfo, 'bh03-tu-choi');
});

test('BH-03: in thật trên A4 (chỉ trình duyệt máy tính): chỉ còn tờ giấy, một trang A4', async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'page.pdf chỉ có ở Chromium.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expectPrint(page, seeded.code.sent, { stamp: null, due: true });
  await page.emulateMedia({ media: 'print' });
  // Menu, thanh công cụ và tên người dùng ẩn khi in.
  await expect(page.getByRole('button', { name: 'Tải PDF' })).toBeHidden();
  await expect(page.getByRole('navigation').first()).toBeHidden();
  const pdf = await page.pdf({ preferCSSPageSize: true });
  const text = pdf.toString('latin1');
  expect(text.match(/\/Type\s*\/Page\b/g)?.length).toBe(1);
  // MediaBox A4 = 595 x 842 điểm (làm tròn).
  const box = /\/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]/.exec(text);
  expect(Math.round(Number(box?.[1]))).toBe(595);
  expect(Math.round(Number(box?.[2]))).toBe(842);
  writeFileSync(shotPath('bh03', 'bh03-a4.pdf'), pdf);
  await page.screenshot({ path: shotPath('bh03', 'bh03-che-do-in.png') });
});

// Q-72: Báo giá xem (bảng một hàng, cuộn ngang) không làm trang tràn ngang ở 1440 và 1280, mỗi dòng một hàng.
for (const width of [1440, 1280]) {
  test(`Báo giá xem ${width}px: trang không tràn ngang, mỗi dòng một hàng`, async ({
    page,
  }, testInfo) => {
    test.skip(isPhone(page), 'Cỡ máy tính.');
    const setup = setupOf(testInfo.project.name);
    await page.setViewportSize({ width, height: 900 });
    await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
    const view = page.getByRole('table', { name: 'Gói học' });
    await expect(view).toBeVisible();
    const overflow = await page.evaluate<number>(
      'document.documentElement.scrollWidth - document.documentElement.clientWidth',
    );
    expect(overflow).toBeLessThanOrEqual(0);
    for (const row of await view
      .getByRole('row')
      .all()
      .then((r) => r.slice(1))) {
      expect((await row.boundingBox())?.height ?? 999).toBeLessThan(70);
    }
  });
}

// Q-82: bảng dòng (LineTable) luôn có thanh cuộn ngang kiểu cổ điển (không để macOS ẩn) và vệt mờ mép phải khi còn cột bị che, mất khi đã cuộn tới cuối.
// Playwright chạy Chromium với --hide-scrollbars nên không đo bề dày thanh cuộn thật: kiểm lớp line-scroll và luật ::-webkit-scrollbar cao 12px đã nạp.
async function expectScrollAffordance(page: Page, tableName: string) {
  const scroller = page.getByRole('table', { name: tableName }).locator('xpath=..');
  await expect(scroller).toHaveClass(/line-scroll/);
  const hasRule: boolean = await page.evaluate(
    "[...document.styleSheets].some((sheet) => [...sheet.cssRules].some((rule) => rule.cssText.includes('::-webkit-scrollbar') && rule.cssText.includes('height: 12px')))",
  );
  expect(hasRule).toBe(true);
  const scrollTo = (end: boolean) =>
    page.evaluate(
      `(() => { const s = document.querySelector('table[aria-label="${tableName}"]').parentElement; s.scrollLeft = ${end ? 's.scrollWidth' : '0'}; })()`,
    );
  const fade = page.getByTestId('line-table-fade');
  await expect(fade).toBeVisible();
  await scrollTo(true);
  await expect(fade).toHaveCount(0);
  await scrollTo(false);
  await expect(fade).toBeVisible();
}

// Q-72, Q-73, Q-74: lưới Gói học là bảng MỘT HÀNG MỘT DÒNG đúng cột của khung (Tạo: BH02_tao 11 cột; Sửa: BH02_sua 13 cột, cột cuối là nút xoá),
// chữ không xuống hàng, cả thẻ trắng và trang không tràn ngang (cột không vừa thì cuộn trong khung bảng).
async function expectLineGrid(page: Page, headers: string[]) {
  const grid = page.getByRole('table', { name: 'Gói học (đang sửa)' });
  await expect(grid.getByRole('columnheader')).toHaveCount(headers.length + 1);
  for (const name of headers)
    await expect(grid.getByRole('columnheader', { name, exact: true })).toBeVisible();
  // Mở ra phải thấy từ cột # (không cuộn sẵn), kèm dòng hướng dẫn kéo ngang của khung BH02_sua.
  await expect(grid.getByRole('columnheader', { name: '#', exact: true })).toBeInViewport();
  await expect(page.getByText('Kéo thanh ngang để xem các cột bên phải.')).toBeVisible();
  // Trần chiết khấu (tham số cài đặt, mặc định 20%) hiện dưới bảng ở cả Tạo và Sửa, như khung BH02_sua.
  await expect(
    page.getByText(
      /^Trần chiết khấu mỗi dòng \d+%\. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được\.$/,
    ),
  ).toBeVisible();
  const overflow = await page.evaluate<number>(
    'document.documentElement.scrollWidth - document.documentElement.clientWidth',
  );
  expect(overflow).toBeLessThanOrEqual(0);
  for (const row of await grid
    .getByRole('row')
    .all()
    .then((r) => r.slice(1))) {
    expect((await row.boundingBox())?.height ?? 999).toBeLessThan(80);
  }
}

test('BH-02 sửa Nháp: lưới K06c, thiếu số lượng báo lỗi theo khung, sửa số lượng rồi Lưu', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Sửa.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  const grid = page.getByRole('table', { name: 'Gói học (đang sửa)' });
  await expect(grid.getByRole('rowgroup', { name: 'Dòng 1' })).toBeVisible();
  await expect(grid.getByRole('rowgroup', { name: 'Dòng 2' })).toBeVisible();
  await expectLineGrid(page, [
    '#',
    'Học sinh',
    'Gói',
    'Hình thức',
    'Số lượng',
    'Đơn vị',
    'Giờ tặng',
    'Đơn giá',
    'Loại chiết khấu',
    '%',
    'Giảm',
    'Thành tiền',
  ]);
  await expectScrollAffordance(page, 'Gói học (đang sửa)');
  await expect(page.getByRole('link', { name: 'Thêm em ở cơ hội.' })).toBeVisible();
  await expectAccessible(page);
  // Xoá số lượng dòng 1: báo lỗi theo khung, chưa lưu.
  await page.getByLabel('Số lượng dòng 1').fill('');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Chưa lưu được.')).toBeVisible();
  await expect(page.getByText(/^Dòng 1 \(LC-TOAN-K09 · .*\) thiếu số lượng\.$/)).toBeVisible();
  await expect(page.getByText('Bắt buộc nhập số lượng.')).toBeVisible();
  // Nhập số hợp lệ thì lỗi tự mất (cả dòng báo và khối "Chưa lưu được"); đổi 10 giờ thành 20 giờ, Lưu.
  await page.getByLabel('Số lượng dòng 1').fill('20');
  await expect(page.getByText('Bắt buộc nhập số lượng.')).toHaveCount(0);
  await expect(page.getByText('Chưa lưu được.')).toHaveCount(0);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu báo giá.').first()).toBeVisible();
  const view = page.getByRole('table', { name: 'Gói học' });
  await expect(view.getByRole('cell', { name: '20', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
});

test('BH-02 sửa Nháp: hộp Chọn gói, thêm dòng mới (chọn em, gói, số lượng), Huỷ bỏ thay đổi', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Sửa.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByRole('button', { name: 'Thêm dòng' }).click();
  await expect(page.getByRole('rowgroup', { name: 'Dòng 3' })).toBeVisible();
  await page.getByRole('combobox', { name: 'Học sinh dòng 3' }).click();
  await page.getByRole('option', { name: /Em Nháp Một/ }).click();
  await page.getByRole('button', { name: 'Gói dòng 3' }).click();
  const dialog = page.getByRole('dialog', { name: 'Chọn gói' });
  await expect(dialog.getByText('TẤT CẢ GÓI', { exact: false })).toBeVisible();
  await expect(dialog.getByText(/Giá lấy từ bảng giá đang hiệu lực/)).toBeVisible();
  await dialog
    .getByRole('button', { name: /LC-TOAN-K09/ })
    .first()
    .click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Gói dòng 3' })).toContainText('LC-TOAN-K09');
  await page.getByLabel('Số lượng dòng 3').fill('3');
  // Bỏ thay đổi: về bản đã lưu (hai dòng).
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
  const view = page.getByRole('table', { name: 'Gói học' });
  await expect(view.getByText('Em Nháp Hai')).toBeVisible();
  await expect(view.getByRole('cell', { name: '3', exact: true })).toHaveCount(0);
});

test('BH-02: cột Đơn nêu mã và trạng thái đơn; báo giá chưa lên đơn hiện dấu gạch', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.converted);
  const grid = page.getByRole('table', { name: 'Gói học' });
  await expect(grid.getByText(seeded.orderCode)).toBeVisible();
  await expect(grid.getByText('Nháp', { exact: true })).toBeVisible();
  // Báo giá đã lên đơn: không còn nút Từ chối (đã có đơn đang sống).
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toHaveCount(0);
  await page.goto('/crm/bao-gia');
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await expect(page.getByText(seeded.orderCode)).toHaveCount(0);
  await expectAccessible(page);
});

test('BH-02 chỉ đọc: Từ chối nêu lý do, Quá hạn nêu nhãn, Đã gửi nêu ngày gửi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.rejected);
  await expect(page.locator('b', { hasText: 'Lý do từ chối' })).toBeVisible();
  await expect(page.getByText(/Giá chưa đúng/).first()).toBeVisible();
  await page.goto('/crm/bao-gia');
  await openRecord(page, setup.sale, setup.mark, seeded.code.overdue);
  await expect(page.getByText('Đã quá hạn 3 ngày')).toBeVisible();
  await expect(page.getByText(/^Đã gửi cho phụ huynh ngày/)).toBeVisible();
});

test('BH-02: ghi chú gắn vào báo giá; báo giá không có thì báo không tìm thấy', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  const note = `Phụ huynh hẹn trả lời ${setup.mark}`;
  await page.getByPlaceholder(/Viết ghi chú/).fill(note);
  await page.getByRole('button', { name: 'Gửi ghi chú' }).click();
  await expect(page.getByText(note)).toBeVisible();
  // Mở trực tiếp một báo giá không tồn tại: báo không tìm thấy.
  await page.goto('/crm/bao-gia/00000000-0000-0000-0000-000000000000');
  await expect(page.getByRole('heading', { name: 'Không tìm thấy báo giá' })).toBeVisible();
});

test('BH-02 sửa Nháp: chính sách chiết khấu, Tổng chiết khấu, Tổng cộng do máy chủ tính; giờ tặng vượt trần', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Sửa.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  const row1 = page.getByRole('rowgroup', { name: 'Dòng 1' });
  // Tổng cộng báo giá do xem thử trả (không chiết khấu): 20 giờ + 5 giờ, mỗi giờ 220.000.
  await expect(page.getByText('5.500.000 đ')).toBeVisible();
  // Hộp Chọn chính sách chiết khấu: chọn "áp đúng mức" 5%.
  await row1.getByRole('button', { name: 'Chính sách' }).click();
  const dialog = page.getByRole('dialog', { name: 'Chọn chính sách chiết khấu' });
  await expect(dialog.getByText(/tối đa một chính sách tặng giờ/)).toBeVisible();
  await expectAccessible(page);
  await dialog.getByLabel(/Giảm khi đóng 6 tháng/).check();
  await dialog.getByRole('button', { name: 'Áp dụng' }).click();
  await expect(row1.getByText(/5% \(áp đúng mức\)/)).toBeVisible();
  // Cột % của bảng Sửa (BH02_sua) là Tổng chiết khấu máy chủ trả.
  await expect(row1.getByText('5%', { exact: true })).toBeVisible();
  await expect(page.getByText('5.280.000 đ')).toBeVisible();
  // Chính sách tặng giờ: tối đa một; chưa nhập giờ thì máy chủ báo lỗi ở dòng.
  await row1.getByRole('button', { name: 'Chính sách' }).click();
  await dialog.getByLabel(/Tặng giờ học/).check();
  await dialog.getByRole('button', { name: 'Áp dụng' }).click();
  await expect(row1.getByText(/phải lớn hơn 0/)).toBeVisible();
  // Nhập 4 giờ tặng trên 20 giờ mua: 5% + 20% = 25%, vượt trần, vẫn lưu được.
  await page.getByLabel('Giờ tặng dòng 1').fill('4');
  // Khung BH02_chip_vuot_tran: câu trần hiện trong hộp cảnh báo vàng (role status), vẫn Lưu được (R-V2-11).
  const capBox = page.getByRole('status').filter({
    hasText: /^Trần chiết khấu mỗi dòng \d+%\. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được\.$/,
  });
  await expect(capBox).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeEnabled();
  await expect(row1.getByText('25%', { exact: true })).toBeVisible();
  // Chữ đơn vị của ô Số lượng không đè lên ô Giờ tặng; hai ô cùng hàng, cùng cao.
  const qty = await page.getByLabel('Số lượng dòng 1').boundingBox();
  const gift = await page.getByLabel('Giờ tặng dòng 1').boundingBox();
  const unit = await row1.getByText('giờ', { exact: true }).first().boundingBox();
  expect(qty && gift && unit).toBeTruthy();
  if (qty && gift && unit) {
    expect(unit.x + unit.width).toBeLessThanOrEqual(gift.x);
    expect(Math.abs(qty.y - gift.y)).toBeLessThanOrEqual(1);
    expect(Math.abs(qty.height - gift.height)).toBeLessThanOrEqual(1);
  }
  // Lưu rồi xem lại: chiết khấu và giờ tặng hiện ở bản xem.
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu báo giá.').first()).toBeVisible();
  const view = page.getByRole('table', { name: 'Gói học' });
  // Q-76 (BH02_gui): sau khi lưu, dòng xem tách cột: Giờ tặng 4, Loại chiết khấu nêu tên hai chính sách, % là tổng 25% (5% + 4/20 giờ quy ra 20%).
  const saved = view.getByRole('row', { name: /Em Nháp Một/ });
  await expect(saved.getByRole('cell', { name: '4', exact: true })).toBeVisible();
  await expect(saved.getByRole('cell', { name: '25%', exact: true })).toBeVisible();
  await expect(saved.getByRole('cell', { name: /Giảm khi đóng 6 tháng/ })).toBeVisible();
});

test('BH-02 sửa Nháp: dòng mới mặc định em đầu của cơ hội (R-TIEN-35), đổi được; chọn gói và số lượng thì tính giá', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Sửa.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByRole('button', { name: 'Thêm dòng' }).click();
  const row3 = page.getByRole('rowgroup', { name: 'Dòng 3' });
  await expect(page.getByRole('combobox', { name: 'Học sinh dòng 3' })).toContainText(
    'Em Nháp Một',
  );
  await page.getByRole('button', { name: 'Gói dòng 3' }).click();
  await page
    .getByRole('dialog', { name: 'Chọn gói' })
    .getByRole('button', { name: /LC-TOAN-K09/ })
    .first()
    .click();
  await page.getByLabel('Số lượng dòng 3').fill('4');
  await expect(row3.getByText('880.000')).toBeVisible();
  // Đổi sang em khác vẫn được.
  await page.getByRole('combobox', { name: 'Học sinh dòng 3' }).click();
  await page.getByRole('option', { name: /Em Nháp Hai/ }).click();
  await expect(page.getByRole('combobox', { name: 'Học sinh dòng 3' })).toContainText(
    'Em Nháp Hai',
  );
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
});

test('BH-02 sửa Nháp: thêm quà tặng qua chính sách quà tặng; vượt mức báo lỗi; quà không đổi Tổng cộng', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Sửa.');
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  const total = page.locator('p', { hasText: 'Tổng cộng báo giá' });
  await expect(total).toContainText('5.280.000 đ');
  await page.getByRole('button', { name: 'Thêm quà tặng' }).click();
  const dialog = page.getByRole('dialog', { name: 'Chọn chính sách quà tặng' });
  await expect(dialog.getByText(/không tính vào trần chiết khấu/)).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: /Tặng bộ tài liệu Toán/ }).click();
  // Dòng quà đánh số tiếp theo dòng gói; chưa chọn em thì ghi "Chọn em để thêm quà".
  const gift = page.getByRole('rowgroup', { name: 'Dòng 3' });
  await expect(gift.getByText('Quà tặng', { exact: true })).toBeVisible();
  await expect(gift.getByText('TL-MATOAN')).toBeVisible();
  // Dòng quà không có giờ tặng: ô Giờ tặng để trống (không có ô nhập, không ghi 0).
  await expect(page.getByLabel('Giờ tặng dòng 3')).toHaveCount(0);
  // R-TIEN-35: dòng quà cũng mặc định em đầu.
  await expect(page.getByRole('combobox', { name: 'Học sinh dòng 3' })).toContainText(
    'Em Nháp Một',
  );
  await page.getByLabel('Số lượng dòng 3').fill('1');
  await expect(gift.getByText('0 đ').first()).toBeVisible();
  // Quà không đổi Tổng cộng báo giá.
  await expect(total).toContainText('5.280.000 đ');
  // Vượt mức tối đa của chính sách: câu lỗi của máy chủ ngay dưới dòng.
  await page.getByLabel('Số lượng dòng 3').fill('5');
  await expect(gift.getByText('Dòng 3: số lượng quà không quá 1.')).toBeVisible();
  await page.getByLabel('Số lượng dòng 3').fill('1');
  await expect(gift.getByText(/không quá 1\./)).toHaveCount(0);
  // Thêm dòng gói mới sau khi đã có quà: dòng gói đứng trước dòng quà.
  await page.getByRole('button', { name: 'Thêm dòng' }).click();
  await expect(page.getByRole('rowgroup', { name: 'Dòng 3' }).getByText('Chọn gói…')).toBeVisible();
  await expect(
    page.getByRole('rowgroup', { name: 'Dòng 4' }).getByText('Quà tặng', { exact: true }),
  ).toBeVisible();
  await page
    .getByRole('rowgroup', { name: 'Dòng 3' })
    .getByRole('button', { name: 'Xoá dòng 3' })
    .click();
  // Lưu rồi xem lại: dòng quà hiện ở bản xem.
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu báo giá.').first()).toBeVisible();
  const view = page.getByRole('table', { name: 'Gói học' });
  await expect(view.getByText('Tặng bộ tài liệu Toán')).toBeVisible();
});

test('BH-02: Sale bấm Gửi báo giá Nháp thì thành Đã gửi, hết nút Gửi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.draft);
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Gửi', exact: true }).click();
  await expect(page.getByText('Đã gửi báo giá.').first()).toBeVisible();
  await expect(page.getByText(/^Đã gửi cho phụ huynh ngày/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Gửi', exact: true })).toHaveCount(0);
  // Báo giá Đã gửi (chưa lên đơn) có nút Từ chối.
  await expect(page.getByRole('button', { name: 'Từ chối', exact: true })).toBeVisible();
});

test('BH-02: Từ chối báo giá qua hộp BH-04, bắt chọn lý do; xong hiện lý do', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.sent);
  await page.getByRole('button', { name: 'Từ chối', exact: true }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Từ chối báo giá' })).toBeVisible();
  // Chưa chọn lý do thì chưa xác nhận được.
  await expect(dialog.getByRole('button', { name: 'Xác nhận' })).toBeDisabled();
  await expectAccessible(page);
  await dialog.getByRole('combobox').click();
  // Lý do chỉ áp dụng cho phiếu thu (Sai số tiền) không hiện ở báo giá.
  await expect(page.getByRole('option', { name: 'Sai số tiền' })).toHaveCount(0);
  await page.getByRole('option', { name: 'Không đúng chính sách' }).click();
  await dialog.getByRole('button', { name: 'Xác nhận' }).click();
  await expect(page.getByText('Đã từ chối báo giá.').first()).toBeVisible();
  await expect(page.locator('b', { hasText: 'Lý do từ chối' })).toBeVisible();
  await expect(page.getByRole('alertdialog')).toHaveCount(0);
});

test('BH-02: menu Hành động có In (mở bản in BH-03) và Huỷ báo giá; có đơn đang xử lý thì hộp báo lỗi và không đóng', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.converted);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'In', exact: true })).toBeEnabled();
  await page.getByRole('menuitem', { name: 'Huỷ báo giá' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog.getByRole('heading', { name: 'Huỷ báo giá' })).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Đóng' })).toBeVisible();
  await expectAccessible(page);
  await dialog.getByRole('button', { name: 'Xác nhận huỷ' }).click();
  await expect(
    dialog.getByText('Báo giá đã có đơn đang xử lý, không huỷ được. Huỷ đơn trước.'),
  ).toBeVisible();
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Đóng' }).click();
  await expect(dialog).toHaveCount(0);
});

test('BH-02: Huỷ báo giá Từ chối có ghi chú; sau huỷ chỉ còn xem, hết mục Huỷ', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.sale, setup.mark, seeded.code.rejected);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ báo giá' }).click();
  const dialog = page.getByRole('alertdialog');
  await dialog.getByLabel('Ghi chú').fill('Phụ huynh không quay lại');
  await dialog.getByRole('button', { name: 'Xác nhận huỷ' }).click();
  await expect(page.getByText('Đã huỷ báo giá.').first()).toBeVisible();
  await expect(page.getByText(/Báo giá đã huỷ: Phụ huynh không quay lại/)).toBeVisible();
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'Huỷ báo giá' })).toHaveCount(0);
  await expect(page.getByRole('menuitem', { name: 'In', exact: true })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('button', { name: 'Gửi', exact: true })).toHaveCount(0);
  // BH-03: báo giá đã huỷ vẫn in được, có nhãn ĐÃ HUỶ (Đ263, Đ273).
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'In', exact: true }).click();
  await expectPrint(page, seeded.code.rejected, { stamp: 'ĐÃ HUỶ', due: true });
  await shot(page, testInfo, 'bh03-huy');
});

async function openOpportunityOfQuote(page: Page, setup: ReturnType<typeof setupOf>, code: string) {
  await openRecord(page, setup.sale, setup.mark, code);
  await page
    .getByRole('link', { name: /^CO\d+/ })
    .first()
    .click();
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
}

test('Tạo báo giá: nút nằm ở bản ghi cơ hội (máy tính), ẩn trên điện thoại; danh sách báo giá không có nút Tạo', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openOpportunityOfQuote(page, setup, seeded.code.sent);
  const create = page.getByRole('button', { name: 'Tạo báo giá', exact: true });
  if (isPhone(page)) {
    await expect(create).toHaveCount(0);
    return;
  }
  await expect(create).toBeEnabled();
  await create.click();
  await expect(page).toHaveURL(/\/crm\/bao-gia\/tao\?co-hoi=/);
  // Form trắng: chưa có bản ghi, chưa cấp mã, dòng đầu mặc định em đầu.
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo báo giá' })).toBeVisible();
  await expect(page.getByText('Chưa lưu', { exact: true })).toBeVisible();
  await expect(page.getByText('cấp khi Lưu, không sửa')).toBeVisible();
  await expect(page.getByText(/ngày kể từ ngày Gửi|tính từ ngày Gửi/)).toBeVisible();
  await expect(page.getByRole('combobox', { name: 'Học sinh dòng 1' })).toContainText('Em Đã Gửi');
  await expect(page.getByText('Lưu để bắt đầu ghi chú: bản ghi chỉ có khi bấm Lưu.')).toBeVisible();
  await expectAccessible(page);
  // Huỷ: bỏ hết, về cơ hội, không có bản ghi mới.
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
  await page.goto('/crm/bao-gia');
  await page.getByRole('searchbox').fill(setup.mark);
  await expect(page.getByText('1–5 / 5')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
});

test('Tạo báo giá: nhập dòng, Lưu mới cấp mã và tạo báo giá Nháp', async ({ page }, testInfo) => {
  test.skip(isPhone(page), 'Đ248: điện thoại chỉ đọc, không có nút Tạo.');
  const setup = setupOf(testInfo.project.name);
  await openOpportunityOfQuote(page, setup, seeded.code.sent);
  await page.getByRole('button', { name: 'Tạo báo giá', exact: true }).click();
  await expectLineGrid(page, [
    '#',
    'Học sinh',
    'Gói',
    'Hình thức',
    'Số lượng',
    'Đơn vị',
    'Giờ tặng',
    'Đơn giá',
    'Chiết khấu',
    'Tổng %',
    'Thành tiền',
  ]);
  await page.getByRole('button', { name: 'Gói dòng 1' }).click();
  await page
    .getByRole('dialog', { name: 'Chọn gói' })
    .getByRole('button', { name: /LC-TOAN-K09/ })
    .first()
    .click();
  // Chưa nhập số lượng: Lưu báo lỗi theo khung, chưa tạo bản ghi.
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Bắt buộc nhập số lượng.')).toBeVisible();
  await expect(page).toHaveURL(/\/crm\/bao-gia\/tao\?co-hoi=/);
  await page.getByLabel('Số lượng dòng 1').fill('3');
  await expect(page.locator('p', { hasText: 'Tổng cộng báo giá' })).toContainText('660.000 đ');
  // Chip Ưu đãi linh hoạt (R-V2-45, Q-151): thêm bằng "Thêm", gõ % ngay trong chip; vượt hạn mức 5% thì chữ đỏ dưới chip và Lưu mờ.
  await page.getByRole('button', { name: 'Thêm chiết khấu dòng 1' }).click();
  await page
    .getByRole('dialog', { name: 'Chọn chính sách chiết khấu' })
    .getByLabel(/Ưu đãi linh hoạt/)
    .check();
  await page.getByRole('dialog').getByRole('button', { name: 'Áp dụng' }).click();
  const chipInput = page.getByLabel('Mức Ưu đãi linh hoạt dòng 1 (%)');
  await chipInput.fill('9');
  await expect(page.getByText('Ưu đãi linh hoạt tối đa 5%')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeDisabled();
  // Dấu phẩy thập phân: 5,5 vượt hạn mức 5%; 1,5 hợp lệ.
  await chipInput.fill('5,5');
  await expect(page.getByText('Ưu đãi linh hoạt tối đa 5%')).toBeVisible();
  await chipInput.fill('3');
  await expect(page.getByText('Ưu đãi linh hoạt tối đa 5%')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeEnabled();
  await expect(page.getByRole('cell', { name: '3%', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  // Lưu xong: bản ghi Nháp có mã báo giá, mở ở trang bản ghi.
  await expect(page.getByText(/^Đã tạo báo giá BG-/).first()).toBeVisible();
  await expect(page).toHaveURL(/\/crm\/bao-gia\/[0-9a-f-]{36}$/);
  await expect(page.getByRole('heading', { level: 2, name: /^BG-/ })).toBeVisible();
  const view = page.getByRole('table', { name: 'Gói học' });
  await expect(view.getByRole('cell', { name: '3', exact: true })).toBeVisible();
  await expect(view.getByText('Em Đã Gửi')).toBeVisible();
});
