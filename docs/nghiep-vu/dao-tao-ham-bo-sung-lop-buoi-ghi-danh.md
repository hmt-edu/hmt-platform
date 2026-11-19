# Hàm bổ sung của vùng Lớp, Buổi, Ghi danh (thẻ A8, Code A, 18/11/2026)

Các hàm dưới đây đã gộp và chạy nhưng chưa có mục trong `docs/nghiep-vu/`. Mô tả chép theo chú thích đầu hàm trong migration (nguồn gốc ghi bên phải); hàm nào đổi luật thì sửa cả chú thích trong migration lẫn tệp này. Hàm nội bộ không gọi trực tiếp từ giao diện.

## Lớp (migration `20261110000100_d1a_lop`, `...101_d1b_ghi_danh_so_gio`)

| Hàm | Làm gì | Ai gọi, luật |
|---|---|---|
| `app.generate_class_sessions(p_class_id, p_from)` | Sinh buổi cho lớp từ ngày `p_from` theo các khung giờ đang dùng. Giữ nguyên buổi trước `p_from`, buổi không còn Nháp và buổi đã chỉnh lẻ tay. Buổi Nháp từ `p_from` còn lại chưa chỉnh lẻ tay đổi sang `DA_THAY` (không xoá cứng) rồi sinh mới. Số buổi cần sinh = `total_sessions` trừ số buổi đang sống (Nháp giữ lại, Đã chốt, Done, Huỷ có tính phí). Ngày kết thúc dự kiến = ngày buổi cuối đang sống. Đánh lại «Buổi N» theo ngày, giờ. | Nội bộ: hàm duyệt lớp và hàm sửa thời khoá biểu gọi. R-LOP-09, R-LOP-10. |
| `app.renumber_class_sessions(p_class_id)` | Đánh lại số «Buổi N» của lớp theo ngày, giờ (buổi đang sống: Nháp, Đã chốt, Done, Huỷ có tính phí). | Nội bộ. Migration `...102_d1c_buoi_diem_danh_tru_gio`. |
| `app.class_normalize_slots(p_branch_id, p_start_date, p_slots)` | Chuẩn hoá và kiểm mảng khung giờ; trả mảng đã chuẩn (đủ trường); sai thì báo lỗi có mã. | Nội bộ. R-LOP-08, R-LOP-13. |
| `app.class_replace_slots(p_class_id, p_branch_id, p_slots)` | Thay các khung giờ của lớp bằng mảng đã chuẩn hoá: đóng khung cũ, thêm khung mới. | Nội bộ. |
| `app.class_seats_left(p_class_id)` | Số chỗ còn lại của lớp; `null` nghĩa là không giới hạn (`max_students = 0`). Đếm dòng xếp lớp đang mở của ghi danh còn hiệu lực. | R-GD-08. |
| `app.class_students_with_hours(p_class_id)` | Liệt kê tên học sinh còn giờ của lớp; dùng chặn đóng lớp khi còn học sinh còn giờ. | R-LOP-04. |

## Ghi danh (migration `...101_d1b_ghi_danh_so_gio`)

| Hàm | Làm gì | Luật |
|---|---|---|
| `app.issue_enrollment_code()` | Cấp mã ghi danh `GD` + 6 số bằng bảng đếm khoá dòng (không nhảy số, không cho sửa). | spec 02 (chuẩn mã) |
| `app.enrollment_hours_balance(p_enrollment_id)` | Số dư quỹ giờ của ghi danh = tổng sổ giờ. | R-GD-03, R-GD-04 |
| `app.assert_class_fits(p_class_id, p_package_id, p_branch_id, p_label)` | Kiểm lớp hợp lệ cho gói và cơ sở: đã duyệt, đúng môn, khối, cơ sở, còn chỗ. Báo lỗi có mã, nêu số dòng (`p_label`). | R-GD-08 |
| `app.assert_enrol_start_date(p_class_id, p_start, p_label)` | Kiểm ngày vào lớp: lớp đã có buổi thì chọn một trong các buổi sắp tới; chưa có buổi thì chọn ngày đúng thứ có lịch và không trước ngày khai giảng. | R-GD-06 |

