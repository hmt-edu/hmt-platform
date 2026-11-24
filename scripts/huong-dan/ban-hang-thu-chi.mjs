// @ts-nocheck
// Kịch bản CHỤP ẢNH có khung đánh dấu + QUAY VIDEO hướng dẫn (T2-S). Chỉ chạy tay, KHÔNG nằm trong CI.
// Chạy: STAGING_URL=https://… STAGING_PASSWORD=… node scripts/huong-dan/chay.mjs [dang-nhap|danh-sach|ban-ghi|tat-ca]
// Chỉ dùng tài khoản GIẢ và dữ liệu giả của bản thử nghiệm; không bao giờ trỏ vào bản chạy thật. Mật khẩu chỉ qua biến môi trường.
// Ra: HD_OUT (mặc định ~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/video-ban-hang-thu-chi/<bài>/): buoc-<n>.png, <bài>.webm, buoc.json. Nén mp4: xem README.md cùng thư mục.
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
  process.env.HD_OUT ??
  join(homedir(), 'VanPhongAI', 'hmt-ca', 'ANH-HUONG-DAN', 'video-ban-hang-thu-chi');
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
    if (loc)
      await loc.first().evaluate((e) => e.scrollIntoView({ block: 'center', inline: 'center' }));
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
const dangNhap = async (page, taiKhoan = TAI_KHOAN) => {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SB_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email: taiKhoan, password: PW }),
  });
  if (!r.ok) throw new Error(`Đăng nhập API lỗi ${r.status}`);
  const khoa = `sb-${new URL(SB_URL).hostname.split('.')[0]}-auth-token`;
  const phien = JSON.stringify(await r.json());
  await page.addInitScript(([k, v]) => localStorage.setItem(k, v), [khoa, phien]);
  await page.goto(`${APP}/crm`);
  await page.waitForURL(/\/crm/, { timeout: 30000 });
  await page.waitForLoadState('networkidle');
};

// Video KHỚP TỪNG BƯỚC các bài Bán hàng, Thu chi (docs/huong-dan/ban-hang-thu-chi/). Chữ phụ đề = chữ bước của bài.
// Chạy: HD_TAI_KHOAN=sale.cs5@thu.hoamatoan.invalid node scripts/huong-dan/ban-hang-thu-chi.mjs bh1
// Dữ liệu ghi trên staging đều thuộc bộ «[MẪU]»; không chạy với bản chạy thật.
const CO_HOI = process.env.HD_CO_HOI ?? '11fce0a4-513c-4304-a5db-e6c27e2707dc'; // cơ hội mẫu L8 của CS5 (đổi bằng HD_CO_HOI)
/** Chuẩn bị (ngoài phần quay chính): tạo một báo giá «Đã gửi» mới ở cơ hội mẫu, trả địa chỉ báo giá. */
async function taoBaoGiaDaGui(p) {
  await p.goto(`${APP}/crm/bao-gia/tao?co-hoi=${CO_HOI}`);
  await p.waitForLoadState('networkidle');
  await p.getByText('Chọn gói…').first().click();
  await p.getByText('Lớp chung Toán 9').first().click();
  await p.getByLabel('Số lượng dòng 1', { exact: true }).fill('10');
  await nutTen('Lưu')(p).click();
  await p.waitForURL(/\/crm\/bao-gia\/(?!tao)/, { timeout: 30000 });
  await nutTen('Gửi')(p).click();
  await p.getByText('Đã gửi báo giá.').first().waitFor({ timeout: 15000 });
  await p.waitForLoadState('networkidle');
}

const EMAIL = (ten) => `${ten}@thu.hoamatoan.invalid`;

/** Chuẩn bị NGOÀI video: mở một phiên riêng (không quay) với tài khoản `ten`, chạy `fn(page)`, đóng. */
async function chuanBi(browser, ten, fn) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();
  try {
    await dangNhap(page, EMAIL(ten));
    return await fn(page);
  } finally {
    await context.close();
  }
}

/** Sale tạo đơn từ báo giá mới, trình duyệt (chưa chọn lớp). Trả địa chỉ đơn (đang «Đã trình»). */
const taoDonDaTrinh = (browser) =>
  chuanBi(browser, 'sale.cs5', async (p) => {
    await taoBaoGiaDaGui(p);
    await nutTen('Chuyển thành đơn')(p).click();
    await p.waitForURL(/\/crm\/don-hang\/tao/);
    await p.getByText('Chọn điều khoản').first().click();
    await p.getByRole('option', { name: 'Cọc rồi đóng phần còn lại' }).click();
    await nutTen('Lưu')(p).click();
    await p.waitForURL(/\/crm\/don-hang\/(?!tao)/, { timeout: 30000 });
    await p.waitForLoadState('networkidle');
    await nutTen('Trình duyệt')(p).click();
    await p.getByText('Đã trình đơn.').first().waitFor({ timeout: 15000 });
    const ma = (await p.locator('main').innerText()).match(/DH-[A-Z0-9]+-\d+-\d+/)?.[0] ?? '';
    return { url: p.url(), ma };
  });

