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
        lam: (p) => p.getByLabel('Email', { exact: true }).fill('ten@hoamatoan.vn'),
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
  // Video KHỚP TỪNG BƯỚC bài TS1 (tạo lead nhanh, LUỒNG CHÍNH: số mới, không trùng): 5 bước, chữ «Bước n/5» cùng chữ với bài docs/huong-dan/tu-van/TS1-tao-lead-nhanh.md.
  // Số điện thoại ngẫu nhiên dải 0998 (chưa có); LƯU lead «[MẪU]» trên staging (Admin huỷ nếu cần). Chạy với HD_TAI_KHOAN=sale.cs5@…
  ts1: (b) =>
    chayBai(
      b,
      'ts1',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào Lead, bấm «Tạo»',
          loc: nutTen('Tạo'),
          lam: async (p) => {
            await nutTen('Tạo')(p).click();
            await p.waitForURL(/\/crm\/lead\/moi/);
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Điền «Họ tên» và «Số điện thoại» (số mới), bấm ra ngoài ô',
          loc: (p) => p.getByLabel('Họ tên', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Họ tên', { exact: true }).fill('[MẪU] Phụ huynh tập TS1');
            await p
              .getByLabel('Số điện thoại', { exact: true })
              .fill(`0998${Math.floor(100000 + Math.random() * 900000)}`);
            await p.getByLabel('Họ tên', { exact: true }).click();
            await p.waitForTimeout(2000);
          },
        },
        {
          chu: 'Điền thêm nếu biết: «Tên học sinh», «Năm sinh», «Trường học»',
          loc: (p) => p.getByLabel('Tên học sinh', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Tên học sinh', { exact: true }).fill('[MẪU] Học sinh tập TS1');
            await p.getByLabel('Năm sinh', { exact: true }).fill('2014');
            await p.getByLabel('Trường học', { exact: true }).fill('[MẪU] Trường tập');
            await p.getByLabel('Source', { exact: true }).scrollIntoViewIfNeeded();
            await p.waitForTimeout(600);
          },
        },
        {
          chu: 'Khối «Nguồn và phụ trách»: chọn «Cơ sở», «Nhân sự phụ trách», «Source»',
          loc: (p) => p.getByLabel('Source', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Source', { exact: true }).click();
            await p.getByRole('option', { name: 'Walk-in', exact: true }).click();
            await p.waitForTimeout(800);
            await p.evaluate(() => {
              document.querySelectorAll('*').forEach((e) => {
                if (e.scrollTop > 0) e.scrollTop = 0;
              });
            });
            await p.waitForTimeout(400);
          },
        },
        {
          chu: 'Bấm «Lưu»: hiện «Đã tạo lead LD-…», lead ở «C1 Data mới»',
          loc: nutTen('Lưu'),
          lam: async (p) => {
            await nutTen('Lưu')(p).click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      { width: 1280, height: 720 },
      5,
    ),
  // Video KHỚP bài TS1b (NGOẠI LỆ: cảnh báo trùng số điện thoại): 4 bước (bắt đầu từ trang tạo lead), KHÔNG lưu lead (bước 4 đóng hộp bằng dấu X). Số mẫu 0999 000 241 của bộ «[MẪU]».
  ts1b: (b) =>
    chayBai(
      b,
      'ts1b',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead/moi`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Nhập «Số điện thoại» đã có, bấm ra ngoài ô: hiện khung vàng',
          loc: (p) => p.getByLabel('Số điện thoại', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Họ tên', { exact: true }).fill('[MẪU] Phụ huynh tập TS1b');
            await p.getByLabel('Số điện thoại', { exact: true }).fill('0999000241');
            await p.getByLabel('Họ tên', { exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Bấm «Mở bản ghi trùng» để xem hồ sơ cũ; cùng khách thì không tạo mới',
          loc: (p) => p.getByText('Mở bản ghi trùng').first(),
        },
        {
          chu: 'Khách khác: điền các ô còn lại, chọn «Source» rồi bấm «Lưu»',
          loc: (p) => p.getByLabel('Source', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Source', { exact: true }).click();
            await p.getByRole('option', { name: 'Walk-in', exact: true }).click();
            await p.waitForTimeout(800);
            await p.evaluate(() => {
              document.querySelectorAll('*').forEach((e) => {
                if (e.scrollTop > 0) e.scrollTop = 0;
              });
            });
            await p.waitForTimeout(400);
            await nutTen('Lưu')(p).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Hộp cảnh báo: «Gắn vào hồ sơ có sẵn» nếu cùng khách, «Vẫn tạo mới» nếu khách khác; chưa chắc thì đóng bằng dấu X',
          loc: (p) => p.getByRole('button', { name: 'Vẫn tạo mới', exact: true }),
          lam: (p) =>
            p
              .locator('button[aria-label*="óng"], button[aria-label="Close"]')
              .first()
              .click()
              .catch(() => {}),
        },
      ],
      { width: 1280, height: 720 },
      4,
    ),
  // Video KHỚP TỪNG BƯỚC bài TS3 (chăm sóc lead, LUỒNG CHÍNH): 7 bước, mỗi bước một bước của bài docs/huong-dan/tu-van/TS3-cham-soc-lead.md (sửa lead mẫu «[MẪU]» của sale.cs5 trên staging).
  ts3: (b) =>
    chayBai(
      b,
      'ts3',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào Lead, tìm lead (ô tìm theo tên hoặc số điện thoại), mở bản ghi',
          loc: (p) => p.locator('main input').first(),
          lam: async (p) => {
            await p.locator('main input').first().fill('[MẪU]');
            await p.waitForTimeout(2500);
            await p.locator('main tbody tr').first().click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Gọi khách, rồi bấm giai đoạn đúng kết quả trên thanh giai đoạn',
          loc: (p) => p.getByText('Chưa liên hệ được', { exact: true }).first(),
          lam: async (p) => {
            await p.getByText('Chưa liên hệ được', { exact: true }).first().click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Chọn «Sub-stage», bấm «Chuyển giai đoạn»',
          loc: (p) => p.getByRole('dialog'),
          lam: async (p) => {
            const d = p.getByRole('dialog');
            await d.getByRole('combobox').first().click();
            await p.getByRole('option').first().click();
            await p.waitForTimeout(600);
            await d.getByRole('button', { name: 'Chuyển giai đoạn', exact: true }).click();
            await p.waitForTimeout(2000);
          },
        },
        {
          chu: 'Chỉ đổi nhóm con trong cùng giai đoạn: chọn lại ở ô «Sub-stage» ngay trên trang lead',
          loc: (p) => p.getByLabel('Sub-stage', { exact: true }),
          lam: async (p) => {
            await p.getByLabel('Sub-stage', { exact: true }).click();
            await p.getByRole('option').last().click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Ghi ý chính vào khung ghi chú bên phải rồi bấm «Gửi ghi chú»',
          loc: (p) => p.getByPlaceholder(/Viết ghi chú/),
          lam: async (p) => {
            await p
              .getByPlaceholder(/Viết ghi chú/)
              .fill('[MẪU] Gọi lần 1, khách hẹn gọi lại chiều mai.');
            await p.getByRole('button', { name: 'Gửi ghi chú', exact: true }).click();
            await p.waitForTimeout(2000);
          },
        },
        {
          chu: 'Khi khách có nhu cầu thật: chuyển lên C4 và chọn C4C «Đủ điều kiện tạo cơ hội»',
          loc: (p) => p.getByText('Khách hàng tiềm năng', { exact: true }).first(),
          lam: async (p) => {
            await p.getByText('Khách hàng tiềm năng', { exact: true }).first().click();
            await p.waitForTimeout(1500);
            const d = p.getByRole('dialog');
            await d.getByRole('combobox').first().click();
            await p.getByRole('option', { name: /C4C/ }).click();
            await p.waitForTimeout(600);
            await d.getByRole('button', { name: 'Chuyển giai đoạn', exact: true }).click();
            await p.waitForTimeout(2000);
          },
        },
        {
          chu: 'Đổi người chăm: menu «Hành động» → «Giao người phụ trách»',
          loc: (p) => p.getByRole('button', { name: 'Hành động', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Hành động', exact: true }).click();
            await p
              .getByRole('menuitem', { name: /Giao người phụ trách/ })
              .or(p.getByRole('button', { name: /Giao người phụ trách/ }))
              .first()
              .click();
            await p.waitForTimeout(1500);
            await p
              .getByRole('button', { name: /Huỷ|Đóng/ })
              .first()
              .click()
              .catch(() => {});
          },
        },
      ],
      { width: 1280, height: 720 },
      7,
    ),
  // Video KHỚP TỪNG BƯỚC bài TS2 (nhập lead từ file CSV, LUỒNG CHÍNH): 6 bước; KHÔNG bấm «Nhập» ở bước 6 (tránh tạo lead thừa), chỉ khoanh nút rồi đóng hộp.
  ts2: (b) => {
    const csv = join(OUT, 'hd-lead-ts2.csv');
    mkdirSync(OUT, { recursive: true });
    writeFileSync(
      csv,
      'Họ tên phụ huynh,SĐT,Tên học sinh,Năm sinh\n[MẪU] Phụ huynh A,0999000901,[MẪU] Học sinh A,2012\n[MẪU] Phụ huynh B,0999000902,[MẪU] Học sinh B,2013\n[MẪU] Phụ huynh C,abc,[MẪU] Học sinh C,2014\n',
    );
    const tiep = async (p) => {
      await p.getByRole('dialog').getByRole('button', { name: 'Tiếp', exact: true }).click();
      await p.waitForTimeout(3500);
    };
    return chayBai(
      b,
      'ts2',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào Lead, bấm «Nhập»',
          loc: (p) => p.getByRole('button', { name: /^Nhập/ }).first(),
          lam: async (p) => {
            await p.getByRole('button', { name: /^Nhập/ }).first().click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Kéo file CSV vào khung, hoặc bấm «chọn file»',
          loc: (p) => p.getByRole('dialog'),
          lam: async (p) => {
            await p.locator('input[type=file]').setInputFiles(csv);
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Sang bước «Ghép cột»: kiểm từng dòng «Cột trong file» ↔ «Trường trong hệ thống»',
          loc: (p) => p.getByRole('dialog'),
          lam: tiep,
        },
        {
          chu: 'Chọn giá trị mặc định cho cả lô nếu file không có cột đó: «Source», «Chiến dịch», «Người phụ trách»',
          loc: (p) => p.getByText('Giá trị mặc định').first(),
          lam: async (p) => {
            await p.getByRole('dialog').getByText('Chưa chọn').first().click();
            await p.getByRole('option', { name: 'Walk-in', exact: true }).click();
            await p.waitForTimeout(800);
          },
        },
        {
          chu: 'Bấm tiếp sang «Xem trước»: đếm dòng hợp lệ, trùng SĐT, lỗi',
          loc: (p) =>
            p
              .getByRole('dialog')
              .getByRole('button', { name: /Tiếp|Xem trước/ })
              .last(),
          lam: tiep,
        },
        {
          chu: 'Đọc các dòng «Lỗi» và «Trùng SĐT»; nếu ổn thì bấm «Nhập»',
          loc: (p) => p.getByText('dòng hợp lệ').first(),
        },
      ],
      { width: 1280, height: 720 },
      6,
    );
  },
  // Video KHỚP TỪNG BƯỚC bài TS9 (lịch hẹn): 7 bước đúng bài; bước 6 (Huỷ) chỉ mở hộp rồi đóng, không huỷ thật lịch của người khác.
  ts9: (b) => {
    const ngay = (n) => {
      const d = new Date(Date.now() + n * 86400000 + 7 * 3600000);
      const f = (x) => String(x).padStart(2, '0');
      return `${f(d.getUTCDate())}/${f(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`;
    };
    const hang = (p, chuoi) => p.locator('tr', { hasText: chuoi }).first();
    return chayBai(
      b,
      'ts9',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
        await p.locator('main input').first().fill('[MẪU] Phụ huynh tập TS1');
        await p.waitForTimeout(2500);
        await p.locator('main tbody tr').first().click();
        await p.waitForTimeout(2500);
      },
      [
        {
          chu: 'Tạo lịch hẹn: từ bản ghi lead bấm «Lên lịch hẹn»',
          loc: (p) => p.getByText(/Lên lịch hẹn/).first(),
          lam: async (p) => {
            await p
              .getByText(/Lên lịch hẹn/)
              .first()
              .click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Chọn loại hoạt động, ngày, giờ, ghi chú rồi bấm «Tạo lịch hẹn»',
          loc: (p) => p.getByRole('dialog'),
          lam: async (p) => {
            const d = p.getByRole('dialog');
            await d.getByRole('button', { name: 'Ngày mai', exact: true }).click();
            await d.getByRole('button', { name: '09:00', exact: true }).click();
            await d.locator('textarea').first().fill('[MẪU] Gọi lại hỏi lịch học');
            await p.waitForTimeout(800);
            await d.getByRole('button', { name: 'Tạo lịch hẹn', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Xem việc trong ngày: vào «Lịch hẹn», xem các nhóm «Hôm nay», «Sắp tới»',
          loc: (p) => p.getByText('Sắp tới').first(),
          lam: async (p) => {
            await p.goto(`${APP}/crm/lich-hen`);
            await p.waitForLoadState('networkidle');
            await p.waitForTimeout(2000);
          },
        },
        {
          chu: 'Dời lịch: ở lịch «Chưa làm» bấm «Dời», chọn ngày mới, giờ mới, bấm «Dời lịch»',
          loc: (p) => hang(p, `${ngay(1)} 09:00`).getByRole('button', { name: 'Dời', exact: true }),
          lam: async (p) => {
            await hang(p, `${ngay(1)} 09:00`)
              .getByRole('button', { name: 'Dời', exact: true })
              .click();
            await p.waitForTimeout(1200);
            const d = p.getByRole('dialog');
            await d.getByRole('button', { name: 'Ngày kia', exact: true }).click();
            await d.getByRole('button', { name: '10:00', exact: true }).click();
            await p.waitForTimeout(800);
            await d.getByRole('button', { name: 'Dời lịch', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Hoàn thành lịch: bấm «Hoàn thành», chọn «Kết quả», bấm «Hoàn thành»',
          loc: (p) =>
            hang(p, `${ngay(2)} 10:00`).getByRole('button', { name: 'Hoàn thành', exact: true }),
          lam: async (p) => {
            await hang(p, `${ngay(2)} 10:00`)
              .getByRole('button', { name: 'Hoàn thành', exact: true })
              .click();
            await p.waitForTimeout(1200);
            const d = p.getByRole('dialog');
            await d.getByRole('combobox').first().click();
            await p.getByRole('option').first().click();
            await p.waitForTimeout(800);
            await d.getByRole('button', { name: 'Hoàn thành', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Huỷ lịch: bấm «Huỷ», chọn lý do, bấm «Huỷ lịch hẹn»',
          loc: (p) =>
            p
              .locator('tr', { has: p.getByRole('button', { name: 'Dời', exact: true }) })
              .first()
              .getByRole('button', { name: 'Huỷ', exact: true }),
          lam: async (p) => {
            await p
              .locator('tr', { has: p.getByRole('button', { name: 'Dời', exact: true }) })
              .first()
              .getByRole('button', { name: 'Huỷ', exact: true })
              .click();
            await p.waitForTimeout(1500);
            await p.keyboard.press('Escape');
            await p.waitForTimeout(800);
          },
        },
        {
          chu: 'Mở lại: ở lịch Hoàn thành hoặc Huỷ bấm «Mở lại», xác nhận ở hộp «Mở lại lịch hẹn?»',
          loc: (p) =>
            hang(p, `${ngay(2)} 10:00`).getByRole('button', { name: 'Mở lại', exact: true }),
          lam: async (p) => {
            await hang(p, `${ngay(2)} 10:00`)
              .getByRole('button', { name: 'Mở lại', exact: true })
              .click();
            await p.waitForTimeout(1200);
            await p
              .locator('[role=dialog],[role=alertdialog]')
              .getByRole('button', { name: /Mở lại/ })
              .last()
              .click();
            await p.waitForTimeout(2000);
          },
        },
      ],
      { width: 1280, height: 720 },
      7,
    );
  },
  // Video KHỚP TỪNG BƯỚC bài TS5 (tạo cơ hội từ lead, LUỒNG CHÍNH): 5 bước. Dùng lead «[MẪU] Phụ huynh tập TS1» ở C4C chưa có cơ hội (TẠO THẬT một cơ hội L1 trên staging).
  ts5: (b) =>
    chayBai(
      b,
      'ts5',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Mở Lead, tìm và mở lead cần tạo cơ hội',
          loc: (p) => p.locator('main input').first(),
          lam: async (p) => {
            await p.locator('main input').first().fill('[MẪU] Phụ huynh tập TS1');
            await p.waitForTimeout(2500);
            await p.locator('main tbody tr').first().click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Bấm «Tạo cơ hội» (nút ở đầu bản ghi)',
          loc: nutTen('Tạo cơ hội'),
          lam: async (p) => {
            await nutTen('Tạo cơ hội')(p).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Tích chọn các em sẽ đi cùng cơ hội này',
          loc: (p) => p.getByRole('dialog').getByRole('checkbox').first(),
          lam: async (p) => {
            const c = p.getByRole('dialog').getByRole('checkbox').first();
            if (!(await c.isChecked())) await c.check();
            await p.waitForTimeout(600);
          },
        },
        {
          chu: 'Bấm «Tạo cơ hội» trong hộp: trang cơ hội mới ở L1',
          loc: (p) =>
            p.getByRole('dialog').getByRole('button', { name: 'Tạo cơ hội', exact: true }),
          lam: async (p) => {
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Tạo cơ hội', exact: true })
              .click();
            await p.waitForTimeout(3000);
          },
        },
        {
          chu: 'Quay lại lead: nhóm con đã là C4D «Tạo cơ hội thành công»',
          loc: (p) => p.locator('main').first(),
          lam: async (p) => {
            await p.goBack();
            await p.waitForTimeout(2500);
          },
        },
      ],
      { width: 1280, height: 720 },
      5,
    ),
  // Video bài TS5b (NGOẠI LỆ: lead đã có cơ hội): 4 bước, KHÔNG tạo gì thêm (đóng hộp bằng Esc).
  ts5b: (b) =>
    chayBai(
      b,
      'ts5b',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/lead`);
        await p.waitForLoadState('networkidle');
        await p.locator('main input').first().fill('[MẪU] Phụ huynh tập TS1');
        await p.waitForTimeout(2500);
        await p.locator('main tbody tr').first().click();
        await p.waitForTimeout(2500);
      },
      [
        {
          chu: 'Ở lead đã có cơ hội, bấm «Tạo cơ hội»',
          loc: nutTen('Tạo cơ hội'),
          lam: async (p) => {
            await nutTen('Tạo cơ hội')(p).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Tích chọn các em: đầu hộp hiện khung vàng «Lead này đã có … cơ hội đang dùng»',
          loc: (p) => p.getByText(/đã có .* cơ hội đang dùng/).first(),
          lam: async (p) => {
            const c = p.getByRole('dialog').getByRole('checkbox').first();
            if (!(await c.isChecked())) await c.check();
            await p.waitForTimeout(600);
          },
        },
        {
          chu: 'Chọn một trong ba: «Mở cơ hội cũ», «Thêm em vào cơ hội cũ» hoặc vẫn tạo thêm',
          loc: (p) => p.getByRole('button', { name: 'Mở cơ hội cũ', exact: true }),
        },
        {
          chu: 'Vẫn tạo thêm: tích ô xác nhận rồi bấm «Vẫn tạo thêm»',
          loc: (p) => p.getByRole('dialog').getByRole('checkbox').last(),
          lam: async (p) => {
            await p.getByRole('dialog').getByRole('checkbox').last().check();
            await p.waitForTimeout(1500);
            await p.keyboard.press('Escape');
          },
        },
      ],
      { width: 1280, height: 720 },
      4,
    ),
  // Video KHỚP TỪNG BƯỚC bài TS6 (đi cơ hội, LUỒNG CHÍNH): 4 bước. Bước 2 chuyển THẬT cơ hội «[MẪU]» của sale.cs5 lên L2; bước 3 chỉ mở hộp L8 rồi đóng (không hoàn tác được nên không xác nhận).
  ts6: (b) => {
    const moCoHoi = async (p, chuoi) => {
      await p.locator('main input').first().fill(chuoi);
      await p.waitForTimeout(2500);
      await p.locator('main tbody tr').first().click();
      await p.waitForTimeout(2500);
    };
    return chayBai(
      b,
      'ts6',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/co-hoi`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Mở Cơ hội, mở cơ hội cần chăm',
          loc: (p) => p.locator('main input').first(),
          lam: (p) => moCoHoi(p, '[MẪU] Phụ huynh tập TS1'),
        },
        {
          chu: 'Bấm giai đoạn phía trước trên thanh, chọn nhóm con nếu hộp hỏi, bấm «Chuyển giai đoạn»',
          loc: (p) =>
            p
              .locator('main')
              .getByText(/^L[2-4]$/)
              .first(),
          lam: async (p) => {
            // chạy lại nhiều lần: bấm giai đoạn kế tiếp còn bấm được (L2, L3 rồi L4)
            for (const n of ['L2', 'L3', 'L4']) {
              const ok = await p
                .locator('main')
                .getByText(n, { exact: true })
                .first()
                .click({ timeout: 2500 })
                .then(() => true)
                .catch(() => false);
              if (ok) break;
            }
            await p.waitForTimeout(1500);
            const d = p.getByRole('dialog');
            if (await d.getByRole('combobox').count()) {
              await d.getByRole('combobox').first().click();
              await p.getByRole('option').first().click();
              await p.waitForTimeout(500);
            }
            await d.getByRole('button', { name: 'Chuyển giai đoạn', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Sang L8 «Đăng ký học» chỉ sau khi phụ huynh đã thanh toán: bấm L8, chọn nhóm con, tích xác nhận, bấm «Chuyển L8»',
          loc: (p) => p.locator('main').getByText(/^L8$/).first(),
          lam: async (p) => {
            await p.locator('main').getByText(/^L8$/).first().click();
            await p.waitForTimeout(2500);
            await p.keyboard.press('Escape');
            await p.waitForTimeout(800);

            await p.goto(`${APP}/crm/co-hoi`);
            await p.waitForLoadState('networkidle');
            for (
              let i = 0;
              i < 6 && !(await p.locator('main tbody tr', { hasText: 'L8' }).count());
              i++
            ) {
              await p.getByRole('button', { name: 'Trang sau' }).click();
              await p.waitForTimeout(2000);
            }
            await p.locator('main tbody tr', { hasText: 'L8' }).first().click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Lập đơn từ cơ hội L8: đơn chỉ lập được từ cơ hội ở L8',
          loc: (p) => p.getByRole('button', { name: /Tạo đơn hàng/ }),
        },
      ],
      { width: 1280, height: 720 },
      4,
    );
  },
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
