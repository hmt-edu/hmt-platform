---
title: Vai: Trưởng cơ sở
slug: theo-vai-truong-co-so
group: vai
order: 70
role: Trưởng cơ sở
portals: [crm]
---

# Vai: Trưởng cơ sở (cổng CRM)

Vai: **Trưởng cơ sở** (quản lý cơ sở). Nếu bạn mới, đọc trước [Giới thiệu hệ thống](/crm/huong-dan/bat-dau). Chữ trong dấu «…» là chữ hiện trên màn.

Menu của bạn: **Trang chủ**, **Việc chờ tôi duyệt**, **Lớp**, **Buổi học**, **Ghi danh**, **Bán hàng và thu chi**, **Phiếu nghiệp vụ**. Bạn chỉ thấy và duyệt việc của **cơ sở mình**.

**Nguyên tắc duyệt (nhớ kỹ):**

- Phiếu ở cấp **«Quản lý cơ sở»** do **Trưởng cơ sở đúng cơ sở** duyệt. **Admin được duyệt thay** Trưởng cơ sở ở cấp này. **Kế toán không duyệt** cấp này.
- Phiếu **tiền** (có cấp Kế toán): cấp quản lý cơ sở vẫn do Trưởng cơ sở duyệt; Admin không duyệt tiền.
- Người tạo phiếu không tự duyệt phiếu của mình; một người không duyệt hai cấp của cùng một phiếu.
- Trưởng cơ sở của cơ sở khác không duyệt được phiếu của cơ sở bạn.

## Việc hằng ngày của bạn (gợi ý thứ tự)

1. Mở **Trang chủ**: xem các khối theo vai trò (mục 1).
2. Mở **Việc chờ tôi duyệt**: duyệt hoặc từ chối từng việc đến lượt bạn (mục 2).
3. Xem **Lớp chờ duyệt** và **Buổi chưa hoàn tất** để không trễ hạn.

## 1. Trang chủ theo vai trò

**Mục tiêu:** thấy ngay việc cần làm trong ngày.

1. Vào **Trang chủ**. Khối nào hiện do quyền của bạn quyết định; khối chưa có việc thì ẩn, không hiện số giả.
2. Các khối thường thấy với Trưởng cơ sở: «Việc chờ tôi duyệt», «Lớp chờ duyệt», «Buổi chưa hoàn tất», «Ticket quá hạn», «Công nợ quá hạn», «Buổi hôm nay».
3. Bấm một dòng trong khối để mở thẳng bản ghi.

- **Kết quả:** mở Trang chủ là biết việc nào đến lượt mình.
- **Lỗi thường gặp:** không thấy một khối nghĩa là chưa có quyền hoặc cơ sở chưa bật phân hệ đó: báo Admin.
- **Ảnh:** [ẢNH: truong-co-so-trang-chu]

## 2. Việc chờ tôi duyệt

**Mục tiêu:** duyệt mọi loại việc đến lượt bạn ở một chỗ.

1. Vào **Việc chờ tôi duyệt**. Các cột: «Loại việc», «Mã», «Học sinh / Phụ huynh», «Mã đối tượng», «Nội dung», «Cấp», «Vai trò duyệt», «Người tạo», «Thời gian chờ». Lọc theo «Loại việc»: Đơn hàng, Phiếu thu, Lớp, Yêu cầu buổi, Hoàn phí, Dừng học, Bảo lưu, Chuyển lớp, Phiếu nghiệp vụ.
2. Bấm một dòng để mở bản ghi.
3. Ở bản ghi, bấm **«Duyệt»** hoặc **«Từ chối»** (từ chối bắt buộc ghi lý do). Không duyệt hàng loạt.

- **Kết quả:** việc đã duyệt biến khỏi danh sách; việc cấp kế tiếp chuyển sang người duyệt kế tiếp.
- **Lỗi thường gặp:** không thấy phiếu của cơ sở khác là đúng; phiếu cấp Kế toán không nằm ở đây.
- **Ảnh:** [ẢNH: viec-cho-toi-duyet-truong-co-so]

## 3. Duyệt phiếu nghiệp vụ cấp Quản lý cơ sở

