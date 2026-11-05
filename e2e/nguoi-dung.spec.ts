// QT-01, QT-02 (Quản trị người dùng): danh sách, Xuất, bản ghi, Quản lý trực tiếp, Thu hồi phiên, Đặt lại hai bước. Máy tính (bản đồ
// màn hình: QT chỉ có bản máy tính). Admin giả riêng (quantri.cs5, hai bước thiết lập ngay trong bài); tài khoản bị thao tác: tg.cs5.
// Edge Function admin-users (đổi vai trò, cơ sở, khoá, mở khoá) không chạy ở môi trường kiểm thử: các hộp của chúng chỉ kiểm biểu mẫu.
import { readFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, enterAsAdmin, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (thiết bị hai bước giả).');
test.describe.configure({ mode: 'serial' });

const ADMIN = 'quantri.cs5';
const TARGET = 'tg.cs5';
const TARGET_NAME = 'Trợ giảng CS5 (giả)';

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Quản trị chỉ có bản máy tính.');
});

async function sql<T = unknown>(query: string, params: unknown[] = []): Promise<T[]> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return (await db.query(query, params)).rows as T[];
  } finally {
    await db.end();
  }
}

async function openList(page: Page) {
  await enterAsAdmin(page, ADMIN);
  await page.goto('/crm/quan-tri/nguoi-dung');
  await expect(page.getByRole('heading', { level: 1, name: 'Người dùng' })).toBeVisible();
}

async function openTarget(page: Page, name = TARGET_NAME) {
  await openList(page);
  await page.getByPlaceholder(/Tìm tên, email, mã/).fill(name);
  await page.getByRole('link', { name, exact: true }).first().click();
  await expect(page).toHaveURL(/\/crm\/quan-tri\/nguoi-dung\/[0-9a-f-]{36}$/);
  await expect(page.getByRole('heading', { level: 2, name })).toBeVisible();
}

const menuItem = (page: Page, name: string) => page.getByRole('menuitem', { name, exact: true });
async function openMenu(page: Page) {
  await page.getByRole('button', { name: 'Hành động' }).click();
}
const toastText = (page: Page, text: string | RegExp) => page.getByText(text).first();

test('Danh sách: tìm, lọc đã khoá, không có nút Tạo (chờ khuôn K4g), Xuất tải CSV', async ({
  page,
}) => {
  await openList(page);
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toHaveCount(0);
  await page.getByPlaceholder(/Tìm tên, email, mã/).fill(TARGET);
  await expect(page.getByRole('link', { name: TARGET_NAME })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Học sinh (giả)' })).toHaveCount(0);
  await expectAccessible(page);
  // Lọc "Đã khoá": chỉ tài khoản bị khoá (khoa.cs5).
  await page.getByPlaceholder(/Tìm tên, email, mã/).fill('');
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await page.getByLabel('Đã khoá', { exact: true }).check();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('link', { name: 'Đã nghỉ việc (giả)' })).toBeVisible();
  await expect(page.getByRole('link', { name: TARGET_NAME })).toHaveCount(0);
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await page.getByLabel('Đã khoá', { exact: true }).uncheck();
  await page.keyboard.press('Escape');
  // Xuất (chỉ Admin): CSV có đủ cột, không có dữ liệu hai bước.
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^nguoi-dung-\d{4}-\d{2}-\d{2}\.csv$/);
  const text = readFileSync(await file.path(), 'utf8');
  expect(text).toContain('Mã NV/GV/TG');
  expect(text).toContain(`${TARGET}@${DOMAIN}`);
  expect(text).not.toMatch(/mfa|secret|mật khẩu/i);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Người không phải Admin mở màn Người dùng: báo không có quyền', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/quan-tri/nguoi-dung');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
  ).toBeVisible();
});

test('Bản ghi: thông tin, lịch sử đăng nhập, menu Hành động (có Đặt lại mật khẩu)', async ({
  page,
}) => {
  await openTarget(page);
  await expect(page.getByText(`${TARGET}@${DOMAIN}`)).toBeVisible();
  await expect(page.getByText('Trợ giảng', { exact: true }).first()).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Lịch sử đăng nhập' })).toBeVisible();
  await expectAccessible(page);
  await openMenu(page);
  for (const name of [
    'Sửa vai trò',
    'Đổi cơ sở',
    'Quản lý trực tiếp',
    'Khoá',
    'Thu hồi phiên',
    'Đặt lại hai bước',
  ]) {
    await expect(menuItem(page, name)).toBeVisible();
  }
  await expect(menuItem(page, 'Đặt lại mật khẩu')).toBeVisible();
});

