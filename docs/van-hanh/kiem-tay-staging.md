# Kiểm tay trên staging: 28 màn LÕI (cho anh Trường)

Soạn 19/11/2026 (Code B, thẻ B21), theo `docs/ke-hoach/ke-hoach-17-11.md` mục 1 (28 màn LÕI). Mục đích: anh tự đi một học sinh giả trọn đường trên màn hình, không dùng SQL, và tick từng ô. Việc anh làm trên **staging** (môi trường thử nghiệm); không làm trên bản chạy thật.

## Trước khi kiểm
- **Chỉ dữ liệu giả.** Tên, số điện thoại, học sinh trên staging là dữ liệu giả; không nhập dữ liệu thật của học sinh hay phụ huynh. Nếu cần tạo thêm, đặt tên có chữ «giả» hoặc «thử».
- **Tài khoản giả** (danh sách ở `scripts/seed-users.ts`; mật khẩu do anh giữ, không ghi vào tài liệu):

| Vai | Tên đăng nhập | Dùng cho |
|---|---|---|
| Trưởng cơ sở CS5 | `truongcs.cs5` | duyệt lớp, đóng/huỷ lớp, điều chỉnh, huỷ và dời buổi, duyệt phiếu thu bước quản lý |
| CSKH CS5 | `cskh.cs5` | ghi danh, xếp lớp, tạo lớp, điểm danh vận hành |
| Sale CS5 | `sale.cs5` | báo giá, đơn hàng, chọn lớp cho dòng đơn |
| Kế toán CS5 | `ketoan.cs5` | duyệt phiếu thu bước kế toán, khoản tiền vào, công nợ (cần thiết lập hai bước lần đầu) |
| Admin CS5 | `quantri.cs5` | xem mọi màn, xuất file (cần thiết lập hai bước lần đầu) |
| Giáo viên CS5 | `gv.cs5` | điểm danh, nội dung buổi, chấm nhận xét, chấm BTVN (cổng Giáo viên, nên thử trên điện thoại) |
| Trợ giảng CS5 | `tg.cs5` | như giáo viên ở buổi được phân công |

- **Cách ghi:** mỗi ô `[ ]` tick `[x]` khi đúng; lệch thì ghi một dòng «màn, bước, thấy gì» và chụp ảnh, gửi Chat. Địa chỉ ghi dạng `/crm/...` là đường dẫn sau tên miền staging.
- Máy tính: Chrome. Điện thoại: chỉ các màn có chữ «điện thoại».

## Đường đi của một học sinh mới (làm theo thứ tự)
Tên gọi chung dưới đây: **Phụ huynh A**, **Em A** là hồ sơ giả có sẵn hoặc anh tạo từ Lead (đã kiểm ở cụm Tuyển sinh, không thuộc 28 màn này).

### Cụm 1 · Khách hàng (4 màn)
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **KH-01** Phụ huynh (danh sách), `/crm/phu-huynh` | `cskh.cs5` | 1) Đăng nhập. 2) Mở danh sách phụ huynh. 3) Gõ tên (hoặc 4 số cuối) vào ô tìm. | Chỉ phụ huynh của cơ sở mình; có thanh tìm, lọc; không có nút Xuất (chỉ Admin có). Có trạng thái đang tải rồi danh sách. | [ ] |
| **KH-02** Phụ huynh (bản ghi), `/crm/phu-huynh/:id` | `cskh.cs5` | Bấm một dòng ở KH-01. | Thấy thông tin, các con, đơn, phiếu thu, số dư, ticket; các nút liên kết có số đếm; có Sửa, Gộp, Tạo ticket (không có Tạo tay). | [ ] |
| **KH-04** Học sinh (danh sách), `/crm/hoc-sinh` | `cskh.cs5` | Mở danh sách học sinh; lọc theo tình trạng (Tiềm năng, Đang học…), khối, lớp. | Lọc đúng; học sinh chưa ghi danh có tình trạng «Tiềm năng». Không có nút Xuất (chỉ Admin). | [ ] |
| **KH-05** Học sinh (hồ sơ 360°), `/crm/hoc-sinh/:id` | `cskh.cs5` | Bấm Em A ở KH-04. | Thấy ghi danh, quỹ giờ, lớp đang học, điểm danh, nhận xét, BTVN, ticket; hồ sơ Tiềm năng thì chưa có ghi danh. | [ ] |

