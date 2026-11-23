import { mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import AxeBuilder from '@axe-core/playwright';
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

/**
 * Đăng nhập rồi chờ tới trang đích; về lại /dang-nhap (dịch vụ đăng nhập local vừa dựng lại chưa sẵn sàng ở lần đầu) thì đăng nhập lại,
 * tối đa trong 40 giây, như người dùng thật bấm lại. Dùng cho bài mà đích sau đăng nhập khác /crm (vd. thiết lập hai bước).
 */
export async function loginStaffUntil(
  page: Page,
  account: string,
  target: RegExp,
  password = PASSWORD,
) {
  await expect(async () => {
    await loginStaff(page, account, password);
    await expect(page).toHaveURL(target, { timeout: 8000 });
  }).toPass({ timeout: 40_000 });
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
  await loginStaffUntil(page, account, /\/crm$/);
  await saveSession(page, account);
}

/**
 * Vào CRM bằng tài khoản Admin: lần đầu xoá thiết bị hai bước cũ, đăng nhập mật khẩu (hai bước không bắt buộc từ D41), lưu phiên để các bài sau dùng lại. Mỗi Admin giả chỉ nên dùng ở một file bài (tránh tranh thiết bị).
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
  // D41 (19/11/2026): hai bước không còn bắt buộc (tham số mfa_required_enabled tắt), Admin đăng nhập mật khẩu vào thẳng CRM.
  await loginStaffUntil(page, account, /\/crm$/);
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
  await page.getByRole('button', { name: / Tài khoản$/ }).click();
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
            // Luật khác (ví dụ label-content-name-mismatch): ghi dữ liệu và tóm tắt lỗi của axe để thấy chữ nó đọc được.
            const extra =
              v.id === 'label-content-name-mismatch'
                ? ` [dữ liệu ${JSON.stringify(n.any[0]?.data ?? null)} | ${(n.failureSummary ?? '').replace(/\s+/g, ' ').slice(0, 300)}]`
                : '';
            return `${n.target.join(' ')}${detail}${extra} ${n.html.slice(0, 400)}`;
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
  // Hộp chọn mở thì ô tìm trong hộp (cmdk) cũng là combobox cùng tên với nút mở: lần thử thứ hai báo strict mode violation (ticket.spec iPhone đỏ khi lần đầu chậm). Luôn lấy nút mở, nằm trước hộp trong DOM (hộp gắn cuối body).
  const trigger = combobox.first();
  await expect(async () => {
    if ((await trigger.getAttribute('aria-expanded')) !== 'true') await trigger.click();
    // Cuộn tới mục trước khi bấm: trên điện thoại danh sách dài, mục nằm ngoài khung nhìn thì lần bấm trượt (lead-ban-ghi.spec.ts:202 chập chờn).
    const item = page.getByRole('option', { name: option });
    await item.scrollIntoViewIfNeeded({ timeout: 2000 });
    await item.click({ timeout: 2000 });
  }).toPass({ timeout: 10000 });
}

/**
 * Đường dẫn ảnh chụp của bài e2e. Mặc định ghi ra thư mục tạm (bước kiểm thử không ghi đè ảnh trong repo); chỉ khi đặt
 * SO_SANH_GHI_VAO_REPO=1 mới ghi vào docs/anh-chup/<nhóm>/ (như kịch bản so sánh, so-sanh*.spec.ts). Tạo thư mục khi cần.
 */
export function shotPath(group: string, file: string): string {
  const dir = process.env.SO_SANH_GHI_VAO_REPO
    ? join('docs', 'anh-chup', group)
    : join(tmpdir(), 'hmt-anh-chup', group);
  mkdirSync(dir, { recursive: true });
  return join(dir, file);
}

/**
 * Hộp «Hoàn thành lịch hẹn» (TS-11) mở ra sau khi bấm nút Hoàn thành của một lịch: chọn kết quả đầu tiên trong danh mục nếu cần
 * (bắt buộc với Gọi điện), rồi bấm Hoàn thành trong hộp.
 */
export async function confirmCompleteAppointment(page: Page) {
  const dialog = page.getByRole('dialog', { name: 'Hoàn thành lịch hẹn' });
  await expect(dialog).toBeVisible();
  const result = dialog.getByLabel(/^Kết quả/);
  await result.selectOption({ index: 1 });
  await dialog.getByRole('button', { name: 'Hoàn thành', exact: true }).click();
}
