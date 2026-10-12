import { defineConfig, devices } from '@playwright/test';

const PREVIEW_PORT = 4173;
const baseURL = `http://localhost:${PREVIEW_PORT}`;

// Hai cỡ màn chuẩn của dự án: laptop 1440×900 và điện thoại 390×844.
const DESKTOP = { width: 1440, height: 900 };
const PHONE = { width: 390, height: 844 };

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
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
    reuseExistingServer: !process.env.CI,
  },
});
