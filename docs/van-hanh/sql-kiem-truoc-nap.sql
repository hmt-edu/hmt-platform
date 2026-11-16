-- KIỂM TRƯỚC KHI NẠP DỮ LIỆU, CHỈ ĐỌC (Code B, 16/11/2026). Chỉ có câu SELECT, không ghi gì, không in họ tên, số điện thoại.
-- Cách chạy: Supabase > project cần nạp > SQL Editor > dán toàn bộ file > Run (hoặc chạy từng khối (a)..(f)). Xong gửi Chat ảnh chụp kết quả.
-- Mục đích: trước khi bấm Nạp thật ở màn Nhập (QT-18), xác nhận cơ sở dữ liệu đã sẵn sàng: bản cập nhật, cờ phân hệ, tham số, danh mục, và
-- hôm nay chưa nạp gì (hoặc đã nạp bao nhiêu). Mỗi khối có cột «dat» (true/false) để đọc nhanh; khối nào false thì sửa trước khi nạp.
-- Quy trình đưa lên chạy thật vẫn qua hmt-deploy; file này chỉ để KIỂM.

-- ===== (a) Bản cập nhật cuối =====
-- So với migration cuối trên main (hỏi Chat số hiện hành). Thiếu migration thì màn Nhập báo hàm không có.
select max(version) as migration_cuoi, count(*) as so_migration_da_ap
  from supabase_migrations.schema_migrations;

-- ===== (b) Cờ phân hệ theo cơ sở =====
-- Nạp Lớp, Ghi danh, Buổi, Điểm danh cần VAN_HANH_LOP bật cho cơ sở trong file (không thì dòng bị từ chối HMT_TINH_NANG_TAT).
select b.code as co_so,
       coalesce((select f.enabled from app.feature_flag f where f.branch_id = b.id and f.module_code = 'VAN_HANH_LOP'), false) as van_hanh_lop_bat,
       coalesce((select f.enabled from app.feature_flag f where f.branch_id = b.id and f.module_code = 'VAN_HANH_LOP'), false) as dat
  from app.branch b
 order by b.code;

-- ===== (c) Tham số ảnh hưởng việc nạp =====
-- import_max_rows: số dòng tối đa mỗi lần nạp (1 đến 5000). opening_balance_date: ngày chốt số dư đầu kỳ.
-- session_done_requires_review: giai đoạn đầu phải là false (Q-198).
select d.key as tham_so, d.value as gia_tri_chung, d.min_value, d.max_value,
       case d.key
         when 'import_max_rows' then d.value::numeric between d.min_value and d.max_value
         when 'session_done_requires_review' then d.value = 'false'
         else d.value is not null
       end as dat
  from app.setting_def d
 where d.key in ('import_max_rows', 'opening_balance_date', 'session_done_requires_review')
 order by d.key;

-- ===== (d) Danh mục tối thiểu để nạp =====
-- Cơ sở, nguồn và loại nguồn (cơ hội), môi trường học (lớp) phải có mục đang dùng. Chỉ số đếm.
select k.catalog_code as danh_muc,
       (select count(*) from app.catalog_item i where i.catalog_code = k.catalog_code and i.is_active) as so_muc_dang_dung,
       (select count(*) from app.catalog_item i where i.catalog_code = k.catalog_code and i.is_active) > 0 as dat
  from (values ('SOURCE_TYPE'), ('SOURCE'), ('PROVINCE'), ('ENROLLMENT_STATUS'), ('SESSION_STATUS'), ('ATTENDANCE_STATUS')) as k (catalog_code)
 order by k.catalog_code;

-- ===== (e) Đã nạp từ dữ liệu cũ bao nhiêu (đếm hồ sơ có mã cũ) =====
-- Để biết trước khi nạp: bao nhiêu hồ sơ đã có (nạp lại sẽ báo TRUNG, không ghi đè). Không có tên hay số điện thoại.
select t.ten_bang, t.so_dong
  from (values
    ('parent', (select count(*) from app.parent where legacy_ref is not null)),
    ('student', (select count(*) from app.student where legacy_ref is not null)),
    ('opportunity', (select count(*) from app.opportunity where legacy_ref is not null)),
    ('class', (select count(*) from app.class where legacy_ref is not null)),
    ('enrollment', (select count(*) from app.enrollment where legacy_ref is not null)),
    ('class_session', (select count(*) from app.class_session where legacy_ref is not null)),
    ('student_test', (select count(*) from app.student_test where legacy_ref is not null))
  ) as t (ten_bang, so_dong)
 order by t.ten_bang;

-- ===== (f) Tài khoản Admin dùng để nạp =====
-- Nạp cần Admin đã xác thực hai bước (AAL2). Chỉ đếm, không in email.
select (select count(*) from app.user_role r join app.user_account u on u.id = r.user_id
         where r.role_code = 'ADMIN' and r.is_active and not u.is_locked) as so_admin_dang_hoat_dong,
       (select count(distinct f.user_id) from auth.mfa_factors f join app.user_role r on r.user_id = f.user_id
         where r.role_code = 'ADMIN' and r.is_active and f.status = 'verified') as so_admin_da_hai_buoc,
       (select count(distinct f.user_id) from auth.mfa_factors f join app.user_role r on r.user_id = f.user_id
         where r.role_code = 'ADMIN' and r.is_active and f.status = 'verified') > 0 as dat;