### Cụm 2 · Lớp (6 màn): tạo lớp trước để có chỗ xếp học sinh
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **LOP-03** Tạo lớp, `/crm/lop/tao` | `cskh.cs5` | Bấm Tạo ở danh sách lớp. Chọn môn, khối, loại, sĩ số tối đa, ngày khai giảng, tổng số buổi; thêm thời khoá biểu (thứ, giờ, giáo viên, phòng). Lưu. | Form trắng khi mở; thiếu trường bắt buộc thì báo tại ô; lưu xong lớp ở tình trạng **Nháp**, có mã lớp. Chỉ sửa được khi Nháp hoặc Từ chối. | [ ] |
| **LOP-01** Danh sách lớp, `/crm/lop` | `cskh.cs5` | Mở danh sách lớp; xem chế độ danh sách và chế độ cột theo bước duyệt. | Lớp vừa tạo ở Nháp; lọc theo cơ sở, môn, khối; sĩ số, còn chỗ đúng. | [ ] |
| **LOP-02** Lớp (bản ghi), `/crm/lop/:id` | `cskh.cs5` | Bấm lớp vừa tạo. | Thanh duyệt, thông tin, thời khoá biểu, danh sách học sinh (dòng xếp lớp), các buổi. | [ ] |
| **LOP-05** Trình, xác nhận, duyệt lớp | `cskh.cs5` rồi `truongcs.cs5` | CSKH bấm **Trình**; đăng nhập Trưởng cơ sở, bấm **Xác nhận** rồi **Duyệt**. Thử Duyệt khi chưa có thời khoá biểu. | Duyệt khi thiếu thời khoá biểu bị chặn kèm lý do. Duyệt xong lớp «Đã duyệt» và **tự sinh các buổi** (có xem trước số buổi). | [ ] |
| **LOP-08** Lịch tuần cơ sở, `/crm/lich-tuan` | `truongcs.cs5` | Mở lịch tuần; chuyển xem theo phòng, theo giáo viên. | Thấy buổi của lớp vừa duyệt; trùng phòng hoặc trùng giáo viên chỉ **cảnh báo, không chặn**. | [ ] |
| **LOP-06** Đóng, huỷ lớp | `truongcs.cs5` | Ở một lớp thử (không dùng lớp đang chạy cả đường), bấm Đóng hoặc Huỷ khi còn học sinh còn giờ hoặc đã có buổi Done. | Bị chặn và **liệt kê lý do** (tên em còn giờ; buổi đã Done). Lớp thử không có em thì đóng/huỷ được. | [ ] |

### Cụm 3 · Ghi danh (6 màn): từ đơn đến xếp lớp
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **BH-08** Chọn lớp và ngày vào lớp, trong đơn `/crm/don-hang/:id` | `sale.cs5` | Mở một đơn **Đã duyệt** (hoặc đơn nháp), bấm Sửa, ở dòng đơn bấm **Chọn lớp**; chọn lớp rồi một buổi sắp tới hoặc ngày đúng thứ; **Lưu đơn**. | Chỉ lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở; chọn xong chưa lưu thì chưa ghi vào đơn; bấm Huỷ sửa thì bỏ lựa chọn. | [ ] |
| **GD-01** Ghi danh (danh sách), `/crm/ghi-danh` | `cskh.cs5` | Duyệt xong phiếu thu của đơn (kế toán duyệt bước cuối) rồi mở danh sách ghi danh. | Mỗi dòng đơn đã thu thành một ghi danh; tình trạng Chờ xếp lớp hoặc Đã xếp lớp; có cột giờ còn. | [ ] |
| **GD-06** Hàng chờ xếp lớp, `/crm/cho-xep-lop` | `cskh.cs5` | Mở hàng chờ. | Chỉ ghi danh ở **Chờ xếp lớp**, lý do chờ là «chưa có lớp». | [ ] |
| **GD-03** Xếp lớp | `cskh.cs5` | Từ hàng chờ (hoặc GD-02) bấm **Xếp lớp**; chọn lớp đã duyệt (theo nhóm lớp hoặc từng lớp); xác nhận. | Mỗi ghi danh một lớp; lớp hết chỗ hoặc trùng giờ thì báo; xếp xong tình trạng sang **Đã xếp lớp**. | [ ] |
| **GD-02** Ghi danh (bản ghi), `/crm/ghi-danh/:id` | `cskh.cs5` | Mở ghi danh vừa xếp. | Quỹ giờ (cấp, đã dùng, còn, tặng), dòng xếp lớp, ngày hết giờ dự kiến, hình thức học; có Xếp lớp (khi chưa xếp). | [ ] |
| **GD-04** Sổ giờ của ghi danh, `/crm/ghi-danh/:id/so-gio` | `cskh.cs5` | Ở GD-02 bấm Sổ giờ. | Mọi dòng cộng/trừ giờ có nguồn (buổi, phiếu thu, điều chỉnh); chỉ xem, không sửa; có thể xuất. | [ ] |

