// Nền động của trang đăng nhập (PR 5c, thiết kế P1 v4 DN01): robot, đường nét, ký hiệu toán chuyển động;
// người bật "giảm chuyển động" của hệ điều hành thấy bản đứng yên.
import { expect, test } from '@playwright/test';

const MOVING = ['.auth-bob', '.auth-pen', '.auth-ant', '.auth-bub', '.auth-q1', '.auth-q2'];
const ART = ['.auth-ln', '.auth-nd', '.auth-sy'];

test.describe('máy tính', () => {
  test.skip(({ isMobile }) => isMobile, 'cột giới thiệu chỉ hiện trên máy tính');

  test('bình thường: robot và nền chuyển động, dấu ? đổi thành 5 theo vòng 6 giây', async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/dang-nhap');
    for (const sel of [...MOVING, ...ART]) {
      await expect(page.locator(sel).first(), sel).not.toHaveCSS('animation-name', 'none');
    }
    // Hai ký hiệu thay nhau: lúc đầu thấy "?", đến giữa vòng thấy "5".
    const q1 = page.locator('.auth-q1');
    const q2 = page.locator('.auth-q2');
    await expect(q1).toHaveCSS('opacity', '1');
    await expect(q2).toHaveCSS('opacity', '0');
    await expect(q2).toHaveCSS('opacity', '1', { timeout: 8000 });
    await expect(q1).toHaveCSS('opacity', '0');
  });

  test('giảm chuyển động: mọi thứ đứng yên, câu chào vẫn hiện', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/dang-nhap');
    for (const sel of [...MOVING, ...ART]) {
      await expect(page.locator(sel).first(), sel).toHaveCSS('animation-name', 'none');
    }
    await expect(page.locator('.auth-bub')).toHaveCSS('opacity', '1');
    await expect(page.locator('.auth-q1')).toHaveCSS('opacity', '1');
    await expect(page.locator('.auth-q2')).toHaveCSS('opacity', '0');
  });
});
