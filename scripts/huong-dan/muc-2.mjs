// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/02-thao-tac-co-ban.md (chỗ «[ẢNH: tên]»). Chạy tay trên bản thử nghiệm, tài khoản giả. Cách chạy như README.md.
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
const DS = '/crm/don-hang';
const SHOTS = {
  'danh-sach-thanh-cong-cu': {
    account: SALE,
    route: '/crm/co-hoi',
    loc: (p) => btn(p, 'Filters').locator('xpath=../..'),
  },
  'danh-sach-tim': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await p.getByPlaceholder(/^Tìm mã/).fill('Lan');
      await p.waitForTimeout(1500);
    },
    loc: (p) => p.getByPlaceholder(/^Tìm mã/),
  },
  'danh-sach-loc': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await btn(p, 'Filters').click();
      await p.waitForTimeout(500);
    },
    loc: (p) => p.getByText('Lọc nhanh').first().locator('xpath=ancestor::*[self::div][2]'),
  },
  'danh-sach-loc-nang-cao': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await btn(p, 'Filters').click();
      await p.getByText('Lọc nâng cao…').click();
      await p.waitForTimeout(600);
    },
    loc: (p) => p.getByRole('dialog').first(),
  },
  'danh-sach-nhom': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await btn(p, 'Group By').click();
      await p.getByText('Tình trạng', { exact: true }).last().click();
      await p.waitForTimeout(1500);
    },
    loc: (p) => btn(p, 'Group By'),
  },
  'danh-sach-luu-bo-loc': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await p.getByPlaceholder(/^Tìm mã/).fill('Lan');
      await p.waitForTimeout(1500);
      await p.getByRole('button', { name: 'Save to Favorites' }).click();
      await p.waitForTimeout(600);
      await p.getByRole('button', { name: 'Lưu bộ lọc hiện tại' }).click();
      await p.waitForTimeout(800);
    },
    loc: (p) => p.getByRole('dialog').first(),
  },
  'danh-sach-favorites': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await btn(p, 'Favorites').click();
      await p.waitForTimeout(500);
    },
    loc: (p) => btn(p, 'Favorites'),
  },
  'danh-sach-chon-cot': {
    account: SALE,
    route: DS,
    truoc: async (p) => {
      await btn(p, 'Cột').click();
      await p.waitForTimeout(500);
    },
    loc: (p) => p.getByText('Cột hiển thị').first(),
  },
  'chuyen-kanban': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await btn(p, 'Kanban').click();
      await p.waitForTimeout(2000);
    },
    loc: (p) => btn(p, 'Kanban'),
  },
  'chuyen-calendar': {
    account: SALE,
    route: '/crm/lich-hen',
    truoc: async (p) => {
      await btn(p, 'Calendar').click();
      await p.waitForTimeout(2000);
    },
    loc: (p) => btn(p, 'Calendar'),
  },
  'danh-sach-phan-trang': {
    account: SALE,
    route: DS,
    loc: (p) => p.getByRole('button', { name: 'Trang sau' }).locator('xpath=..'),
  },
  'ban-ghi-mo': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => btn(p, 'Sửa'),
  },
  'ban-ghi-tao': {
    account: SALE,
    route: '/crm/lead',
    truoc: async (p) => {
      await p.getByRole('button', { name: /^Tạo/ }).first().click();
      await p.waitForTimeout(1500);
    },
  },
  'ban-ghi-sua-luu': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
      await btn(p, 'Sửa').click();
      await p.waitForTimeout(800);
    },
    loc: (p) => btn(p, 'Lưu'),
  },
  'ban-ghi-ghi-chu': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
      await p
        .locator('textarea[placeholder^="Viết ghi chú"]')
        .fill('Phụ huynh hẹn gọi lại chiều mai');
    },
    loc: (p) => p.locator('textarea[placeholder^="Viết ghi chú"]'),
  },
  'ban-ghi-nhat-ky': {
    account: SALE,
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await p.locator('main tbody tr').nth(1).click();
      await p.waitForTimeout(2500);
      await p.getByText('DÒNG THỜI GIAN').first().scrollIntoViewIfNeeded();
    },
    loc: (p) => p.getByText('DÒNG THỜI GIAN').first(),
  },
  'thong-bao': {
    account: SALE,
    route: '/crm',
    truoc: async (p) => {
      await p
        .getByRole('button', { name: /Thông báo/ })
        .first()
        .click();
      await p.waitForTimeout(800);
    },
    loc: (p) =>
      p
        .getByRole('dialog')
        .first()
        .or(p.getByText('Đánh dấu tất cả đã đọc').locator('xpath=ancestor::*[2]')),
  },
  'viec-cho-toi-duyet-danh-sach': {
    account: 'admin.cs1',
    route: '/crm/viec-cho-duyet',
    loc: (p) => p.locator('main').first(),
  },
  'viec-cho-toi-duyet-mo-ban-ghi': {
    account: 'admin.cs1',
    route: '/crm/viec-cho-duyet',
    truoc: async (p) => {
      await p.locator('main tbody tr').first().click();
      await p.waitForTimeout(2500);
    },
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
