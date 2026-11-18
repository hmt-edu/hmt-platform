# Đề xuất GV-07X · Xuất nhận xét ra PDF hoặc ảnh (thẻ A24, Code A, 19/11/2026) · CHỜ CHAT DUYỆT, chưa code

Nguồn: canvas 9189 (15 khung `GV07X_*`: `nut_pc`, `nut_kt_pc`, `nut_dt`, `hop_thoai_pc`, `ca_lop_pc`, `dang_tao_pc`, `loi_pc`, `loi_dt`, `chua_luu_pc`, `xem_truoc_dt`, `sheet_dt`, `mau_a4_thuong`, `mau_a4_kiem_tra`, `mau_anh_thuong`, `mau_anh_kiem_tra`), QĐ-Đ291 (04/11: giáo viên xuất nhận xét PDF hoặc ảnh, TỰ gửi tay vào group Zalo lớp chung; gửi tự động và nút Chia sẻ là phase sau, KHÔNG làm), R-V2-38 (dấu «Đã xuất»), R-V2-39 (mức gợi ý và mẫu câu lời nhắn phụ huynh), R-GV-04, R-GV-08/09, CLAUDE.md (chi phí gói Free, quy ước SQL 7).

## 1. Việc cần làm
Ở màn chấm nhận xét (GV-07) và chấm kiểm tra (GV-07K), giáo viên bấm «Xuất nhận xét» để lấy phiếu nhận xét của từng em (hoặc cả lớp) thành **PDF khổ A4** hoặc **ảnh**, hai mẫu: buổi thường (tiêu chí, điểm 1–5, lời nhắn phụ huynh) và buổi kiểm tra (điểm theo nhóm, điểm tổng, lời nhắn). Em vắng không có phiếu. Chỉ xuất khi em đã **lưu đủ** (không còn thay đổi chưa lưu; có khung «Chưa lưu thay đổi»).

## 2. Đề xuất kỹ thuật (không Edge Function, không lưu file lên máy chủ)
- **File tạo ngay trên trình duyệt**, đúng chữ trong khung: «File tạo trên trình duyệt, không lưu lên máy chủ.» Không có dịch vụ mới, không tốn gói Free, không dữ liệu em rời khỏi máy giáo viên ngoài việc giáo viên tự gửi.
- **Dữ liệu:** màn đã tải điểm, nhận xét, lời nhắn (R-V2-39, bảng mẫu câu ở migration 103). Không cần hàm đọc mới; không dùng AI (QĐ-Đ291).
- **Ảnh:** vẽ phiếu lên `<canvas>` bằng trình duyệt rồi tải `.png` (không thêm thư viện).
- **PDF:** hai cách, cần Chat chọn: (a) mẫu A4 là một trang in riêng (CSS `@media print`) và giáo viên chọn «Lưu thành PDF» ở hộp thoại in của trình duyệt (không thêm thư viện, chạy cả iPhone Safari; không tự đặt tên file); (b) thêm thư viện tạo PDF (ví dụ jsPDF, ~90 KB nén, chỉ tải khi mở chức năng, phụ thuộc mới) để tải thẳng `.pdf` có tên file. Đề xuất (a) cho bản đầu.
- **Cả lớp:** PDF một tệp nhiều trang (mỗi em một trang). Ảnh: tải lần lượt từng ảnh; trình duyệt có thể hỏi cho phép tải nhiều tệp (cần Chat quyết: có ghép một ảnh dài không).
- **Tên file:** `<mã lớp>-<ngày buổi>-<tên em không dấu>.<đuôi>`; không chứa số điện thoại phụ huynh.

## 3. Chỗ cần DB (một PR nhỏ, mức CAO vì chạm dữ liệu học sinh)
R-V2-38: dấu «Đã xuất», **một cờ cho mỗi em mỗi buổi**, không làm lịch sử, chỉ để nhìn. Đề xuất: cột `review_exported_at timestamptz` ở bảng nhận xét từng em từng buổi (hoặc bảng nhỏ nếu chưa có dòng), hàm `app.mark_review_exported(p_session_id, p_student_id)`: chỉ giáo viên hoặc trợ giảng được phân công của buổi (R-GV-08, R-GV-09), em có mặt và đã lưu đủ; cập nhật thời điểm; ghi nhật ký chuẩn của khung chung. pgTAP: đúng (giáo viên của buổi), bị chặn (giáo viên khác, CSKH, em vắng, buổi chưa chấm). Dải migration 300–349 (A). Không đổi luật tính tiền hay giờ.

## 4. Quyền theo vai
- Giáo viên, trợ giảng được phân công của buổi: xuất, thấy dấu «Đã xuất».
- CSKH, Trưởng cơ sở, Admin: không có nút ở cổng giáo viên (CS-16 đã bỏ, CSKH không tham gia gửi nhận xét).
- Khoá theo cờ phân hệ? Không đề xuất cờ mới (chức năng chỉ thêm nút, không đổi luật).

## 5. Phạm vi các PR (mỗi PR một việc)
1. DB: cột và hàm `mark_review_exported` + pgTAP (CAO, chờ duyệt).
2. Lõi xuất: hàm thuần dựng nội dung phiếu (buổi thường, kiểm tra) + vẽ ảnh + mẫu in A4, Vitest (không DB).
3. Giao diện: nút ở GV-07, GV-07K (máy tính và điện thoại), hộp thoại chọn (một em, cả lớp, PDF hay ảnh), xem trước, trạng thái đang tạo, lỗi có thử lại, chưa lưu; dấu «Đã xuất»; e2e.

## 6. Câu hỏi cần Chat/anh chốt trước khi code
1. PDF: cách (a) hộp thoại in của trình duyệt hay cách (b) thêm thư viện jsPDF?
2. Ảnh cả lớp: nhiều tệp hay một ảnh ghép?
3. Mẫu A4 và ảnh: logo HMT, tên trung tâm, chữ ký có hay không (khung `mau_*` có logo, chưa có chữ ký)?
4. Dấu «Đã xuất» hiện ở đâu trên GV-07 (cạnh tên em)?
5. Chữ mẫu «Mô tả thật theo môn nhập ở CH-07» trong khung là ví dụ giả; mô tả mức lấy từ Rubric (CH-07, đã làm ở lane E): xác nhận.
