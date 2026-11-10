# Hướng dẫn nạp dữ liệu đào tạo ngày 17/11/2026

Dành cho người chuẩn bị file và người nạp dữ liệu. Không cần biết lập trình. Chỉ quản trị viên (Admin) được nạp. Diễn tập trên staging trước (14/11); nạp thật trên bản chạy thật do anh Trường làm.

## 1. Ai làm gì

| Việc | Ai | Khi nào |
| --- | --- | --- |
| Điền file mẫu bằng dữ liệu thật của cơ sở | Người phụ trách dữ liệu của cơ sở, anh Trường duyệt | Trước 13/11 |
| Diễn tập trên staging bằng file dữ liệu GIẢ | Admin | 14/11 |
| Nạp thật trên bản chạy thật | Anh Trường | 17/11 |

File mẫu: `docs/van-hanh/mau/HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` (toàn dữ liệu giả). Không đưa file có tên, số điện thoại thật vào repo, vào chat hay vào staging. File thật chỉ nằm trên máy anh Trường.

## 2. Thứ tự nạp

Nạp đúng thứ tự, vì tab sau cần tab trước đã có:

1. Người dùng (giáo viên cần có mã nhân sự dạng GV2001).
2. **Lớp** (tab 03_LOP).
3. Phụ huynh (01_PHUHUYNH) rồi Học sinh (02_HOCSINH).
4. **Ghi danh** (tab 04_GHIDANH): tạo ghi danh, xếp lớp và dòng "Số dư đầu kỳ" cho giờ còn lại.
5. Số dư học phí bằng tiền (tab 09_SODU) do phần Bán hàng, Thu chi nạp, không nằm trong hướng dẫn này.
6. **Buổi học** (07_BUOIHOC) và **Điểm danh** (08_DIEMDANH): chỉ để đối soát, không tạo buổi, không trừ giờ.

Mỗi tab: bấm **Xem trước** trước. Xem trước không ghi gì; chỉ khi báo cáo không còn lỗi (hoặc lỗi đã hiểu rõ) mới bấm **Nạp**.

## 3. Cột bắt buộc

### Tab 03_LOP (Lớp)

| Cột | Điền gì | Bắt buộc |
| --- | --- | --- |
| ma_lop_cu | Mã lớp ở hệ thống cũ, ví dụ 4M1. Không đổi sau khi nạp | Có |
| loai_lop | "Lớp chung" hoặc "Lớp riêng" | Có |
| phan_loai | CB (Cơ bản) hoặc NC (Nâng cao). Lớp riêng để trống | Lớp chung |
| trinh_do | S, A, B... (theo danh mục Trình độ). Lớp riêng để trống | Lớp chung |
| nam_hoc | 4 số, ví dụ 2627 cho năm 2026-2027 | Có |
| mon, khoi | Môn (Toán, Vật lý...) và khối (số 2 đến 12) | Có |
| lich_hoc | Đúng dạng `Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)`. Nhiều khung ngăn bằng dấu `;`. Chủ nhật viết `Chủ nhật` | Có |
| so_buoi | **Số buổi CÒN LẠI kể từ 17/11/2026**, không phải tổng số buổi cả khoá | Có |
| ma_gv | Số nhân sự của giáo viên, ví dụ 2001 (hệ thống ghép với mã GV2001) | Nên có |
| ngay_khai_giang, si_so_toi_da, tinh_trang, co_so | Ngày khai giảng gốc, sĩ số, "Đang chạy" hoặc "Đã đóng", mã cơ sở (CS1...) | Có |

Hệ thống chỉ sinh buổi từ 17/11/2026 trở đi. Buổi trước ngày đó không được sinh, nên không bị trừ giờ lần hai.

### Tab 04_GHIDANH (Ghi danh)

| Cột | Điền gì | Bắt buộc |
| --- | --- | --- |
| hoc_sinh_ma_cu, ma_lop_cu | Mã học sinh cũ và mã lớp cũ (lớp, học sinh đã nạp) | Có |
| tinh_trang_moi | Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí hoặc Chờ xếp lớp | Có |
| ngay_vao_lop | yyyy-mm-dd | Với Đang học, Bảo lưu |
| thoi_luong_buoi | Số giờ mỗi buổi, ví dụ 2.5 | Có |
| gio_du_kien, gio_da_hoc, gio_con_lai | Giờ đã mua, đã học, còn lại. **gio_con_lai phải đúng bằng gio_du_kien trừ gio_da_hoc** | Có |

