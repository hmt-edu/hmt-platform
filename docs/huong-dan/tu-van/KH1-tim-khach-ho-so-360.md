---
id: kh1
ten: Tìm khách và xem hồ sơ phụ huynh, học sinh
vai: [tu-van, cskh]
phan_he: Khách hàng
ma_man: [KH-01, KH-02, KH-04, KH-05]
uu_tien: P1
cap_nhat: 2026-11-24
ma_luong: kh1
cong: crm
nguoi_viet: Code B
---

# Tìm khách và xem hồ sơ phụ huynh, học sinh

**Làm xong bạn có:** tìm được đúng phụ huynh hoặc học sinh, đọc được toàn bộ hồ sơ (con, đơn, phiếu thu, lớp, ghi danh, ticket) và biết sửa hoặc nhờ ai khi cần.
**Ai làm:** Tư vấn tuyển sinh, CSKH (Trưởng cơ sở, Kế toán cũng xem được). **Màn:** menu **Khách hàng** → «Phụ huynh», «Học sinh».

> Video: [VIDEO: kh1]
> Không xem được video? Làm theo các bước dưới là đủ.

## Trước khi bắt đầu, kiểm
- [ ] Ô chọn cơ sở ở thanh trên đúng. Bạn chỉ thấy khách của cơ sở mình được phép xem.
- [ ] Biết ít nhất một trong: tên, số điện thoại, mã (phụ huynh), mã cũ (học sinh).

## Luật cần nhớ (lời thường)
- **Không có nút tạo phụ huynh hay học sinh bằng tay.** Hồ sơ phụ huynh tự sinh khi tạo cơ hội (khớp theo số điện thoại; trùng số thì dùng hồ sơ có sẵn). Hồ sơ học sinh tự sinh khi tạo phiếu kiểm tra hoặc khi đơn hàng được duyệt. Muốn có khách mới, tạo lead rồi cơ hội.
- Hồ sơ **«Cơ sở tiếp nhận»** bạn chỉ xem; đổi cơ sở do Admin làm qua ticket «Chuyển cơ sở».
- Hồ sơ đã gộp (trùng với hồ sơ khác) chỉ xem được, hãy mở hồ sơ còn lại.
- Xuất danh sách chỉ Admin làm được.

## Các bước
1. Vào **Khách hàng** → **Phụ huynh**. Gõ vào ô «Tìm tên, số điện thoại, mã…», hoặc dùng bộ lọc «Tình trạng» («Có con đang học», «Chưa có con đang học»), «Cơ sở tiếp nhận», «Đang học tại».
   *Bạn thấy:* danh sách có cột «Mã», «Họ tên», «Tình trạng», «Cơ sở tiếp nhận», «Đang học tại», «SĐT», «Số con». Không có kết quả thì hiện «Chưa có phụ huynh».
   [ẢNH: kh01-kh1-b1] [CHƯA CHỤP: cần chụp trên staging CS5]
2. Bấm một dòng để mở **hồ sơ phụ huynh**. Các tab: «Tổng quan», «Các con», «Đơn hàng», «Phiếu thu», «Ticket», «Tài chính». Khối «Thông tin phụ huynh» có tỉnh/thành, phường/xã, «Cơ sở tiếp nhận», «Đang học tại».
   *Bạn thấy:* các nút liên kết có số đếm: «Con», «Cơ hội», «Phiếu test», «Ghi danh», «Phiếu thu». Nút «Cơ hội», «Phiếu test», «Ghi danh» có thể mờ kèm chỉ dẫn mở từ menu Tuyển sinh hoặc Đào tạo.
   [ẢNH: kh02-kh1-b2] [CHƯA CHỤP: cần chụp trên staging CS5]
3. Xem các con: tab **«Các con»**, bấm tên con để mở hồ sơ học sinh. Tab «Đơn hàng» và «Phiếu thu» cho biết phụ huynh đã mua và đóng gì. Không có dữ liệu thì hiện «Chưa có học sinh», «Chưa có đơn hàng», «Chưa có phiếu thu».
   *Bạn thấy:* danh sách con, đơn, phiếu thu của đúng phụ huynh đó.
4. Muốn tìm học sinh: **Khách hàng** → **Học sinh**, ô «Tìm tên, mã, mã cũ…», lọc «Tình trạng», «Cơ sở tiếp nhận», «Khối». Cột «Phụ huynh» và «SĐT phụ huynh» có thể bật ở nút chọn cột.
   *Bạn thấy:* danh sách học sinh; «Chưa có học sinh» nếu chưa có.
   [ẢNH: kh04-kh1-b4] [CHƯA CHỤP: cần chụp trên staging CS5]
