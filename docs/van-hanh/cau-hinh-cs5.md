# Cấu hình cờ và tham số cho cơ sở CS5 ngày 17/11/2026

Phiếu dieu-phoi-kit#278. Viết 13/11/2026 từ mọi migration trên `main` (đến 126), spec `docs/spec/06-danh-muc-va-tham-so.md` và các tài liệu vận hành. Dành cho anh Trường khi lên bản chạy thật.

**Cách dùng:** chạy khối (d) ở cuối `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` (chỉ đọc) trong Supabase > hmt-prod > SQL Editor, rồi so từng dòng với bảng 1 dưới đây. Cột `lech` của câu SQL ghi «khớp» hoặc «LỆCH» cho các dòng ở bảng 1; dòng trống nghĩa là giữ mặc định (bảng 2).

## Hai điều cần biết

- **Migration áp lên MỌI môi trường nó tới** (staging khi gộp vào `main`; bản chạy thật khi anh chạy workflow bản chạy thật). Cờ và tham số đặt bằng migration sẽ tự có trên production ngay lúc anh deploy. Dữ liệu giả trong `supabase/seed.sql` KHÔNG áp lên production.
- Cờ là một dòng bảng `app.feature_flag` (phân hệ × cơ sở); **không có dòng = TẮT**. Tham số lấy từ `app.setting_def` (giá trị chung) và `app.setting_branch` (ghi đè theo cơ sở, nếu có), đúng cách hàm `app.get_setting` đọc.

## 1. Cờ và tham số cần đúng giá trị cho CS5 ngày 17/11

| # | Cờ / tham số | Giá trị CS5 cần | Đặt bằng | Có trên main? | Nguồn quyết định |
|---|--------------|-----------------|----------|---------------|------------------|
| 1 | Cờ `VAN_HANH_LOP` ở CS5 (ghi danh, lớp, buổi, điểm danh; hàm nạp dữ liệu đào tạo kiểm cờ này) | BẬT | Migration `20261111000110_bat_van_hanh_lop_cs5.sql` (số 110) | Có | Q-262 |
| 2 | Cờ `BAN_HANG` ở CS5 (lead, cơ hội, test, báo giá, đơn, phiếu thu; 39 chỗ gọi `require_feature('BAN_HANG')`) | BẬT | Migration `20261112000125_bat_ban_hang_cs5.sql` (số 125). Trước đó chỉ `seed.sql` bật, nên production sẽ tắt nếu thiếu migration này | Có | Q-262 (phần còn thiếu, ghi trong chính migration 125) |
| 3 | Tham số `opening_balance_date` (Ngày chốt số dư đầu kỳ, chữ yyyy-mm-dd) | `2026-11-17` | Migration 105 (`20261111000105_d1e_nap_du_lieu_dao_tao.sql`) khai báo với giá trị này. Về sau chỉ Admin sửa ở Cài đặt (mọi lần sửa có nhật ký); không sửa giữa lúc đang nạp | Có | Q-200 (spec 06, dòng «Ngày chốt số dư đầu kỳ») |
| 4 | Tham số `session_done_requires_review` (Done buổi cần nhận xét hoặc điểm) | `false` (Tắt) | Migration 110, lệnh `update app.setting_def set value = 'false'` (giá trị chung, không ghi đè theo cơ sở). Muốn Bật lại phải có migration mới | Có | Q-198 (Chat duyệt 10/11). Q-272: bước chấm BTVN buổi trước chỉ chặn Done khi tham số này Bật |
| 5 | Tham số `teacher_session_complete_hours` (Hạn giáo viên hoàn tất buổi) | `8` giờ | Mặc định từ migration 005 (`20261010000005_cai_dat.sql`), không cần đặt. Cho phép ghi đè theo cơ sở | Có | Spec 06, dòng «Hạn hoàn tất buổi» [CHỐT] |
| 6 | Tham số `session_autocomplete_minutes` (Chu kỳ tự Done buổi) | `15` phút | Migration 104 (`20261111000104_pg_cron_tu_chot_tu_done.sql`) khai báo mặc định 15 | Có | Q-180 (anh OK 10/11) |
| 7 | Tham số `session_autoclose_before_minutes` (Tự chốt danh sách trước giờ học) | `30` phút | Mặc định từ migration 005, lịch đăng ký ở migration 104 | Có | Q-180 (cùng cụm tự chốt, tự Done), spec 06 |
| 8 | **pg_cron** (phần mở rộng Supabase; không phải cờ, nhưng nếu thiếu thì dòng 6 và 7 vô tác dụng: buổi KHÔNG tự chốt, tự Done) | Bật; `select jobname, schedule from cron.job;` thấy `hmt-auto-close-sessions` (`*/30 * * * *`) và `hmt-auto-complete-sessions` (`*/15 * * * *`) | Anh bật tay ở Database > Extensions trước khi migration 104 chạy, hoặc bật sau rồi chạy `select app.sync_session_cron();`. Chi tiết `docs/van-hanh/bat-pg-cron.md` | Có tài liệu; **trạng thái trên hmt-prod chưa kiểm** (câu SQL (d) không thấy được cron) | Q-180 |
| 9 | Tham số `import_user_email_domain` (miền email quy ước khi nạp người dùng, chỉ dùng khi dòng nhân sự thiếu email) | **CHƯA CÓ** giá trị chốt cho production. Mặc định trong migration là `tam.invalid` (miền giả). `docs/TIEN-DO.md` ghi anh đặt tay `nv.hmt.invalid` trên staging 05/11; sau đó anh dặn email lấy từ file nhân sự | **CHƯA CÓ migration**: theo TIEN-DO là đặt tay bằng `select app.set_setting('import_user_email_domain', '…');` | Chỉ có mặc định `tam.invalid` | `docs/nghiep-vu/phan-tich-nap-nguoi-dung-co-hoi.md` mục email; TIEN-DO.md (không có số Q) |

