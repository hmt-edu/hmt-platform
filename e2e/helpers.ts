import AxeBuilder from '@axe-core/playwright';
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
