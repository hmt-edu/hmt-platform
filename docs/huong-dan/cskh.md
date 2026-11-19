# Hướng dẫn cho CSKH (cổng CRM)

Vai: CSKH (chăm sóc khách hàng, vận hành lớp). Menu: **Khách hàng** (Phụ huynh, Học sinh), **Đào tạo** (Ghi danh, Lớp, Buổi học, Điểm danh trong ngày), **Chăm sóc KH** (Tất cả ticket, Phiếu nghiệp vụ). Xem `README.md` về cách đọc.

## 1. Tìm khách và xem hồ sơ
- **Mục đích:** tìm phụ huynh, học sinh; xem toàn cảnh một em.
- **Ai làm:** CSKH, mọi vai CRM trong cơ sở.
- **Các bước:** 1) **Phụ huynh** (`/crm/phu-huynh`) hoặc **Học sinh** (`/crm/hoc-sinh`). 2) Gõ tên hoặc số điện thoại vào ô tìm; lọc theo tình trạng (Tiềm năng, Đang học, Bảo lưu, Dừng học), khối, lớp. 3) Bấm một dòng để mở hồ sơ: phụ huynh có các con, đơn, phiếu thu, số dư, ticket; học sinh có ghi danh, quỹ giờ, lớp đang học, điểm danh, nhận xét, BTVN, ticket.
- **Kết quả mong đợi:** thấy đúng khách của cơ sở mình; không có nút xuất (chỉ Admin).
- **Lỗi thường gặp:** không thấy khách → kiểm cơ sở và bộ lọc; `HMT_KHONG_CO_QUYEN` → khách của cơ sở khác. **Ảnh:** [ẢNH: phu-huynh-ds], [ẢNH: hoc-sinh-ho-so]

## 2. Xếp lớp cho ghi danh
- **Mục đích:** đưa ghi danh đang chờ vào lớp.
- **Ai làm:** CSKH (hoặc Trưởng cơ sở).
- **Các bước:**
  1. **Ghi danh** (`/crm/ghi-danh`) hoặc hàng chờ **Chờ xếp lớp** (`/crm/cho-xep-lop`): chỉ ghi danh ở «Chờ xếp lớp».
  2. Mở một ghi danh. Bấm **«Xếp lớp»**; chọn lớp đã duyệt (theo nhóm lớp hoặc từng lớp), chọn ngày vào lớp; xác nhận.
  3. Kiểm lại ở «Dòng xếp lớp» (Lớp, Ngày vào, Ngày rời, Giờ đã học tại lớp) và «Quỹ giờ» (Giờ cấp, Giờ tặng, Còn lại). Bấm **«Sổ giờ»** để xem từng dòng cộng/trừ giờ (chỉ xem).
- **Kết quả mong đợi:** ghi danh sang «Đã xếp lớp»; lớp hiện học sinh mới; sĩ số còn chỗ giảm.
- **Lỗi thường gặp:**

| Thấy gì | Làm gì |
|---|---|
| Lớp không hiện trong danh sách | lớp chưa duyệt, hết chỗ, hoặc sai môn/khối/cơ sở: chọn lớp khác |
| Báo trùng giờ học | em đã có lớp trùng giờ: đổi lớp hoặc ngày vào |
| Xếp xong vẫn «Chờ xếp lớp» | tải lại trang; nếu vẫn thế báo Chat kèm mã ghi danh |

- **Ảnh:** [ẢNH: ghi-danh-cho-xep], [ẢNH: ghi-danh-xep-lop], [ẢNH: ghi-danh-so-gio]. Điều chỉnh giờ («Điều chỉnh giờ») là việc của Trưởng cơ sở: xem `truong-co-so.md`.

## 3. Tạo lớp và trình duyệt
- **Mục đích:** lập lớp mới cho Trưởng cơ sở duyệt.
- **Ai làm:** CSKH soạn và trình; Trưởng cơ sở xác nhận và duyệt.
- **Các bước:** 1) **Lớp** (`/crm/lop`) → tạo lớp (`/crm/lop/tao`). 2) Điền môn, khối, loại, sĩ số tối đa, ngày khai giảng, tổng số buổi; thêm thời khoá biểu (thứ, giờ, giáo viên, phòng). 3) **«Lưu nháp»**: lớp ở «Nháp». 4) Ở bản ghi lớp bấm **«Trình»**. Trưởng cơ sở sẽ xác nhận và duyệt; duyệt xong lớp tự sinh các buổi.
- **Kết quả mong đợi:** lớp từ Nháp sang Đã trình; sau duyệt có buổi học. Chỉ sửa được khi Nháp hoặc Từ chối.
- **Lỗi thường gặp:** thiếu thời khoá biểu thì không duyệt được (câu lý do hiện trên màn); trùng phòng hoặc giáo viên chỉ **cảnh báo**, không chặn. **Ảnh:** [ẢNH: lop-tao], [ẢNH: lop-trinh]

## 4. Buổi học và điểm danh vận hành
- **Mục đích:** theo dõi buổi hôm nay, gọi nhắc em vắng, ghi lý do liên hệ.
- **Ai làm:** CSKH.
- **Các bước:** 1) **Điểm danh trong ngày** (`/crm/diem-danh-trong-ngay`): các buổi hôm nay, em chưa tới hoặc vắng. 2) Ghi trạng thái phía vận hành và **lý do liên hệ** (Không nghe máy, Đã nhắc…), có thể ghi hàng loạt. 3) Mở **Buổi học** (`/crm/buoi-hoc`) → bản ghi buổi: cột «Trung tâm điểm danh» và «Điểm danh giáo viên (chính thức)»; «Lệch» đánh dấu hai bên khác nhau. 4) Buổi cần thêm em học thử: «Thêm học thử». Buổi cần chốt: «Chốt danh sách».
- **Kết quả mong đợi:** điểm danh vận hành lưu riêng; giáo viên quyết định chính thức ở cổng giáo viên.
- **Lỗi thường gặp:** không sửa được điểm danh chính thức (việc của giáo viên; sửa sau Done do Trưởng cơ sở bằng «Sửa điểm danh»). **Ảnh:** [ẢNH: diem-danh-trong-ngay], [ẢNH: buoi-ban-ghi]

