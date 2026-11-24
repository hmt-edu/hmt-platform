# Sổ tệp `stored_file` (migration 664, F-23-46 a)

Thiết kế: `docs/ke-hoach/luu-tru-tep-drive.md`. Phần này chỉ có **bảng, RLS, chỉ mục, tham số**; chưa có hàm hay Edge Function (PR sau).

- **Bảng `app.stored_file`:** khoá tệp (`storage_key`, `thumb_storage_key`), mã băm `sha256`, loại (`BAI_NOP`, `DINH_KEM_GV`), cơ sở, lớp, bài giao, bài nộp, học sinh chủ ảnh, loại tệp, cỡ, `is_color`, `delete_after` (chụp lúc tải lên), trạng thái `CHO_TAI`, `DANG_DUNG`, `DA_XOA`. Không lưu nội dung tệp.
- **Chặn nộp trùng:** chỉ mục duy nhất (bài, học sinh, mã băm) khi tệp chưa `DA_XOA`.
- **RLS:** đọc theo `app.lms_assignment_visible(assignment_id)` (cùng luật bảng LMS). Không cấp ghi: chỉ Edge Function bằng khoá dịch vụ. Học sinh, phụ huynh đọc qua Edge Function `file-view-url` (PR sau).
- **Tham số (nhóm HOC_TAP):** `file_retention_days` 90, `file_retention_after_leave_days` 30, `file_cleanup_dry_run` bật, `file_max_mb` 20 (MB; đổi tên từ `file_max_bytes` vì sai đơn vị), `file_log_keep_days` 180 (dọn dòng DA_XOA cũ), `file_max_count_per_upload` 10, `file_max_total_mb_per_upload` 50, `file_storage_soft_limit_percent` 80, `file_storage_free_gb` 15.
- **Vênh spec:** R-LMS-04 ghi 10 MB và 20 trang; anh chốt 24/11 là 20 MB, 10 tệp, 50 MB. Cần cập nhật R-LMS-04 khi anh duyệt PR.

- **Dung lượng DB (F-23-50):** chỉ giữ 5 chỉ mục có lý do (ghi trong migration); dòng `DA_XOA` quá `file_log_keep_days` bị việc dọn xoá hẳn khỏi sổ (việc dọn làm ở PR Edge Function). Ước 0,4 GB/năm của bản đầu giảm rõ nhờ bỏ 4 chỉ mục và dọn dòng cũ; nhật ký `audit_log` vẫn ghi mỗi thao tác (chỉ trường đổi).
- **Hạng 3 (đổi luật):** «hạng 3 xoá thẳng» khác luật 23/11 (lưu trữ rồi xoá). CHỜ ANH XÁC NHẬN; em nghiêng về xoá hẳn sau hạn.
