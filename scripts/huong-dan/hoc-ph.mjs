// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/03-hoc-sinh.md (cổng /hoc, HS900001) và 03-phu-huynh.md (cổng /ph, cần HD_TAI_KHOAN_PH), điện thoại 390×844. Chạy tay trên bản thử nghiệm.
// Chạy: set -a; . ~/VanPhongAI/hmt-ca/.staging-test.env; set +a; node scripts/huong-dan/hoc-ph.mjs [tên-ảnh …]
// Ra: HD_OUT (mặc định public/huong-dan/anh/<tên>.png), khung cam #EF6925 quanh chỗ cần bấm/chú ý. Chỉ xem, không bấm nút ghi.
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? '';
const SB_KEY = process.env.HD_SUPABASE_KEY ?? '';
const OUT = process.env.HD_OUT ?? join(process.cwd(), 'public', 'huong-dan', 'anh');
const HS = process.env.HD_TAI_KHOAN_HS ?? 'HS900001';
const PH = process.env.HD_TAI_KHOAN_PH ?? '';
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
    body: JSON.stringify({
      email: /^HS\d+$/i.test(account)
        ? `${account.toLowerCase()}@hocsinh.hoamatoan.edu.vn`
        : `${account}@thu.hoamatoan.invalid`,
      password: PW,
    }),
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
async function chup(browser, ten, { tk, route, truoc, loc }) {
  const ctx = await browser.newContext({ viewport: PHONE, deviceScaleFactor: 2 });
  const [k, v] = await phien(tk);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  const page = await ctx.newPage();
  try {
    await page.goto(`${APP}${route}`);
    await page.waitForLoadState('load');
    await page.waitForTimeout(2500);
    if (truoc) await truoc(page);
    await page.waitForTimeout(500);
    if (loc) await khung(page, loc(page));
    mkdirSync(OUT, { recursive: true });
    await page.screenshot({ path: join(OUT, `${ten}.png`) });
    console.log('✔', ten);
  } catch (e) {
    console.log('✘', ten, String(e.message).split('\n')[0]);
  }
  await ctx.close();
}

const SHOTS = {
  'hoc-sinh-trang-chu': { tk: HS, route: '/hoc' },
  'hoc-sinh-bai-tap': { tk: HS, route: '/hoc/bai-tap' },
  'hoc-sinh-lich': { tk: HS, route: '/hoc/lich' },
  'hoc-sinh-ket-qua': { tk: HS, route: '/hoc/ket-qua' },
  'hoc-sinh-nhan-xet': { tk: HS, route: '/hoc/ket-qua/nhan-xet' },
  'hoc-sinh-tai-khoan': { tk: HS, route: '/hoc/tai-khoan' },
  'phu-huynh-trang-chu': { tk: PH, route: '/ph' },
  'phu-huynh-ket-qua': { tk: PH, route: '/ph/ket-qua' },
  'phu-huynh-nhan-xet': { tk: PH, route: '/ph/ket-qua/nhan-xet' },
  'phu-huynh-hoc-phi': { tk: PH, route: '/ph/hoc-phi' },
  'phu-huynh-lich': { tk: PH, route: '/ph/lich' },
};
const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS)) {
    if (chon.length && !chon.includes(ten)) continue;
    if (!s.tk) {
      console.log('⏭', ten, '(thiếu tài khoản, đặt HD_TAI_KHOAN_PH)');
      continue;
    }
    await chup(browser, ten, s);
  }
} finally {
  await browser.close();
}
