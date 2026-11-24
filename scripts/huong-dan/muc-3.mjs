// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/03-tu-van-tuyen-sinh.md (chỗ «[ẢNH: tên]»). Chạy tay trên bản thử nghiệm, tài khoản giả. Cách chạy như README.md.
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

const btn = (p, n) => p.getByRole('button', { name: n, exact: true });
const SALE = 'sale.cs5';
const SHOTS = {
  'lead-ds': {
    account: SALE,
    route: '/crm/lead',
    loc: (p) => p.getByRole('button', { name: /^Tạo/ }).first(),
  },
  'lead-ban-ghi': {
    account: SALE,
    route: '/crm/lead',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => btn(p, 'Sửa'),
  },
  'lead-giai-doan': {
    account: SALE,
    route: '/crm/lead',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => p.getByText(/^C1 /).first().locator('xpath=../..'),
  },
  'lead-tao-co-hoi': {
    account: SALE,
    route: '/crm/lead',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => p.getByRole('button', { name: /Tạo cơ hội/ }),
  },
  'co-hoi-thanh-giai-doan': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => p.getByText(/^L1 /).first().locator('xpath=../..'),
  },
  'co-hoi-lien-ket': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) =>
      p.locator('main').locator('a,button', { hasText: 'Lịch h' }).first().locator('xpath=..'),
  },
  'lich-hen-ds': {
    account: SALE,
    route: '/crm/lich-hen',
    loc: (p) => p.getByRole('button', { name: /^Tạo/ }).first(),
  },
  'lich-hen-bang-the': {
    account: SALE,
    route: '/crm/lich-hen',
    truoc: async (p) => {
      await p
        .getByRole('button', { name: /Kanban|Bảng/ })
        .first()
        .click();
      await p.waitForTimeout(2000);
    },
  },
  'bao-gia-ds': { account: SALE, route: '/crm/bao-gia' },
  'don-hang-ds': { account: SALE, route: '/crm/don-hang' },
};
const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS))
    if (!chon.length || chon.includes(ten)) await chup(browser, ten, s);
} finally {
  await browser.close();
}
