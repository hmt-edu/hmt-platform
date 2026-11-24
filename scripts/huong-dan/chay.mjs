// @ts-nocheck
// Kịch bản CHỤP ẢNH có khung đánh dấu + QUAY VIDEO hướng dẫn (T2-S). Chỉ chạy tay, KHÔNG nằm trong CI.
// Chạy: STAGING_URL=https://… STAGING_PASSWORD=… node scripts/huong-dan/chay.mjs [dang-nhap|danh-sach|ban-ghi|tat-ca]
// Chỉ dùng tài khoản GIẢ và dữ liệu giả của bản thử nghiệm; không bao giờ trỏ vào bản chạy thật. Mật khẩu chỉ qua biến môi trường.
// Ra: HD_OUT (mặc định ~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/huong-dan-mau/<bài>/): buoc-<n>.png, <bài>.webm, buoc.json. Nén mp4: xem README.md cùng thư mục.
import { mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { chromium } from '@playwright/test';
import { NHAN } from './nhan.mjs';

const APP = (process.env.STAGING_URL ?? '').replace(/\/$/, '');
const PW = process.env.STAGING_PASSWORD ?? '';
const SB_URL = process.env.HD_SUPABASE_URL ?? ''; // địa chỉ Supabase của bản thử nghiệm (công khai)
const SB_KEY = process.env.HD_SUPABASE_KEY ?? ''; // khoá publishable (công khai), KHÔNG phải khoá secret
const TAI_KHOAN = process.env.HD_TAI_KHOAN ?? 'sale.cs5@thu.hoamatoan.invalid';
const OUT =
  process.env.HD_OUT ?? join(homedir(), 'VanPhongAI', 'hmt-ca', 'ANH-HUONG-DAN', 'huong-dan-mau');
const DUNG = Number(process.env.HD_DUNG_MS ?? 1600); // thời gian dừng mỗi bước trong video
if (!APP.startsWith('https://') || /prod/i.test(APP) || !PW || !SB_URL || !SB_KEY) {
  console.error(
    'Thiếu STAGING_URL (https, bản thử nghiệm), STAGING_PASSWORD, HD_SUPABASE_URL hoặc HD_SUPABASE_KEY; không chạy với địa chỉ có chữ prod.',
  );
  process.exit(1);
}

const CAM = '#EF6925';

/** Chèn khung cam, số tròn, chú thích quanh phần tử và thanh phụ đề đáy; con trỏ giả bám theo chuột. */
async function ve(page, loc, so, chu) {
  const box = loc ? await loc.first().boundingBox() : null;
  await page.evaluate(
    ({ box, so, chu, CAM }) => {
      document.getElementById('hd-lop')?.remove();
      const lop = document.createElement('div');
      lop.id = 'hd-lop';
      lop.style.cssText =
        'position:fixed;inset:0;pointer-events:none;z-index:2147483647;font-family:system-ui,sans-serif';
      if (box) {
        const k = document.createElement('div');
        k.style.cssText = `position:absolute;left:${box.x - 4}px;top:${box.y - 4}px;width:${box.width + 8}px;height:${box.height + 8}px;border:3px solid ${CAM};border-radius:8px`;
        const n = document.createElement('div');
        n.textContent = String(so);
        n.style.cssText = `position:absolute;left:-14px;top:-14px;width:28px;height:28px;border-radius:50%;background:${CAM};color:#fff;font:700 15px/28px system-ui;text-align:center`;
        k.append(n);
        lop.append(k);
      }
      const d = document.createElement('div');
      d.textContent = `${so}. ${chu}`;
      d.style.cssText =
        'position:absolute;left:50%;bottom:20px;transform:translateX(-50%);max-width:92%;background:#211C16;color:#fff;padding:10px 18px;border-radius:10px;font:600 18px system-ui;text-align:center;border:2px solid #EF6925';
      lop.append(d);
      document.body.append(lop);
    },
    { box, so, chu, CAM },
  );
}

const goKhung = (page) => page.evaluate(() => document.getElementById('hd-lop')?.remove());

/** Con trỏ giả: chấm cam theo chuột (video không quay con trỏ thật). */
async function conTro(context) {
  await context.addInitScript((CAM) => {
    addEventListener('DOMContentLoaded', () => {
      const c = document.createElement('div');
      c.style.cssText = `position:fixed;left:-50px;top:-50px;width:20px;height:20px;margin:-10px 0 0 -10px;border-radius:50%;background:${CAM}99;border:2px solid ${CAM};z-index:2147483647;pointer-events:none;transition:left .35s,top .35s`;
      document.body.append(c);
      addEventListener('mousemove', (e) => {
        c.style.left = e.clientX + 'px';
        c.style.top = e.clientY + 'px';
      });
    });
  }, CAM);
}

/** Một bài: dựng ngữ cảnh có quay video, chạy từng bước {chu, loc, lam}; mỗi bước chụp ảnh khung rồi mới làm. */
async function chayBai(browser, ten, vaoTruoc, cacBuoc, khung = { width: 1280, height: 720 }) {
  const dir = join(OUT, ten);
  mkdirSync(dir, { recursive: true });
  const context = await browser.newContext({ viewport: khung, recordVideo: { dir, size: khung } });
  await conTro(context);
  const page = await context.newPage();
  const ghi = [];
  await vaoTruoc?.(page);
  let so = 0;
  for (const b of cacBuoc) {
    so += 1;
    const loc = b.loc ? b.loc(page) : null;
    if (loc) await loc.first().waitFor({ timeout: 15000 });
    if (loc) {
      const hop = await loc.first().boundingBox();
      if (hop) await page.mouse.move(hop.x + hop.width / 2, hop.y + hop.height / 2, { steps: 12 });
    }
    await ve(page, loc, so, b.chu);
    await page.waitForTimeout(DUNG);
    const anh = `buoc-${so}.png`;
    await page.screenshot({ path: join(dir, anh) });
    ghi.push({ so, chu: b.chu, anh });
    await goKhung(page);
    await b.lam?.(page, loc);
    await page.waitForTimeout(500);
  }
  const video = page.video();
  await context.close();
  if (video) renameSync(await video.path(), join(dir, `${ten}.webm`));
  writeFileSync(join(dir, 'buoc.json'), JSON.stringify(ghi, null, 2));
  // Nén mp4 H.264 (cần ffmpeg: brew install ffmpeg); không có ffmpeg thì giữ .webm và báo.
  const nen = spawnSync('ffmpeg', [
    '-loglevel',
    'error',
    '-y',
    '-i',
    join(dir, `${ten}.webm`),
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-crf',
    '32',
    '-vf',
    'scale=-2:720',
    '-pix_fmt',
    'yuv420p',
    '-an',
    join(dir, `${ten}.mp4`),
  ]);
  if (nen.status !== 0) console.warn('Chưa nén được mp4 (thiếu ffmpeg?): giữ tệp .webm.');
  console.log(`✔ ${ten}: ${ghi.length} bước → ${dir}`);
}

const nutTen = (ten) => (p) => p.getByRole('button', { name: ten, exact: true });
/** Bản thử nghiệm có bước chống máy tự động (Turnstile) chặn đăng nhập bằng biểu mẫu khi chạy tự động: lấy phiên bằng API Auth (mật khẩu thật của tài khoản giả) rồi nạp vào trình duyệt. */
const dangNhap = async (page) => {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SB_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email: TAI_KHOAN, password: PW }),
  });
  if (!r.ok) throw new Error(`Đăng nhập API lỗi ${r.status}`);
  const khoa = `sb-${new URL(SB_URL).hostname.split('.')[0]}-auth-token`;
  const phien = JSON.stringify(await r.json());
  await page.addInitScript(([k, v]) => localStorage.setItem(k, v), [khoa, phien]);
  await page.goto(`${APP}/crm`);
  await page.waitForURL(/\/crm/, { timeout: 30000 });
  await page.waitForLoadState('networkidle');
};

