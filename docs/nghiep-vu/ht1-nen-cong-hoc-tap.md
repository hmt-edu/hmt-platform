# HT-1 · Nền DB cho cổng Học tập (/hoc) và cổng Phụ huynh (/ph)

Migration 637, kiểm thử `supabase/tests/database/637_ht1_nen_cong_hoc_tap.test.sql`. Kế hoạch: `docs/ke-hoach/cong-hoc-tap-phu-huynh.md` (lane 2).

Nguyên tắc: học sinh chỉ thấy chính mình, phụ huynh chỉ thấy con mình; **không mở RLS cho vai HS/PH** trên bảng nghiệp vụ. Mọi hàm đọc của cổng (`hs_*`, `ph_*`, làm ở các PR sau) gọi `app.portal_require_student` ở đầu.

| Hàm | Việc | Ai gọi |
| --- | --- | --- |
| `app.portal_student_ids()` | Các học sinh người gọi được thấy: HS = chính mình (`student_code`), PH = các con (`parent_code`); nhân viên và tài khoản khoá = rỗng | hàm cổng |
| `app.portal_require_student(student_id)` | Kiểm học sinh thuộc người gọi và công tắc Học tập (`HOC_TAP`) bật ở cơ sở học sinh; trả cơ sở. Lỗi `HMT_KHONG_CO_QUYEN`, `HMT_TINH_NANG_TAT` | đầu mọi hàm cổng |
| `app.portal_children()` | Mảng `{id, code, full_name}` các con (chip chọn con, ẩn khi một con); chỉ cơ sở đã bật Học tập | giao diện cổng |
| `app.portal_schedule(student_id, from, to)` (migration 638, HT-06 và PH-05) | Lịch học một học sinh trong khoảng ngày: buổi của lớp đang học (dòng xếp lớp còn hiệu lực) và buổi có tên trong điểm danh (bù, bổ trợ); bỏ buổi `DA_THAY`; tối đa `list_page_size_max` dòng. Lỗi `HMT_KHOANG_NGAY_SAI` | giao diện cổng |
| `app.portal_assignments(student_id, group, limit, offset)` (migration 639, HT-02) | Bài tập của học sinh theo nhóm CAN_LAM (chưa nộp, kể cả quá hạn), DA_NOP, DA_CHAM; kèm số bài mỗi nhóm; phân trang ở máy chủ; chỉ bài đang giao | giao diện cổng |
| `app.portal_assignment(student_id, assignment_id)` (migration 639, HT-03 và HT-05) | Chi tiết bài: `window_state` (CON_HAN, QUA_HAN_NHAN_MUON, QUA_HAN_KHONG_NHAN, R-LMS-02), `can_submit` (R-LMS-03), bài nộp, kết quả chỉ sau khi chấm, tên tệp đề. Không hàm nộp bài: HT-04 chờ kho R2 | giao diện cổng |