Cờ các phân hệ còn lại **không cần bật cho 17/11**: `CONG_GIAO_VIEN` và `HOC_TAP` không có hàm hay màn nào kiểm (migration 125 cũng ghi vậy cho `CONG_GIAO_VIEN`); `BAO_CAO` chỉ ẩn mục Báo cáo trong menu CRM, báo cáo để sau 17/11 (`docs/ke-hoach/ke-hoach-17-11.md`). Các cơ sở khác (CS1 đến CS4) KHÔNG bật ở đây: chỉ bật khi anh xác nhận cơ sở đó chạy.

**Lưu ý lệch giữa các tài liệu (chưa sửa, ngoài phạm vi phiếu):**
- `docs/van-hanh/nap-du-lieu-17-11.md` mục 7 nói đặt `session_done_requires_review` = Tắt là «bước làm tay, không phải migration». Thực tế migration 110 đã đặt Tắt. Spec 06 vẫn ghi mặc định «Bật». Lấy migration 110 làm chuẩn: sau khi deploy, câu SQL (d) phải ra `false`.
- `quotation_validity_days`: `seed.sql` ghi đè 7 ngày cho CS5 (chỉ ở staging, CI, máy thử). Production không có dòng này, dùng giá trị chung 14 ngày.

## 2. Tham số còn lại: giữ mặc định từ migration

Không cần đặt gì cho CS5. Giá trị là giá trị chung trong `app.setting_def` sau mọi migration trên main (đọc từ cơ sở dữ liệu cục bộ sau `db reset`). Cột «Ghi đè» cho biết Admin có thể đặt riêng theo cơ sở; cột cuối là số migration khai báo tham số.

