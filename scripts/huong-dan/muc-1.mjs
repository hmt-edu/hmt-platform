// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/01-bat-dau-nhanh.md (chỗ «[ẢNH: tên]»). Chạy tay trên bản thử nghiệm, tài khoản giả. Cách chạy như README.md.
// Ra: HD_OUT (mặc định docs/huong-dan/assets/): <tên>.png, khung cam #EF6925 quanh phần cần chú ý. Không email, số điện thoại thật.
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? '';
const SB_KEY = process.env.HD_SUPABASE_KEY ?? '';
const OUT = process.env.HD_OUT ?? join(process.cwd(), 'docs', 'huong-dan', 'assets');
const DOMAIN = 'thu.hoamatoan.invalid';
if (!APP.startsWith('https://') || /prod/i.test(APP) || !PW || !SB_URL || !SB_KEY) {
  console.error(
    'Thiếu STAGING_URL (https, bản thử nghiệm), STAGING_PASSWORD, HD_SUPABASE_URL, HD_SUPABASE_KEY.',
  );
  process.exit(1);
}
mkdirSync(OUT, { recursive: true });
const DESKTOP = { width: 1280, height: 720 };
const PHONE = { width: 390, height: 844 };

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

const taiKhoan = (p) => p.locator('header button').last();
const SHOTS = {
  'dang-nhap-nhan-vien': {
    route: '/dang-nhap',
    truoc: async (p) => {
      await p.getByLabel('Email', { exact: true }).fill('ten@hoamatoan.vn');
      await p.getByLabel('Mật khẩu', { exact: true }).fill('matkhaumau');
    },
    loc: (p) => p.getByRole('button', { name: 'Đăng nhập', exact: true }),
  },
  'dang-nhap-hoc-sinh': {
    route: '/dang-nhap/hoc-sinh',
    truoc: async (p) => {
      await p.getByLabel('Mã học sinh', { exact: true }).fill('HS000212');
    },
    loc: (p) => p.getByRole('button', { name: 'Vào học', exact: true }),
  },
  'dang-nhap-phu-huynh': {
    route: '/dang-nhap/phu-huynh',
    truoc: async (p) => {
      await p.getByLabel('Mã phụ huynh', { exact: true }).fill('PH000212');
    },
    loc: (p) => p.getByRole('button', { name: 'Đăng nhập', exact: true }),
  },
  'quen-mat-khau': {
    route: '/quen-mat-khau',
    loc: (p) =>
      p
        .getByRole('link', { name: 'Quay lại đăng nhập' })
        .or(p.getByRole('button', { name: 'Quay lại đăng nhập' })),
  },
  'doi-mat-khau-ho-so': {
    account: 'sale.cs5',
    route: '/crm/tai-khoan',
    truoc: async (p) => {
      await p.getByText('Đổi mật khẩu').first().scrollIntoViewIfNeeded();
    },
    loc: (p) => p.getByRole('button', { name: 'Đổi mật khẩu', exact: true }),
  },
  'menu-crm': { account: 'sale.cs5', route: '/crm', loc: (p) => p.getByRole('navigation').first() },
  'viec-cua-toi-hom-nay': {
    account: 'sale.cs5',
    route: '/crm',
    loc: (p) => p.getByText('Việc của tôi hôm nay').first(),
  },
  'viec-cho-toi-duyet': { account: 'admin.cs1', route: '/crm/viec-cho-duyet' },
  'chon-co-so': {
    account: 'admin.cs1',
    route: '/crm',
    loc: (p) => p.getByLabel('Cơ sở đang xem').first(),
  },
  'menu-tai-khoan': {
    account: 'admin.cs1',
    route: '/crm',
    truoc: async (p) => {
      await taiKhoan(p).click();
      await p.waitForTimeout(600);
    },
    loc: (p) => p.getByRole('menu').first(),
  },
  'thanh-duoi-giao-vien': {
    account: 'gv.cs5',
    viewport: PHONE,
    route: '/gv',
    loc: (p) => p.getByRole('navigation').last(),
  },
};

const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS))
    if (!chon.length || chon.includes(ten)) await chup(browser, ten, s);
} finally {
  await browser.close();
}