**Mục tiêu:** duyệt Cập nhật hồ sơ, Bảo lưu, Chuyển lớp và cấp 1 của Hoàn học phí do CSKH trình.

1. Vào **Phiếu nghiệp vụ**, lọc «Chờ tôi duyệt» (hoặc mở từ «Việc chờ tôi duyệt»), mở phiếu.
2. Đọc nội dung phiếu (cột «Hạn» là hạn của ticket gốc) và lý do.
3. Bấm **«Duyệt»** (ghi chú tuỳ chọn) hoặc **«Từ chối»** (bắt buộc lý do).
4. **Admin duyệt thay:** nếu Trưởng cơ sở vắng, Admin mở đúng phiếu đó và bấm «Duyệt». **Kế toán không thấy nút «Duyệt»** ở cấp này.

- **Kết quả:** phiếu một cấp sang «Đã duyệt» để người tạo bấm «Thực hiện»; phiếu Hoàn học phí còn chờ Kế toán (cấp 2).
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_PHIEU_TU_DUYET` | người tạo không tự duyệt phiếu của mình: nhờ người khác |
| `HMT_PHIEU_MOT_NGUOI_HAI_CAP` | một người không duyệt hai cấp |
| `HMT_KHONG_CO_QUYEN` | phiếu của cơ sở khác, hoặc bạn không có vai Trưởng cơ sở hay Admin |

- **Ảnh:** [ẢNH: phieu-nghiep-vu-cho-toi], [ẢNH: phieu-nghiep-vu-duyet]

## 4. Duyệt đơn hàng

**Mục tiêu:** duyệt đơn Sale trình lên.

1. Mở đơn «Đã trình».
2. Bấm **«Duyệt»** hoặc **«Từ chối»** (ghi lý do).
3. Huỷ đơn: **«Huỷ đơn hàng»** rồi **«Xác nhận huỷ»** (chỉ khi chưa có phiếu thu).

- **Kết quả:** đơn «Đã duyệt» để Sale lập phiếu thu.
- **Lỗi thường gặp:** `HMT_KHONG_CO_QUYEN` khi bạn không phải người duyệt đã chốt lúc trình.
- **Ảnh:** [ẢNH: don-hang-duyet]

## 5. Duyệt phiếu thu bước quản lý

**Mục tiêu:** xác nhận phiếu thu đúng trước khi sang Kế toán.

1. Vào **Phiếu thu**, lọc «Chờ tôi duyệt», mở phiếu.
2. Kiểm số tiền, chứng từ, phần chia vào các dòng đơn.
3. Duyệt (chuyển sang Kế toán) hoặc bấm **«Từ chối phiếu thu»** và ghi lý do (phiếu về Nháp).

- **Kết quả:** phiếu chờ Kế toán duyệt bước cuối (xem [bài Kế toán](/crm/huong-dan/theo-vai-ke-toan)).
- **Lỗi thường gặp:** người duyệt bước quản lý và bước kế toán phải là hai người khác nhau.
- **Ảnh:** [ẢNH: phieu-thu-duyet-quan-ly]

## 6. Duyệt lớp

**Mục tiêu:** cho lớp CSKH soạn đi vào hoạt động và tự sinh buổi.

1. Vào **Lớp**, chọn chế độ cột theo bước duyệt để thấy lớp «Đã trình» (khối «Lớp chờ duyệt» ở Trang chủ cũng dẫn tới đây).
2. Mở lớp. Menu **«Hành động»**: **«Xác nhận»**, rồi **«Duyệt»**; hoặc **«Từ chối»** (kèm lý do), **«Đưa về Nháp»**.
3. Hộp duyệt cho xem trước số buổi sẽ sinh; xác nhận.

- **Kết quả:** lớp «Đã duyệt»; buổi mở từ nút liên kết «Buổi học» trên bản ghi lớp (bấm vào mở danh sách buổi của lớp); thời khoá biểu hiện ở **Lịch tuần**.
- **Lỗi thường gặp:** lớp thiếu thời khoá biểu bị chặn kèm lý do; trùng phòng hoặc giáo viên chỉ cảnh báo.
- **Ảnh:** [ẢNH: lop-duyet], [ẢNH: lich-tuan]

## 7. Đóng hoặc huỷ lớp

- **Các bước:** ở menu «Hành động» của lớp chọn **«Đóng lớp»** hoặc **«Huỷ lớp»**.
- **Kết quả:** lớp đóng hoặc huỷ.
- **Lỗi thường gặp:** đóng bị chặn khi còn em còn giờ (liệt kê tên em); huỷ bị chặn khi đã có buổi Done (liệt kê buổi). Xử lý các em hoặc buổi đó trước.
- **Ảnh:** [ẢNH: lop-dong-bi-chan]

## 8. Buổi học: huỷ, dời, đổi giáo viên, sửa điểm danh

Mở **Buổi học** → bản ghi buổi; các nút ở đầu bản ghi theo tình trạng:

1. **«Huỷ»**: trung tâm huỷ (không tính phí, tự thêm buổi cuối) hoặc học sinh huỷ lớp riêng (bắt buộc lý do, chọn có hoặc không tính phí).
2. **«Dời»**: đổi ngày, giờ, phòng; trùng phòng hoặc giáo viên chỉ cảnh báo.
3. **«Đổi giáo viên»**: chọn giáo viên, trợ giảng cho buổi.
4. **«Thêm học thử»**: thêm em học thử vào buổi.
5. **«Sửa điểm danh»**: sửa điểm danh sau khi buổi Done, kèm lý do (có nhật ký).

- **Kết quả:** thông báo thành công; dòng sổ giờ điều chỉnh khi cần.
- **Lỗi thường gặp:** buổi đã diễn ra không huỷ hoặc dời được (huỷ, dời chỉ cho buổi chưa diễn ra).
- **Theo dõi:** màn **Buổi chưa Done** cho buổi kẹt ở «Đã chốt» và giáo viên sắp trễ hạn.
- **Ảnh:** [ẢNH: buoi-huy], [ẢNH: buoi-doi], [ẢNH: buoi-sua-diem-danh]

## 9. Điều chỉnh giờ của ghi danh

**Mục tiêu:** thêm dòng **cộng** hoặc **bớt** giờ (có lý do), không sửa dòng cũ. Giờ là tiền (R-GIO-01) nên mọi lần đều được ghi lại.

1. **Ghi danh** → mở ghi danh → **«Điều chỉnh giờ»**.
2. Trong hộp «Điều chỉnh giờ»: nhập «Số giờ» (số dương để cộng, số âm để bớt), chọn «Lý do», ghi «Ghi chú».
3. Bấm **«Thêm dòng điều chỉnh»**. Kiểm ở **«Sổ giờ»**.
- **Quyền:** Trưởng cơ sở (ghi danh của cơ sở mình), Kế toán và Admin đều **cộng** (số dương) và **bớt** (số âm) được. Mỗi lần có trần theo tham số «hours_adjust_max_per_call».

- **Kết quả:** sổ giờ có dòng điều chỉnh mới; «Còn lại» đổi theo.
- **Lỗi thường gặp:** lý do bắt buộc; «Quỹ giờ của ghi danh không đủ để bớt số giờ này.» (HMT_QUY_GIO_AM) là bớt quá số giờ còn lại; nếu máy chủ từ chối thì câu lý do tiếng Việt hiện ngay trong hộp.
- **Ảnh:** [ẢNH: dieu-chinh-gio]

## 10. Phân hệ theo cơ sở

Một số việc (Bảo lưu, Chuyển lớp, Hoàn phí, Thu nợ đầu kỳ) chỉ làm được khi phân hệ đã **bật cho cơ sở**. Nếu màn báo phân hệ chưa bật, nhờ Admin kiểm **Công tắc tính năng**.

## Khi gặp lỗi

Lỗi từ hệ thống hiện thẳng câu tiếng Việt trên màn. Báo Admin: chụp màn hình, ghi mã phiếu hoặc mã đơn và câu lỗi. Nếu màn báo `HMT_TINH_NANG_TAT`, nhờ Admin kiểm **Công tắc tính năng**. Việc thu tiền, hoàn tiền của Kế toán xem [bài Kế toán](/crm/huong-dan/theo-vai-ke-toan).
