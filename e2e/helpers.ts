import AxeBuilder from '@axe-core/playwright';
import { generateSync } from 'otplib';
import pg from 'pg';
import { expect, type Locator, type Page } from '@playwright/test';

// Tài khoản giả do scripts/seed-users.ts tạo. Cần SEED_PASSWORD (CI tự sinh; local đặt trong môi trường).
export const PASSWORD = process.env.SEED_PASSWORD ?? '';
export const DOMAIN = 'thu.hoamatoan.invalid';

export function isPhone(page: Page): boolean {
  return (page.viewportSize()?.width ?? 0) < 1024;
}

export async function fillLogin(
  page: Page,
  label: 'Email' | 'Mã học sinh',
  login: string,
  password = PASSWORD,
) {
  await page.getByLabel(label, { exact: true }).fill(login);
  await page.getByLabel('Mật khẩu', { exact: true }).fill(password);
  await page
    .getByRole('button', { name: label === 'Email' ? 'Đăng nhập' : 'Vào học', exact: true })
    .click();
}

export async function loginStaff(page: Page, account: string, password = PASSWORD) {
  await page.goto('/dang-nhap');
  await fillLogin(page, 'Email', `${account}@${DOMAIN}`, password);
}

// Phiên đăng nhập dùng lại: Supabase local giới hạn 30 lần đăng nhập mỗi 5 phút mỗi địa chỉ, mà mỗi bài tính năng đều đăng nhập.
// `enterAs` đăng nhập THẬT một lần cho mỗi tài khoản (mỗi tiến trình chạy bài, mỗi loại trình duyệt), các bài sau nạp lại phiên đã
// lưu (chỉ khoá `sb-…` của Supabase trong localStorage). Phiên hỏng (ví dụ bài khác đã đăng xuất mọi nơi) thì tự đăng nhập lại.
// Bài kiểm CHÍNH luồng đăng nhập (auth, dang-nhap-thiet-ke, so-sanh-dang-nhap) vẫn gọi `loginStaff` để đi qua màn đăng nhập.
const savedSessions = new Map<string, Record<string, string>>();

const sessionKey = (page: Page, account: string) =>
  `${page.context().browser()?.browserType().name() ?? 'browser'}:${account}`;

/** Nạp phiên đã lưu của tài khoản vào thẻ này và mở /crm; true nếu phiên còn dùng được. */
async function restoreSession(page: Page, account: string): Promise<boolean> {
  const key = sessionKey(page, account);
  const saved = savedSessions.get(key);
  if (!saved) return false;
  await page.addInitScript((entries: Record<string, string>) => {
    // Nạp một lần mỗi thẻ: lần tải sau (hoặc sau khi đăng xuất) không ghi đè phiên hiện tại.
    if (sessionStorage.getItem('hmt-e2e-session')) return;
    sessionStorage.setItem('hmt-e2e-session', '1');
    for (const [name, value] of Object.entries(entries)) localStorage.setItem(name, value);
  }, saved);
  await page.goto('/crm');
  try {
    await expect(page).toHaveURL(/\/crm$/, { timeout: 10000 });
    return true;
  } catch {
    savedSessions.delete(key);
    return false;
  }
}

async function saveSession(page: Page, account: string) {
  savedSessions.set(
    sessionKey(page, account),
    await page.evaluate(() =>
      Object.fromEntries(Object.entries(localStorage).filter(([name]) => name.startsWith('sb-'))),
    ),
  );
}