Mỗi dòng ghi danh sinh **một** dòng "Số dư đầu kỳ" bằng gio_con_lai, mang ngày 17/11/2026.

### Tab 07_BUOIHOC và 08_DIEMDANH

Giữ nguyên cột như file mẫu. Buổi nghỉ lễ ghi tình trạng "Huỷ không tính phí": hệ thống ghi nhận là buổi huỷ, không điểm danh, giờ trừ 0, không tạo buổi bù. Cột `tinh_gio` của tab 08 ghi "Có" hoặc "Không" (x, P, KP, M tính giờ; N không tính).

## 4. Đọc báo cáo sau khi bấm Xem trước hoặc Nạp

Báo cáo cho biết: số dòng hợp lệ, số dòng trùng (đã nạp trước đó, bỏ qua, không ghi đè), số dòng lỗi.

- **Lỗi theo từng loại**: mỗi loại lỗi kèm danh sách số dòng.
- **Lớp chưa có giáo viên**: danh sách mã lớp cũ chưa ghép được giáo viên. Lớp vẫn được nạp, nhưng khung giờ chưa có giáo viên: cần gán sau.

## 5. Lỗi thường gặp và cách sửa

| Thông báo | Nghĩa là | Cách sửa rồi nạp lại |
| --- | --- | --- |
| Thiếu giá trị cột X | Ô bắt buộc để trống | Điền ô đó trong file |
| Lịch học sai dạng | `lich_hoc` không đúng dạng mẫu | Viết lại đúng `Thứ 5 (19h00-21h00)` |
| Cột so_buoi phải lớn hơn 0 | Điền 0 hoặc để chữ | Điền số buổi còn lại, từ 1 trở lên |
| Lớp chung cần cột phan_loai | Thiếu CB hoặc NC | Điền phan_loai, trinh_do |
| Giờ còn lại phải bằng giờ dự kiến trừ giờ đã học | Ba cột giờ không khớp | Kiểm lại số liệu, sửa cho khớp |
| Không tìm thấy học sinh / lớp | Chưa nạp tab Học sinh hoặc Lớp | Nạp tab trước rồi nạp lại tab này |
| Cột ngay phải có dạng yyyy-mm-dd | Ngày sai dạng | Sửa thành ví dụ 2026-11-17 |

**Cách sửa và nạp lại:** sửa các dòng lỗi trong file, giữ nguyên các dòng đã đúng, rồi nạp lại cả file. Dòng đã nạp được nhận ra qua mã cũ và bỏ qua (báo là "trùng"), không bị nạp hai lần. Chỉ dòng chưa nạp mới được ghi.

## 6. Ngày chốt 17/11/2026

Ngày này là tham số **Ngày chốt số dư đầu kỳ** (`opening_balance_date`) trong Cài đặt. Chỉ Admin sửa, mọi lần sửa đều ghi nhật ký. Không sửa giữa lúc đang nạp.

## 7. Chế độ Done buổi học giai đoạn đầu

Giai đoạn đầu, khi giáo viên chưa chấm nhận xét trên cổng giáo viên, đặt tham số **Done buổi cần nhận xét hoặc điểm** (`session_done_requires_review`) ở trạng thái **Tắt** trên staging và bản chạy thật. Khi Tắt, buổi vẫn Done khi giáo viên đã điểm danh xong, giờ vẫn trừ.

- **Đặt Tắt:** Admin vào Cài đặt, mục Vận hành lớp, tìm "Done buổi cần nhận xét hoặc điểm", chọn Tắt, lưu. Đây là bước làm tay, không phải migration.
- **Bật lại** khi tính năng chấm nhận xét của giáo viên sẵn sàng: cũng vào chỗ đó, chọn Bật, lưu. Từ lúc Bật, buổi thường chỉ Done khi không còn ô nhận xét "Chưa đánh giá", buổi Kiểm tra khi mọi em có mặt đã được chấm. Buổi đã Done trước đó không bị ảnh hưởng.