## Buổi và điểm danh

| Hàm | Làm gì | Ai gọi, luật |
|---|---|---|
| `app.assert_session_access(p_session_id, p_module, p_action, p_staff_only)` | Kiểm quyền thao tác trên một buổi. Phạm vi: toàn hệ thống; cơ sở của buổi; hoặc được phân công (giáo viên, trợ giảng). `p_staff_only = true` loại phạm vi «được phân công» (thao tác của vận hành). | Mọi hàm thao tác buổi. R-BUOI-09, R-DD-02, R-GV-08. |
| `app.session_starts_at(p_session_id)`, `app.session_ends_at(p_session_id)` | Thời điểm bắt đầu, kết thúc của buổi (giờ Việt Nam; lưu UTC, ngày học là `date`). | Nội bộ. |
| `app.session_has_content(p_session_id)` | Buổi đã có ít nhất một dòng nội dung chưa. Dùng cho lý do chưa Done và màn tiến độ. | R-V2-35. Migration `20261111000107_gv_doc_du_lieu_`. |
| `app.save_attendance_teacher(p_session_id, p_entries)` | Giáo viên lưu điểm danh nhiều em một lần. Nếu ô đã bị người khác sửa từ lúc người dùng mở màn (giờ ghi khác lúc mở và trạng thái hiện tại khác trạng thái định lưu) thì KHÔNG ghi gì, trả danh sách ô vênh để giao diện hỏi «Giữ của tôi» hoặc «Lấy của [tên]». Mọi kiểm tra khác (quyền, buổi chưa chốt, Done rồi, em không trong danh sách, trạng thái hợp lệ) do `app.set_attendance_teacher` quyết. Kết quả `{saved, conflicts: [{student_id, full_name, current_status_code, marked_by_name, marked_at}]}`. | Giáo viên được phân công. R-GV-09. Migration `20261111000111_gv05_diem_danh_`. |

## Phòng học (migration `20261116000225_quan_tri_co_so_phong`)

| Hàm | Làm gì | Ai gọi, luật |
|---|---|---|
| `app.save_room(p_data)` | Thêm phòng (không có `id`) hoặc sửa phòng (có `id`). Dữ liệu: `id` (sửa), `branch_id` và `code` (thêm), `name`, `capacity`. Mã chỉ chữ hoa, số, gạch dưới, không trùng trong cơ sở; tên không rỗng, không trùng trong cơ sở (không phân biệt hoa thường, dấu); sức chứa là số nguyên lớn hơn 0; cơ sở phải là cơ sở dạy học. Mã phòng và cơ sở không đổi sau khi tạo. Kết quả `{id, created}`. | Quản trị · Sửa (QT-08). |
| `app.set_room_active(p_id, p_active)` | Ngừng hoặc Dùng lại một phòng. Ngừng thì không hiện ở ô chọn phòng mới; dữ liệu cũ giữ nguyên; không xoá phòng. | Quản trị · Sửa. |

## Loại buổi và form nhận xét (migration `20261119000305_a25_loai_buoi_form_nhan_xet`, A25, Q-176)