5. Mở **hồ sơ học sinh** (hồ sơ 360°). Các tab: «Tổng quan», «Học tập», «Điểm danh», «Điểm kiểm tra», «Chăm sóc» (chưa có dữ liệu), «Đề nghị & khiếu nại». Khối «Thông tin học sinh» có «Họ tên», «Ngày sinh», «Năm sinh», «Khối», «Trường học», «Mục tiêu», «Phụ huynh», «Tình trạng».
   *Bạn thấy:* các nút liên kết «Ghi danh», «Lớp», «Phiếu test» có số đếm; «Điểm kiểm tra trong lớp» và «Phiếu kiểm tra đầu vào» ở các tab tương ứng.
   [ẢNH: kh05-kh1-b5] [CHƯA CHỤP: cần chụp trên staging CS5]
6. Cần sửa thông tin: menu **«Hành động» → «Sửa»**, đổi ô cần đổi rồi lưu (báo «Đã lưu.»). Học sinh: **năm sinh bắt buộc**.
   *Bạn thấy:* các ô chuyển sang nhập được; «Cơ sở tiếp nhận» vẫn chỉ đọc.
7. Việc khác trong menu «Hành động»: **«Gộp»** (hai hồ sơ cùng một người, cần quyền Duyệt), **«Tạo ticket»** (phụ huynh: mở ticket cho CSKH; ở hồ sơ học sinh hiện còn mờ «Ticket chăm sóc làm sau»), «Cấp tài khoản» (học sinh; còn mờ «Tài khoản học tập chưa bật»). Mục nào mờ, rê chuột đọc lý do.
   *Bạn thấy:* mục mờ kèm câu giải thích.

## Sau bước này
- **Ai làm tiếp:** phụ huynh xin bảo lưu, chuyển lớp, hoàn phí → CSKH tạo ticket (bài CSKH). Hồ sơ trùng cần gộp → người có quyền Duyệt (thường Trưởng cơ sở).
- **Bạn xem ở đâu:** tìm nhanh bằng ô tìm kiếm chung ở thanh trên; kết quả «Khách hàng» mở thẳng hồ sơ phụ huynh.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Sửa sai thông tin | Vào «Sửa» lại và nhập đúng giá trị |
| Sửa nhầm hồ sơ người khác | Sửa lại đúng giá trị; không rõ giá trị cũ thì báo Trưởng cơ sở |
| Gộp nhầm | Liên hệ Admin, không tự gỡ được |
| Không thấy khách | Kiểm cơ sở ở thanh trên và bộ lọc đang bật; tìm theo số điện thoại |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Hồ sơ đã gộp chỉ xem được» | hồ sơ đã gộp vào hồ sơ khác | mở hồ sơ còn lại |
| «Bạn không có quyền sửa phụ huynh» / «…sửa học sinh» | vai không có quyền Sửa | nhờ CSKH hoặc Trưởng cơ sở |
| «Bạn không có quyền gộp (cần quyền Duyệt)» | gộp cần quyền Duyệt | nhờ Trưởng cơ sở |
| «Bạn không có quyền xem ticket» | vai không xem ticket | nhờ CSKH |
| Báo «không có quyền» khi mở hồ sơ | khách thuộc cơ sở khác | báo Trưởng cơ sở |

## Hỏi đáp
- **Muốn tạo phụ huynh mới thì sao?** Tạo lead rồi tạo cơ hội: hồ sơ phụ huynh tự sinh. Hồ sơ học sinh sinh khi tạo phiếu kiểm tra hoặc duyệt đơn.
- **Một phụ huynh có con học hai cơ sở?** Cột «Đang học tại» liệt kê các cơ sở đó.
- **Muốn xuất danh sách?** Chỉ Admin có nút xuất.

## Tập trên dữ liệu mẫu
- **Cần:** `sale.cs5` và `cskh.cs5`.
- **Dùng:** phụ huynh «[MẪU] …» (số điện thoại dải 0999 000 …). Tìm theo số, mở hồ sơ, xem tab «Các con».

## Tự kiểm: bạn làm được khi
- [ ] Tìm ra một phụ huynh «[MẪU]» bằng số điện thoại và mở được hồ sơ con.
- [ ] Bạn nói được vì sao không có nút «Tạo» phụ huynh và ai đổi được cơ sở tiếp nhận.

**Bước trước:** Tạo lead nhanh · **Bước sau:** Ticket chăm sóc (bài CSKH)
