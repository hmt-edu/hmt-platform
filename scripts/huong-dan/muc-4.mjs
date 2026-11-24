// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/03-ke-toan.md (chỗ «[ẢNH: tên]»). Chạy tay trên bản thử nghiệm, tài khoản giả. Cách chạy như README.md.
// Ra: HD_OUT (mặc định public/huong-dan/anh/): <tên>.png, khung cam #EF6925 quanh phần cần chú ý. Không email, số điện thoại thật.
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? '';
const SB_KEY = process.env.HD_SUPABASE_KEY ?? '';
const OUT = process.env.HD_OUT ?? join(process.cwd(), 'public', 'huong-dan', 'anh');
const DOMAIN = 'thu.hoamatoan.invalid';
if (!APP.startsWith('https://') || /prod/i.test(APP) || !PW || !SB_URL || !SB_KEY) {
  console.error(
    'Thiếu STAGING_URL (https, bản thử nghiệm), STAGING_PASSWORD, HD_SUPABASE_URL, HD_SUPABASE_KEY.',
  );
  process.exit(1);
}
mkdirSync(OUT, { recursive: true });
const DESKTOP = { width: 1280, height: 720 };

async function phien(account) {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SB_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${account}@${DOMAIN}`, password: PW }),
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
    k.id = 'hd-khung';
    k.style.cssText = `position:fixed;left:${b.x - 4}px;top:${b.y - 4}px;width:${b.width + 8}px;height:${b.height + 8}px;border:3px solid #EF6925;border-radius:8px;pointer-events:none;z-index:2147483647`;
    document.body.append(k);
  }, box);
}

async function chup(browser, ten, { account, viewport = DESKTOP, route, truoc, loc }) {
  const ctx = await browser.newContext({ viewport });
  if (account) {
    const [k, v] = await phien(account);
    await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  }
  const page = await ctx.newPage();
  try {
    await page.goto(`${APP}${route}`);
    await page.waitForLoadState('load');
    await page.waitForTimeout(2500);
    if (truoc) await truoc(page);
    await page.waitForTimeout(500);
    if (loc) await khung(page, loc(page));
    await page.screenshot({ path: join(OUT, `${ten}.png`) });
    console.log('✔', ten);
  } catch (e) {
    console.log('✘', ten, String(e.message).split('\n')[0]);
  }
  await ctx.close();
}

const KT = 'ketoan.cs5';
const dongDau = async (p) => {
  await p.locator('main tbody tr').first().click();
  await p.waitForTimeout(2500);
};
const SHOTS = {
  'ke-toan-trang-chu': { account: KT, route: '/crm' },
  'ke-toan-viec-cho-toi-duyet': { account: KT, route: '/crm/viec-cho-duyet' },
  'ke-toan-don-hang': { account: KT, route: '/crm/don-hang' },
  'ke-toan-phieu-thu-ds': { account: KT, route: '/crm/phieu-thu' },
  'phieu-thu-cho-ke-toan': {
    account: KT,
    route: '/crm/phieu-thu',
    truoc: async (p) => {
      await p
        .locator('main tbody tr', { hasText: 'Chờ kế toán' })
        .first()
        .locator('a')
        .first()
        .click();
      await p.waitForTimeout(2500);
    },
  },
  'khoan-tien-vao-ds': { account: KT, route: '/crm/khoan-tien-vao' },
  'cong-no': { account: KT, route: '/crm/cong-no' },
  'phieu-chi-ban-ghi': {
    account: KT,
    route: '/crm/phieu-chi',
    truoc: async (p) => {
      await p.locator('main tbody tr a').first().click();
      await p.waitForTimeout(2500);
    },
  },
  'so-du-ds': { account: KT, route: '/crm/so-du-khach-hang' },
};
const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS))
    if (!chon.length || chon.includes(ten)) await chup(browser, ten, s);
} finally {
  await browser.close();
}
