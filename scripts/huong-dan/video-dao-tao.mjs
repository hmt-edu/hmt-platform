// @ts-nocheck
// Video hướng dẫn nhóm Đào tạo (D-23-57): khung quay và hàm trợ giúp chép từ chay.mjs của Tester 2 (#749) để không đụng file của họ. Chỉ chạy tay, KHÔNG nằm trong CI.
// Chạy: STAGING_URL=https://… STAGING_PASSWORD=… node scripts/huong-dan/chay.mjs [dang-nhap|danh-sach|ban-ghi|tat-ca]
// Chỉ dùng tài khoản GIẢ và dữ liệu giả của bản thử nghiệm; không bao giờ trỏ vào bản chạy thật. Mật khẩu chỉ qua biến môi trường.
// Ra: HD_OUT (mặc định ~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/huong-dan-mau/<bài>/): buoc-<n>.png, <bài>.webm, buoc.json. Nén mp4: xem README.md cùng thư mục.
import { mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { chromium } from '@playwright/test';

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
async function ve(page, loc, so, chu, tong) {
  const box = loc ? await loc.first().boundingBox() : null;
  await page.evaluate(
    ({ box, so, chu, tong, CAM }) => {
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
      d.textContent = tong ? `Bước ${so}/${tong}: ${chu}` : `${so}. ${chu}`;
      d.style.cssText =
        'position:absolute;left:50%;bottom:20px;transform:translateX(-50%);max-width:92%;background:#211C16;color:#fff;padding:10px 18px;border-radius:10px;font:600 18px system-ui;text-align:center;border:2px solid #EF6925';
      lop.append(d);
      document.body.append(lop);
    },
    { box, so, chu, tong, CAM },
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
async function chayBai(
  browser,
  ten,
  vaoTruoc,
  cacBuoc,
  khung = { width: 1280, height: 720 },
  tong = 0,
) {
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
    // Phần tử ở dưới màn hình 720 thì cuộn tới giữa màn để khung đánh dấu thấy được.
    if (loc) await loc.first().evaluate((e) => e.scrollIntoView({ block: 'center' }));
    if (loc) {
      const hop = await loc.first().boundingBox();
      if (hop) await page.mouse.move(hop.x + hop.width / 2, hop.y + hop.height / 2, { steps: 12 });
    }
    await ve(page, loc, so, b.chu, tong);
    // Phụ đề phải đọc kịp (anh chốt 24/11): tối thiểu 3 giây, khoảng 1 giây cho mỗi 13 ký tự; video khớp từng bước (tong > 0) dùng mức này.
    await page.waitForTimeout(tong ? Math.max(3000, Math.ceil((b.chu.length / 13) * 1000)) : DUNG);
    const anh = `buoc-${so}.png`;
    await page.screenshot({ path: join(dir, anh) });
    ghi.push({ so, chu: b.chu, anh });
    // Video khớp từng bước: GIỮ phụ đề trong lúc thao tác và lúc màn đổi (bước sau tự thay phụ đề); bản cũ gỡ khung trước khi làm.
    if (!tong) await goKhung(page);
    else
      await page.evaluate(() => {
        const lop = document.getElementById('hd-lop');
        while (lop && lop.children.length > 1) lop.firstElementChild.remove(); // gỡ khung, giữ phụ đề
      });
    await b.lam?.(page, loc);
    await page.waitForTimeout(tong ? 1200 : 500);
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

const chung = { width: 1280, height: 720 };
const cho = (p) => p.waitForLoadState('networkidle');
const vao = (duong) => async (p) => {
  await dangNhap(p);
  await p.goto(`${APP}${duong}`);
  await cho(p);
};

const BAI = {
  // DT1 «Xem ghi danh, quỹ giờ và sổ giờ của một em» (CSKH, chỉ xem): bước 1 đến 5 của bài.
  dt1: (b) =>
    chayBai(
      b,
      'dt1',
      vao('/crm/ghi-danh'),
      [
        {
          chu: 'Vào menu Đào tạo → Ghi danh',
          loc: (p) => p.getByRole('heading', { name: 'Ghi danh' }).first(),
        },
        {
          chu: 'Gõ tên hoặc mã em vào ô tìm, hoặc lọc theo «Tình trạng»',
          loc: (p) => p.getByRole('searchbox').or(p.getByPlaceholder(/Tìm/)).first(),
        },
        {
          chu: 'Bấm vào dòng ghi danh để mở bản ghi',
          loc: (p) => p.locator('main tbody tr').nth(1),
          lam: async (p) => {
            await p.locator('main tbody tr').nth(1).click();
            await cho(p);
          },
        },
        {
          chu: 'Xem «Dòng xếp lớp»: lớp, «Ngày vào», «Ngày rời»',
          loc: (p) => p.getByText('Dòng xếp lớp').first(),
        },
        {
          chu: 'Bấm «Sổ giờ» để xem từng dòng cộng, trừ giờ',
          loc: (p) => p.getByText('Sổ giờ', { exact: true }).first(),
          lam: async (p) => {
            await p.getByText('Sổ giờ', { exact: true }).first().click();
            await cho(p);
          },
        },
      ],
      chung,
      5,
    ),
  // DT2 «Xếp lớp cho ghi danh đang chờ» (CSKH): 7 bước của bài; bước 6 XẾP THẬT một em mẫu trên staging.
  dt2: (b) =>
    chayBai(
      b,
      'dt2',
      vao('/crm/ghi-danh'),
      [
        {
          chu: 'Vào menu Đào tạo → Hàng chờ xếp lớp',
          loc: (p) => p.getByRole('link', { name: 'Hàng chờ xếp lớp', exact: true }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/cho-xep-lop`);
            await cho(p);
          },
        },
        {
          chu: 'Tìm em cần xếp, bấm «Xếp lớp» ở cuối dòng',
          loc: (p) => p.getByRole('button', { name: 'Xếp lớp', exact: true }).first(),
          lam: async (p) => {
            globalThis.hsXep = (
              await p.locator('main tbody tr').first().locator('td').nth(0).innerText()
            ).trim();
            await p.getByRole('button', { name: 'Xếp lớp', exact: true }).first().click();
            await p.getByText('Xếp lớp cho ghi danh').first().waitFor({ timeout: 15000 });
          },
        },
        {
          chu: 'Ở «Cách xếp lớp» chọn «Theo nhóm lớp» hoặc «Một lớp lẻ» (không có nhóm phù hợp thì chỉ có «Một lớp lẻ»)',
          loc: (p) => p.getByText('Một lớp lẻ', { exact: true }).first(),
        },
        {
          chu: 'Chọn nhóm hoặc lớp; lớp hiện mờ là không xếp được, đọc lý do bên dưới',
          loc: (p) => p.getByText('CS5-2627-TOAN-K09-CB-A-001').first(),
          lam: async (p) => {
            await p.getByText('CS5-2627-TOAN-K09-CB-A-001').first().click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Chọn «Ngày vào lớp» cho từng ghi danh',
          loc: (p) => p.getByLabel('Ngày vào lớp').first(),
          lam: async (p) => {
            const o = p.getByLabel('Ngày vào lớp').first();
            if ((await o.evaluate((e) => e.tagName)) === 'SELECT' && (await o.inputValue()) === '')
              await o.selectOption({ index: 1 });
            await p.waitForTimeout(800);
          },
        },
        {
          chu: 'Bấm «Xếp lớp» ở cuối hộp: hiện «Đã xếp lớp.»',
          loc: (p) => p.getByRole('dialog').getByRole('button', { name: 'Xếp lớp', exact: true }),
          lam: async (p) => {
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Xếp lớp', exact: true })
              .click();
            await p.waitForTimeout(2500);
            await p.goto(`${APP}/crm/ghi-danh`);
            await cho(p);
            await p.locator('main tbody tr', { hasText: globalThis.hsXep }).first().click();
            await cho(p);
          },
        },
        {
          chu: 'Mở bản ghi ghi danh để kiểm: «Dòng xếp lớp» có lớp và «Ngày vào»',
          loc: (p) => p.getByText('Dòng xếp lớp').first(),
        },
      ],
      chung,
      7,
    ),
  // DT12 «Xem buổi học hôm nay và theo dõi buổi chưa hoàn tất» (CSKH): 7 bước; staging hết buổi Nháp có học sinh (buổi 26/11 đã chốt ở lần quay thử) nên bước 4 quay trên buổi đã chốt, chỉ chỉ vào thanh trạng thái; chờ dữ liệu Nháp để quay lại bước này.
  dt12: (b) =>
    chayBai(
      b,
      'dt12',
      vao('/crm/ghi-danh'),
      [
        {
          chu: 'Vào menu Đào tạo → Buổi học: mặc định chỉ hiện buổi hôm nay',
          loc: (p) => p.getByRole('link', { name: 'Buổi học', exact: true }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/buoi-hoc`);
            await cho(p);
          },
        },
        {
          chu: 'Lọc theo ngày, lớp hoặc tình trạng nếu cần; tìm theo mã lớp',
          loc: (p) => p.getByText('Xoá tất cả').first(),
          lam: async (p) => {
            await p.getByText('Xoá tất cả').first().click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Bấm một dòng để mở bản ghi buổi',
          loc: (p) =>
            p.locator('main tbody tr', { hasText: /17\/11\/2026[\s\S]*K06-CB-S-003/ }).first(),
          lam: async (p) => {
            await p
              .locator('main tbody tr', { hasText: /17\/11\/2026[\s\S]*K06-CB-S-003/ })
              .first()
              .click();
            await cho(p);
          },
        },
        {
          chu: 'Buổi còn Nháp: bấm «Chốt danh sách», đọc câu hỏi, bấm «Chốt danh sách» lần nữa',
          loc: (p) => p.getByText('Đã chốt', { exact: true }).first(),
        },
        {
          chu: 'Xem «Danh sách và điểm danh»: cột «Trung tâm» và cột «giáo viên (chính thức)»',
          loc: (p) => p.getByText('Danh sách và điểm danh').first(),
        },
        {
          chu: 'Vào Đào tạo → Buổi chưa hoàn tất để theo dõi buổi giáo viên chưa hoàn tất',
          loc: (p) => p.getByRole('link', { name: 'Buổi chưa hoàn tất', exact: true }),
          lam: async (p) => {
            await p.getByRole('link', { name: 'Buổi chưa hoàn tất', exact: true }).click();
            await cho(p);
          },
        },
        {
          chu: 'Bấm «Mở buổi» ở dòng cần xử lý; «Nhắc GV» đang mờ, nhắc bằng điện thoại hoặc tin nhắn',
          loc: (p) => p.locator('main tbody tr').first(),
        },
      ],
      chung,
      7,
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