| Tham số | Giá trị | Nhóm | Ghi đè | Khai báo ở migration |
|---------|---------|------|--------|----------------------|
| `export_max_rows` | 5000 dòng | chung | không | 033 |
| `import_max_rows` | 1000 dòng | chung | không | 068 |
| `import_temp_password_length` | 14 ký tự | chung | không | 069 |
| `kanban_cards_per_column` | 20 thẻ | chung | không | 028 |
| `list_page_size` | 25 dòng | chung | không | 016 |
| `list_page_size_default` | 50 dòng | chung | không | 023 |
| `list_page_size_max` | 100 dòng | chung | không | 023 |
| `note_mention_max` | 10 người | chung | không | 016 |
| `search_min_length` | 2 ký tự | chung | không | 016 |
| `search_result_max` | 8 dòng | chung | không | 016 |
| `user_login_history_rows` | 10 dòng | chung | không | 042 |
| `login_fail_alert_count` | 5 lần | ADMIN | không | 011 |
| `login_fail_alert_window_minutes` | 15 phút | ADMIN | không | 011 |
| `login_lock_after_failures` | 10 lần | ADMIN | không | 011 |
| `login_lock_minutes` | 15 phút | ADMIN | không | 011 |
| `login_user_agent_max_length` | 300 ký tự | ADMIN | không | 011 |
| `password_min_length` | 8 ký tự | ADMIN | không | 011 |
| `password_require_letter_digit` | true | ADMIN | không | 011 |
| `staff_idle_logout_minutes` | 60 phút | ADMIN | không | 011 |
| `student_idle_logout_minutes` | 10080 phút | ADMIN | không | 011 |
| `teacher_idle_logout_minutes` | 10080 phút | ADMIN | không | 011 |
| `debt_due_soon_days` | 3 ngày | BAN_HANG | không | 044 |
| `deposit_min_amount` | 1000000 đồng | BAN_HANG | có | 005 |
| `discount_total_cap_percent` | 20 % | BAN_HANG | không | 008 |
| `flexible_discount_max_percent` | 5 % | BAN_HANG | không | 085 |
| `lead_import_max_rows` | 500 dòng | BAN_HANG | không | 023 |
| `merge_preview_max_items` | 20 mục | BAN_HANG | không | 040 |
| `package_default_validity_months` | 6 tháng | BAN_HANG | có | 005 |
| `prospect_max_students` | 5 em | BAN_HANG | không | 043 |
| `quotation_popular_packages_count` | 5 gói | BAN_HANG | không | 055 |
| `quotation_popular_window_days` | 90 ngày | BAN_HANG | không | 055 |
| `quotation_validity_days` | 14 ngày | BAN_HANG | có | 005 |
| `refund_processing_fee_percent` | 10 % | BAN_HANG | không | 008 |
| `test_reminder_short_lead_hours` | 2 giờ | BAN_HANG | không | 023 |
| `test_reminder_short_window_hours` | 24 giờ | BAN_HANG | không | 023 |
| `test_reminder_time_minutes` | 1020 phút kể từ 0 giờ | BAN_HANG | không | 023 |
| `upsale_days_left_threshold` | 30 ngày | BAN_HANG | có | 005 |
| `upsale_hours_left_threshold` | 10 giờ | BAN_HANG | có | 005 |
| `exam_default_max_score` | 10 điểm | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_exam_level2` | 50 % | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_exam_level3` | 75 % | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_exam_level4` | 90 % | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_regular_level2` | 2.5 điểm | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_regular_level3` | 3.5 điểm | CONG_GIAO_VIEN | không | 103 |
| `parent_hint_regular_level4` | 4.5 điểm | CONG_GIAO_VIEN | không | 103 |
| `review_all_class_level` | 3 mức | CONG_GIAO_VIEN | không | 103 |
| `complaint_reopen_max_days` | 7 ngày | CSKH | có | 008 |
| `sla_complaint_critical_resolve_days` | 1 ngày | CSKH | có | 008 |
| `sla_complaint_critical_response_hours` | 2 giờ | CSKH | có | 008 |
| `sla_complaint_resolve_days` | 3 ngày | CSKH | có | 008 |
| `sla_complaint_response_hours` | 24 giờ | CSKH | có | 008 |
| `sla_refund_resolve_days` | 7 ngày | CSKH | có | 008 |
| `sla_request_resolve_days` | 2 ngày | CSKH | có | 008 |
| `sla_request_response_hours` | 24 giờ | CSKH | có | 008 |
| `absence_risk_sessions` | 3 buổi | VAN_HANH_LOP | có | 005 |
| `algebra_geometry_split_grade` | 7 khối | VAN_HANH_LOP | không | 005 |
| `class_slot_repeat_weeks_max` | 4 tuần | VAN_HANH_LOP | không | 100 |
| `max_sessions_ahead` | 2 buổi | VAN_HANH_LOP | có | 005 |
| `reservation_max_months` | 6 tháng | VAN_HANH_LOP | có | 005 |
| `session_autoclose_scan_hours` | 2 giờ | VAN_HANH_LOP | có | 005 |

## Kiểm trước khi gộp (cho tester)

1. `supabase db reset` rồi chạy khối (d) trong `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` (dán vào psql hoặc SQL Editor local). 7 dòng bảng 1 (dòng 1 đến 7) phải ra «khớp». Dòng `quotation_validity_days` ra «ghi đè theo CS5 = 7» là do `seed.sql`, đúng như lưu ý trên.
2. So các dòng còn lại với bảng 2 (60 tham số).
3. Câu SQL chỉ đọc: có thể chạy trong `begin read only; … rollback;`.
