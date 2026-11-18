# Nhật ký thiết kế · 6 màn còn thiếu khung (HMT Platform)

Canvas: https://claude.ai/artifact/VLEPAjcSZWAh8yyWjj1dc2 · phiên bản 5 (1794988956-1aab) · 18/11/2026
Chưa đóng gói bàn giao. Chưa đẩy GitHub (không có quyền ghi) nên xuất kèm file này.

## Cụm 1 · CHUNG-15 Hàng việc chờ tôi duyệt (khuôn K03)
13 khung: CHUNG15_pc (Trưởng cơ sở), _kt_pc (Kế toán, thêm cột Cơ sở), _loc_pc, _da_loc_pc, _trong_pc, _trong_loc_pc, _tai_pc, _loi_pc, _quyen_pc; mobile: CHUNG15_dt, _loc_dt, _trong_dt, _tai_dt.
- Cột: loại việc, mã, đối tượng, cấp duyệt hiện tại/tổng, người tạo, thời gian chờ. Lọc theo loại việc, cơ sở. Bấm dòng mở màn chi tiết.
- Không có "Duyệt hàng loạt"; Duyệt/Từ chối nằm trong màn chi tiết từng loại.

## Cụm 2 · BC-08, BC-09 (khuôn K03/K09, theo GV-16)
- BC08 (5 khung): bảng theo giáo viên: số buổi trễ, tổng giờ trễ; lọc tháng, cơ sở; Xuất CSV theo quyền. Chỉ ghi số liệu, không tính vi phạm, không hiện mức xử lý.
- BC09 (7 khung): giờ dạy GV và TG theo loại buổi; tháng chưa chốt (nút Chốt tháng), hộp thoại xác nhận, tháng đã chốt (nhãn, khoá), Trưởng cơ sở không có nút Chốt. Chỉ buổi Hoàn thành; buổi huỷ không tính.

## Cụm 3 · CH-05, CH-06, CH-07
- CH05 (7 khung): danh sách khung theo Môn, Khối, Cấp độ, Năm; Tạo bản mới; Ngừng (có xác nhận); Trưởng cơ sở chỉ xem.
- CH06 (8 khung): danh sách bài của một khung; sửa tại dòng, thêm bài, kéo đổi thứ tự; trạng thái khoá khi đã có lớp dùng (chờ luật).
- CH07 (5 khung): lưới 9 tiêu chí x 5 mức, mẫu Vật lý; sửa; tạo phiên bản.
- Ba màn là tab dưới mục Cấu hình › "Đào tạo: khung, rubric, ngày nghỉ".

## Dừng / thiếu khuôn
- CH-06 "Nhập từ file": thiếu khuôn T5 (bước tải file cột cố định, xem trước theo loại, hộp kết quả). Gần nhất: K4b, TS04. Đã vẽ nút, không vẽ hộp thoại nhập.
- CH-07: thiếu tên 9 tiêu chí bộ Toán và mô tả mức chính thức (Q-190). Dùng bộ môn phụ, chữ mẫu ghi rõ là mẫu.

## Câu hỏi treo
Xem khung CAU_HOI_TREO (khoảng 33 câu: CHUNG-15 x10, BC x9, CH x13).

## Không vẽ
GV07b_, GV08b_ (bản nháp).

## Cập nhật 18/11/2026 theo bản Chat trả lời 32 câu
- CHUNG-15: đổi nhãn "Ticket đề nghị" thành Hoàn phí, Bảo lưu, Chuyển phí (bộ lọc loại việc cũng đổi).
- BC-08: thêm trợ giảng (dòng "Trợ giảng" nhỏ dưới tên); ghi chú tháng tính theo ngày buổi diễn ra.
- BC-09: tháng đã chốt hiện "Đã chốt bởi <tên> lúc <giờ>".
- CH-06: bỏ khung CH06_khoa_pc (chờ anh chốt luật khoá).
- CH-07: vẽ bộ Toán (Ghi nhớ công thức, Hiểu bản chất, Nhận biết dạng toán; Giải bài tập, Tư duy lập luận, Tính toán và trình bày); thêm CH07_cau_mau_pc (câu mẫu lời nhắn phụ huynh theo mức) và CH07_phu_pc (bộ môn phụ, mẫu Vật lý); Tạo phiên bản ghi rõ chỉ áp cho buổi sau.
- Khung mới: DA_TRA_LOI (các câu đã chốt). CAU_HOI_TREO chỉ còn câu chờ.
- Còn chờ anh OK: 15 (phạm vi chốt tháng), 20 (hai bản cùng năm), 21 (sao chép bài), 24 (khoá khi đã dùng). Chưa vẽ thêm các phần này.
- Chưa vẽ bản Admin của CHUNG-15 (làm sau, câu 4).

## Cập nhật 18/11/2026 15:00 theo 4 câu anh chốt
- BC-09 (câu 15): thêm BC09_chot_loc_pc; đang lọc CS1 vẫn ghi Phạm vi "Tất cả cơ sở".
- CH-05 (câu 20, 21): mã có hậu tố -v2 (thêm dòng TOAN-K03-CB-2627-v2); Tạo bản mới hiện mã sắp cấp (chỉ xem) và dòng "Sao chép 12 bài từ bản TOAN-K06-NC-2627".
- CH-06 (câu 24): giữ nguyên, không khoá, không nhãn, không cột số lớp.
- CHUNG-15: thêm CHUNG15_ad_pc (Admin, mọi cơ sở, phiếu thu chỉ "Chuyển người duyệt").
- CH-07 Toán: 9 tiêu chí đã khớp đúng tên trong v2-danh-gia-hoc-sinh.md.
