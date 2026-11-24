// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/giao-vien/ (GV2, GV9–GV13), điện thoại 390×844. Chạy tay trên bản thử nghiệm, tài khoản giả gv.cs5.
// Chạy: set -a; . ~/VanPhongAI/hmt-ca/.staging-test.env; set +a; node scripts/huong-dan/gv-p2.mjs [GV2 GV9 …]
// Ra: HD_OUT (mặc định public/huong-dan/anh/<mã>/NN.png (đọc được bằng [ẢNH: <mã>/NN])), khung cam #EF6925 quanh chỗ cần bấm/chú ý. Chỉ xem, không bấm nút ghi.
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? '';
const SB_KEY = process.env.HD_SUPABASE_KEY ?? '';
const OUT = process.env.HD_OUT ?? join(process.cwd(), 'public', 'huong-dan', 'anh');
const TK = process.env.HD_TAI_KHOAN ?? 'gv.cs5';
if (!APP.startsWith('https://') || /prod/i.test(APP) || !PW || !SB_URL || !SB_KEY) {
  console.error(
    'Thiếu STAGING_URL (https, bản thử nghiệm), STAGING_PASSWORD, HD_SUPABASE_URL, HD_SUPABASE_KEY.',
  );
  process.exit(1);
}
const PHONE = { width: 390, height: 844 };

async function phien(account) {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SB_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${account}@thu.hoamatoan.invalid`, password: PW }),
  });
  if (!r.ok) throw new Error(`Đăng nhập API ${account}: ${r.status}`);
  return [
    `sb-${new URL(SB_URL).hostname.split('.')[0]}-auth-token`,
    JSON.stringify(await r.json()),
  ];
}

async function khung(page, loc) {
  const box = loc ? await loc.first().boundingBox() : null;
  if (!box) return;
  await page.evaluate((b) => {
    const k = document.createElement('div');
    k.style.cssText = `position:fixed;left:${b.x - 4}px;top:${b.y - 4}px;width:${b.width + 8}px;height:${b.height + 8}px;border:3px solid #EF6925;border-radius:8px;pointer-events:none;z-index:2147483647`;
    document.body.append(k);
  }, box);
}

/** Mở đường dẫn, chạy `truoc` (nếu có), vẽ khung quanh `loc`, chụp vào <mã>/<số>.png. */
async function chup(browser, ma, so, { route, truoc, loc }) {
  const ctx = await browser.newContext({ viewport: PHONE, deviceScaleFactor: 2 });
  const [k, v] = await phien(TK);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  const page = await ctx.newPage();
  try {
    await page.goto(`${APP}${route}`);
    await page.waitForLoadState('load');
    await page.waitForTimeout(2500);
    if (truoc) await truoc(page);
    await page.waitForTimeout(500);
    if (loc) await khung(page, loc(page));
    mkdirSync(join(OUT, ma), { recursive: true });
    await page.screenshot({ path: join(OUT, ma, `${so}.png`) });
    console.log('✔', ma, so);
  } catch (e) {
    console.log('✘', ma, so, String(e.message).split('\n')[0]);
  }
  await ctx.close();
}

const browser = await chromium.launch();
try {
  // Lớp đầu tiên của gv.cs5 (không viết cứng mã lớp).
  const ctx = await browser.newContext({ viewport: PHONE });
  const [k, v] = await phien(TK);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  const page = await ctx.newPage();
  await page.goto(`${APP}/gv/lop`);
  await page.waitForTimeout(3000);
  const lop = await page
    .locator('main a[href*="/gv/lop/"]')
    .first()
    .getAttribute('href')
    .catch(() => null);
  await page.goto(`${APP}${lop}`);
  await page.waitForTimeout(3000);
  const hs = await page
    .locator('a[href*="/hoc-sinh/"]')
    .first()
    .getAttribute('href')
    .catch(() => null);
  await ctx.close();
  const chon = process.argv.slice(2);
  const co = (m) => !chon.length || chon.includes(m);

  if (co('GV2')) {
    await chup(browser, 'GV2', '01', {
      route: '/gv/lich-day',
      loc: (p) => p.getByRole('button', { name: 'Tháng', exact: true }),
    });
    await chup(browser, 'GV2', '02', {
      route: '/gv/lich-day',
      loc: (p) => p.getByRole('button', { name: /^T5/ }),
    });
    await chup(browser, 'GV2', '03', {
      route: '/gv/lich-day',
      truoc: async (p) => {
        await p.getByRole('button', { name: /^T5/ }).click();
        await p.waitForTimeout(1500);
      },
      loc: (p) => p.locator('main a[href*="/gv/buoi/"]').first(),
    });
  }
  if (lop && co('GV9')) {
    await chup(browser, 'GV9', '01', {
      route: '/gv/lop',
      loc: (p) => p.locator('main a[href*="/gv/lop/"]').first(),
    });
    await chup(browser, 'GV9', '02', { route: lop, loc: (p) => p.getByText(/^Học sinh · /) });
    await chup(browser, 'GV9', '03', { route: lop, loc: (p) => p.getByText('Lịch sử buổi') });
    if (hs)
      await chup(browser, 'GV9', '04', { route: hs, loc: (p) => p.getByText('Hồ sơ rút gọn') });
  }
  if (co('GV10')) {
    await chup(browser, 'GV10', '01', {
      route: '/gv/lich-day',
      loc: (p) => p.getByRole('link', { name: 'Giờ dạy của tôi' }),
    });
    await chup(browser, 'GV10', '02', {
      route: '/gv/gio-day',
      loc: (p) => p.getByText('Căn cứ tính lương'),
    });
    await chup(browser, 'GV10', '03', {
      route: '/gv/gio-day',
      truoc: async (p) => {
        await p.getByRole('button', { name: 'Xem chi tiết' }).click();
        await p.waitForTimeout(2000);
      },
    });
  }
  if (co('GV11')) {
    await chup(browser, 'GV11', '01', {
      route: lop ?? '/gv/lop',
      loc: (p) => p.getByRole('link', { name: 'Tạo ticket' }),
    });
    await chup(browser, 'GV11', '02', {
      route: '/gv/ticket/tao',
      loc: (p) => p.getByText('Chọn nhóm').first(),
    });
    await chup(browser, 'GV11', '03', {
      route: '/gv/ticket',
      loc: (p) => p.getByText('Ticket của lớp tôi'),
    });
  }
  if (lop && co('GV12')) {
    await chup(browser, 'GV12', '01', {
      route: lop,
      loc: (p) => p.getByRole('link', { name: 'Bài đã giao' }),
    });
    await chup(browser, 'GV12', '02', {
      route: `${lop}/bai-giao`,
      loc: (p) => p.getByRole('link', { name: /Giao bài/ }),
    });
    await chup(browser, 'GV12', '03', { route: `${lop}/bai-giao/moi` });
    await chup(browser, 'GV12', '04', {
      route: `${lop}/bai-giao`,
      truoc: async (p) => {
        await p
          .locator('main a[href*="/bai-giao/"]')
          .nth(1)
          .click()
          .catch(() => {});
        await p.waitForTimeout(2500);
        const m = p.url().match(/bai-giao\/([0-9a-f-]{36})/);
        if (m) {
          await p.goto(`${APP}${lop}/bai-giao/${m[1]}/cham`);
          await p.waitForTimeout(3000);
        }
      },
    });
  }
} finally {
  await browser.close();
}