export async function enterAs(page: Page, account: string) {
  if (await restoreSession(page, account)) return;
  await loginStaff(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await saveSession(page, account);
}

/**
 * Vào CRM bằng tài khoản Admin (bắt buộc xác thực hai bước): lần đầu xoá thiết bị cũ, đăng nhập, thiết lập một thiết bị mới bằng mã TOTP
 * rồi lưu phiên đã đạt mức hai bước để các bài sau dùng lại. Mỗi Admin giả chỉ nên dùng ở một file bài (tránh tranh thiết bị).
 */
export async function enterAsAdmin(page: Page, account: string) {
  if (await restoreSession(page, account)) return;
  const db = new pg.Client({ connectionString: process.env.DB_URL ?? '' });
  await db.connect();
  try {
    await db.query(
      'delete from auth.mfa_factors where user_id = (select id from auth.users where email = $1)',
      [`${account}@${DOMAIN}`],
    );
  } finally {
    await db.end();
  }
  await loginStaff(page, account);
  await expect(page).toHaveURL(/\/thiet-lap-hai-buoc$/);
  const secret = (await page.locator('code').first().textContent())?.replace(/\s+/g, '') ?? '';
  expect(secret.length).toBeGreaterThan(10);
  await page.getByRole('button', { name: 'Tiếp', exact: true }).click();
  await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
  await page.getByRole('button', { name: 'Hoàn tất' }).click();
  await expect(page).toHaveURL(/\/crm$/);
  await saveSession(page, account);
}

export async function loginStudent(page: Page, code: string, password = PASSWORD) {
  await page.goto('/dang-nhap/hoc-sinh');
  await fillLogin(page, 'Mã học sinh', code, password);
}

/** Mở menu CRM: laptop có sẵn bên trái, điện thoại nằm trong ngăn kéo. */
export async function openCrmMenu(page: Page) {
  if (isPhone(page)) await page.getByRole('button', { name: 'Mở menu' }).click();
  return page.getByRole('navigation', { name: 'Menu CRM' }).last();
}

export async function signOut(page: Page) {
  await page.getByRole('button', { name: /^Tài khoản:/ }).click();
  await page.getByRole('menuitem', { name: 'Đăng xuất' }).click();
}

/** Kiểm truy cập bằng axe: không có lỗi mức nghiêm trọng (critical) hay nặng (serious). */
export async function expectAccessible(page: Page) {
  // Đo sau khi mọi hiệu ứng chuyển màu đã xong: nút vừa đổi từ mờ sang sáng có màu trung gian chưa đạt
  // tương phản (white trên #CB4D0E chỉ vừa đủ 4,56:1). WebKit không huỷ ngay hiệu ứng đang chạy nên chờ hết.
  await page.addStyleTag({ content: '*, *::before, *::after { transition: none !important; }' });
  // Chỉ chờ hiệu ứng chuyển màu (CSSTransition); vòng quay "đang tải" chạy mãi nên không tính.
  await page.waitForFunction(
    "document.getAnimations().every((a) => !(a instanceof CSSTransition) || a.playState !== 'running')",
  );
  await page.waitForTimeout(100);
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();
  const blocking = results.violations.filter(
    (v) => v.impact === 'critical' || v.impact === 'serious',
  );
  expect(
    blocking.map(
      (v) =>
        `${v.id}: ${v.help} (${v.nodes
          .map((n) => {
            // Với color-contrast, ghi màu chữ, màu nền, tỉ lệ để biết ngay phần tử nào và vì sao trượt.
            const data = (n.any[0]?.data ?? {}) as {
              contrastRatio?: number;
              fgColor?: string;
              bgColor?: string;
            };
            const detail =
              data.contrastRatio !== undefined
                ? ` [chữ ${data.fgColor ?? '?'} trên ${data.bgColor ?? '?'}, tỉ lệ ${data.contrastRatio}]`
                : '';
            return `${n.target.join(' ')}${detail} ${n.html.slice(0, 160)}`;
          })
          .join('; ')})`,
    ),
  ).toEqual([]);
}

// Hộp thoại đang hiện hiệu ứng thì nhấp đầu tiên có thể rơi vào khoảng trống: bấm lại tới khi nút "chip" đã được chọn.
export async function pickChip(scope: Locator, name: string) {
  const chip = scope.getByRole('button', { name, exact: true });
  await expect(async () => {
    await chip.click();
    await expect(chip).toHaveAttribute('aria-pressed', 'true', { timeout: 1000 });
  }).toPass({ timeout: 10000 });
}

// Mở ô chọn rồi chọn một mục; mở chưa được (hộp đang hiện) thì mở lại.
export async function pickOption(page: Page, combobox: Locator, option: string | RegExp) {
  await expect(async () => {
    if ((await combobox.getAttribute('aria-expanded')) !== 'true') await combobox.click();
    await page.getByRole('option', { name: option }).click({ timeout: 2000 });
  }).toPass({ timeout: 10000 });
}