| Hàm | Làm gì | Ai gọi, luật |
|---|---|---|
| `app.set_session_type_form(p_type_code, p_form_code)` | Đổi form nhận xét của một loại buổi: `TIEU_CHI` (9 tiêu chí) hoặc `DIEM` (form điểm). Mã loại buổi không đổi. Chỉ áp dụng cho buổi tạo SAU; buổi đã tạo giữ form lúc tạo (cột `class_session.review_form`). | Admin cấu hình (`assert_config_writer`). |
| `app.session_is_exam(p_session)` | Buổi này chấm bằng form điểm không. Thay cho so sánh mã `KIEM_TRA` ở các hàm nhận xét, Done, hạn hoàn tất. | Nội bộ, không gọi từ giao diện. |
| `app.set_request_exam(..., p_type_code)` | Thêm tham số loại kiểm tra (mặc định `KIEM_TRA`; cũng `KT_GIUA_KY`, `KT_CUOI_KY`). Chỉ nhận loại có form điểm. Duyệt yêu cầu sinh buổi đúng loại. Cả ba loại kiểm tra trừ giờ như buổi Chính. | Buổi học · Tạo, như trước. |

## Hồ sơ giáo viên, trợ giảng (migration `20261121000313_qt16_ho_so_giao_vien`, QT-16)

Bảng `app.teaching_profile`: mỗi người dùng có vai Giáo viên (TEACHER) hoặc Trợ giảng (TA) có tối đa MỘT hồ sơ dạy (môn, khối, cơ sở thường dạy, ghi chú, đang dạy hay ngừng). Mã GV/TG là mã nhân sự (`staff_code`) của tài khoản. Hồ sơ chỉ là thông tin tham khảo khi xếp lịch (R-LOP-08, R-LOP-10): khi tạo lớp vẫn chọn được mọi giáo viên đúng cơ sở, hồ sơ không chặn. Không xoá, chỉ Ngừng.

| Hàm | Làm gì | Ai gọi, luật |
|---|---|---|
| `app.list_teaching_profiles(p_filters, p_sort, p_limit, p_offset)` | Danh sách hồ sơ dạy, phân trang ở máy chủ. Bộ lọc: `search`, `kind` (GV, TG), `subject`, `grade`, `branch_id`, `active`. Trả tên môn, khối từ danh mục, mã cơ sở. | Cấu hình đào tạo · Xem (Admin, Trưởng cơ sở, CSKH, giáo viên). |
| `app.list_teaching_candidates()` | Người dùng đang hoạt động có vai Giáo viên hoặc Trợ giảng mà chưa có hồ sơ (ô chọn khi tạo). | Quản trị · Sửa (Admin). |
| `app.save_teaching_profile(p_data)` | Thêm (có `user_id`) hoặc sửa (có `id`) hồ sơ: `subject_codes`, `grade_codes` (mã ĐANG DÙNG của danh mục SUBJECT, GRADE), `branch_ids`, `note`. Loại GV nếu có vai Giáo viên, không thì TG. Lỗi: `HMT_KHONG_PHAI_GIAO_VIEN`, `HMT_HO_SO_DA_CO`, `HMT_MON_SAI`, `HMT_KHOI_SAI`. | Quản trị · Sửa (Admin). |
| `app.set_teaching_profile_active(p_id, p_active)` | Ngừng hoặc Dùng lại hồ sơ. | Quản trị · Sửa (Admin). |

Ô chọn giáo viên, trợ giảng khi tạo, sửa lớp (migration `20261121000314_qt16_chon_giao_vien_tu_ho_so`): `app.list_class_form_options` thêm cho mỗi giáo viên, trợ giảng `has_profile`, `subject_names`, `grade_names` từ hồ sơ dạy đang dùng; giao diện ghi «Tên · Môn · Khối» hoặc «Tên (chưa có hồ sơ dạy)». Chỉ gợi ý, KHÔNG chặn (người chưa có hồ sơ vẫn chọn được).

## Chưa liệt kê (cố ý)

Hàm nhập dữ liệu cũ (`import_one_*`), trigger (`tg_*`), hàm đọc phạm vi (`enrollment_read_scope`, `session_read_scope`, `session_visible`, `is_assigned_to_*`) và hàm khoá dòng (`enrollment_hold_for_update`, `enrollment_stop_for_update`, `refund_request_for_update`, `finish_enrollment_hold`) thuộc tài liệu nạp dữ liệu và quyền; không mô tả lại ở đây.
