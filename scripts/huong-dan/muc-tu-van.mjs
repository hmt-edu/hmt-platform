// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/tu-van/*.md (B-23-48). Chạy tay trên bản thử nghiệm, tài khoản giả, CHỈ ĐỌC:
// mở màn và hộp thoại rồi chụp, không bấm lưu/gửi. Cách chạy như README.md: node scripts/huong-dan/muc-tu-van.mjs [tên-ảnh …]
// Ra: HD_OUT (mặc định public/huong-dan/anh/): <tên>.png, khung cam #EF6925. Không email, số điện thoại thật.
import { mkdirSync, writeFileSync } from 'node:fs';
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
const DESKTOP = { width: 1440, height: 900 };
const SALE = 'sale.cs5';

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
  if (!box) return false;
  await page.evaluate((b) => {
    const k = document.createElement('div');
    k.style.cssText = `position:fixed;left:${b.x - 4}px;top:${b.y - 4}px;width:${b.width + 8}px;height:${b.height + 8}px;border:3px solid #EF6925;border-radius:8px;pointer-events:none;z-index:2147483647`;
    document.body.append(k);
  }, box);
  return true;
}

const btn = (p, n) => p.getByRole('button', { name: n });
const dong = async (p, n = 1) => {
  await p.locator('main tbody tr').nth(n).click();
  await p.waitForTimeout(2500);
};
const lead = (p) => dong(p, 1);
const thanhGD = (p) =>
  p
    .locator('main')
    .getByText(/Đồng ý tham gia test|Chưa liên hệ được/)
    .first()
    .locator('xpath=../../..');
const timKiem = (p) => p.locator('main input').first();
const csv =
  '/private/tmp/claude-501/-Users-caoxuantruong-Developer-hmt-platform-code2/4bbb2736-19b8-4388-8964-b95907a89086/scratchpad/hd-lead.csv';
writeFileSync(
  csv,
  'Họ tên phụ huynh,SĐT,Tên học sinh,Năm sinh\nHD Phụ huynh A,0999000901,HD Học sinh A,2012\nHD Phụ huynh B,0999000902,HD Học sinh B,2013\nHD Phụ huynh C,abc,HD Học sinh C,2014\n',
);
const moNhap = async (p) => {
  await btn(p, /^Nhập/).first().click();
  await p.waitForTimeout(1200);
  await p.locator('input[type=file]').setInputFiles(csv);
  await p.waitForTimeout(1500);
};
const tiep = async (p) => {
  await btn(p, /Tiếp|Ghép cột|Xem trước/)
    .last()
    .click();
  await p.waitForTimeout(1500);
};

