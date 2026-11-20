// QT-01, QT-02, QT-03 (Quản trị người dùng): danh sách, Xuất, bản ghi, Quản lý trực tiếp, Thu hồi phiên, Đặt lại hai bước. Máy tính (bản đồ
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

test('Danh sách: có nút Tạo người dùng, tìm, lọc đã khoá, Xuất tải CSV', async ({ page }) => {
  await openList(page);
  await expect(page.getByRole('button', { name: 'Tạo người dùng', exact: true })).toBeVisible();
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
  await expect(confirm.getByText(TARGET_NAME).first()).toBeVisible();
  // So canvas QT02_xac_nhan_dat_lai: câu hết hiệu lực ngay, thu hồi phiên, hiện đúng một lần, chỉ Admin.
  await expect(confirm.getByText(/Mật khẩu cũ hết hiệu lực ngay/)).toBeVisible();
  await expect(confirm.getByText(/hiện đúng một lần/)).toBeVisible();
  await expect(confirm.getByText(/Chỉ Admin được đặt lại mật khẩu/)).toBeVisible();
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

// QT-03 Tạo người dùng (ngăn kéo) và Sửa email. Edge Function admin-users trả lời giả; việc báo trùng ở ô gọi hàm DB thật (check_account_fields).
test('Tạo người dùng: gợi ý tên đăng nhập (tên + chữ cái đầu họ, đệm) và email, báo trùng ngay ở ô, tạo xong hiện mật khẩu tạm một lần', async ({
  page,
}) => {
  await sql(`update app.user_account set username = 'tg.cs5.e2e' where login_name = $1`, [
    `${TARGET}@${DOMAIN}`,
  ]);
  const temp = 'Tam7654321wxyz';
  let body: Record<string, unknown> | null = null;
  await page.route('**/functions/v1/admin-users', async (route) => {
    body = route.request().postDataJSON() as Record<string, unknown>;
    await route.fulfill({
      json: { userId: '00000000-0000-0000-0000-000000000000', password: temp },
    });
  });
  await enterAsAdmin(page, ADMIN);
  await page.goto('/crm/quan-tri/nguoi-dung');
  await page.getByRole('button', { name: 'Tạo người dùng' }).click();
  const drawer = page.getByRole('dialog', { name: 'Tạo người dùng' });
  await expect(drawer.getByRole('button', { name: 'Tạo tài khoản' })).toBeDisabled();
  await drawer.getByLabel('Tên hiển thị').fill('Giáo viên Thử');
  // Gợi ý: tên + chữ cái đầu họ và tên đệm, bỏ dấu; email theo tên miền quy ước trong Cài đặt.
  await expect(drawer.getByLabel('Tên đăng nhập')).toHaveValue('thugv');
  await expect(drawer.getByLabel('Email')).toHaveValue(/^thugv@.+/);
  // Tên đăng nhập đã có người dùng: báo ngay ở ô, chưa cho tạo.
  await drawer.getByLabel('Tên đăng nhập').fill('tg.cs5.e2e');
  await expect(drawer.getByText('Tên đăng nhập này đã có người dùng.')).toBeVisible();
  await drawer.getByLabel('Tên đăng nhập').fill('thugv');
  await expect(drawer.getByText('Tên đăng nhập này đã có người dùng.')).toHaveCount(0);
  // So canvas QT03_tao: vai trò là chip, thêm bằng nút «Thêm vai trò», bỏ bằng dấu x.
  await drawer.getByRole('button', { name: 'Thêm vai trò' }).click();
  await page.getByRole('menuitem', { name: 'Giáo viên', exact: true }).click();
  await expect(drawer.getByRole('button', { name: 'Bỏ vai trò Giáo viên' })).toBeVisible();
  await drawer.getByRole('button', { name: 'Bỏ vai trò Giáo viên' }).click();
  await expect(drawer.getByRole('button', { name: 'Bỏ vai trò Giáo viên' })).toHaveCount(0);
  await drawer.getByRole('button', { name: 'Thêm vai trò' }).click();
  await page.getByRole('menuitem', { name: 'Giáo viên', exact: true }).click();
  await expectAccessible(page);
  await drawer.getByRole('button', { name: 'Tạo tài khoản' }).click();
  const dialog = page.getByRole('dialog', { name: 'Mật khẩu tạm' });
  await expect(dialog.getByLabel('Mật khẩu tạm')).toHaveText(temp);
  expect(body).toMatchObject({
    action: 'create',
    username: 'thugv',
    roles: ['TEACHER'],
    displayName: 'Giáo viên Thử',
  });
});

test('Sửa email: hộp có email hiện tại, báo trùng email ngay ở ô, lưu gọi máy chủ', async ({
  page,
}) => {
  let body: Record<string, unknown> | null = null;
  await page.route('**/functions/v1/admin-users', async (route) => {
    body = route.request().postDataJSON() as Record<string, unknown>;
    await route.fulfill({ json: { ok: true } });
  });
  await openTarget(page);
  await openMenu(page);
  await menuItem(page, 'Sửa email').click();
  const dialog = page.getByRole('dialog', { name: /Sửa email của/ });
  await expect(dialog.getByLabel('Email hiện tại')).toHaveValue(`${TARGET}@${DOMAIN}`);
  await expect(dialog.getByRole('button', { name: 'Lưu email' })).toBeDisabled();
  // Email đã dùng cho tài khoản khác (quản trị giả).
  await dialog.getByLabel('Email mới').fill(`${ADMIN}@${DOMAIN}`);
  await expect(dialog.getByText('Email này đã dùng cho tài khoản khác.')).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Lưu email' })).toBeDisabled();
  await dialog.getByLabel('Email mới').fill('tg.moi@thu.example');
  await expect(dialog.getByText('Email này đã dùng cho tài khoản khác.')).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Lưu email' }).click();
  await expect(dialog).toHaveCount(0);
  expect(body).toMatchObject({ action: 'set_email', email: 'tg.moi@thu.example' });
});

test('Sửa email: không có mục này cho chính mình', async ({ page }) => {
  await openTarget(page, 'Quản trị CS5 (giả)');
  await openMenu(page);
  await expect(menuItem(page, 'Sửa email')).toHaveCount(0);
  await expect(menuItem(page, 'Sửa vai trò')).toBeVisible();
});
