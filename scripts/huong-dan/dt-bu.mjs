// @ts-nocheck
// Ảnh chụp bù DT6, DT8 (máy tính 1440×900) trên bản thử nghiệm, tài khoản giả. Chạy: set -a; . ~/VanPhongAI/hmt-ca/.staging-test.env; set +a; node scripts/huong-dan/dt-bu.mjs [DT8 DT6]
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? '';
const SB_KEY = process.env.HD_SUPABASE_KEY ?? '';
const OUT = process.env.HD_OUT ?? join(process.cwd(), 'public', 'huong-dan', 'anh');
if (!APP.startsWith('https://') || /prod/i.test(APP) || !PW || !SB_URL || !SB_KEY) {
  console.error(
    'Thiếu STAGING_URL (https, bản thử nghiệm), STAGING_PASSWORD, HD_SUPABASE_URL, HD_SUPABASE_KEY.',
  );
  process.exit(1);
}

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
  const box = loc
    ? await loc
        .first()
        .boundingBox({ timeout: 4000 })
        .catch(() => null)
    : null;
  if (!box) return;
  await page.evaluate((b) => {
    const k = document.createElement('div');
    k.style.cssText = `position:fixed;left:${b.x - 4}px;top:${b.y - 4}px;width:${b.width + 8}px;height:${b.height + 8}px;border:3px solid #EF6925;border-radius:8px;pointer-events:none;z-index:2147483647`;
    document.body.append(k);
  }, box);
}

const DESKTOP = { width: 1440, height: 900 };

async function phienTrang(browser, tk) {
  const ctx = await browser.newContext({ viewport: DESKTOP, deviceScaleFactor: 1 });
  const [k, v] = await phien(tk);
  await ctx.addInitScript(([k, v]) => localStorage.setItem(k, v), [k, v]);
  return { ctx, page: await ctx.newPage() };
}

async function anh(page, ten, loc) {
  if (loc) await khung(page, loc);
  mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: join(OUT, `${ten}.png`) });
  console.log('✔', ten);
  await page.evaluate(() =>
    document.querySelectorAll('body > div[style*="EF6925"]').forEach((d) => d.remove()),
  );
}

const browser = await chromium.launch();
const chon = process.argv.slice(2);
const co = (m) => !chon.length || chon.includes(m);
try {
  if (co('DT8')) {
    // Lớp «Đã trình» chưa có em (lớp mẫu ANH-K06-CB-S-008): Xác nhận → Duyệt, bằng màn thật.
    const { ctx, page } = await phienTrang(browser, 'truongcs.cs5');
    await page.goto(`${APP}/crm/lop`);
    await page.waitForTimeout(3500);
    await page.getByText('CS5-2627-ANH-K06-CB-S-008').first().click();
    await page.waitForTimeout(3500);
    const hanhDong = () => page.getByRole('button', { name: 'Hành động' });
    const trangThai = await page.locator('main').innerText();
    if (trangThai.includes('Lớp đã trình')) {
      await hanhDong().click();
      await page.getByRole('menuitem', { name: 'Xác nhận' }).click();
      await page.waitForTimeout(1200);
      await page.getByRole('button', { name: 'Xác nhận', exact: true }).last().click();
      await page.waitForTimeout(3000);
    }
    await hanhDong().click();
    await page.getByRole('menuitem', { name: 'Duyệt' }).click();
    await page.waitForTimeout(1500);
    await anh(page, 'dt8-b4a', page.getByRole('button', { name: 'Duyệt', exact: true }).last());
    await page.getByRole('button', { name: 'Duyệt', exact: true }).last().click();
    await page.waitForTimeout(3000);
    await anh(page, 'dt8-b4b', page.getByText(/Đã duyệt/).first());
    await ctx.close();
  }
  if (co('DT6')) {
    // Phiếu tái tục mẫu TT000003 (L1, chưa có người phụ trách): Giao người phụ trách bằng màn thật. Chạy MỘT lần (mỗi lần chạy giao lại một lần, dòng thời gian bị lặp).
    const { ctx, page } = await phienTrang(browser, 'truongcs.cs5');
    await page.goto(`${APP}/crm/tai-tuc`);
    await page.waitForTimeout(3500);
    await page.getByText('TT000003').first().click();
    await page.waitForTimeout(3500);
    const chonDau = async (nhan, pgx = page) => {
      const s = pgx.getByLabel(nhan, { exact: true }).last();
      const opts = await s
        .locator('option')
        .allInnerTexts()
        .catch(() => []);
      const dich = opts.find((o) => o.trim() && !/^Chọn|^—/.test(o.trim()));
      if (dich) await s.selectOption({ label: dich });
      else {
        await s.click();
        await pgx.getByRole('option').first().click();
      }
    };
    await page.getByRole('button', { name: 'Giao', exact: true }).click();
    await page.waitForTimeout(1200);
    await chonDau('Người phụ trách');
    await anh(page, 'dt6-b3a', page.getByRole('button', { name: /^(Giao|Tạo đơn nháp)$/ }).last());
    await page.getByRole('button', { name: 'Giao', exact: true }).last().click();
    await page.waitForTimeout(2500);
    await anh(page, 'dt6-b3b', page.getByText(/Đã giao cho/).first());
    await ctx.close();
  }
} finally {
  await browser.close();
}