### Cụm 4 · Buổi (7 màn)
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **BUOI-01** Buổi học (danh sách), `/crm/buoi-hoc` | `cskh.cs5` | Mở; mặc định ngày hôm nay; lọc ngày, lớp, giáo viên, tình trạng. | Buổi chưa Done kèm lý do; lọc đúng. | [ ] |
| **BUOI-02** Buổi học (bản ghi), `/crm/buoi-hoc/:id` | `cskh.cs5` | Bấm một buổi. | Thanh Nháp → Đã chốt → Done và nhánh huỷ; loại buổi; danh sách em; em không vào danh sách có lý do; hai cột điểm danh (vận hành, giáo viên chính thức). | [ ] |
| **BUOI-03** Điểm danh vận hành, `/crm/diem-danh/buoi/:id` | `cskh.cs5` | Từ BUOI-02 mở điểm danh vận hành; ghi trạng thái và **lý do liên hệ** (Không nghe máy, Đã nhắc…); Lưu. Thử cả điện thoại. | Lưu được; ô «giáo viên quyết định chính thức» chỉ xem. | [ ] |
| **BUOI-11** Điểm danh trong ngày, `/crm/diem-danh-trong-ngay` | `cskh.cs5` | Mở; xem em chưa tới hoặc vắng; ghi lý do liên hệ hàng loạt. | Chỉ buổi hôm nay; ghi lý do được, mở buổi được. | [ ] |
| **BUOI-04** Huỷ buổi | `truongcs.cs5` | Ở BUOI-02 của một buổi **chưa diễn ra** bấm Huỷ buổi: thử «trung tâm huỷ» và «học sinh huỷ lớp riêng». | Trung tâm huỷ: không tính phí, tự thêm buổi cuối, dời bài. Lớp riêng: bắt buộc lý do và chọn có/không tính phí. | [ ] |
| **BUOI-05** Dời một buổi | `truongcs.cs5` | Ở BUOI-02 của buổi chưa diễn ra bấm Dời; đổi ngày, giờ, phòng. | Trùng phòng hoặc trùng giáo viên chỉ **cảnh báo, không chặn**; xác nhận được. | [ ] |
| **BUOI-12** Buổi chưa Done, `/crm/buoi-chua-done` | `truongcs.cs5` | Mở; xem buổi kẹt ở Đã chốt. | Mỗi dòng có lý do kẹt; có «Nhắc giáo viên» và «Mở buổi»; giáo viên sắp trễ hạn được đánh dấu. | [ ] |

### Cụm 5 · Thu tiền (2 màn)
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **TC-08** Khoản tiền vào, `/crm/khoan-tien-vao` | `ketoan.cs5` | Mở sau khi kế toán đã duyệt một phiếu thu. | Khoản sinh **tự động** khi duyệt phiếu; khoản đảo trỏ về khoản gốc; chỉ đọc (đảo khoản chỉ Kế toán). | [ ] |
| **TC-13** Công nợ, `/crm/cong-no` | `ketoan.cs5` | Mở; xem tab sắp đến hạn, quá hạn. | Đơn còn phải thu theo lịch từng đợt; đợt đã đóng đủ không hiện; mở được đơn. | [ ] |

### Cụm 6 · Giáo viên (3 màn, cổng `/gv`, nên thử trên điện thoại)
| Màn | Tài khoản | Các bước | Kết quả mong đợi | Tick |
|---|---|---|---|---|
| **GV-05** Điểm danh, `/gv/buoi/:id/diem-danh` | `gv.cs5` | Đăng nhập cổng Giáo viên, mở buổi hôm nay của lớp mình, Điểm danh. | Bốn trạng thái: Có mặt, Đi muộn, Vắng có phép, Vắng không phép; trống là chưa; có nút «Còn lại: Có mặt»; thấy ghi chú vận hành; Lưu được. | [ ] |
| **GV-07** Chấm nhận xét, `/gv/buoi/:id/cham-nhan-xet` | `gv.cs5` | Sau điểm danh, chấm nhận xét từng em: Thái độ, Kiến thức, Vận dụng (thang 1–5); lời nhắn phụ huynh. | Điện thoại: từng em; máy tính: bảng chấm nhanh; **trống khác 0**; thang có mô tả mức; lưu được. | [ ] |
| **GV-08** Chấm BTVN của buổi trước, `/gv/buoi/:id/cham-btvn` | `gv.cs5` | Mở chấm BTVN; chọn trạng thái từng em; thử «Nộp sau» cho bài cũ. | Năm trạng thái (Đã chấm, Làm chưa xong, Không làm, Nộp sau, Không áp dụng); cập nhật bài «Nộp sau» **không mở lại buổi cũ**; buổi trước không giao BTVN thì có chữ báo. | [ ] |

## Kết thúc
- Đóng buổi: giáo viên lưu đủ các mục thì buổi sang **Done** (kiểm ở BUOI-02: dấu Đúng hạn hoặc Trễ hạn, chỉ ghi một lần).
- Đếm: 4 + 6 + 6 + 7 + 2 + 3 = **28 màn**. Tất cả tick thì cụm LÕI đạt phần kiểm tay.
- Gặp lỗi: ghi mã màn (ví dụ GD-03), bước đang làm, thấy gì (kèm ảnh), gửi Chat; không sửa tay trong cơ sở dữ liệu.
