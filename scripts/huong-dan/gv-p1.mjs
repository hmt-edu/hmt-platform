// @ts-nocheck
// Ảnh THẬT cho docs/huong-dan/giao-vien/ (GV1, GV3–GV8), điện thoại 390×844. Chạy tay trên bản thử nghiệm, tài khoản giả gv.cs5.
// Chạy: set -a; . ~/VanPhongAI/hmt-ca/.staging-test.env; set +a; node scripts/huong-dan/gv-p1.mjs [GV1 GV8 …]
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

// Buổi cần làm của gv.cs5 lấy từ trang «Cần làm» (không viết cứng mã buổi).
async function layBuoi(browser) {
  const ctx = await browser.newContext({ viewport: PHONE });
  const [k, v] = await phien(TK);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  const page = await ctx.newPage();
  await page.goto(`${APP}/gv/viec-can-lam`);
  await page.waitForTimeout(3000);
  const href = await page
    .locator('a[href*="/gv/buoi/"]')
    .first()
    .getAttribute('href')
    .catch(() => null);
  await ctx.close();
  return href;
}

const btn = (ten) => (p) =>
  p.getByRole('button', { name: ten }).or(p.getByRole('link', { name: ten }));
const THANH_DUOI = (p) => p.locator('nav').last();

const browser = await chromium.launch();
try {
  const buoi = await layBuoi(browser);
  if (!buoi) console.log('Không có buổi nào cần làm: bỏ qua ảnh GV3–GV7');
  const chon = process.argv.slice(2);
  const co = (m) => !chon.length || chon.includes(m);
  if (co('GV1')) {
    await chup(browser, 'GV1', '01', {
      route: '/gv',
      loc: (p) => p.getByText('Hôm nay bạn không có buổi dạy'),
    });
    await chup(browser, 'GV1', '02', { route: '/gv', loc: THANH_DUOI });
  }
  if (co('GV8')) {
    await chup(browser, 'GV8', '01', {
      route: '/gv/viec-can-lam',
      loc: (p) => p.getByText('BUỔI CHƯA HOÀN TẤT'),
    });
    await chup(browser, 'GV8', '02', {
      route: '/gv/viec-can-lam',
      loc: (p) => p.getByRole('link', { name: 'Mở' }).first(),
    });
  }
  if (buoi) {
    if (co('GV3')) {
      await chup(browser, 'GV3', '01', {
        route: buoi,
        loc: (p) => p.locator(`a[href$="/diem-danh"]`).first(),
      });
      await chup(browser, 'GV3', '02', {
        route: `${buoi}/diem-danh`,
        loc: (p) => p.getByRole('button', { name: 'Lưu điểm danh' }),
      });
    }
    if (co('GV4')) {
      await chup(browser, 'GV4', '01', {
        route: buoi,
        loc: (p) => p.locator(`a[href$="/noi-dung"]`).first(),
      });
      await chup(browser, 'GV4', '02', {
        route: `${buoi}/noi-dung`,
        loc: (p) => p.getByRole('button', { name: 'Thêm dòng' }),
      });
      await chup(browser, 'GV4', '03', {
        route: `${buoi}/noi-dung`,
        loc: (p) => p.getByText('Giao BTVN cho buổi sau'),
      });
    }
    if (co('GV5'))
      await chup(browser, 'GV5', '01', {
        route: buoi,
        loc: (p) => p.getByText('Chấm nhận xét từng em'),
      });
    if (co('GV6'))
      await chup(browser, 'GV6', '01', {
        route: buoi,
        loc: (p) => p.getByText('Chấm BTVN buổi trước'),
      });
    if (co('GV7')) {
      await chup(browser, 'GV7', '01', { route: buoi, loc: (p) => p.getByText('Kiểm còn thiếu') });
      await chup(browser, 'GV7', '02', {
        route: buoi,
        truoc: async (p) => {
          await p
            .getByRole('button', { name: 'Hoàn tất', exact: true })
            .first()
            .click()
            .catch(() => {});
          await p.waitForTimeout(1500);
        },
      });
    }
  }
} finally {
  await browser.close();
}
