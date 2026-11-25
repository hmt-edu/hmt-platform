// F-24-16/17: các màn Cấu hình (CH) và Quản trị (QT) dùng CÙNG khung trang: so sánh GIỮA các màn (không viết cứng số cho từng màn).
// Đo: lề trái nội dung, cỡ chữ tiêu đề, tiêu đề nằm cùng hàng với nút chính, bảng không tràn khung. Đặt SHOT_DIR để chụp thêm ảnh từng màn (không commit).
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { enterAsAdmin } from './helpers';

const SCREENS: { code: string; path: string }[] = [
  { code: 'CH-01', path: '/crm/cau-hinh/goi-ban' },
  { code: 'CH-02', path: '/crm/cau-hinh/bang-gia' },
  { code: 'CH-03', path: '/crm/cau-hinh/chiet-khau' },
  { code: 'CH-04', path: '/crm/cau-hinh/dieu-khoan-thanh-toan' },
  { code: 'CH-05', path: '/crm/cau-hinh/chien-dich' },
  { code: 'CH-06', path: '/crm/cau-hinh/khung-chuong-trinh' },
  { code: 'CH-07', path: '/crm/cau-hinh/rubric' },
  { code: 'CH-08', path: '/crm/cau-hinh/ngay-nghi' },
  { code: 'CH-NDT', path: '/crm/cau-hinh/nguoi-duyet-ticket' },
  { code: 'QT-04', path: '/crm/quan-tri/vai-tro' },
  { code: 'QT-05', path: '/crm/quan-tri/ma-tran-quyen' },
  { code: 'QT-06', path: '/crm/quan-tri/danh-muc' },
  { code: 'QT-07', path: '/crm/quan-tri/co-so' },
  { code: 'QT-09', path: '/crm/quan-tri/tham-so' },
  { code: 'QT-10', path: '/crm/quan-tri/cong-tac' },
  { code: 'QT-18', path: '/crm/quan-tri/nhap-du-lieu' },
];

type Frame = {
  code: string;
  left: number;
  right: number;
  titlePx: number;
  sameRow: boolean | null;
  overflow: number;
};

async function measure(page: Page, code: string): Promise<Frame> {
  // Chuỗi JS chạy trong trình duyệt (cấu hình TypeScript của e2e không có kiểu DOM).
  const m = await page.evaluate<Omit<Frame, 'code'>>(`(() => {
    const main = document.querySelector('main');
    const header = document.querySelector('[data-page-header]');
    const h1 = (header && header.querySelector('h1')) || document.querySelector('main h1');
    const frame = document.querySelector('[data-page-frame]') || (header && header.parentElement) || h1;
    const btn = header && header.querySelector('button');
    const fr = frame.getBoundingClientRect();
    return {
      left: Math.round(fr.left),
      right: Math.round(fr.right),
      titlePx: parseFloat(getComputedStyle(h1).fontSize),
      sameRow: btn ? Math.abs(btn.getBoundingClientRect().top - h1.getBoundingClientRect().top) < 40 : null,
      overflow: Math.max(0, main.scrollWidth - main.clientWidth),
    };
  })()`);
  return { code, ...m };
}

test('màn Cấu hình và Quản trị cùng lề, cùng cỡ tiêu đề, nút chính cùng hàng tiêu đề, không tràn ngang', async ({
  page,
}) => {
  test.skip(test.info().project.name !== 'may-tinh', 'Đo trên máy tính.');
  test.setTimeout(180_000);
  await enterAsAdmin(page, 'quantri.cs5');
  const shots = process.env.SHOT_DIR;
  if (shots) mkdirSync(shots, { recursive: true });
  const frames: Frame[] = [];
  for (const s of SCREENS) {
    await page.goto(s.path);
    await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
    await page.waitForLoadState('networkidle');
    frames.push(await measure(page, s.code));
    if (shots)
      await page.screenshot({
        path: join(shots, `${s.code}-${page.viewportSize()?.width}.png`),
        fullPage: true,
      });
  }
  const lefts = new Set(frames.map((f) => f.left));
  const rights = new Set(frames.map((f) => f.right));
  const sizes = new Set(frames.map((f) => f.titlePx));
  expect(lefts, JSON.stringify(frames)).toHaveProperty('size', 1);
  expect(rights, JSON.stringify(frames)).toHaveProperty('size', 1);
  expect([...sizes], JSON.stringify(frames)).toEqual([20]);
  for (const f of frames) {
    expect(f.sameRow, `${f.code}: nút chính phải cùng hàng tiêu đề`).not.toBe(false);
    expect(f.overflow, `${f.code}: nội dung tràn ngang`).toBe(0);
  }
});

test('QT-09 Tham số hiện đủ cột Giá trị, Đơn vị, Khoảng, Ghi đè, Thao tác trong khung', async ({
  page,
}) => {
  test.skip(test.info().project.name !== 'may-tinh', 'Đo trên máy tính.');
  await enterAsAdmin(page, 'quantri.cs5');
  await page.goto('/crm/quan-tri/tham-so');
  const table = page.getByRole('table').first();
  for (const name of ['Giá trị hiện tại', 'Đơn vị', 'Khoảng cho phép', 'Ghi đè theo cơ sở']) {
    await expect(table.getByRole('columnheader', { name })).toBeInViewport({ ratio: 1 });
  }
  const box = await table.boundingBox();
  const section = await page.getByRole('region', { name: 'Tham số của nhóm' }).boundingBox();
  expect(box!.x + box!.width).toBeLessThanOrEqual(section!.x + section!.width + 1);
});
