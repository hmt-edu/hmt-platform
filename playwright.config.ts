import { defineConfig, devices } from '@playwright/test';

// Cổng xem trước: mặc định 4173; đặt E2E_PREVIEW_PORT để hai thư mục làm việc (hai Code) chạy e2e song song mà không tranh cổng (Q-222).
const DEFAULT_PREVIEW_PORT = 4173;
const PREVIEW_PORT = Number(process.env.E2E_PREVIEW_PORT || DEFAULT_PREVIEW_PORT);
const EXPECT_TIMEOUT_MS = 10_000;
const baseURL = `http://localhost:${PREVIEW_PORT}`;

// Hai cỡ màn chuẩn của dự án: laptop 1440×900 và điện thoại 390×844.
const DESKTOP = { width: 1440, height: 900 };
const PHONE = { width: 390, height: 844 };

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // Thử lại bài trượt: CI 2 lần; máy local mặc định 0, `npm run check:all` đặt E2E_RETRIES=2 như CI (GoTrue trên Docker máy tính
  // thỉnh thoảng báo 'failed SASL auth ... i/o timeout' khi dồn nhiều trình duyệt; lỗi thật vẫn trượt cả ba lần).
  retries: process.env.CI ? 2 : Number(process.env.E2E_RETRIES ?? 0),
  // Chờ kết quả hiện lên tối đa 10 giây (mặc định 5): máy dồn nhiều trình duyệt chạy song song thì đăng nhập, tải dữ liệu chậm hơn
  // vài giây; lỗi thật vẫn báo, chỉ không báo nhầm vì chậm.
  expect: { timeout: EXPECT_TIMEOUT_MS },
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'may-tinh', use: { ...devices['Desktop Chrome'], viewport: DESKTOP } },
    { name: 'dien-thoai', use: { ...devices['iPhone 15'], viewport: PHONE } },
  ],
  webServer: {
    command: `npm run build && npm run preview -- --port ${PREVIEW_PORT} --strictPort`,
    url: baseURL,
    // CI chạy Playwright trong container (D18): máy chủ xem trước đã chạy sẵn trên runner, đặt E2E_REUSE_SERVER=1 để dùng lại.
    reuseExistingServer: !process.env.CI || !!process.env.E2E_REUSE_SERVER,
  },
});