test('Hộp Sửa vai trò, Đổi cơ sở, Khoá: kiểm biểu mẫu (không gửi; Edge Function không chạy ở đây)', async ({
  page,
}) => {
  await openTarget(page);
  // Sửa vai trò: chưa đổi thì Lưu mờ; bỏ hết vai trò thì báo cần ít nhất một.
  await openMenu(page);
  await menuItem(page, 'Sửa vai trò').click();
  const roles = page.getByRole('dialog', { name: 'Sửa vai trò' });
  await expect(roles.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  await roles.getByRole('checkbox', { name: 'Trợ giảng' }).uncheck();
  await expect(roles.getByText('Chọn ít nhất một vai trò.')).toBeVisible();
  await expect(roles.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  await roles.getByRole('checkbox', { name: 'Giáo viên' }).check();
  await expect(roles.getByRole('button', { name: 'Lưu' })).toBeEnabled();
  await page.keyboard.press('Escape');
  // Đổi cơ sở: cơ sở hiện tại thì Lưu mờ.
  await openMenu(page);
  await menuItem(page, 'Đổi cơ sở').click();
  const branch = page.getByRole('dialog', { name: 'Đổi cơ sở' });
  await expect(branch.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  await page.keyboard.press('Escape');
  // Khoá: bắt chọn lý do từ danh mục.
  await openMenu(page);
  await menuItem(page, 'Khoá').click();
  const lock = page.getByRole('alertdialog', { name: 'Khoá tài khoản' });
  await expect(lock).toBeVisible();
  await expect(lock.getByRole('button', { name: 'Khoá', exact: true })).toBeDisabled();
});

test('Quản lý trực tiếp: đặt rồi bỏ', async ({ page }) => {
  await openTarget(page);
  await openMenu(page);
  await menuItem(page, 'Quản lý trực tiếp').click();
  const dialog = page.getByRole('dialog', { name: 'Quản lý trực tiếp' });
  await expect(dialog.getByRole('button', { name: 'Lưu' })).toBeDisabled();
  // Danh sách chỉ hiện vài người đầu: gõ để tìm ở máy chủ rồi chọn.
  await dialog.getByRole('combobox', { name: 'Quản lý trực tiếp' }).click();
  await page.getByPlaceholder('Gõ để tìm (không cần dấu)').fill('truongcs.cs5');
  await page.getByRole('option', { name: /^Trưởng CS5 \(giả\)/ }).click();
  await dialog.getByRole('button', { name: 'Lưu' }).click();
  await expect(toastText(page, 'Đã lưu quản lý trực tiếp.')).toBeVisible();
  await expect(page.getByText('Trưởng CS5 (giả)').first()).toBeVisible();
  // Bỏ quản lý (trả lại như cũ).
  await openMenu(page);
  await menuItem(page, 'Quản lý trực tiếp').click();
  const again = page.getByRole('dialog', { name: 'Quản lý trực tiếp' });
  await again.getByRole('button', { name: 'Bỏ quản lý' }).click();
  await again.getByRole('button', { name: 'Lưu' }).click();
  await expect(toastText(page, 'Đã lưu quản lý trực tiếp.')).toBeVisible();
  const [row] = await sql<{ manager_id: string | null }>(
    'select manager_id from app.user_account where login_name = $1',
    [`${TARGET}@${DOMAIN}`],
  );
  expect(row?.manager_id ?? null).toBeNull();
});

test('Thu hồi phiên: hộp xác nhận rồi số phiên bản của người đó tăng', async ({ page }) => {
  const email = `${TARGET}@${DOMAIN}`;
  const [before] = await sql<{ v: number }>(
    'select session_version as v from app.user_account where login_name = $1',
    [email],
  );
  await openTarget(page);
  await openMenu(page);
  await menuItem(page, 'Thu hồi phiên').click();
  const dialog = page.getByRole('alertdialog', { name: 'Thu hồi phiên' });
  await expect(dialog.getByText(TARGET_NAME)).toBeVisible();
  await dialog.getByRole('button', { name: 'Thu hồi phiên' }).click();
  await expect(toastText(page, 'Đã thu hồi phiên.')).toBeVisible();
  const [after] = await sql<{ v: number }>(
    'select session_version as v from app.user_account where login_name = $1',
    [email],
  );
  expect(after?.v).toBe((before?.v ?? 0) + 1);
});

test('Đặt lại hai bước: xoá thiết bị của người đó, vai trò không bắt buộc hai bước thì nói rõ', async ({
  page,
}) => {
  const email = `${TARGET}@${DOMAIN}`;
  await sql(
    `insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret)
     select gen_random_uuid(), id, 'Thiết bị thử', 'totp', 'verified', now(), now(), 'x' from auth.users where email = $1`,
    [email],
  );
  await openTarget(page);
  await expect(page.getByText(/1 thiết bị/)).toBeVisible();
  await openMenu(page);
  await menuItem(page, 'Đặt lại hai bước').click();
  const dialog = page.getByRole('alertdialog', { name: 'Đặt lại hai bước' });
  await expect(dialog.getByText(/không bắt buộc hai bước/)).toBeVisible();
  await dialog.getByRole('button', { name: 'Đặt lại hai bước' }).click();
  await expect(toastText(page, 'Đã đặt lại hai bước.')).toBeVisible();
  const [left] = await sql<{ n: number }>(
    'select count(*)::int as n from auth.mfa_factors f join auth.users u on u.id = f.user_id where u.email = $1',
    [email],
  );
  expect(left?.n).toBe(0);
  const [log] = await sql<{ at: string | null }>(
    'select mfa_reset_at as at from app.user_account where login_name = $1',
    [email],
  );
  expect(log?.at).not.toBeNull();
  await expect(page.getByText(/0 thiết bị/)).toBeVisible();
});

test('Bản ghi của chính Admin: không có Thu hồi phiên, Đặt lại mật khẩu, Đặt lại hai bước (Đ50)', async ({
  page,
}) => {
  await openTarget(page, 'Quản trị CS5 (giả)');
  await openMenu(page);
  await expect(menuItem(page, 'Sửa vai trò')).toBeVisible();
  await expect(menuItem(page, 'Thu hồi phiên')).toHaveCount(0);
  await expect(menuItem(page, 'Đặt lại mật khẩu')).toHaveCount(0);
  await expect(menuItem(page, 'Đặt lại hai bước')).toHaveCount(0);
});

// Edge Function admin-users không chạy ở môi trường kiểm thử: trả lời giả để kiểm hộp xác nhận và hộp mật khẩu tạm (K4g, hiện một lần).
test('Đặt lại mật khẩu: hộp xác nhận, rồi hộp mật khẩu tạm hiện một lần, chưa chép thì báo trước khi đóng', async ({
  page,
}) => {
  const temp = 'Tam1234567abcd';
  let calls = 0;
  await page.route('**/functions/v1/admin-users', async (route) => {
    calls += 1;
    expect(route.request().postDataJSON()).toMatchObject({ action: 'reset_password' });
    await route.fulfill({ json: { ok: true, password: temp } });
  });
  await openTarget(page);
  await openMenu(page);
  await menuItem(page, 'Đặt lại mật khẩu').click();
  const confirm = page.getByRole('alertdialog', { name: 'Đặt lại mật khẩu' });
  await expect(confirm.getByText(TARGET_NAME)).toBeVisible();
  await expect(confirm.getByText(/chỉ hiện một lần/)).toBeVisible();
  await confirm.getByRole('button', { name: 'Đặt lại mật khẩu' }).click();
  const dialog = page.getByRole('dialog', { name: 'Mật khẩu tạm' });
  await expect(dialog.getByLabel('Mật khẩu tạm')).toHaveText(temp);
  await expectAccessible(page);
  // Chưa chép: Xong lần đầu chỉ báo, lần hai mới đóng.
  await dialog.getByRole('button', { name: 'Xong' }).click();
  await expect(dialog.getByText(/Chưa chép mật khẩu/)).toBeVisible();
  await dialog.getByRole('button', { name: 'Xong' }).click();
  await expect(dialog).toHaveCount(0);
  expect(calls).toBe(1);
  // Mở lại màn: mật khẩu không còn ở đâu.
  await expect(page.getByText(temp)).toHaveCount(0);
});
