// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/03-cskh.md và 03-truong-co-so.md (chỗ «[ẢNH: tên]»). Chạy tay trên bản thử nghiệm, tài khoản giả. Cách chạy như README.md.
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

const CS = 'cskh.cs5';
const TC = 'truongcs.cs5';
const moDong = (sel) => async (p) => {
  await (sel ? p.locator('main tbody tr', { hasText: sel }) : p.locator('main tbody tr'))
    .first()
    .locator('a')
    .first()
    .click();
  await p.waitForTimeout(2500);
};
const clickDong = async (p) => {
  await p.locator('main tbody tr').first().click();
  await p.waitForTimeout(2500);
};
const SHOTS = {
  // CSKH: chỉ xem hoặc mở hộp rồi chụp, không ghi.
  'phu-huynh-ds': { account: CS, route: '/crm/phu-huynh' },
  'hoc-sinh-ho-so': { account: CS, route: '/crm/hoc-sinh', truoc: moDong() },
  'ghi-danh-cho-xep': { account: CS, route: '/crm/ghi-danh' },
  'ghi-danh-xep-lop': { account: CS, route: '/crm/ghi-danh', truoc: moDong() },
  'ghi-danh-so-gio': {
    account: CS,
    route: '/crm/ghi-danh',
    truoc: async (p) => {
      await moDong()(p);
      await p
        .getByRole('button', { name: /Sổ giờ/ })
        .first()
        .click()
        .catch(() => {});
      await p.waitForTimeout(1500);
    },
  },
  'lop-trinh': { account: CS, route: '/crm/lop', truoc: moDong() },
  'diem-danh-trong-ngay': { account: CS, route: '/crm/diem-danh-trong-ngay' },
  'buoi-ban-ghi': { account: CS, route: '/crm/buoi-hoc', truoc: clickDong },
  'ticket-ds': { account: CS, route: '/crm/ticket' },
  'ticket-kanban': {
    account: CS,
    route: '/crm/ticket',
    truoc: async (p) => {
      await p
        .getByRole('button', { name: /Kanban/i })
        .first()
        .click()
        .catch(() => {});
      await p.waitForTimeout(1500);
    },
  },
  'ticket-ban-ghi': { account: CS, route: '/crm/ticket', truoc: clickDong },
  // Trưởng cơ sở: chỉ xem.
  'truong-co-so-trang-chu': { account: TC, route: '/crm' },
  'viec-cho-toi-duyet-truong-co-so': { account: TC, route: '/crm/viec-cho-duyet' },
  'phieu-nghiep-vu-cho-toi': { account: TC, route: '/crm/phieu-nghiep-vu' },
  'phieu-nghiep-vu-duyet': { account: TC, route: '/crm/phieu-nghiep-vu', truoc: moDong() },
  'don-hang-duyet': { account: TC, route: '/crm/don-hang', truoc: moDong() },
  'phieu-thu-duyet-quan-ly': { account: TC, route: '/crm/phieu-thu', truoc: moDong() },
  'lop-duyet': { account: TC, route: '/crm/lop' },
  'lich-tuan': { account: TC, route: '/crm/lich-tuan' },
};
const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS))
    if (!chon.length || chon.includes(ten)) await chup(browser, ten, s);
} finally {
  await browser.close();
}
