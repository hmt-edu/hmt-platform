// B-27-05: tab mở từ trước khi cập nhật bản mới, tệp của màn xác thực hai bước không còn (máy chủ trả HTML thay JS).
// Không cần đăng nhập: chưa đăng nhập thì màn này chuyển về trang đăng nhập sau khi tải được mã của màn.
import { expect, test } from '@playwright/test';

const CHUNK = '**/assets/MfaPages-*.js';
const staleResponse = {
  status: 200,
  contentType: 'text/html',
  body: '<!doctype html><title>x</title>',
};

test('tệp màn cũ: trang tự tải lại một lần rồi mở được màn', async ({ page }) => {
  let documents = 0;
  page.on('request', (r) => {
    if (r.isNavigationRequest() && r.frame() === page.mainFrame()) documents += 1;
  });
  // Lần mở đầu: tệp cũ. Sau khi trang tải lại: tệp có thật.
  await page.route(CHUNK, (route) =>
    documents < 2 ? route.fulfill(staleResponse) : route.continue(),
  );
  await page.goto('/xac-thuc-hai-buoc');
  await expect(page).toHaveURL(/\/dang-nhap$/);
  expect(documents).toBe(2);
});

test('tệp màn vẫn lỗi sau khi tải lại: hiện khung lỗi kèm mã lỗi thật, không lặp', async ({
  page,
}) => {
  await page.route(CHUNK, (route) => route.fulfill(staleResponse));
  await page.goto('/xac-thuc-hai-buoc');
  await expect(page.getByText(/Mã lỗi: TypeError/)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Thử lại' })).toBeVisible();
});
