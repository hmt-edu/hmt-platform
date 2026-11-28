// @ts-nocheck
// Video khớp từng bước các bài CSKH (cs1…) và Giáo viên (GV…): luồng chính, dữ liệu giả «[MẪU]» trên bản thử nghiệm.
// Chạy: HD_TAI_KHOAN=cskh.cs5@thu.hoamatoan.invalid node scripts/huong-dan/chay.mjs cs1
// Chữ «Bước n/N» trong video cùng chữ với bước đánh số trong bài docs/huong-dan/<nhóm>/….
export function baiCskhGv({ chayBai, APP, dangNhap, nutTen }) {
  const K = { width: 1280, height: 720 };
  const cho = (p) => p.waitForLoadState('networkidle');
  const chon = async (p, ten, opt) => {
    await p.getByRole('combobox', { name: ten, exact: true }).click();
    await p.getByRole('option', { name: opt, exact: true }).click();
  };
  /** Đổi người dùng ngay trong video: lấy phiên bằng API Auth (mật khẩu tài khoản giả) rồi nạp vào trình duyệt. */
  const doiTaiKhoan = async (p, email, url) => {
    const r = await fetch(`${process.env.HD_SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: process.env.HD_SUPABASE_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ email, password: process.env.STAGING_PASSWORD }),
    });
    if (!r.ok) throw new Error(`Đổi tài khoản lỗi ${r.status}`);
    const khoa = `sb-${new URL(process.env.HD_SUPABASE_URL).hostname.split('.')[0]}-auth-token`;
    const phien = JSON.stringify(await r.json());
    // dangNhap đã gắn addInitScript nạp phiên cũ ở MỌI lần tải trang: gắn thêm một cái sau nó để phiên mới thắng.
    await p.addInitScript(([k, v]) => localStorage.setItem(k, v), [khoa, phien]);
    await p.goto(url);
    await cho(p);
  };
  /** Chuẩn bị NGOÀI video: tạo sẵn một ticket «[MẪU]» (đúng loại), giao sẵn nếu cần; trả địa chỉ ticket để video mở thẳng. */
  const taoTicketNgam = async (b, loai, tieuDe, tuyChon = {}) => {
    const ctx = await b.newContext({ viewport: K });
    const p = await ctx.newPage();
    await dangNhap(p);
    await p.goto(`${APP}/crm/ticket/moi`);
    await cho(p);
    await chon(p, 'Loại', loai);
    await p.getByLabel('Tiêu đề', { exact: true }).fill(tieuDe);
    await chon(p, 'Kênh', 'Gọi điện');
    await p.getByRole('combobox', { name: 'Phụ huynh' }).first().click();
    await p.keyboard.type('0999000008');
    await p.getByRole('option').first().waitFor();
    await p.waitForTimeout(800);
    await p.getByRole('option').first().click();
    await p.getByRole('combobox', { name: 'Nhóm', exact: true }).click();
    if (tuyChon.nhom) await p.getByRole('option', { name: tuyChon.nhom, exact: true }).click();
    else await p.getByRole('option').nth(1).click();
    await p.getByRole('combobox', { name: 'Nhóm con', exact: true }).click();
    if (tuyChon.nhomCon)
      await p.getByRole('option', { name: tuyChon.nhomCon, exact: true }).click();
    else await p.getByRole('option').nth(1).click();
    if (tuyChon.hocSinh) {
      await p.getByRole('combobox', { name: 'Học sinh' }).first().click();
      await p.keyboard.type('[MẪU]');
      await p.getByRole('option').first().waitFor();
      await p.waitForTimeout(800);
      await p.getByRole('option').first().click();
    }
    await p
      .getByLabel('Mô tả', { exact: true })
      .fill('[MẪU] Phụ huynh phản ánh giờ học bị đổi không báo trước.');
    await p.getByRole('button', { name: 'Lưu', exact: true }).click();
    await p.waitForURL(/\/crm\/ticket\/(?!moi)/, { timeout: 20000 });
    await cho(p);
    const url = p.url();
    await ctx.close();
    return url;
  };
  return {
    // CS1 · 7 bước, chữ «Bước n/7» cùng chữ với docs/huong-dan/cskh/cs1-tao-ticket-va-xu-ly.md. LƯU ticket «[MẪU]» trên staging. Tài khoản cskh.cs5@…
    cs1: (b) =>
      chayBai(
        b,
        'cs1',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/crm/ticket`);
          await cho(p);
        },
        [
          {
            chu: 'Vào «Chăm sóc khách hàng» → «Ticket», bấm «Tạo»',
            loc: nutTen('Tạo'),
            lam: async (p) => {
              await nutTen('Tạo')(p).click();
              await p.waitForURL(/\/crm\/ticket\/moi/);
              await cho(p);
            },
          },
          {
            chu: 'Chọn «Loại» (Đề nghị hoặc Khiếu nại), gõ «Tiêu đề», chọn «Kênh»',
            loc: (p) => p.getByRole('combobox', { name: 'Loại', exact: true }),
            lam: async (p) => {
              await chon(p, 'Loại', 'Đề nghị');
              await p
                .getByLabel('Tiêu đề', { exact: true })
                .fill('[MẪU] Phụ huynh hỏi lịch học bù');
              await chon(p, 'Kênh', 'Gọi điện');
            },
          },
          {
            chu: 'Ở «Người gửi», gõ tên, số điện thoại hoặc mã phụ huynh rồi chọn đúng người',
            loc: (p) => p.getByRole('combobox', { name: 'Phụ huynh' }).first(),
            lam: async (p) => {
              await p.getByRole('combobox', { name: 'Phụ huynh' }).first().click();
              await p.keyboard.type('0999000007');
              await p.getByRole('option').first().waitFor();
              await p.waitForTimeout(800);
              await p.getByRole('option').first().click();
              await p.waitForTimeout(600);
            },
          },
          {
            chu: 'Chọn «Nhóm», rồi «Nhóm con»; gõ «Mô tả»; «Mức độ» để trống thì lấy mặc định',
            loc: (p) => p.getByRole('combobox', { name: 'Nhóm', exact: true }),
            lam: async (p) => {
              await chon(p, 'Nhóm', 'Hỗ trợ');
              await p.getByRole('combobox', { name: 'Nhóm con', exact: true }).click();
              await p.getByRole('option').nth(1).click();
              await p
                .getByLabel('Mô tả', { exact: true })
                .fill('[MẪU] Phụ huynh cần học bù buổi nghỉ.');
              await p.waitForTimeout(600);
            },
          },
          {
            chu: 'Bấm «Lưu»: mở thẳng ticket vừa tạo, trạng thái «Mới»',
            loc: nutTen('Lưu'),
            lam: async (p) => {
              await nutTen('Lưu')(p).click();
              await p.waitForURL(/\/crm\/ticket\/(?!moi)/, { timeout: 20000 });
              await cho(p);
            },
          },
          {
            chu: 'Bấm «Giao ticket», chọn «Đội» và «Người phụ trách», bấm «Giao»',
            loc: nutTen('Giao ticket'),
            lam: async (p) => {
              await nutTen('Giao ticket')(p).click();
              await p.waitForTimeout(800);
              const hop = p.getByRole('dialog');
              await hop.getByRole('combobox').first().click();
              await p.getByRole('option').nth(1).click(); // mục 0 là «Chưa chọn»
              await p.waitForTimeout(1500); // danh sách người phụ trách tải xong
              await hop.getByRole('combobox').nth(1).click();
              await p.getByRole('option').nth(1).click();
              await hop.getByRole('button', { name: 'Giao', exact: true }).click();
              await p.waitForTimeout(1500);
            },
          },
          {
            chu: 'Xử lý: bấm bước «Đang xử lý», ghi «Ghi chú»; xong việc chuyển «Đã xử lý» kèm «Kết quả»',
            loc: (p) => p.getByRole('button', { name: /Đang xử lý/ }).first(),
            lam: async (p) => {
              await p
                .getByRole('button', { name: /Đang xử lý/ })
                .first()
                .click();
              await p.waitForTimeout(800);
              await p
                .getByRole('dialog')
                .getByRole('button', { name: 'Chuyển', exact: true })
                .click();
              await p.waitForTimeout(1500);
              await p
                .locator('textarea[placeholder^="Viết ghi chú"]')
                .fill('[MẪU] Đã gọi phụ huynh, hẹn học bù thứ Bảy.');
              await p.getByRole('button', { name: 'Gửi ghi chú', exact: true }).click();
              await p.waitForTimeout(1500);
              await p
                .getByRole('button', { name: /Đã xử lý/ })
                .first()
                .click();
              await p.waitForTimeout(800);
              await p.getByLabel('Kết quả').fill('[MẪU] Đã xếp học bù thứ Bảy.');
              await p
                .getByRole('dialog')
                .getByRole('button', { name: 'Chuyển', exact: true })
                .click();
              await p.waitForTimeout(4000); // để người xem thấy trạng thái mới
            },
          },
        ],
        K,
        7,
      ),
    // CS2 (luồng chính, bước 1–5 của bài «Khiếu nại»; 6 Nâng cấp và 7 Mở lại là ngoại lệ). Ticket Khiếu nại tạo sẵn ngoài video.
    cs2: async (b) => {
      const url = await taoTicketNgam(b, 'Khiếu nại', '[MẪU] Khiếu nại giờ học bị đổi');
      return chayBai(
        b,
        'cs2',
        async (p) => {
          await dangNhap(p);
          await p.goto(url);
          await cho(p);
        },
        [
          {
            chu: 'Mở ticket Khiếu nại, bấm «Sửa phần riêng», điền các ô và bấm «Lưu»',
            loc: nutTen('Sửa phần riêng'),
            lam: async (p) => {
              await nutTen('Sửa phần riêng')(p).click();
              await p.waitForTimeout(800);
              const hop = p.getByRole('dialog');
              await hop.getByLabel('Mong muốn của khách').fill('[MẪU] Được học đúng giờ đã báo.');
              await hop.getByLabel('Nguyên nhân gốc').fill('[MẪU] Lịch đổi chưa báo phụ huynh.');
              await hop.getByRole('button', { name: 'Lưu', exact: true }).click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Bấm «Giao ticket»; người phụ trách bấm «Đang xử lý» rồi «Chuyển»',
            loc: nutTen('Giao ticket'),
            lam: async (p) => {
              await nutTen('Giao ticket')(p).click();
              await p.waitForTimeout(800);
              const hop = p.getByRole('dialog');
              await hop.getByRole('combobox').first().click();
              await p.getByRole('option').nth(1).click();
              await p.waitForTimeout(1500);
              await hop.getByRole('combobox').nth(1).click();
              await p.getByRole('option').nth(1).click();
              await hop.getByRole('button', { name: 'Giao', exact: true }).click();
              await p.waitForTimeout(1500);
              await p
                .getByRole('button', { name: /Đang xử lý/ })
                .first()
                .click();
              await p.waitForTimeout(800);
              await p
                .getByRole('dialog')
                .getByRole('button', { name: 'Chuyển', exact: true })
                .click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Ghi xác minh ở «Ghi chú» rồi bấm «Gửi ghi chú»',
            loc: (p) => p.locator('textarea[placeholder^="Viết ghi chú"]'),
            lam: async (p) => {
              await p
                .locator('textarea[placeholder^="Viết ghi chú"]')
                .fill('[MẪU] Đã hỏi giáo viên: lịch đổi do trùng phòng.');
              await p.getByRole('button', { name: 'Gửi ghi chú', exact: true }).click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Phụ huynh đồng ý: bấm «Đã xử lý», gõ «Kết quả», bấm «Chuyển»',
            loc: (p) => p.getByRole('button', { name: /Đã xử lý/ }).first(),
            lam: async (p) => {
              await p
                .getByRole('button', { name: /Đã xử lý/ })
                .first()
                .click();
              await p.waitForTimeout(800);
              await p
                .getByLabel('Kết quả')
                .fill('[MẪU] Xin lỗi phụ huynh, đã báo lịch mới bằng Zalo.');
              await p
                .getByRole('dialog')
                .getByRole('button', { name: 'Chuyển', exact: true })
                .click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Bấm «Đã đóng», nhập mức hài lòng 1 đến 5, bấm «Đóng khiếu nại»',
            loc: (p) => p.getByRole('button', { name: /Đã đóng/ }).first(),
            lam: async (p) => {
              await p
                .getByRole('button', { name: /Đã đóng/ })
                .first()
                .click();
              await p.waitForTimeout(800);
              await p.getByRole('dialog').locator('input[type=number]').fill('5');
              await p
                .getByRole('dialog')
                .getByRole('button', { name: 'Đóng khiếu nại', exact: true })
                .click();
              await p.waitForTimeout(4000);
            },
          },
        ],
        K,
        5,
      );
    },
    // CS3 · 7 bước, cùng thứ tự bài docs/huong-dan/cskh/cs3-phieu-nghiep-vu-va-duyet.md. Dùng loại phiếu đơn giản nhất (Cập nhật hồ sơ, một cấp) nên bước 5 chỉ chỉ ra «bỏ qua»; bước 7 quay lại ticket gốc và đóng ticket làm tay.
    cs3: async (b) => {
      const ticketUrl = await taoTicketNgam(b, 'Đề nghị', '[MẪU] Chung quy trình phiếu cs3', {
        nhom: 'Hồ sơ',
        nhomCon: 'Cập nhật thông tin học sinh, phụ huynh',
        hocSinh: true,
      });
      let phieuUrl = '';
      const EM = process.env.HD_TAI_KHOAN;
      const hop = (p) => p.getByRole('dialog');
      return chayBai(
        b,
        'cs3',
        async (p) => {
          await dangNhap(p);
          await p.goto(ticketUrl);
          await cho(p);
        },
        [
          {
            chu: 'Mở ticket, bấm «Tạo phiếu»',
            loc: nutTen('Tạo phiếu'),
            lam: async (p) => {
              await nutTen('Tạo phiếu')(p).click();
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Điền các ô của loại phiếu và ô «Lý do», bấm «Tạo phiếu»',
            loc: (p) => hop(p).getByRole('textbox', { name: 'Trường', exact: true }),
            lam: async (p) => {
              await hop(p)
                .getByRole('textbox', { name: 'Trường', exact: true })
                .fill('[MẪU] THCS Cầu Giấy');
              await hop(p)
                .getByLabel('Lý do', { exact: true })
                .fill('[MẪU] Phụ huynh báo trường mới');
              await p.waitForTimeout(600);
              await hop(p).getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
              await p.waitForURL(/\/crm\/phieu-nghiep-vu\/(?!moi)/, { timeout: 20000 });
              await cho(p);
              phieuUrl = p.url();
            },
          },
          {
            chu: 'Đọc lại «Thông tin phiếu», kiểm khối «Duyệt», rồi bấm «Gửi duyệt»',
            loc: nutTen('Gửi duyệt'),
            lam: async (p) => {
              await nutTen('Gửi duyệt')(p).click();
              await p.waitForTimeout(1200);
              const xn = hop(p).getByRole('button', { name: 'Gửi duyệt', exact: true });
              if (await xn.count()) await xn.click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Người duyệt cấp 1 (Trưởng cơ sở) mở phiếu, bấm «Duyệt», rồi «Duyệt» trong hộp «Duyệt phiếu»',
            loc: null,
            lam: async (p) => {
              await doiTaiKhoan(p, 'truongcs.cs5@thu.hoamatoan.invalid', phieuUrl);
              await nutTen('Duyệt')(p).click();
              await p.waitForTimeout(1000);
              await hop(p).getByRole('button', { name: 'Duyệt', exact: true }).click();
              await p.waitForTimeout(2000);
            },
          },
          {
            chu: 'Phiếu có cấp kế toán thì Kế toán duyệt cấp 2; phiếu chỉ một cấp thì bỏ qua bước này',
            loc: (p) => p.getByText('Duyệt xong lúc').first(),
            lam: (p) => p.waitForTimeout(1500),
          },
          {
            chu: 'CSKH mở phiếu «Đã duyệt», bấm «Thực hiện», rồi «Thực hiện» trong hộp «Thực hiện phiếu?»',
            loc: null,
            lam: async (p) => {
              await doiTaiKhoan(p, EM, phieuUrl);
              await nutTen('Thực hiện')(p).click();
              await p.waitForTimeout(1200);
              await p
                .getByRole('alertdialog')
                .getByRole('button', { name: 'Thực hiện', exact: true })
                .click();
              await p.waitForTimeout(4000);
            },
          },
          {
            chu: 'Quay lại ticket gốc, kiểm thấy phiếu, rồi chuyển ticket sang «Đã đóng» (ghi chú làm tay)',
            loc: null,
            lam: async (p) => {
              await p.goto(ticketUrl);
              await cho(p);
              await p.waitForTimeout(1500);
              await p
                .getByRole('button', { name: /Đã đóng/ })
                .first()
                .click();
              await p.waitForTimeout(1200);
              await hop(p)
                .getByLabel('Ghi chú làm tay')
                .fill('[MẪU] Đã làm theo phiếu cập nhật hồ sơ');
              await hop(p).getByRole('button', { name: 'Đóng ticket', exact: true }).click();
              await p.waitForTimeout(2500);
            },
          },
        ],
        K,
        7,
      );
    },
    // CS4 · 7 bước, cùng thứ tự bài docs/huong-dan/cskh/cs4-phieu-cap-nhat-ho-so.md. Ticket tạo sẵn ngoài video; bước 6 đổi sang Trưởng cơ sở duyệt (người khác người tạo), bước 7 quay lại CSKH.
    cs4: async (b) => {
      const ticketUrl = await taoTicketNgam(b, 'Đề nghị', '[MẪU] Cập nhật trường học của em', {
        nhom: 'Hồ sơ',
        nhomCon: 'Cập nhật thông tin học sinh, phụ huynh',
        hocSinh: true,
      });
      let phieuUrl = '';
      const EM = process.env.HD_TAI_KHOAN;
      const hop = (p) => p.getByRole('dialog');
      return chayBai(
        b,
        'cs4',
        async (p) => {
          await dangNhap(p);
          await p.goto(ticketUrl);
          await cho(p);
        },
        [
          {
            chu: 'Mở ticket «Cập nhật thông tin học sinh, phụ huynh», bấm «Tạo phiếu»',
            loc: nutTen('Tạo phiếu'),
            lam: async (p) => {
              await nutTen('Tạo phiếu')(p).click();
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Chọn «Hồ sơ cần sửa» là «Học sinh» hoặc «Phụ huynh»',
            loc: (p) => hop(p).getByRole('combobox').first(),
            lam: (p) => p.waitForTimeout(500),
          },
          {
            chu: 'Gõ giá trị mới vào đúng ô cần đổi, rồi gõ «Lý do»',
            loc: (p) => hop(p).getByRole('textbox', { name: 'Trường', exact: true }),
            lam: async (p) => {
              await hop(p)
                .getByRole('textbox', { name: 'Trường', exact: true })
                .fill('[MẪU] THCS Mỹ Đình');
              await hop(p)
                .getByLabel('Lý do', { exact: true })
                .fill('[MẪU] Phụ huynh báo trường mới');
              await p.waitForTimeout(600);
            },
          },
          {
            chu: 'Bấm «Tạo phiếu»',
            loc: (p) => hop(p).getByRole('button', { name: 'Tạo phiếu', exact: true }),
            lam: async (p) => {
              await hop(p).getByRole('button', { name: 'Tạo phiếu', exact: true }).click();
              await p.waitForURL(/\/crm\/phieu-nghiep-vu\/(?!moi)/, { timeout: 20000 });
              await cho(p);
              phieuUrl = p.url();
            },
          },
          {
            chu: 'Kiểm lại nội dung, bấm «Gửi duyệt»',
            loc: nutTen('Gửi duyệt'),
            lam: async (p) => {
              await nutTen('Gửi duyệt')(p).click();
              await p.waitForTimeout(1200);
              const xn = hop(p).getByRole('button', { name: 'Gửi duyệt', exact: true });
              if (await xn.count()) await xn.click();
              await p.waitForTimeout(1800);
            },
          },
          {
            chu: 'Nhờ Trưởng cơ sở duyệt: mở phiếu, bấm «Duyệt», rồi «Duyệt» trong hộp «Duyệt phiếu»',
            loc: null,
            lam: async (p) => {
              await doiTaiKhoan(p, 'truongcs.cs5@thu.hoamatoan.invalid', phieuUrl);
              await nutTen('Duyệt')(p).click();
              await p.waitForTimeout(1000);
              await hop(p).getByRole('button', { name: 'Duyệt', exact: true }).click();
              await p.waitForTimeout(2000);
            },
          },
          {
            chu: 'Mở lại phiếu «Đã duyệt», bấm «Thực hiện», rồi «Thực hiện» trong hộp «Thực hiện phiếu?»',
            loc: null,
            lam: async (p) => {
              await doiTaiKhoan(p, EM, phieuUrl);
              await nutTen('Thực hiện')(p).click();
              await p.waitForTimeout(1200);
              await p
                .getByRole('alertdialog')
                .getByRole('button', { name: 'Thực hiện', exact: true })
                .click();
              await p.waitForTimeout(4000);
            },
          },
        ],
        K,
        7,
      );
    },
    // GV1 · 3 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV1-hom-nay.md (điện thoại 390×844). Cần buổi dạy hôm nay của gv.cs5 trên bản thử nghiệm.
    gv1: (b) => {
      const DT = { width: 390, height: 844 };
      return chayBai(
        b,
        'gv1',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
        },
        [
          {
            chu: 'Mở Cổng Giáo viên: màn «Hôm nay» hiện các buổi dạy hôm nay',
            loc: (p) => p.getByText('Cần hoàn tất').first(),
            lam: (p) => p.waitForTimeout(800),
          },
          {
            chu: 'Nhìn thanh dưới để chuyển nhanh sang «Lịch dạy», «Lớp», «Cần làm»',
            loc: (p) => p.locator('nav').last(),
            lam: (p) => p.waitForTimeout(800),
          },
          {
            chu: 'Bấm một buổi trong danh sách để vào các bước của buổi đó',
            loc: (p) => p.locator('main a').first(),
            lam: async (p) => {
              await p.locator('main a').first().click();
              await cho(p);
              await p.waitForTimeout(1500);
            },
          },
        ],
        DT,
        3,
      );
    },
    // GV4 · 4 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV4-noi-dung-btvn.md (điện thoại). Nhập nội dung buổi đầu tiên «Hôm nay» của gv.cs5 (nhập trước được, không cần chốt danh sách).
    gv4: (b) => {
      const DT = { width: 390, height: 844 };
      const mo = (p) =>
        p.getByRole('link', { name: 'Mở' }).or(p.getByRole('button', { name: 'Mở' }));
      return chayBai(
        b,
        'gv4',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
          await p.locator('main a').first().click();
          await cho(p);
          await p.waitForTimeout(1200);
        },
        [
          {
            chu: 'Ở trang «Buổi dạy», bấm «Mở» ở bước 2',
            loc: (p) => mo(p).first(),
            lam: async (p) => {
              await mo(p).first().click();
              await cho(p);
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Bấm «Thêm dòng», gõ một nội dung đã dạy',
            loc: (p) => p.getByRole('button', { name: 'Thêm dòng' }),
            lam: async (p) => {
              await p.getByRole('button', { name: 'Thêm dòng' }).click();
              await p.getByLabel('Dòng nội dung 1').fill('[MẪU] Phép nhân số có hai chữ số');
              await p.waitForTimeout(800);
            },
          },
          {
            chu: 'Nếu có giao bài, gõ vào «Bài tập về nhà giao mới»; không giao thì bỏ trống',
            loc: (p) => p.getByLabel('Bài tập về nhà giao mới'),
            lam: async (p) => {
              await p.getByLabel('Bài tập về nhà giao mới').fill('[MẪU] Làm bài 1 đến 5 trang 24');
              await p.waitForTimeout(800);
            },
          },
          {
            chu: 'Bấm «Lưu»',
            loc: (p) => p.getByRole('button', { name: 'Lưu', exact: true }),
            lam: async (p) => {
              await p.getByRole('button', { name: 'Lưu', exact: true }).click();
              await p.waitForTimeout(2500);
            },
          },
        ],
        DT,
        4,
      );
    },
    // GV8 · 4 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV8-viec-can-lam.md (điện thoại). Chỉ xem và mở, không đổi dữ liệu.
    gv8: (b) => {
      const DT = { width: 390, height: 844 };
      const tab = (p) => p.locator('nav').last().getByText('Cần làm');
      const mo = (p) =>
        p.getByRole('link', { name: 'Mở' }).or(p.getByRole('button', { name: 'Mở' }));
      return chayBai(
        b,
        'gv8',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
        },
        [
          {
            chu: 'Bấm «Cần làm» ở thanh dưới',
            loc: tab,
            lam: async (p) => {
              await tab(p).click();
              await cho(p);
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Ở mỗi buổi chưa hoàn tất, đọc dòng «quá hạn» hoặc «còn … giờ» và lý do bên dưới',
            loc: (p) => p.getByTestId('gv12-deadline').first(),
            lam: (p) => p.waitForTimeout(800),
          },
          {
            chu: 'Bấm «Mở» ở dòng muốn làm',
            loc: (p) => mo(p).first(),
            lam: async (p) => {
              await mo(p).first().click();
              await cho(p);
              await p.waitForTimeout(1500);
            },
          },
          {
            chu: 'Làm xong, quay lại «Cần làm» để kiểm việc còn lại',
            loc: tab,
            lam: async (p) => {
              await tab(p).click();
              await cho(p);
              await p.waitForTimeout(1500);
            },
          },
        ],
        DT,
        4,
      );
    },
    // GV3 · 3 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV3-diem-danh.md (điện thoại). Điểm danh buổi «Hôm nay» ĐÃ chốt danh sách (lớp …-S-013) của gv.cs5; đổi dữ liệu mẫu, mỗi bộ dữ liệu chạy một lần.
    gv3: (b) => {
      const DT = { width: 390, height: 844 };
      const mo = (p) =>
        p.getByRole('link', { name: 'Mở' }).or(p.getByRole('button', { name: 'Mở' }));
      return chayBai(
        b,
        'gv3',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
          await p.locator('main a').filter({ hasText: 'S-013' }).first().click();
          await cho(p);
          await p.waitForTimeout(1200);
        },
        [
          {
            chu: 'Ở trang «Buổi dạy», bấm «Mở» ở bước 1 «Điểm danh»',
            loc: (p) => mo(p).first(),
            lam: async (p) => {
              await mo(p).first().click();
              await cho(p);
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Chọn các em vắng trước, rồi bấm «Còn lại: Có mặt»',
            loc: (p) => p.getByRole('radiogroup').first(),
            lam: async (p) => {
              await p
                .getByRole('radiogroup')
                .first()
                .getByRole('radio', { name: 'Vắng có phép' })
                .click();
              await p.waitForTimeout(800);
              await p.getByRole('button', { name: /^Còn lại/ }).click();
              await p.waitForTimeout(1000);
            },
          },
          {
            chu: 'Bấm «Lưu điểm danh»',
            loc: (p) => p.getByRole('button', { name: 'Lưu điểm danh' }),
            lam: async (p) => {
              await p.getByRole('button', { name: 'Lưu điểm danh' }).click();
              await p.waitForTimeout(2500);
            },
          },
        ],
        DT,
        3,
      );
    },
    // GV5 · 5 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV5-cham-nhan-xet.md (điện thoại). Chấm nhận xét buổi «Hôm nay» lớp …-S-013 sau khi điểm danh (GV3). Bước 5 chỉ chỉ nút «Xuất nhận xét», không tải tệp.
    gv5: (b) => {
      const DT = { width: 390, height: 844 };
      const mo = (p) =>
        p
          .locator('li')
          .filter({ hasText: 'Chấm nhận xét từng em' })
          .getByRole('link', { name: 'Mở' });
      const muc4 = (p) => p.getByRole('button', { name: 'Mức 4', exact: true });
      return chayBai(
        b,
        'gv5',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
          await p.locator('main a').filter({ hasText: 'S-013' }).first().click();
          await cho(p);
          await p.waitForTimeout(1200);
        },
        [
          {
            chu: 'Ở trang «Buổi dạy», bấm «Mở» ở bước 3',
            loc: (p) => mo(p).first(),
            lam: async (p) => {
              await mo(p).first().click();
              await cho(p);
              await p.waitForTimeout(1200);
              // Lần đầu mở buổi: màn hỏi «Mở nhận xét của buổi» (bài chưa nhắc bước này).
              const moNx = p.getByRole('button', { name: 'Mở nhận xét của buổi' });
              if (await moNx.count()) await moNx.click();
              await p.waitForTimeout(2500);
            },
          },
          {
            chu: 'Bấm tên một em, rồi với từng tiêu chí chọn mức 1–5',
            loc: (p) => p.getByRole('button', { name: /Học sinh|\[MẪU\]/ }).first(),
            lam: async (p) => {
              // Em đầu tiên vắng có phép (GV3) không chấm: chọn em có mặt kế tiếp.
              await p
                .getByRole('button', { name: /^\[MẪU\]/ })
                .nth(1)
                .click();
              await p.waitForTimeout(800);
              const n = await muc4(p).count();
              for (let i = 0; i < n; i += 1) {
                await muc4(p).nth(i).click();
                await p.waitForTimeout(250);
              }
            },
          },
          {
            chu: 'Điền «Nhận xét chung» và «Định hướng cải thiện», bấm «Xem trước lời nhắn phụ huynh»',
            loc: (p) => p.getByLabel('Nhận xét chung'),
            lam: async (p) => {
              await p.getByLabel('Nhận xét chung').fill('[MẪU] Tập trung nghe giảng, làm bài tốt.');
              await p.getByLabel('Định hướng cải thiện').fill('[MẪU] Luyện thêm phép nhân.');
              await p.getByRole('button', { name: 'Xem trước lời nhắn phụ huynh' }).click();
              await p.waitForTimeout(1000);
            },
          },
          {
            chu: 'Bấm «Lưu», rồi sang em kế bằng «Em kế ›»',
            loc: (p) => p.getByRole('button', { name: 'Lưu', exact: true }).first(),
            lam: async (p) => {
              await p.getByRole('button', { name: 'Lưu', exact: true }).first().click();
              await p.waitForTimeout(2500);
              await p.getByRole('button', { name: 'Em kế ›' }).first().click();
              await p.waitForTimeout(1000);
            },
          },
          {
            chu: 'Muốn gửi phụ huynh: cuối trang bấm «Xuất nhận xét» hoặc «Xuất cả lớp»',
            loc: (p) => p.getByRole('button', { name: /^Xuất/ }).first(),
            lam: (p) => p.waitForTimeout(1000),
          },
        ],
        DT,
        5,
      );
    },
    // GV6 · 4 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV6-cham-btvn.md (điện thoại). Chấm BTVN buổi trước cho một em có mặt của buổi «Hôm nay» lớp …-S-013.
    gv6: (b) => {
      const DT = { width: 390, height: 844 };
      const dong = (p) => p.locator('li').filter({ hasText: 'Chấm BTVN buổi trước' });
      const em = 'Trần Gia Bảo';
      return chayBai(
        b,
        'gv6',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
          await p.locator('main a').filter({ hasText: 'S-013' }).first().click();
          await cho(p);
          await p.waitForTimeout(1200);
        },
        [
          {
            chu: 'Ở trang «Buổi dạy», nhìn bước 4: có BTVN cần chấm thì hiện nút «Mở»',
            loc: (p) => dong(p).first(),
            lam: (p) => p.waitForTimeout(800),
          },
          {
            chu: 'Bấm «Mở», chọn trạng thái cho từng em',
            loc: (p) => dong(p).getByRole('link', { name: 'Mở' }),
            lam: async (p) => {
              await dong(p).getByRole('link', { name: 'Mở' }).click();
              await cho(p);
              await p.waitForTimeout(1500);
              await p
                .getByRole('group', { name: `Trạng thái BTVN của [MẪU] ${em}` })
                .getByRole('button', { name: /Đã chấm/ })
                .click();
              await p.waitForTimeout(800);
            },
          },
          {
            chu: 'Với em «Đã chấm», chọn điểm 1–5; thêm ghi chú nếu cần',
            loc: (p) => p.getByRole('group', { name: `Điểm 1–5 của [MẪU] ${em}` }),
            lam: async (p) => {
              await p
                .getByRole('group', { name: `Điểm 1–5 của [MẪU] ${em}` })
                .getByRole('button', { name: '4', exact: true })
                .click();
              await p.getByLabel(`Ghi chú cho [MẪU] ${em}`).fill('[MẪU] Làm bài cẩn thận.');
              await p.waitForTimeout(800);
            },
          },
          {
            chu: 'Bấm «Lưu»',
            loc: (p) => p.getByRole('button', { name: 'Lưu', exact: true }).first(),
            lam: async (p) => {
              await p.getByRole('button', { name: 'Lưu', exact: true }).first().click();
              await p.waitForTimeout(2500);
            },
          },
        ],
        DT,
        4,
      );
    },
    // GV7 · 4 bước, cùng thứ tự bài docs/huong-dan/giao-vien/GV7-hoan-tat-buoi.md (điện thoại). Hộp «Hoàn tất buổi» chỉ kiểm việc còn thiếu, không đổi tình trạng buổi (R-GV-08: Done do hệ thống). Buổi mẫu …-S-013 còn thiếu nội dung buổi và nhận xét/BTVN của một em, nên bước 4 dừng ở nút «Hoàn tất» còn mờ.
    gv7: (b) => {
      const DT = { width: 390, height: 844 };
      const hopMo = (p) => p.getByRole('dialog');
      const nutHoanTat = (p) => p.getByRole('button', { name: 'Hoàn tất', exact: true });
      return chayBai(
        b,
        'gv7',
        async (p) => {
          await dangNhap(p);
          await p.goto(`${APP}/gv`);
          await cho(p);
          await p.locator('main a').filter({ hasText: 'S-013' }).first().click();
          await cho(p);
          await p.waitForTimeout(1200);
        },
        [
          {
            chu: 'Cuộn xuống dưới các bước: khung vàng «Kiểm còn thiếu» liệt kê việc chưa làm',
            loc: (p) => p.getByText('Kiểm còn thiếu').first(),
            lam: (p) => p.waitForTimeout(800),
          },
          {
            chu: 'Bấm «Hoàn tất»: tấm trượt «Hoàn tất buổi» hiện việc còn thiếu, nút «Hoàn tất» mờ',
            loc: (p) => nutHoanTat(p).first(),
            lam: async (p) => {
              await nutHoanTat(p).first().click();
              await p.waitForTimeout(1500);
            },
          },
          {
            chu: 'Bấm «Đi tới» ở từng việc, làm xong rồi quay lại trang buổi',
            loc: (p) => hopMo(p).getByRole('link', { name: 'Đi tới' }).first(),
            lam: async (p) => {
              await hopMo(p).getByRole('link', { name: 'Đi tới' }).first().click();
              await cho(p);
              await p.waitForTimeout(2000);
              await p.goBack();
              await cho(p);
              await p.waitForTimeout(1200);
            },
          },
          {
            chu: 'Khi không còn thiếu, bấm «Hoàn tất» trong tấm trượt',
            loc: (p) => nutHoanTat(p).first(),
            lam: async (p) => {
              await nutHoanTat(p).first().click();
              await p.waitForTimeout(2500);
            },
          },
        ],
        DT,
        4,
      );
    },
  };
}
