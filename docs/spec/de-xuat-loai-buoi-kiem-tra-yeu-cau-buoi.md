# Đề xuất A25 · «Loại kiểm tra» trong yêu cầu buổi (BUOI-07/08/09) và form «Loại buổi» ở Danh mục (Code A, 19/11/2026) · CHỜ CHAT DUYỆT, chưa code

Nguồn: canvas 9189: 9 khung `BUOI07/08/09_bs_loai_buoi_thuong`, `_bs_loai_kiem_tra`, `_bs_loai_kiem_tra_loi_tong` («bổ sung theo quyết định nghiệp vụ 04/11») và `DM_loai_buoi_form`. Luật: R-V2-20 (buổi Kiểm tra: phạm vi, điểm tối đa, nhập theo điểm tổng hoặc 3 nhóm; `app.set_exam_config`), R-BUOI-03, 04, 05 (học bù, củng cố, bổ trợ), R-GIO-01/04/06 (trừ giờ theo loại buổi), CLAUDE.md (danh mục: có `code`, không đổi; không xoá, chỉ Ngừng; luật lõi trong code).

## 1. Hiện trạng
- Danh mục `SESSION_TYPE` có CHINH, CUNG_CO, HOC_BU, BO_TRO, KIEM_TRA (một mã Kiểm tra). Mã `KIEM_TRA` được viết cứng ở ~10 tệp giao diện và 7 migration để chọn «form điểm» thay cho «9 tiêu chí».
- Yêu cầu buổi (migration 139–141) mỗi loại yêu cầu sinh ĐÚNG một loại buổi: củng cố → CUNG_CO, bổ trợ → BO_TRO, học bù → HOC_BU. Cấu hình điểm kiểm tra (`set_exam_config`) do người xếp lịch đặt SAU khi buổi đã có.

## 2. Khung muốn thêm (mô tả)
1. Ở form tạo yêu cầu (BUOI-07, 08, 09) có ô **Loại buổi** (Chính, Củng cố, Học bù, Học bổ trợ, Kiểm tra giữa kỳ, Kiểm tra cuối kỳ); «loại buổi quyết định form nhận xét: 9 tiêu chí hoặc form điểm».
2. Chọn loại Kiểm tra: hiện **Phạm vi kiến thức**, **Điểm tối đa** (mặc định 10), **Cách nhập điểm** (điểm tổng hoặc 3 nhóm Ghi nhớ·Hiểu·Vận dụng, mỗi nhóm có điểm tối đa); lỗi lệch: tổng điểm tối đa 3 nhóm phải bằng điểm tối đa của buổi.
3. Danh mục chung «Loại buổi»: thêm cột **Form nhận xét** (9 tiêu chí | Form điểm) cho từng loại; «đổi form chỉ áp dụng cho buổi tạo sau; buổi đã tạo giữ form lúc tạo»; thêm hai mã kiểm tra (KT_GIUA_KY, KT_CUOI_KY).

## 3. XUNG ĐỘT PHẢI GỠ TRƯỚC (luật > canvas)
- **Trừ giờ:** loại buổi quyết định trừ giờ (CHINH, CUNG_CO trừ; HOC_BU, BO_TRO không trừ, R-BUOI-03: học bù không trừ giờ kể cả khi huỷ có tính phí). Nếu yêu cầu **học bù** cho phép chọn loại «Chính» hoặc «Củng cố» thì buổi sinh ra TRỪ GIỜ, trái R-BUOI-03. Đề xuất: ô Loại buổi của mỗi yêu cầu chỉ cho chọn **loại có cùng cách tính giờ**: yêu cầu học bù/bổ trợ chỉ HOC_BU, BO_TRO, và các loại Kiểm tra (kiểm tra có trừ giờ hay không? CẦN CHAT/ANH CHỐT, hiện KIEM_TRA chưa có quy tắc giờ riêng trong code, xem R-GIO-01); yêu cầu củng cố chỉ CUNG_CO hoặc Kiểm tra.
- **Hai mã kiểm tra:** KIEM_TRA (đang dùng, dữ liệu cũ) vs KT_GIUA_KY, KT_CUOI_KY (khung). Đề xuất giữ KIEM_TRA (lịch sử) đổi tên «Kiểm tra» và THÊM hai mã mới cùng form điểm; buổi cũ không đổi.

## 4. Đề xuất thiết kế (khi duyệt)
- **DB (CAO, một PR, dải 300–349):** bảng `app.session_type_form (type_code, form_code)` với `form_code` ∈ {`TIEU_CHI`, `DIEM`}, nạp sẵn (CHINH, CUNG_CO, HOC_BU, BO_TRO → TIEU_CHI; KIEM_TRA, KT_GIUA_KY, KT_CUOI_KY → DIEM); cột chụp lại `class_session.review_form` lúc tạo buổi (buổi cũ giữ). Thay các so sánh `type_code = 'KIEM_TRA'` bằng tra `review_form = 'DIEM'` (SQL ~7 chỗ; giao diện ~10 tệp đọc `review_form` từ RPC thay vì mã). Cột mới ở `session_request`: `session_type_code`, `exam_scope`, `exam_max_score`, `exam_mode`, `exam_group_*` (chỉ dùng khi form = DIEM); duyệt thì tạo buổi đúng loại và gọi cấu hình điểm kiểm tra (chụp lại tham số). Kiểm: tổng 3 nhóm = điểm tối đa (cùng luật `set_exam_config`, R-V2-20), chặn loại không hợp lệ với yêu cầu (mục 3).
- **Giao diện:** ô Loại buổi + khối cấu hình điểm ở ba form yêu cầu (khuôn dùng chung), form Loại buổi ở Danh mục (thêm cột Form nhận xét, chỉ Sửa form, mã không đổi).
- **Kiểm thử:** pgTAP (luật từng loại, trừ giờ đúng, buổi cũ giữ form, lệch tổng 3 nhóm bị chặn, quyền), Vitest, e2e.

## 5. Câu hỏi cần Chat/anh chốt
1. Gỡ xung đột trừ giờ như mục 3 (mỗi loại yêu cầu chỉ chọn loại buổi cùng cách tính giờ)? Buổi Kiểm tra có trừ giờ như buổi Chính không?
2. Giữ KIEM_TRA và thêm KT_GIUA_KY, KT_CUOI_KY, hay thay hẳn?
3. Có làm ở bước yêu cầu (khung muốn thế) hay giữ cách hiện tại (đặt cấu hình điểm sau khi buổi có, `set_exam_config`)? Làm ở yêu cầu thì thêm cột cho `session_request`.
4. DM form Loại buổi thuộc làn A hay F (Danh mục chung)?
