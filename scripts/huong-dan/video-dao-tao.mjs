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
import { createHmac } from 'node:crypto';
const maTotp = (khoa) => {
  const bang = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bit = '';
  for (const c of khoa.replace(/[\s=]/g, '').toUpperCase())
    bit += bang.indexOf(c).toString(2).padStart(5, '0');
  const byte = [];
  for (let i = 0; i + 8 <= bit.length; i += 8) byte.push(parseInt(bit.slice(i, i + 8), 2));
  const dem = Buffer.alloc(8);
  dem.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const h = createHmac('sha1', Buffer.from(byte)).update(dem).digest();
  const o = h[19] & 15;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1e6).padStart(6, '0');
};

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
  let dl = await r.json();
  // Tài khoản Admin có hai bước: HD_TOTP (khoá TOTP của tài khoản giả, chỉ qua biến môi trường) → nâng phiên lên aal2 bằng API Auth.
  if (process.env.HD_TOTP) {
    const H = {
      apikey: SB_KEY,
      authorization: `Bearer ${dl.access_token}`,
      'content-type': 'application/json',
    };
    const nguoi = await (await fetch(`${SB_URL}/auth/v1/user`, { headers: H })).json();
    const yeuTo = (nguoi.factors ?? []).find((x) => x.status === 'verified');
    if (yeuTo) {
      const th = await (
        await fetch(`${SB_URL}/auth/v1/factors/${yeuTo.id}/challenge`, {
          method: 'POST',
          headers: H,
          body: '{}',
        })
      ).json();
      const xm = await fetch(`${SB_URL}/auth/v1/factors/${yeuTo.id}/verify`, {
        method: 'POST',
        headers: H,
        body: JSON.stringify({ challenge_id: th.id, code: maTotp(process.env.HD_TOTP) }),
      });
      if (!xm.ok) throw new Error(`Xác minh hai bước lỗi ${xm.status}`);
      dl = await xm.json();
    }
  }
  const phien = JSON.stringify(dl);
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
  // DT7 «Tạo lớp, thời khoá biểu và trình duyệt» (CSKH): 7 bước; TẠO THẬT một lớp «[MẪU] Lớp tập DT7» trên staging rồi Trình.
  dt7: (b) =>
    chayBai(
      b,
      'dt7',
      vao('/crm/lop'),
      [
        {
          chu: 'Vào «Lớp học», bấm «Tạo lớp»',
          loc: (p) => p.getByRole('button', { name: 'Tạo lớp' }).first(),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo lớp' }).first().click();
            await p.waitForURL(/\/crm\/lop\/tao/);
            await cho(p);
          },
        },
        {
          chu: 'Điền «Thông tin chung»: Năm học, Môn học, Khối, Phân loại, Trình độ, Tổng số buổi, Ngày khai giảng',
          loc: (p) => p.getByLabel('Môn học', { exact: true }),
          lam: async (p) => {
            const nam = new Date().getFullYear();
            await p
              .getByLabel('Năm học')
              .selectOption(`${String(nam).slice(2)}${String(nam + 1).slice(2)}`);
            await p.getByLabel('Mã lớp cũ (Sheet)').fill(`MAU-DT7-${Date.now() % 100000}`);
            await p.getByLabel('Môn học').selectOption({ label: 'Toán' });
            await p.getByLabel('Khối').selectOption({ index: 5 });
            await p.getByLabel('Phân loại').selectOption({ label: 'Cơ bản' });
            await p.getByLabel('Trình độ').selectOption({ index: 1 });
            await p.getByLabel('Tổng số buổi').fill('12');
            await p.getByLabel('Ngày khai giảng').fill('2027-01-05');
            await p.waitForTimeout(800);
          },
        },
        {
          chu: '(Tuỳ chọn) Mục «Nhóm lớp»: «Không thuộc nhóm», gắn nhóm có sẵn hoặc tạo nhóm mới',
          loc: (p) => p.getByText('Nhóm lớp', { exact: false }).first(),
        },
        {
          chu: 'Mục «Time Table»: chọn tab thứ, bấm «Thêm khung giờ», điền giờ, giáo viên, phòng',
          loc: (p) => p.getByRole('tab', { name: /^Thứ 3/ }),
          lam: async (p) => {
            await p.getByRole('tab', { name: /^Thứ 3/ }).click();
            await p.getByRole('button', { name: 'Thêm khung giờ' }).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Bấm «Lưu nháp»: mở bản ghi lớp ở trạng thái Nháp, có mã lớp',
          loc: (p) => p.getByRole('button', { name: 'Lưu nháp' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Lưu nháp' }).click();
            await p.waitForURL(/\/crm\/lop\/[0-9a-f-]{36}$/, { timeout: 30000 });
            await cho(p);
          },
        },
        {
          chu: 'Mở menu «Hành động», chọn «Trình», rồi bấm «Trình» ở hộp xác nhận',
          loc: (p) => p.getByRole('button', { name: 'Hành động' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Hành động' }).click();
            await p.getByRole('menuitem', { name: 'Trình' }).click();
            await p.getByRole('button', { name: 'Trình', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Sau khi đã trình: bấm «Sửa», chỉ còn sửa được Time Table',
          loc: (p) => p.getByRole('button', { name: 'Sửa', exact: true }).first(),
        },
      ],
      chung,
      7,
    ),
  // DT8 «Duyệt hoặc từ chối lớp» (Trưởng cơ sở, tài khoản truongcs.cs5): 6 bước; xác nhận và DUYỆT THẬT lớp mẫu «MAU-DT7» ở Đã trình; bước 5 (Từ chối) chỉ mở menu rồi đóng, không bấm Từ chối.
  dt8: (b) =>
    chayBai(
      b,
      'dt8',
      vao('/crm/viec-cho-duyet'),
      [
        {
          chu: 'Vào «Việc chờ tôi duyệt», lọc «Loại việc» là «Lớp», bấm vào dòng của lớp',
          loc: (p) => p.locator('main tbody tr', { hasText: /K06-CB-S-009/ }).first(),
          lam: async (p) => {
            await p
              .locator('main tbody tr', { hasText: /K06-CB-S-009/ })
              .first()
              .click();
            await cho(p);
          },
        },
        {
          chu: 'Đọc kỹ «Thông tin chung», «Thời gian và địa điểm» và mục «Time Table»',
          loc: (p) => p.getByText('Time Table', { exact: true }).first(),
        },
        {
          chu: 'Lớp «Đã trình»: «Hành động» → «Xác nhận», bấm «Xác nhận» ở hộp «Xác nhận lớp»',
          loc: (p) => p.getByRole('button', { name: 'Hành động' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Hành động' }).click();
            await p.getByRole('menuitem', { name: 'Xác nhận' }).click();
            await p.getByRole('button', { name: 'Xác nhận', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Lớp «Đã xác nhận»: «Hành động» → «Duyệt»; hộp «Duyệt lớp» cho biết dự kiến sinh bao nhiêu buổi, bấm «Duyệt»',
          loc: (p) => p.getByRole('button', { name: 'Hành động' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Hành động' }).click();
            await p.getByRole('menuitem', { name: 'Duyệt' }).click();
            await p.waitForTimeout(2000);
            await p.getByRole('button', { name: 'Duyệt', exact: true }).click();
            await p.waitForTimeout(3000);
          },
        },
        {
          chu: 'Từ chối: «Hành động» → «Từ chối», gõ «Lý do» bắt buộc (video chỉ mở menu, không bấm)',
          loc: (p) => p.getByRole('button', { name: 'Hành động' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Hành động' }).click();
            await p.waitForTimeout(1500);
            await p.keyboard.press('Escape');
          },
        },
        {
          chu: 'Kiểm lại sau khi duyệt: bấm nút «Buổi học» trên bản ghi lớp, xem danh sách buổi',
          loc: (p) => p.getByRole('button', { name: /^Buổi học/ }),
          lam: async (p) => {
            await p.getByRole('button', { name: /^Buổi học/ }).click();
            await cho(p);
          },
        },
      ],
      chung,
      6,
    ),
  // DT14 «Huỷ buổi và dời một buổi», phần HUỶ (Trưởng cơ sở): 5 bước (bước 4 là nhánh Học sinh huỷ nên chỉ chỉ vào ô «Ai huỷ»); HUỶ THẬT một buổi của lớp mẫu S-009 trên staging.
  dt14: (b) =>
    chayBai(
      b,
      'dt14',
      vao('/crm/buoi-hoc'),
      [
        {
          chu: 'Vào Đào tạo → Buổi học, mở buổi cần huỷ',
          loc: (p) => p.getByPlaceholder(/Tìm mã lớp/),
          lam: async (p) => {
            await p.getByText('Xoá tất cả').first().click();
            await p.waitForTimeout(1500);
            await p.getByPlaceholder(/Tìm mã lớp/).fill('K06-CB-S-009');
            await p.keyboard.press('Enter');
            await p.waitForTimeout(2500);
            await p.locator('main tbody tr').first().click();
            await cho(p);
          },
        },
        {
          chu: 'Bấm «Huỷ»: hộp «Huỷ buổi» có «Ai huỷ»',
          loc: (p) => p.getByRole('button', { name: 'Huỷ', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Huỷ', exact: true }).click();
            await p.getByRole('radiogroup', { name: 'Ai huỷ' }).waitFor();
          },
        },
        {
          chu: 'Chọn «Trung tâm huỷ», chọn «Lý do huỷ»: hiện dòng «Buổi thêm vào cuối lịch»',
          loc: (p) => p.getByRole('combobox', { name: 'Lý do huỷ' }),
          lam: async (p) => {
            await p.getByText('Trung tâm huỷ (cả lớp nghỉ)').click();
            await p.getByRole('combobox', { name: 'Lý do huỷ' }).click();
            await p.waitForTimeout(600);
            await p.getByRole('option').last().click();
            await p.waitForTimeout(600);
            const hop = p.locator('[role=dialog],[role=alertdialog]');
            if (await hop.getByLabel('Ghi chú').count())
              await hop.getByLabel('Ghi chú').fill('[MẪU] Tập huỷ buổi');
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Học sinh huỷ (lớp riêng): chọn lý do rồi chọn có tính phí hoặc không tính phí',
          loc: (p) => p.getByRole('radiogroup', { name: 'Ai huỷ' }),
        },
        {
          chu: 'Bấm «Xác nhận huỷ buổi»: hiện «Đã huỷ buổi»',
          loc: (p) => p.getByRole('button', { name: 'Xác nhận huỷ buổi' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Xác nhận huỷ buổi' }).click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      chung,
      5,
    ),
  // DT14b «Dời một buổi» (Trưởng cơ sở): 3 bước; DỜI THẬT một buổi của lớp mẫu S-009.
  dt14b: (b) =>
    chayBai(
      b,
      'dt14b',
      vao('/crm/buoi-hoc'),
      [
        {
          chu: 'Mở buổi, bấm «Dời»: hộp «Dời buổi» có Ngày mới, Giờ bắt đầu, Giờ kết thúc, Phòng',
          loc: (p) => p.getByPlaceholder(/Tìm mã lớp/),
          lam: async (p) => {
            await p.getByText('Xoá tất cả').first().click();
            await p.waitForTimeout(1500);
            await p.getByPlaceholder(/Tìm mã lớp/).fill('K06-CB-S-009');
            await p.keyboard.press('Enter');
            await p.waitForTimeout(2500);
            await p.locator('main tbody tr').nth(1).click();
            await cho(p);
            await p.getByRole('button', { name: 'Dời', exact: true }).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Nhập ngày và giờ mới; giờ kết thúc phải sau giờ bắt đầu',
          loc: (p) => p.getByLabel('Ngày mới'),
          lam: async (p) => {
            await p.getByLabel('Ngày mới').fill('2027-02-10');
            await p.getByLabel('Giờ bắt đầu').fill('19:00');
            await p.getByLabel('Giờ kết thúc').fill('20:30');
            await p.waitForTimeout(800);
          },
        },
        {
          chu: 'Bấm «Xác nhận»: hiện «Đã dời buổi»',
          loc: (p) => p.getByRole('dialog').getByRole('button', { name: 'Xác nhận', exact: true }),
          lam: async (p) => {
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Xác nhận', exact: true })
              .click();
            await p.waitForTimeout(3000);
          },
        },
      ],
      chung,
      3,
    ),
  // DT6 «Phiếu tái tục» (CSKH): 7 bước; KHÔNG ghi gì lên staging (chỉ mở hộp rồi đóng). Bước 3 (Giao) chỉ chỉ vào dòng đầu vì phiếu mẫu đã có người phụ trách; bước 6 hộp «Gói» còn trống vì staging chưa có Gói bán.
  dt6: (b) =>
    chayBai(
      b,
      'dt6',
      vao('/crm/tai-tuc'),
      [
        {
          chu: 'Vào «Tái tục»: mặc định là danh sách, các dòng phiếu theo giai đoạn',
          loc: (p) => p.getByRole('heading', { name: 'Tái tục' }).first(),
        },
        {
          chu: 'Lọc việc của mình: bộ lọc «Phụ trách» chọn «Của tôi» hoặc «Chưa giao»',
          loc: (p) => p.getByRole('button', { name: 'Filters', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Filters', exact: true }).click();
            await p.waitForTimeout(1500);
            await p.keyboard.press('Escape');
          },
        },
        {
          chu: 'Phiếu chưa có người phụ trách: bấm «Giao», chọn «Người phụ trách», bấm «Giao»',
          loc: (p) => p.locator('main tbody tr').first(),
        },
        {
          chu: 'Bấm một dòng để mở phiếu: xem tab «Tổng quan», «Giờ học»; ghi ý phụ huynh rồi «Lưu»',
          loc: (p) => p.locator('main tbody tr', { hasText: 'TT000004' }).first(),
          lam: async (p) => {
            await p.locator('main tbody tr', { hasText: 'TT000004' }).first().click();
            await cho(p);
          },
        },
        {
          chu: 'Sau cuộc gọi, bấm «Chuyển giai đoạn», chọn «Giai đoạn mới», bấm «Chuyển»',
          loc: (p) => p.getByRole('button', { name: 'Chuyển giai đoạn', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Chuyển giai đoạn', exact: true }).click();
            await p.waitForTimeout(2000);
            await p.keyboard.press('Escape');
          },
        },
        {
          chu: 'Phiếu ở L6 Đồng ý tái tục: bấm «Tạo đơn», chọn «Gói», nhập «Số giờ», bấm «Tạo đơn nháp»',
          loc: (p) => p.getByRole('button', { name: 'Tạo đơn', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo đơn', exact: true }).click();
            await p.waitForTimeout(2500);
            await p.keyboard.press('Escape');
            await p.goto(`${APP}/crm/tai-tuc`);
            await cho(p);
          },
        },
        {
          chu: 'Tạo tay một phiếu: ở danh sách «Tái tục» bấm «Tạo», nhập «Mã ghi danh của học sinh»',
          loc: (p) => p.getByRole('button', { name: 'Tạo', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo', exact: true }).click();
            await p.waitForTimeout(2000);
            await p.keyboard.press('Escape');
          },
        },
      ],
      chung,
      7,
    ),
  // QT1 «Người dùng: tạo» (Admin admin.cs1 + HD_TOTP): 5 bước; TẠO THẬT một tài khoản giả [MẪU] trên staging (email .invalid).
  qt1: (b) =>
    chayBai(
      b,
      'qt1',
      vao('/crm/quan-tri/nguoi-dung'),
      [
        {
          chu: 'Vào Quản trị → Người dùng, bấm «Tạo người dùng»',
          loc: (p) => p.getByRole('button', { name: 'Tạo người dùng' }).first(),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo người dùng' }).first().click();
            await p.getByText('Tài khoản nhân viên, giáo viên, trợ giảng.').waitFor();
          },
        },
        {
          chu: 'Điền «Tên hiển thị», «Tên đăng nhập» và «Email»',
          loc: (p) => p.getByLabel('Tên hiển thị', { exact: true }),
          lam: async (p) => {
            const so = Date.now() % 100000;
            await p.getByLabel('Tên hiển thị', { exact: true }).fill(`[MẪU] Nhân viên tập ${so}`);
            await p.getByLabel('Tên đăng nhập', { exact: true }).fill(`mau.qt1.${so}`);
            await p
              .getByLabel('Email', { exact: true })
              .fill(`mau.qt1.${so}@thu.hoamatoan.invalid`);
            await p.waitForTimeout(1200);
          },
        },
        {
          chu: 'Chọn «Cơ sở», «Loại nhân sự», rồi bấm «Thêm vai trò» để chọn vai trò',
          loc: (p) => p.getByRole('button', { name: 'Thêm vai trò' }),
          lam: async (p) => {
            await p.getByRole('combobox', { name: 'Cơ sở' }).click();
            await p.getByRole('option').first().click();
            await p.getByRole('combobox', { name: 'Loại nhân sự' }).click();
            await p.getByRole('option').first().click();
            await p.getByRole('button', { name: 'Thêm vai trò' }).click();
            await p.waitForTimeout(800);
            await p.getByText('Chăm sóc, vận hành lớp', { exact: true }).last().click();
            await p.getByRole('heading', { name: 'Tạo người dùng' }).click();
            await p.waitForTimeout(800);
          },
        },
        {
          chu: 'Bấm «Tạo tài khoản»: hiện hộp «Mật khẩu tạm»',
          loc: (p) => p.getByRole('button', { name: 'Tạo tài khoản' }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tạo tài khoản' }).click();
            await p.getByText('Mật khẩu tạm').first().waitFor({ timeout: 30000 });
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Chép mật khẩu, giao cho người dùng, rồi bấm «Xong»',
          loc: (p) => p.getByRole('button', { name: 'Chép mật khẩu' }),
          lam: async (p) => {
            await p
              .getByRole('button', { name: 'Chép mật khẩu' })
              .click()
              .catch(() => {});
            await p.waitForTimeout(1200);
            await p.getByRole('button', { name: 'Xong', exact: true }).click();
          },
        },
      ],
      chung,
      5,
    ),
  // QT4 «Cơ sở và phòng» (Admin): 6 bước; trên cơ sở CS3 Hội sở: SỬA địa chỉ (còn lại «[MẪU]»), THÊM một phòng mẫu rồi sửa và NGỪNG phòng đó.
  qt4: (b) =>
    chayBai(
      b,
      'qt4',
      vao('/crm/quan-tri/nguoi-dung'),
      [
        {
          chu: 'Vào Quản trị → Cơ sở và phòng',
          loc: (p) => p.getByRole('link', { name: 'Cơ sở và phòng', exact: true }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/quan-tri/co-so`);
            await cho(p);
          },
        },
        {
          chu: 'Bấm vào một cơ sở ở cột trái, rồi bấm «Sửa cơ sở»',
          loc: (p) => p.getByRole('button', { name: /^CS3 Hội sở/ }),
          lam: async (p) => {
            await p.getByRole('button', { name: /^CS3 Hội sở/ }).click();
            await p.waitForTimeout(1200);
            await p.getByRole('button', { name: 'Sửa cơ sở' }).click();
            await p.waitForTimeout(1200);
          },
        },
        {
          chu: 'Sửa tên hoặc địa chỉ rồi bấm «Lưu»',
          loc: (p) => p.getByRole('button', { name: 'Lưu', exact: true }),
          lam: async (p) => {
            await p.getByLabel('Địa chỉ').fill('[MẪU] Địa chỉ tập');
            await p.getByRole('button', { name: 'Lưu', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Ở khối «Phòng học» của cơ sở đó, bấm «Thêm phòng»',
          loc: (p) => p.getByRole('button', { name: 'Thêm phòng', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Thêm phòng', exact: true }).click();
            await p.waitForTimeout(1200);
          },
        },
        {
          chu: 'Điền «Mã phòng», «Tên phòng», «Sức chứa» rồi bấm «Thêm phòng»',
          loc: (p) => p.getByLabel('Mã phòng'),
          lam: async (p) => {
            const so = Date.now() % 10000;
            await p.getByLabel('Mã phòng').fill(`MAU_QT4_${so}`);
            await p.getByLabel('Tên phòng').fill(`MAU-QT4-${so}`);
            await p.getByLabel('Sức chứa').fill('12');
            await p.waitForTimeout(800);
            await p
              .getByRole('dialog')
              .getByRole('button', { name: 'Thêm phòng', exact: true })
              .click();
            await p.waitForTimeout(2500);
          },
        },
        {
          chu: 'Đổi tên hoặc sức chứa: «Sửa» ở dòng phòng; muốn ngừng: «Ngừng», rồi «Ngừng phòng»',
          loc: (p) =>
            p.locator('tr', { hasText: 'MAU-QT4' }).getByRole('button', { name: 'Ngừng' }),
          lam: async (p) => {
            await p
              .locator('tr', { hasText: 'MAU-QT4' })
              .getByRole('button', { name: 'Ngừng' })
              .click();
            await p.waitForTimeout(1200);
            await p.getByRole('button', { name: 'Ngừng phòng', exact: true }).click();
            await p.waitForTimeout(2500);
          },
        },
      ],
      chung,
      6,
    ),
  // QT6 «Công tắc tính năng» (Admin): 3 bước; BẬT phân hệ Học tập ở CS3 rồi (ngoài video) TẮT lại để giữ nguyên staging.
  qt6: (b) =>
    chayBai(
      b,
      'qt6',
      vao('/crm/quan-tri/nguoi-dung'),
      [
        {
          chu: 'Vào Quản trị → Công tắc tính năng',
          loc: (p) => p.getByRole('link', { name: 'Công tắc tính năng', exact: true }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/quan-tri/cong-tac`);
            await cho(p);
          },
        },
        {
          chu: 'Tìm dòng phân hệ và cột cơ sở, bấm vào ô «Bật» hoặc «Tắt» ở giao điểm',
          loc: (p) => p.locator('tr', { hasText: 'Học tập (LMS)' }).getByRole('button').nth(4),
          lam: async (p) => {
            await p.locator('tr', { hasText: 'Học tập (LMS)' }).getByRole('button').nth(4).click();
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Đọc dòng giải thích trong hộp, rồi bấm «Bật» để xác nhận',
          loc: (p) =>
            p
              .locator('[role=dialog],[role=alertdialog]')
              .getByRole('button', { name: 'Bật', exact: true }),
          lam: async (p) => {
            await p
              .locator('[role=dialog],[role=alertdialog]')
              .getByRole('button', { name: 'Bật', exact: true })
              .click();
            await p.waitForTimeout(2500);
            // Hoàn lại ngoài lời thoại: tắt lại phân hệ vừa bật.
            await p.locator('tr', { hasText: 'Học tập (LMS)' }).getByRole('button').nth(4).click();
            await p
              .locator('[role=dialog],[role=alertdialog]')
              .getByRole('button', { name: 'Tắt', exact: true })
              .click();
            await p.waitForTimeout(2000);
          },
        },
      ],
      chung,
      3,
    ),
  // QT8 «Nhập dữ liệu cũ» (Admin): bước 1 đến 6 của bài (bước 7 chỉ riêng loại Người dùng nên không quay); file mẫu tải về từ chính màn, KHÔNG bấm «Nạp thật» (chỉ xem trước), nên không ghi gì lên staging.
  qt8: (b) => {
    const tep = join(OUT, 'qt8', 'mau-nhap.csv');
    return chayBai(
      b,
      'qt8',
      vao('/crm/quan-tri/nguoi-dung'),
      [
        {
          chu: 'Vào Quản trị → Nhập dữ liệu, tìm đúng loại trong bảng',
          loc: (p) => p.getByRole('link', { name: 'Nhập dữ liệu', exact: true }),
          lam: async (p) => {
            await p.goto(`${APP}/crm/quan-tri/nhap-du-lieu`);
            await cho(p);
          },
        },
        {
          chu: 'Chưa có file: bấm «Tải file mẫu» ở dòng đó, điền theo file mẫu, lưu CSV UTF-8',
          loc: (p) => p.getByRole('button', { name: /^Tải file mẫu/ }).first(),
          lam: async (p) => {
            mkdirSync(join(OUT, 'qt8'), { recursive: true });
            const [dl] = await Promise.all([
              p.waitForEvent('download'),
              p
                .getByRole('button', { name: /^Tải file mẫu/ })
                .first()
                .click(),
            ]);
            await dl.saveAs(tep);
          },
        },
        {
          chu: 'Bấm nút «Nhập …» ở dòng đó: hộp nhiều bước «Nhập … từ file»',
          loc: (p) =>
            p
              .getByRole('button', { name: /^Nhập / })
              .and(p.locator(':enabled'))
              .first(),
          lam: async (p) => {
            await p
              .getByRole('button', { name: /^Nhập / })
              .and(p.locator(':enabled'))
              .first()
              .click();
            await p.waitForTimeout(1800);
          },
        },
        {
          chu: 'Kéo file CSV vào khung, hoặc bấm «chọn file»',
          loc: (p) => p.getByText('chọn file').first(),
          lam: async (p) => {
            await p.locator('input[type=file]').setInputFiles(tep);
            await p.waitForTimeout(1500);
          },
        },
        {
          chu: 'Bấm «Tiếp» để xem trước: chưa có gì được nạp ở bước này',
          loc: (p) => p.getByRole('button', { name: 'Tiếp', exact: true }),
          lam: async (p) => {
            await p.getByRole('button', { name: 'Tiếp', exact: true }).click();
            await p.waitForTimeout(3000);
          },
        },
        {
          chu: 'Xem kỹ dòng «Lỗi» và «Trùng»; hài lòng thì bấm «Nạp thật» (video không bấm)',
          loc: (p) => p.getByRole('button', { name: 'Nạp thật', exact: true }),
        },
      ],
      chung,
      6,
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