const BAI = {
  // Bài 1: đăng nhập và nhìn menu.
  'dang-nhap': (b) =>
    chayBai(b, 'dang-nhap', (p) => p.goto(`${APP}/dang-nhap`), [
      {
        chu: 'Nhập email được cấp',
        loc: (p) => p.getByLabel('Email', { exact: true }),
        lam: (p) => p.getByLabel('Email', { exact: true }).fill(TAI_KHOAN),
      },
      {
        chu: 'Nhập mật khẩu',
        loc: (p) => p.getByLabel('Mật khẩu', { exact: true }),
        lam: (p) => p.getByLabel('Mật khẩu', { exact: true }).fill(PW),
      },
      { chu: 'Bấm Đăng nhập', loc: nutTen(NHAN.dangNhap), lam: dangNhap },
      { chu: 'Menu bên trái: chọn màn cần làm', loc: (p) => p.getByRole('navigation').first() },
    ]),
  // Bài 2: danh sách K03 (Filters, Group By, Favorites).
  'danh-sach': (b) =>
    chayBai(
      b,
      'danh-sach',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/don-hang`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Mở Filters để lọc nhanh',
          loc: nutTen(NHAN.filters),
          lam: (p) => nutTen(NHAN.filters)(p).click(),
        },
        {
          chu: 'Chọn «Của tôi» để chỉ xem việc của mình',
          loc: (p) => p.getByText('Của tôi', { exact: true }).first(),
          lam: async (p) => {
            await p.getByText('Của tôi', { exact: true }).first().click();
            await p.keyboard.press('Escape');
          },
        },
        {
          chu: 'Mở Group By để gom theo cột',
          loc: nutTen(NHAN.groupBy),
          lam: (p) => nutTen(NHAN.groupBy)(p).click(),
        },
        {
          chu: 'Chọn nhóm theo Tình trạng',
          loc: (p) => p.getByText('Tình trạng', { exact: true }).last(),
          lam: async (p) => {
            await p.getByText('Tình trạng', { exact: true }).last().click();
            await p.keyboard.press('Escape');
          },
        },
        {
          chu: 'Favorites: lưu bộ lọc đang dùng',
          loc: nutTen(NHAN.favorites),
          lam: (p) => nutTen(NHAN.favorites)(p).click(),
        },
      ],
    ),
  // Bài 3: mở một cơ hội và lưu một ghi chú (dữ liệu giả, ghi chú có tiền tố).
  'ban-ghi': (b) =>
    chayBai(
      b,
      'ban-ghi',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/co-hoi`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Bấm vào một dòng để mở cơ hội',
          loc: (p) => p.locator('main tbody tr').nth(1),
          lam: async (p) => {
            await p.locator('main tbody tr').nth(1).click();
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Gõ ghi chú vào ô bên dưới',
          loc: (p) => p.locator('textarea[placeholder^="Viết ghi chú"]'),
          lam: (p) =>
            p
              .locator('textarea[placeholder^="Viết ghi chú"]')
              .fill('[Hướng dẫn mẫu] Phụ huynh hẹn gọi lại chiều mai'),
        },
        {
          chu: 'Bấm Gửi ghi chú để lưu',
          loc: nutTen(NHAN.guiGhiChu),
          lam: (p) => nutTen(NHAN.guiGhiChu)(p).click(),
        },
        {
          chu: 'Ghi chú đã nằm trong dòng thời gian',
          loc: (p) => p.getByText('[Hướng dẫn mẫu]').first(),
        },
      ],
    ),
  // Vai Tư vấn tuyển sinh (chỉ xem, không ghi): lead → giai đoạn → cơ hội → lịch hẹn. Chạy với HD_TAI_KHOAN=sale.cs5@…
  'tu-van': (b) =>
    chayBai(
      b,
      'tu-van',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Lead mới nằm ở danh sách Lead',
          loc: (p) => p.locator('main tbody tr').nth(1),
          lam: async (p) => {
            await p.locator('main tbody tr').nth(1).click();
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Giai đoạn của lead hiện ở thanh trên',
          loc: (p) => p.getByText(/^C1 /).first().locator('xpath=../..'),
        },
        {
          chu: 'Đủ điều kiện thì Tạo cơ hội',
          loc: (p) => p.getByRole('button', { name: /Tạo cơ hội/ }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/co-hoi`);
            await p.waitForLoadState('networkidle');
            await p.locator('main tbody tr').nth(1).click();
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Cơ hội: chuyển giai đoạn L1 đến L8',
          loc: (p) => p.getByText(/^L1 /).first().locator('xpath=../..'),
        },
        {
          chu: 'Có tư vấn xong thì Tạo báo giá',
          loc: (p) => p.getByRole('button', { name: 'Tạo báo giá', exact: true }),
        },
        {
          chu: 'Lên lịch hẹn ngay ở cột ghi chú',
          loc: (p) => p.getByRole('button', { name: 'Lên lịch hẹn', exact: true }),
        },
      ],
    ),
  // Vai Kế toán (chỉ xem, không bấm duyệt): trang chủ → phiếu thu chờ kế toán. Chạy với HD_TAI_KHOAN=ketoan.cs5@…
  'ke-toan': (b) =>
    chayBai(
      b,
      'ke-toan',
      async (p) => {
        await dangNhap(p);
      },
      [
        {
          chu: 'Trang chủ: việc chờ bạn duyệt',
          loc: (p) => p.getByText('Việc chờ tôi duyệt').first(),
        },
        {
          chu: 'Vào Bán hàng và thu chi, mở Phiếu thu',
          loc: (p) =>
            p
              .getByRole('link', { name: 'Bán hàng và thu chi' })
              .or(p.getByText('Bán hàng và thu chi').first()),
          lam: async (p) => {
            await p.goto(`${APP}/crm/phieu-thu`);
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Tìm phiếu ở tình trạng Chờ kế toán',
          loc: (p) => p.locator('main tbody tr', { hasText: 'Chờ kế toán' }).first(),
          lam: async (p) => {
            await p
              .locator('main tbody tr', { hasText: 'Chờ kế toán' })
              .first()
              .locator('a')
              .first()
              .click();
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Đối chiếu số tiền, đơn hàng rồi Duyệt phiếu thu',
          loc: (p) => p.getByRole('button', { name: 'Duyệt phiếu thu', exact: true }),
        },
        {
          chu: 'Không khớp thì bấm Từ chối',
          loc: (p) => p.getByRole('button', { name: 'Từ chối', exact: true }),
        },
      ],
    ),
  // «Dữ liệu mẫu của tôi» (#667): tạo một bộ [MẪU] rồi xoá đúng bộ đó. CHỈ staging, tài khoản giả. Chạy với HD_TAI_KHOAN=sale.cs5@…
  'du-lieu-mau': (b) =>
    chayBai(
      b,
      'du-lieu-mau',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/du-lieu-mau`);
        await p.waitForLoadState('networkidle');
        // Dọn các bộ còn sót của tài khoản giả (tối đa 3 bộ/người) trước khi quay.
        const xoa = p.getByRole('button', { name: 'Xoá bộ', exact: true });
        for (let i = 0; i < 5 && (await xoa.count()) > 0; i++) {
          await xoa.first().click();
          await xoa.last().click();
          await p.waitForTimeout(2000);
        }
        await p.reload();
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Mở «Dữ liệu mẫu của tôi» từ menu tài khoản',
          loc: (p) => p.getByRole('heading', { name: 'Dữ liệu mẫu của tôi' }),
        },
        {
          chu: 'Bấm Tạo bộ dữ liệu mẫu',
          loc: (p) => p.getByRole('button', { name: 'Tạo bộ dữ liệu mẫu', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo bộ dữ liệu mẫu', exact: true }).click();
            await p
              .getByRole('button', { name: 'Xoá bộ', exact: true })
              .first()
              .waitFor({ timeout: 30000 });
          },
        },
        {
          chu: 'Bộ mới hiện ở danh sách; dữ liệu trong bộ ghi «[MẪU]»',
          loc: (p) => p.locator('main ul > li').first(),
        },
        {
          chu: 'Dùng xong thì bấm Xoá bộ',
          loc: (p) => p.getByRole('button', { name: 'Xoá bộ', exact: true }).first(),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Xoá bộ', exact: true }).first().click();
          },
        },
        {
          chu: 'Xác nhận Xoá bộ (không khôi phục được)',
          loc: (p) => p.getByRole('button', { name: 'Xoá bộ', exact: true }).last(),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Xoá bộ', exact: true }).last().click();
            await p.waitForTimeout(1500);
          },
        },
      ],
    ),
};

const chon = process.argv[2] ?? 'tat-ca';
const ds = chon === 'tat-ca' ? Object.keys(BAI) : [chon];
const browser = await chromium.launch();
try {
  for (const t of ds) {
    if (!BAI[t]) throw new Error(`Không có bài «${t}». Bài có: ${Object.keys(BAI).join(', ')}`);
    await BAI[t](browser);
  }
} finally {
  await browser.close();
}