## 5. Tạo ticket và theo dõi
- **Mục đích:** ghi nhận đề nghị, khiếu nại của phụ huynh và xử lý đúng hạn.
- **Ai làm:** CSKH.
- **Các bước:**
  1. **Tất cả ticket** (`/crm/ticket`): lọc Đề nghị, Khiếu nại, Giáo viên, Chờ đóng, Sắp quá hạn, Quá hạn, Của tôi; đổi sang Kanban để xem theo bước.
  2. Tạo ticket (`/crm/ticket/moi`): chọn loại, kênh, người gửi, nhóm và nhóm con, học sinh (nếu có), mô tả.
  3. Mở ticket. Nút «Giao ticket» chọn đội và người phụ trách; «Phân loại lại» đổi loại, nhóm, mức độ; thanh trạng thái chuyển bước (Mới → Đã giao → Đang xử lý → Đã xử lý → Đã đóng).
  4. Chuyển «Đã xử lý» phải ghi **Kết quả**; chuyển «Đã huỷ» (nút «Huỷ ticket») phải ghi lý do; **đóng khiếu nại** phải chọn mức hài lòng 1–5; đóng ticket có nghiệp vụ đi kèm là «Đóng ticket làm tay» và cần ghi chú; ticket đã đóng mở lại bằng cách bấm bước «Đang xử lý» trên thanh trạng thái, hộp «Mở lại ticket» bắt buộc ghi lý do mở lại (trong số ngày cho phép); nút xác nhận của huỷ là «Huỷ ticket», của mở lại là «Mở lại».
- **Kết quả mong đợi:** ticket có mã, hạn xử lý theo loại và mức độ; dòng thời gian ghi mọi thay đổi.
- **Lỗi thường gặp:**

| Mã | Câu trên màn | Làm gì |
|---|---|---|
| `HMT_TICKET_THIEU_KET_QUA` | «Chuyển sang Đã xử lý cần ghi kết quả.» | điền ô Kết quả |
| `HMT_TICKET_THIEU_LY_DO` | «Huỷ ticket cần ghi lý do.» | điền lý do huỷ |
| `HMT_TICKET_THIEU_HAI_LONG` | «Đóng khiếu nại cần ghi mức hài lòng của phụ huynh từ 1 đến 5.» | chọn mức 1–5 |
| `HMT_TICKET_QUA_HAN_MO_LAI` | «Đã quá số ngày cho phép mở lại ticket.» | tạo ticket mới |

- **Ảnh:** [ẢNH: ticket-ds], [ẢNH: ticket-kanban], [ẢNH: ticket-ban-ghi], [ẢNH: ticket-doi-trang-thai]

## 6. Phiếu nghiệp vụ (cập nhật hồ sơ, bảo lưu, chuyển lớp, hoàn học phí)
- **Mục đích:** làm thay đổi thật (sửa hồ sơ, bảo lưu, chuyển lớp, hoàn tiền) qua phiếu có người duyệt.
- **Ai làm:** CSKH tạo và **«Trình duyệt»**; Trưởng cơ sở duyệt (hoàn học phí thêm Kế toán); người tạo bấm **«Thực hiện»** khi phiếu Đã duyệt.
- **Các bước:** 1) Mở ticket có nhóm con gắn nghiệp vụ → bấm **«Tạo phiếu»** (mỗi ticket một phiếu đang mở). 2) Điền: Cập nhật hồ sơ (chọn hồ sơ và trường mới); Bảo lưu (ghi danh, lý do, số tháng); Chuyển lớp (ghi danh, loại chuyển, lớp mới, buổi bắt đầu); mọi loại cần lý do. 3) Vào **Phiếu nghiệp vụ** → mở phiếu → **«Trình duyệt»**. 4) Khi Đã duyệt bấm **«Thực hiện»** (hộp xác nhận). 5) Nếu bị «Từ chối», sửa theo lý do; «Huỷ phiếu» khi nhập nhầm.
- **Kết quả mong đợi:** phiếu Đã thực hiện; ticket tự sang «Đã xử lý», người phụ trách đóng tay.
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_PHIEU_DA_CO` | ticket đã có phiếu đang mở: xong hoặc huỷ phiếu đó trước |
| `HMT_PHIEU_DU_LIEU_SAI` | thiếu ghi danh, lý do, số tháng, lớp mới…: điền đủ rồi tạo lại |
| `HMT_PHIEU_TU_DUYET` | người tạo không tự duyệt phiếu của mình |
| `HMT_PHIEU_TRANG_THAI_SAI` | chỉ thực hiện phiếu đã duyệt |
| `HMT_TINH_NANG_TAT` | phân hệ (Bảo lưu, Chuyển lớp, Hoàn phí) chưa bật ở cơ sở: báo Trưởng cơ sở/Admin |

- Chuyển cơ sở và các loại phiếu khác (Chuyển phí, Đổi lịch, Dừng học) **chưa làm được** ở bản hiện tại; câu báo chưa làm hiện trên màn.
- **Ảnh:** [ẢNH: phieu-tao-tu-ticket], [ẢNH: phieu-trinh-duyet], [ẢNH: phieu-thuc-hien]
