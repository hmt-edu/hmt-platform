# Hướng dẫn cho Trưởng cơ sở (cổng CRM)

Vai: Trưởng cơ sở (quản lý cơ sở). Việc chính: duyệt lớp, duyệt đơn, duyệt phiếu thu bước quản lý, duyệt phiếu nghiệp vụ, xử lý buổi học (huỷ, dời, đổi giáo viên, sửa điểm danh), điều chỉnh giờ. Xem `README.md` về cách đọc.

## 1. Duyệt lớp (xác nhận, duyệt, từ chối)
- **Mục đích:** cho lớp CSKH soạn đi vào hoạt động và tự sinh buổi.
- **Ai làm:** Trưởng cơ sở.
- **Các bước:** 1) **Lớp** (`/crm/lop`): chế độ cột theo bước duyệt cho thấy lớp «Đã trình». 2) Mở lớp. Menu **«Hành động»** theo tình trạng: **«Xác nhận»**, rồi **«Duyệt»**; hoặc **«Từ chối»** (kèm lý do) hay **«Đưa về Nháp»**. 3) Hộp duyệt cho **xem trước số buổi** sẽ sinh; xác nhận.
- **Kết quả mong đợi:** lớp «Đã duyệt»; các buổi hiện ở tab «Buổi học»; thời khoá biểu hiện ở **Lịch tuần** (`/crm/lich-tuan`).
- **Lỗi thường gặp:** lớp thiếu thời khoá biểu bị chặn kèm lý do; trùng phòng hoặc giáo viên chỉ **cảnh báo**. **Ảnh:** [ẢNH: lop-duyet], [ẢNH: lich-tuan]

## 2. Đóng hoặc huỷ lớp
- **Ai làm:** Trưởng cơ sở. **Các bước:** ở menu «Hành động» của lớp chọn **«Đóng lớp»** hoặc **«Huỷ lớp»**.
- **Kết quả mong đợi:** lớp đóng hoặc huỷ.
- **Lỗi thường gặp:** đóng bị chặn khi còn em còn giờ (liệt kê tên em); huỷ bị chặn khi đã có buổi Done (liệt kê buổi). Xử lý các em hoặc buổi đó trước. **Ảnh:** [ẢNH: lop-dong-bi-chan]

## 3. Duyệt đơn hàng
- **Mục đích:** duyệt đơn Sale trình lên.
- **Ai làm:** Trưởng cơ sở (người duyệt đã chốt lúc trình).
- **Các bước:** mở đơn «Đã trình» → bấm **«Duyệt»** hoặc **«Từ chối»** (ghi lý do). Đơn có thể huỷ bằng «Huỷ đơn hàng» → «Xác nhận huỷ» (chỉ khi chưa có phiếu thu).
- **Kết quả mong đợi:** đơn «Đã duyệt» để Sale lập phiếu thu.
- **Lỗi thường gặp:** `HMT_KHONG_CO_QUYEN` khi không phải người duyệt đã chốt (Admin duyệt thay phải qua hai bước). **Ảnh:** [ẢNH: don-hang-duyet]

## 4. Duyệt phiếu thu bước quản lý
- **Các bước:** **Phiếu thu** → lọc «Chờ tôi duyệt» → mở phiếu → kiểm số tiền, chứng từ, chia vào dòng đơn → duyệt (chuyển sang Kế toán) hoặc **«Từ chối phiếu thu»** (ghi lý do, phiếu về Nháp).
- **Kết quả mong đợi:** phiếu chờ Kế toán duyệt bước cuối (xem `ke-toan.md`).
- **Lỗi thường gặp:** người duyệt quản lý và kế toán phải là hai người khác nhau. **Ảnh:** [ẢNH: phieu-thu-duyet-quan-ly]

