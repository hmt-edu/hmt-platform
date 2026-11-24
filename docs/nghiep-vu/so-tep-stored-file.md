# Sổ tệp `stored_file` (migration 664, F-23-46 a)

Thiết kế: `docs/ke-hoach/luu-tru-tep-drive.md`. Phần này chỉ có **bảng, RLS, chỉ mục, tham số**; chưa có hàm hay Edge Function (PR sau).

- **Bảng `app.stored_file`:** khoá tệp (`storage_key`, `thumb_storage_key`), mã băm `sha256`, loại (`BAI_NOP`, `DINH_KEM_GV`), cơ sở, lớp, bài giao, bài nộp, học sinh chủ ảnh, loại tệp, cỡ, `is_color`, `delete_after` (chụp lúc tải lên), trạng thái `CHO_TAI`, `DANG_DUNG`, `DA_XOA`. Không lưu nội dung tệp.
- **Chặn nộp trùng:** chỉ mục duy nhất (bài, học sinh, mã băm) khi tệp chưa `DA_XOA`.
- **RLS:** đọc theo `app.lms_assignment_visible(assignment_id)` (cùng luật bảng LMS). Không cấp ghi: chỉ Edge Function bằng khoá dịch vụ. Học sinh, phụ huynh đọc qua Edge Function `file-view-url` (PR sau).
- **Tham số (nhóm HOC_TAP):** `file_retention_days` 90, `file_retention_after_leave_days` 30, `file_cleanup_dry_run` bật, `file_max_bytes` 20 MB, `file_max_count_per_upload` 10, `file_max_total_mb_per_upload` 50, `file_storage_soft_limit_percent` 80, `file_storage_free_gb` 15.
- **Vênh spec:** R-LMS-04 ghi 10 MB và 20 trang; anh chốt 24/11 là 20 MB, 10 tệp, 50 MB. Cần cập nhật R-LMS-04 khi anh duyệt PR.

## Hàm kiểm quyền (migration 665, F-23-49)

- `app.file_authorize_upload(kind, bài giao, học sinh)`: học sinh nộp bài của CHÍNH MÌNH (phụ huynh, em khác, bài không giao cho em đều bị chặn `HMT_KHONG_CO_QUYEN`); giáo viên có quyền Sửa buổi giao đính kèm tệp đề (`DINH_KEM_GV`). Kiểm công tắc HOC_TAP, R-LMS-02 (quá hạn, `HMT_LMS_QUA_HAN`), R-LMS-03 (không cho nộp lại, `HMT_LMS_KHONG_NOP_LAI`), bài đã gỡ (`HMT_LMS_BAI_DA_GO`). `BAI_NOP` tạo hoặc lấy bài nộp NHÁP (chưa `submitted_at`; chốt lần nộp là hàm nộp bài HT-05). Trả cơ sở, lớp, bài nộp, cờ giữ màu, `delete_after` (chụp lúc tải), giới hạn tệp từ tham số.
- `app.file_authorize_view(id tệp)`: nhân viên theo quyền xem bài giao; học sinh chủ ảnh; phụ huynh của em; tệp đề: em được giao bài và phụ huynh của em. Tệp đã dọn: `HMT_TEP_DA_DON`; chưa tải xong: `HMT_KHONG_TIM_THAY`. Tệp không tồn tại báo cùng lỗi không có quyền (không lộ).
- `app.file_setting_int(khoá, cơ sở)`: nội bộ, chỉ khoá `file_*`, vì `app.get_setting` chặn phiên học sinh đọc tham số (migration 467).
