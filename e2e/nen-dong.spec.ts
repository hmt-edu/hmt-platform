// Nền động của cột giới thiệu trang đăng nhập (canvas 9933 v149, thay robot của P1 v4): đường nét, ký hiệu toán, năm cột mọc lần lượt, cờ, sao,
// slogan sáng từng từ; người bật "giảm chuyển động" của hệ điều hành thấy bản đứng yên và slogan hiện đủ chữ.
import { expect, test } from '@playwright/test';

const MOVING = ['.auth-rise', '.auth-flag', '.auth-spk', '.auth-slogan .auth-w'];
const ART = ['.auth-ln', '.auth-nd', '.auth-sy'];

test.describe('máy tính', () => {
  test.skip(({ isMobile }) => isMobile, 'cột giới thiệu chỉ hiện trên máy tính');

  test('bình thường: năm cột, cờ, sao, slogan và nền chuyển động; không còn robot', async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/dang-nhap');
    for (const sel of [...MOVING, ...ART]) {
      await expect(page.locator(sel).first(), sel).not.toHaveCSS('animation-name', 'none');
    }
    await expect(page.locator('.auth-rise')).toHaveCount(5);
    await expect(page.locator('.auth-robot')).toHaveCount(0);
    // Slogan: nhãn đọc màn hình là câu đầy đủ, từng từ ẩn với trình đọc.
    const slogan = page.getByLabel(
      'Học tập bằng niềm vui, tiến bộ bằng năng lực, chinh phục mọi cuộc thi',
    );
    await expect(slogan).toBeVisible();
    await expect(slogan.locator('.auth-w[aria-hidden="true"]')).toHaveCount(15);
  });

  test('giảm chuyển động: mọi thứ đứng yên, slogan hiện đủ chữ', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/dang-nhap');
    for (const sel of [...MOVING, ...ART]) {
      await expect(page.locator(sel).first(), sel).toHaveCSS('animation-name', 'none');
    }
    for (const word of await page.locator('.auth-slogan .auth-w').all()) {
      await expect(word).toHaveCSS('opacity', '1');
    }
  });
});
