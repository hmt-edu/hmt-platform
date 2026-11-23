# HT-1 · Nền DB cho cổng Học tập (/hoc) và cổng Phụ huynh (/ph)

Migration 637, kiểm thử `supabase/tests/database/637_ht1_nen_cong_hoc_tap.test.sql`. Kế hoạch: `docs/ke-hoach/cong-hoc-tap-phu-huynh.md` (lane 2).

Nguyên tắc: học sinh chỉ thấy chính mình, phụ huynh chỉ thấy con mình; **không mở RLS cho vai HS/PH** trên bảng nghiệp vụ. Mọi hàm đọc của cổng (`hs_*`, `ph_*`, làm ở các PR sau) gọi `app.portal_require_student` ở đầu.

| Hàm | Việc | Ai gọi |
| --- | --- | --- |
| `app.portal_student_ids()` | Các học sinh người gọi được thấy: HS = chính mình (`student_code`), PH = các con (`parent_code`); nhân viên và tài khoản khoá = rỗng | hàm cổng |
| `app.portal_require_student(student_id)` | Kiểm học sinh thuộc người gọi và công tắc Học tập (`HOC_TAP`) bật ở cơ sở học sinh; trả cơ sở. Lỗi `HMT_KHONG_CO_QUYEN`, `HMT_TINH_NANG_TAT` | đầu mọi hàm cổng |
| `app.portal_children()` | Mảng `{id, code, full_name}` các con (chip chọn con, ẩn khi một con); chỉ cơ sở đã bật Học tập | giao diện cổng |
