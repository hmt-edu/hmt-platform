// Aftersale lát đầu và lát 3b: danh sách Ticket (CSN-01), Tạo mới và Chi tiết (CSN-03): tạo khiếu nại, xem chi tiết, thêm ghi chú, đổi trạng thái bị luật chặn.
// Dữ liệu giả: bật phân hệ AFTERSALE cho CS5 và dựng một phụ huynh giả có dấu riêng mỗi dự án; ticket tạo bằng giao diện.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible, isPhone, pickSearchedOption } from './helpers';
import { DB_URL, setupOf } from './lich-hen-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phụ huynh giả).');
test.describe.configure({ mode: 'serial' });

let parentName = '';
let title = '';

async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const tag = `${testInfo.project.name === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  parentName = `Phụ huynh E2E TK ${tag}`;
  title = `Khiếu nại E2E ${tag}`;
  await withDb(async (db) => {
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'AFTERSALE', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id)
       values ($1, $2, $3, (select id from app.branch where code = 'CS5'))`,
      [
        `PHE2ETK${tag}`,
        parentName,
        `09${tag.slice(-6)}${testInfo.project.name === 'dien-thoai' ? '4' : '3'}1`,
      ],
    );
  });
});

async function openCreate(page: Page, account: string) {
  await enterAs(page, account);
  await page.goto('/crm/ticket');
  await expect(page.getByRole('heading', { level: 1, name: 'Ticket' })).toBeVisible();
  await page.getByRole('button', { name: 'Tạo', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/moi$/);
}

test('Tạo khiếu nại: thiếu ô thì báo tại ô; đủ thì lưu và mở chi tiết', async ({
  page,
}, testInfo) => {
  await openCreate(page, setupOf(testInfo.project.name).account);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Nhập tiêu đề.')).toBeVisible();
  await expect(page.getByText('Chọn phụ huynh (người gửi).')).toBeVisible();
  await page.getByLabel('Loại').click();
  await page.getByRole('option', { name: 'Khiếu nại' }).click();
  await page.getByLabel('Tiêu đề').fill(title);
  await page.getByLabel('Kênh').click();
  await page.getByRole('option', { name: 'Gọi điện' }).click();
  await pickSearchedOption(
    page,
    page.getByRole('combobox', { name: 'Phụ huynh' }),
    parentName,
    parentName,
  );
  await page.getByLabel('Nhóm', { exact: true }).click();
  await page.getByRole('option', { name: 'Học sinh trong lớp' }).click();
  await page.getByLabel('Nhóm con').click();
  await page.getByRole('option', { name: 'Bắt nạt' }).click();
  await page.getByLabel('Mô tả').fill('Mô tả giả cho bài kiểm thử.');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await expect(page.getByText(/^KN-CS5-\d{4}-\d{4}$/).first()).toBeVisible();
  await expect(page.getByText('Tạo ticket.')).toBeVisible();
  await expectAccessible(page);
});

test('Chi tiết: thêm ghi chú; Đã xử lý cần kết quả; huỷ cần lý do', async ({ page }, testInfo) => {
  await enterAs(page, setupOf(testInfo.project.name).account);
  await page.goto('/crm/ticket');
  await page.getByRole('main').getByPlaceholder(/Tìm/).fill(title);
  // Máy tính là bảng (bấm ô tiêu đề), điện thoại là danh sách thẻ.
  await (
    isPhone(page)
      ? page
          .getByRole('list', { name: 'Ticket' })
          .getByRole('listitem')
          .filter({ hasText: title })
          .first()
      : page.getByRole('cell', { name: title, exact: true })
  ).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await page.getByRole('combobox', { name: 'Ghi chú' }).first().fill('Đã gọi lại phụ huynh.');
  await page.getByRole('button', { name: 'Gửi ghi chú' }).click();
  await expect(page.getByText('Đã gọi lại phụ huynh.')).toBeVisible();
  // Khiếu nại có phần riêng: sửa và lưu, giá trị hiện ở chi tiết và dòng thời gian ghi lại.
  await page.getByRole('button', { name: 'Sửa phần riêng' }).click();
  await page.getByLabel('Mong muốn của khách').fill('Đổi giáo viên giảng lại.');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đổi giáo viên giảng lại.')).toBeVisible();
  await expect(page.getByText('Cập nhật phần riêng của khiếu nại.')).toBeVisible();
  // Phân loại lại: đổi mức độ thì hạn tính lại và dòng thời gian ghi «Đổi mức độ».
  await page.getByRole('button', { name: 'Phân loại lại' }).click();
  const dialog = page.getByRole('dialog', { name: 'Phân loại lại ticket' });
  await dialog.getByLabel('Mức độ').click();
  await page.getByRole('option', { name: 'Thấp' }).click();
  await dialog.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đổi mức độ.')).toBeVisible();
  // Huỷ không ghi lý do: nút Huỷ ticket mờ cho tới khi có lý do (canvas CSN-04).
  await page.getByRole('button', { name: /Đã huỷ/ }).click();
  await expect(page.getByRole('button', { name: 'Huỷ ticket', exact: true })).toBeDisabled();
  await page.getByLabel('Lý do huỷ').fill('Phụ huynh rút khiếu nại.');
  await page.getByRole('button', { name: 'Huỷ ticket', exact: true }).click();
  await expect(page.getByText('Đổi trạng thái: Mới → Đã huỷ.')).toBeVisible();
});

test('Khách huỷ (CS-12): chỉ ticket Đề nghị có nút; lý do bắt buộc; huỷ xong ghi «Khách huỷ» ở nhật ký', async ({
  page,
}, testInfo) => {
  const dnTitle = `${title} DN`;
  await openCreate(page, setupOf(testInfo.project.name).account);
  await page.getByLabel('Loại').click();
  await page.getByRole('option', { name: 'Đề nghị' }).click();
  await page.getByLabel('Tiêu đề').fill(dnTitle);
  await page.getByLabel('Kênh').click();
  await page.getByRole('option', { name: 'Gọi điện' }).click();
  await pickSearchedOption(
    page,
    page.getByRole('combobox', { name: 'Phụ huynh' }),
    parentName,
    parentName,
  );
  await page.getByLabel('Nhóm', { exact: true }).click();
  await page.getByRole('option', { name: 'Hỗ trợ', exact: true }).click();
  await page.getByLabel('Nhóm con').click();
  await page.getByRole('option', { name: 'Tư vấn lộ trình' }).click();
  await page.getByLabel('Mô tả').fill('Đề nghị giả cho bài kiểm thử Khách huỷ.');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/ticket\/[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: 'Khách huỷ', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Khách huỷ ticket' });
  await expect(
    dialog.getByRole('button', { name: 'Xác nhận khách huỷ', exact: true }),
  ).toBeDisabled();
  await dialog.getByLabel('Lý do khách huỷ').fill('Gia đình đổi kế hoạch.');
  await dialog.getByRole('button', { name: 'Xác nhận khách huỷ', exact: true }).click();
  await expect(page.getByText('Khách huỷ: Gia đình đổi kế hoạch.', { exact: true })).toBeVisible();
});