## 5. Buổi học: huỷ, dời, đổi giáo viên, sửa điểm danh
- **Ai làm:** Trưởng cơ sở. Mở **Buổi học** → bản ghi buổi; các nút ở đầu bản ghi theo tình trạng:
  1. **«Huỷ»**: trung tâm huỷ (không tính phí, tự thêm buổi cuối) hoặc học sinh huỷ lớp riêng (bắt buộc lý do, chọn có/không tính phí).
  2. **«Dời»**: đổi ngày, giờ, phòng; trùng phòng hoặc giáo viên chỉ cảnh báo.
  3. **«Đổi giáo viên»**: chọn giáo viên, trợ giảng cho buổi.
  4. **«Thêm học thử»**: thêm em học thử vào buổi.
  5. **«Sửa điểm danh»**: sửa điểm danh sau khi buổi Done, kèm lý do (có nhật ký).
- **Kết quả mong đợi:** thông báo thành công; dòng sổ giờ điều chỉnh khi cần.
- **Lỗi thường gặp:** buổi đã diễn ra không huỷ hoặc dời được (huỷ/dời chỉ cho buổi chưa diễn ra). **Ảnh:** [ẢNH: buoi-huy], [ẢNH: buoi-doi], [ẢNH: buoi-sua-diem-danh]
- **Theo dõi:** **Buổi chưa Done** (`/crm/buoi-chua-done`) cho buổi kẹt ở «Đã chốt» và giáo viên sắp trễ hạn.

## 6. Điều chỉnh giờ của ghi danh
- **Mục đích:** thêm dòng cộng hoặc trừ giờ (có lý do), không sửa dòng cũ.
- **Ai làm:** Trưởng cơ sở.
- **Các bước:** **Ghi danh** → mở ghi danh → **«Điều chỉnh giờ»** → nhập số giờ (âm hoặc dương), chọn lý do, ghi chú → xác nhận. Kiểm ở **«Sổ giờ»**.
- **Kết quả mong đợi:** sổ giờ có dòng điều chỉnh mới; «Còn lại» đổi theo.
- **Lỗi thường gặp:** lý do bắt buộc; hạn mức hoặc quy tắc «Tặng giờ cần duyệt» có thể chặn (câu lý do hiện trên màn). **Ảnh:** [ẢNH: dieu-chinh-gio]

## 7. Duyệt phiếu nghiệp vụ (cấp quản lý cơ sở)
- **Mục đích:** duyệt cập nhật hồ sơ, bảo lưu, chuyển lớp, và cấp 1 của hoàn học phí do CSKH trình.
- **Ai làm:** Trưởng cơ sở. Admin và Kế toán **không** duyệt thay cấp này đối với phiếu có tiền.
- **Các bước:** **Phiếu nghiệp vụ** → lọc «Chờ tôi duyệt» → mở phiếu → xem nội dung (cột «Hạn» là hạn ticket gốc) → **«Duyệt»** (ghi chú tuỳ chọn) hoặc **«Từ chối»** (bắt buộc lý do).
- **Kết quả mong đợi:** phiếu một cấp sang «Đã duyệt» để người tạo «Thực hiện»; phiếu Hoàn học phí còn chờ Kế toán (cấp 2).
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_PHIEU_TU_DUYET` | người tạo không tự duyệt phiếu của mình: nhờ người khác |
| `HMT_PHIEU_MOT_NGUOI_HAI_CAP` | một người không duyệt hai cấp |
| `HMT_KHONG_CO_QUYEN` | phiếu của cơ sở khác hoặc không có quyền duyệt |

- **Ảnh:** [ẢNH: phieu-nghiep-vu-cho-toi], [ẢNH: phieu-nghiep-vu-duyet]

## 8. Cờ phân hệ theo cơ sở
Một số việc (Bảo lưu, Chuyển lớp, Hoàn phí, Thu nợ đầu kỳ) chỉ làm được khi phân hệ đã **bật cho cơ sở**. Nếu màn báo `HMT_TINH_NANG_TAT`, báo Admin kiểm **Công tắc tính năng** (`/crm/quan-tri/cong-tac`).