// route: trang mở đầu; truoc: thao tác mở hộp/chuyển trang (chỉ đọc); loc: phần tử đóng khung.
const SHOTS = {
  // TS1
  'ts03-ts1-b1': { route: '/crm/lead/moi', loc: (p) => btn(p, /^Lưu$/) },
  'ts03-ts1-b2': {
    route: '/crm/lead/moi',
    truoc: async (p) => {
      await p
        .getByLabel(/Số điện thoại/)
        .first()
        .fill('0999000001');
      await p.keyboard.press('Tab');
      await p.waitForTimeout(2500);
    },
    loc: (p) => p.getByText('Số điện thoại này đã có trong hệ thống'),
  },
  'ts03-ts1-b5': { route: '/crm/lead/moi', loc: (p) => p.getByText('Nguồn và phụ trách').first() },
  'ts14-ts1-b7': {
    route: '/crm/lead/moi',
    truoc: async (p) => {
      await p
        .getByLabel(/Họ tên/)
        .first()
        .fill('HD Khách thử');
      await p
        .getByLabel(/Số điện thoại/)
        .first()
        .fill('0999000001');
      await p.keyboard.press('Tab');
      await p.waitForTimeout(1500);
      await btn(p, /^Lưu$/).click();
      await p.waitForTimeout(2500);
    },
    loc: (p) => p.getByRole('dialog'),
  },
  // TS2
  'ts04-ts2-b1': {
    route: '/crm/lead',
    truoc: async (p) => {
      await btn(p, /^Nhập/).first().click();
      await p.waitForTimeout(1500);
    },
    loc: (p) => p.getByRole('dialog'),
  },
  'ts04-ts2-b2': { route: '/crm/lead', truoc: moNhap, loc: (p) => p.getByRole('dialog') },
  'ts04-ts2-b3': {
    route: '/crm/lead',
    truoc: async (p) => {
      await moNhap(p);
      await tiep(p);
    },
    loc: (p) => p.getByText('Cột trong file').first(),
  },
  'ts04-ts2-b5': {
    route: '/crm/lead',
    truoc: async (p) => {
      await moNhap(p);
      await tiep(p);
      await tiep(p);
    },
    loc: (p) => p.getByText(/Kết quả từng dòng/).first(),
  },
  // TS3
  'ts02-ts3-b1': { route: '/crm/lead', truoc: lead, loc: thanhGD },
  'ts02-ts3-b2': { route: '/crm/lead', truoc: lead, loc: (p) => p.getByText('Sub-stage').first() },
  // TS5
  'ts-02-ts5-b1': { route: '/crm/lead', truoc: lead, loc: (p) => btn(p, /Tạo cơ hội/) },
  'ts-06-ts5-b2': {
    route: '/crm/lead',
    truoc: async (p) => {
      await lead(p);
      await btn(p, /Tạo cơ hội/).click();
      await p.waitForTimeout(1500);
    },
    loc: (p) => p.getByRole('dialog'),
  },
  // TS6
  'ts-08-ts6-b1': { route: '/crm/co-hoi', truoc: (p) => dong(p, 1), loc: thanhGD },
  // TS9
  'ts-11-ts9-b2': { route: '/crm/lich-hen', loc: (p) => p.getByText(/Hôm nay/).first() },
  'ts-13-ts9-b1': {
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await dong(p, 1);
      await btn(p, /Lên lịch hẹn/).click();
      await p.waitForTimeout(1500);
    },
    loc: (p) => p.getByRole('dialog'),
  },
  'ts08-ts10-b1': {
    route: '/crm/co-hoi',
    truoc: (p) => dong(p, 1),
    loc: (p) => btn(p, /Tạo lịch Test/),
  },
  'ts15-ts10-b2': {
    route: '/crm/co-hoi',
    truoc: async (p) => {
      await dong(p, 1);
      await btn(p, /Tạo lịch Test/).click();
      await p.waitForTimeout(1500);
    },
    loc: (p) => p.getByRole('dialog'),
  },
  'ts17-ts10-b7': { route: '/crm/phieu-kiem-tra', truoc: (p) => dong(p, 0), loc: null },
  // KH1
  'kh01-kh1-b1': { route: '/crm/phu-huynh', loc: (p) => timKiem(p) },
  'kh02-kh1-b2': { route: '/crm/phu-huynh', truoc: (p) => dong(p, 0), loc: null },
  'kh04-kh1-b4': { route: '/crm/hoc-sinh', loc: (p) => timKiem(p) },
  'kh05-kh1-b5': { route: '/crm/hoc-sinh', truoc: (p) => dong(p, 0), loc: null },
  // TS10/TS11
  'ts17-ts11-b1': { route: '/crm/phieu-kiem-tra', loc: (p) => timKiem(p) },
};

async function chup(browser, ten, s) {
  const ctx = await browser.newContext({ viewport: s.viewport ?? DESKTOP });
  const [k, v] = await phien(s.account ?? SALE);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  const page = await ctx.newPage();
  page.setDefaultTimeout(8000);
  try {
    await page.goto(`${APP}${s.route}`);
    await page.waitForLoadState('load');
    await page.waitForTimeout(2500);
    if (s.truoc) await s.truoc(page);
    await page.waitForTimeout(500);
    let ok = true;
    if (s.loc) ok = await khung(page, s.loc(page));
    await page.screenshot({ path: join(OUT, `${ten}.png`) });
    console.log(ok ? '✔' : '△ (không thấy chỗ đóng khung)', ten);
  } catch (e) {
    console.log('✘', ten, String(e.message).split('\n')[0]);
  }
  await ctx.close();
}

const chon = process.argv.slice(2);
const browser = await chromium.launch();
try {
  for (const [ten, s] of Object.entries(SHOTS))
    if (!chon.length || chon.includes(ten)) await chup(browser, ten, s);
} finally {
  await browser.close();
}