/** Trưởng cơ sở duyệt đơn `url` (ngoài video). */
const duyetDon = (browser, url) =>
  chuanBi(browser, 'truongcs.cs5', async (p) => {
    await p.goto(url);
    await p.waitForLoadState('networkidle');
    await nutTen('Duyệt')(p).click();
    await p.getByRole('dialog').getByRole('button', { name: 'Duyệt', exact: true }).click();
    await p.getByText('Đã duyệt đơn hàng.').first().waitFor({ timeout: 15000 });
  });

/** Sale tạo một đơn đã trình rồi Trưởng cơ sở duyệt: trả địa chỉ đơn «Đã duyệt». */
const taoDonDaDuyet = async (browser) => {
  const { url } = await taoDonDaTrinh(browser);
  await duyetDon(browser, url);
  return url;
};

/** Sale tạo phiếu thu nháp cho đơn `url` và trình quản lý: trả địa chỉ phiếu «Đã gửi». */
const taoPhieuDaGui = (browser, url) =>
  chuanBi(browser, 'sale.cs5', async (p) => {
    await p.goto(url);
    await p.waitForLoadState('networkidle');
    await nutTen('Tạo phiếu thu')(p).click();
    await p.getByRole('dialog').getByText('Chọn hình thức').click();
    await p.getByRole('option', { name: 'Tiền mặt', exact: true }).click();
    await p
      .getByRole('dialog')
      .getByRole('button', { name: 'Tạo phiếu nháp', exact: true })
      .click();
    await p
      .getByText(/Đã tạo phiếu thu nháp/)
      .first()
      .waitFor({ timeout: 15000 });
    await p.waitForLoadState('networkidle');
    await nutTen('Trình quản lý')(p).click();
    await p.getByText('Đã trình, chờ quản lý duyệt.').first().waitFor({ timeout: 15000 });
    const ma = (await p.locator('main').innerText()).match(/PT-[A-Z0-9]+-\d+-\d+/)?.[0] ?? '';
    return { url: p.url(), ma };
  });

/** Trưởng cơ sở duyệt phiếu `url` (tích ô xác nhận): phiếu sang «Chờ kế toán». */
const truongDuyetPhieu = (browser, url) =>
  chuanBi(browser, 'truongcs.cs5', async (p) => {
    await p.goto(url);
    await p.waitForLoadState('networkidle');
    await nutTen('Duyệt (chuyển Kế toán)')(p).click();
    await p.getByRole('dialog').getByRole('checkbox').check();
    await p
      .getByRole('dialog')
      .getByRole('button', { name: 'Xác nhận duyệt', exact: true })
      .click();
    await p.getByText('Đã duyệt, chuyển Kế toán.').first().waitFor({ timeout: 15000 });
  });

