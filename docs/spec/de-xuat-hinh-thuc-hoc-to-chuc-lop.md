# Đề xuất A50 · «Hình thức học» và «Tổ chức lớp» trên màn Tạo/sửa lớp (LOP-03) · Code A, 19/11/2026 · CHỜ CHAT TRÌNH ANH TRƯỜNG, chưa có migration

Nguồn: canvas 9933 `LOP03_tao`, `LOP03_sua`, `LOP03_da_duyet` có hai ô bắt buộc **Hình thức học** (Offline, Online, OMO) và **Tổ chức lớp** (Học chung, Học riêng) ở nhóm «Thông tin chung». Bảng `app.class` hiện KHÔNG có hai cột này; màn hiện không có hai ô.

## 1. Đối chiếu với luật hiện có
- **Hình thức học:** R-TIEN-12 (docs/spec/04) nói «hình thức học thuộc về GHI DANH, mỗi em trả giá theo hình thức của mình; lớp OMO nhận cả học sinh online và offline». Danh mục spec 06 mục 7 chỉ có Offline, Online (Khoá); `OMO` chưa là mã danh mục. Ghi danh đã có `delivery_mode_code` (OFF, ONL). Như vậy «OMO» là thuộc tính của LỚP (lớp nhận cả hai), còn mỗi ghi danh vẫn OFF hoặc ONL.
- **Tổ chức lớp (Học chung, Học riêng):** trùng ý với **Phân loại = Lớp riêng** (`LR`, R-LOP-xx): lớp riêng đã có kiểu riêng, trình độ không áp dụng. Hai ô «Phân loại» và «Tổ chức lớp» có thể mâu thuẫn (Cơ bản + Học riêng?).

## 2. Hai việc cần anh Trường quyết
1. **Tổ chức lớp:** bỏ (vì Phân loại = Lớp riêng đã nói lên), hay giữ như một thuộc tính riêng? Nếu giữ: khác gì «Lớp riêng», quan hệ giữa hai ô ra sao (ví dụ «Lớp riêng» luôn «Học riêng»)?
2. **Hình thức học của lớp:** thêm OMO vào danh mục? Lớp OFFLINE chỉ nhận ghi danh OFF, lớp ONLINE chỉ nhận ONL, lớp OMO nhận cả hai: có chặn khi xếp lớp không (R-GD-xx)?

## 3. Thiết kế nếu duyệt (ước lượng, một migration CAO nhẹ dải 300–349)
- Danh mục `CLASS_DELIVERY` (mã OFF, ONL, OMO; Khoá, `code` không đổi) và cột `app.class.delivery_mode_code` (not null, mặc định OFF cho lớp cũ, chụp lúc tạo); cột `class_organization` nếu giữ (CHUNG, RIENG; mặc định CHUNG).
- Hàm `app.create_class`, `app.update_class_info` nhận thêm hai khoá; sửa được ở Nháp, Từ chối như các trường khác; Đã duyệt thì khoá (nằm trong mã/tính giờ).
- Luật xếp lớp: ghi danh vào lớp OFF/ONL chỉ khi hình thức khớp; lớp OMO nhận cả hai (R-TIEN-12). Cần pgTAP cho từng nhánh và cho dữ liệu cũ.
- Giao diện: hai ô chọn ở nhóm Thông tin chung (đúng khung), cột ở danh sách lớp nếu canvas có.

## 4. Rủi ro và đề nghị
- Đụng luật tiền/xếp lớp nếu làm chặn theo hình thức: mức CAO, cần Tester.
- Đề nghị: KHÔNG làm gì cho tới khi anh Trường trả lời mục 2; màn hiện tại đã bỏ hai ô này (ghi trong PR, không tự bịa).