const BAI = {
  // BH1: lập báo giá, gửi, in (luồng chính, 5 bước). Tạo thêm một báo giá mới ở cơ hội mẫu.
  bh1: (b) =>
    chayBai(
      b,
      'bh1',
      async (p) => {
        await dangNhap(p);
        await p.goto(`${APP}/crm/co-hoi/${CO_HOI}`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Ở bản ghi cơ hội bấm «Tạo báo giá»',
          loc: nutTen('Tạo báo giá'),
          lam: async (p) => {
            await nutTen('Tạo báo giá')(p).click();
            await p.waitForURL(/\/crm\/bao-gia\/tao/);
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Bấm «Chọn gói…», chọn gói, chọn em học, nhập số lượng giờ',
          loc: (p) => p.getByText('Chọn gói…').first(),
          lam: async (p) => {
            await p.getByText('Chọn gói…').first().click();
            await p.getByText('Lớp chung Toán 9').first().click();
            await p.getByLabel('Số lượng dòng 1', { exact: true }).fill('10');
            await p.waitForTimeout(1200);
          },
        },
        {
          chu: 'Thêm chiết khấu theo chính sách nếu có (chọn trong danh sách, không gõ số)',
          loc: (p) => p.getByRole('button', { name: 'Thêm chiết khấu dòng 1' }),
        },
        {
          chu: 'Bấm «Lưu», rồi bấm «Gửi»',
          loc: nutTen('Lưu'),
          lam: async (p) => {
            await nutTen('Lưu')(p).click();
            await p.waitForURL(/\/crm\/bao-gia\/(?!tao)/, { timeout: 30000 });
            await nutTen('Gửi')(p).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Mở menu «Hành động» và bấm «In»',
          loc: nutTen('Hành động'),
          lam: async (p) => {
            await nutTen('Hành động')(p).click();
            await p.waitForTimeout(1200);
            await p
              .getByRole('menuitem', { name: 'In', exact: true })
              .or(p.getByText('In', { exact: true }).first())
              .first()
              .click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      { width: 1280, height: 720 },
      5,
    ),
  // BH3: lập đơn hàng từ báo giá, chọn lớp và ngày vào lớp, trình duyệt (4 bước). Tự tạo báo giá «Đã gửi» trước khi quay.
  bh3: (b) =>
    chayBai(
      b,
      'bh3',
      async (p) => {
        await dangNhap(p);
        await taoBaoGiaDaGui(p);
      },
      [
        {
          chu: 'Ở báo giá «Đã gửi» bấm «Chuyển thành đơn»',
          loc: nutTen('Chuyển thành đơn'),
          lam: async (p) => {
            await nutTen('Chuyển thành đơn')(p).click();
            await p.waitForURL(/\/crm\/don-hang\/tao/);
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Chọn «Điều khoản thanh toán» (bắt buộc), rồi bấm «Lưu»',
          loc: (p) => p.getByText('Chọn điều khoản').first(),
          lam: async (p) => {
            await p.getByText('Chọn điều khoản').first().click();
            await p.getByRole('option', { name: 'Cọc rồi đóng phần còn lại' }).click();
            await nutTen('Lưu')(p).click();
            await p.waitForURL(/\/crm\/don-hang\/(?!tao)/, { timeout: 30000 });
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Bấm «Sửa đơn», «Chọn lớp», chọn lớp và «Ngày vào lớp», bấm «Chọn», rồi «Lưu»',
          loc: nutTen('Sửa đơn'),
          lam: async (p) => {
            await nutTen('Sửa đơn')(p).click();
            await p.getByText('Chọn lớp', { exact: true }).first().click();
            await p.getByRole('radio').first().check();
            await p.waitForTimeout(1500);
            const ngay = p.getByRole('dialog').getByRole('radio');
            if ((await ngay.count()) > 3) await ngay.nth(3).check();
            await p.waitForTimeout(1500);
            await p.getByRole('dialog').getByRole('button', { name: 'Chọn', exact: true }).click();
            await nutTen('Lưu')(p).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Bấm «Trình duyệt»: đơn thành «Đã trình», chờ người duyệt',
          loc: nutTen('Trình duyệt'),
          lam: async (p) => {
            await nutTen('Trình duyệt')(p).click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      { width: 1280, height: 720 },
      4,
    ),
  // BH4: Trưởng cơ sở duyệt đơn (3 bước; Từ chối là ngoại lệ, video riêng bh4b). Tự tạo một đơn «Đã trình» trước khi quay.
  bh4: async (b) => {
    const { url: don, ma } = await taoDonDaTrinh(b);
    return chayBai(
      b,
      'bh4',
      async (p) => {
        await dangNhap(p, EMAIL('truongcs.cs5'));
        await p.goto(`${APP}/crm/viec-cho-duyet`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào «Việc chờ tôi duyệt», bấm mã đơn để mở',
          loc: (p) => p.getByText(ma, { exact: true }),
          lam: async (p) => {
            await p.getByText(ma, { exact: true }).first().click();
            await p.waitForLoadState('networkidle');
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Đọc từng dòng đơn và điều khoản thanh toán',
          loc: (p) => p.getByText('Dòng đơn', { exact: false }).first(),
        },
        {
          chu: 'Đồng ý: bấm «Duyệt», rồi bấm «Duyệt» trong hộp để xác nhận',
          loc: nutTen('Duyệt'),
          lam: async (p) => {
            await nutTen('Duyệt')(p).click();
            await p.waitForTimeout(1500);
            await p.getByRole('dialog').getByRole('button', { name: 'Duyệt', exact: true }).click();
            await p.getByText('Đã duyệt đơn hàng.').first().waitFor({ timeout: 15000 });
          },
        },
      ],
      { width: 1280, height: 720 },
      3,
    );
  },
  // TC1: tạo phiếu thu từ đơn «Đã duyệt» và trình quản lý (4 bước). Tự tạo một đơn «Đã duyệt» trước khi quay.
  tc1: async (b) => {
    const don = await taoDonDaDuyet(b);
    return chayBai(
      b,
      'tc1',
      async (p) => {
        await dangNhap(p);
        await p.goto(don);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Ở đơn «Đã duyệt» bấm «Tạo phiếu thu»',
          loc: nutTen('Tạo phiếu thu'),
          lam: async (p) => {
            await nutTen('Tạo phiếu thu')(p).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Ở hộp «Tạo phiếu thu»: kiểm «Số tiền», chọn «Hình thức», bấm «Tạo phiếu nháp»',
          loc: (p) => p.getByRole('dialog'),
          lam: async (p) => {
            await p.getByRole('dialog').getByText('Chọn hình thức').click();
            await p.getByRole('option', { name: 'Tiền mặt', exact: true }).click();
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Tạo phiếu nháp', exact: true })
              .click();
            await p
              .getByText(/Đã tạo phiếu thu nháp/)
              .first()
              .waitFor({ timeout: 15000 });
            await p.waitForLoadState('networkidle');
          },
        },
        {
          chu: 'Trong phiếu, kiểm «Ngày nhận», «Người nhận tiền», «Cơ sở thu tiền», «Tài khoản nhận»',
          loc: (p) => p.getByText('Ngày nhận').first(),
        },
        {
          chu: 'Bấm «Trình quản lý»: phiếu thành «Đã gửi», chờ quản lý duyệt',
          loc: nutTen('Trình quản lý'),
          lam: async (p) => {
            await nutTen('Trình quản lý')(p).click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      { width: 1280, height: 720 },
      4,
    );
  },
  // TC2: Trưởng cơ sở duyệt phiếu thu (4 bước, bước 4 từ chối chỉ nêu). Tự tạo phiếu «Đã gửi» trước khi quay.
  tc2: async (b) => {
    const { url: phieu, ma } = await taoPhieuDaGui(b, await taoDonDaDuyet(b));
    return chayBai(
      b,
      'tc2',
      async (p) => {
        await dangNhap(p, EMAIL('truongcs.cs5'));
        await p.goto(`${APP}/crm/viec-cho-duyet`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào «Việc chờ tôi duyệt», bấm mã phiếu «PT-…»',
          loc: (p) => p.getByText(ma, { exact: true }),
          lam: async (p) => {
            await p.getByText(ma, { exact: true }).first().click();
            await p.waitForLoadState('networkidle');
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Kiểm «Số tiền», «Hình thức», «Ngày nhận», «Người lập» và đơn hàng',
          loc: nutTen('Duyệt (chuyển Kế toán)'),
        },
        {
          chu: 'Bấm «Duyệt (chuyển Kế toán)», tích ô xác nhận rồi bấm «Xác nhận duyệt»',
          loc: nutTen('Duyệt (chuyển Kế toán)'),
          lam: async (p) => {
            await nutTen('Duyệt (chuyển Kế toán)')(p).click();
            await p.waitForTimeout(1500);
            await p.getByRole('dialog').getByRole('checkbox').check();
            await p.waitForTimeout(1200);
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Xác nhận duyệt', exact: true })
              .click();
            await p.getByText('Đã duyệt, chuyển Kế toán.').first().waitFor({ timeout: 15000 });
          },
        },
        {
          chu: 'Phiếu sang «Chờ kế toán»; chưa sinh khoản tiền vào, chưa cấp giờ',
          loc: (p) => p.getByText('Chờ kế toán').first(),
        },
      ],
      { width: 1280, height: 720 },
      4,
    );
  },
  // TC3: Kế toán duyệt phiếu thu (đủ cọc thì sinh ghi danh). Tự tạo phiếu «Chờ kế toán» trước khi quay.
  tc3: async (b) => {
    const { url: phieu, ma } = await taoPhieuDaGui(b, await taoDonDaDuyet(b));
    await truongDuyetPhieu(b, phieu);
    return chayBai(
      b,
      'tc3',
      async (p) => {
        await dangNhap(p, EMAIL('ketoan.cs5'));
        await p.goto(`${APP}/crm/viec-cho-duyet`);
        await p.waitForLoadState('networkidle');
      },
      [
        {
          chu: 'Vào «Việc chờ tôi duyệt», bấm mã phiếu «PT-…»',
          loc: (p) => p.getByText(ma, { exact: true }),
          lam: async (p) => {
            await p.getByText(ma, { exact: true }).first().click();
            await p.waitForLoadState('networkidle');
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Đối chiếu số tiền, hình thức, đơn hàng rồi bấm «Duyệt phiếu thu»',
          loc: nutTen('Duyệt phiếu thu'),
          lam: async (p) => {
            await nutTen('Duyệt phiếu thu')(p).click();
            await p.waitForTimeout(2000);
            const hop = p.getByRole('dialog');
            const o = hop.getByRole('checkbox');
            if ((await o.count()) > 0) await o.first().check();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Bấm «Xác nhận duyệt»: sinh khoản tiền vào; đủ cọc thì sinh ghi danh',
          loc: (p) =>
            p
              .getByRole('dialog')
              .getByRole('button', { name: /Xác nhận duyệt|Duyệt/ })
              .last(),
          lam: async (p) => {
            await p
              .getByRole('dialog')
              .getByRole('button', { name: /Xác nhận duyệt|Duyệt/ })
              .last()
              .click();
            await p.waitForTimeout(3500);
          },
        },
      ],
      { width: 1280, height: 720 },
      3,
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
