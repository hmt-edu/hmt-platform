-- D1e (migration 105): nạp Lớp, Ghi danh (số dư giờ đầu kỳ), Buổi học và Điểm danh cũ. Luật: R-V2-30, R-V2-32, R-V2-33, Q-177, Q-186..188, Q-199, Q-200.
-- Dữ liệu giả; ngày chốt lấy từ tham số opening_balance_date, không viết cứng trong bài.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('gv1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1e.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, staff_code)
select u.id, 'Giả ' || u.key, u.key || '@d1e.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false, case u.key when 'gv1' then 'GV2001' end from u;
insert into app.user_role (user_id, role_code) select id, case key when 'admin' then 'ADMIN' when 'cskh1' then 'CSKH' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1E01', 'Phụ huynh giả D1e', '0900001001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id, legacy_ref)
  values ('HSD1E01', (select id from app.parent where code = 'PHD1E01'), 'Học sinh giả D1e 1', 2012, (select id from app.branch where code = 'CS1'), 'M-HS-0001'),
         ('HSD1E02', (select id from app.parent where code = 'PHD1E01'), 'Học sinh giả D1e 2', 2012, (select id from app.branch where code = 'CS1'), 'M-HS-0002')$$);
create function pg_temp.sched(p_text text, p_from date) returns jsonb language sql security definer as $$ select app.import_parse_schedule(p_text, p_from) $$;
create function pg_temp.cutover() returns date language sql stable as $$ select app.get_setting('opening_balance_date')::date $$;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;

-- ================= Tham số mốc nạp (Q-200) =================
select is(app.get_setting('opening_balance_date'), '2026-11-17', 'Tham số ngày chốt mặc định 17/11/2026 (Q-200)');

-- ================= Tách lịch học (Q-187) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(pg_temp.sched('Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)', '2026-11-17')), 2, 'Lịch hai khung tách thành 2 khung (Q-187)');
select is(pg_temp.sched('Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)', '2026-11-17') -> 0 ->> 'first_date', '2026-11-19', 'Thứ 5 đầu tiên không trước ngày 17/11/2026 là 19/11/2026');
select is(pg_temp.sched('Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)', '2026-11-17') -> 1 ->> 'start_time', '18:30', 'Giờ bắt đầu khung thứ 2 là 18:30');
select is(pg_temp.sched('Chủ nhật (8h00-10h00)', '2026-11-17') -> 0 ->> 'weekday', '7', 'Chủ nhật là thứ 7 theo chuẩn ISO');
select is(pg_temp.err($$select pg_temp.sched('Thứ 5 lúc 19h', '2026-11-17')$$), 'HMT_NAP_LICH_SAI', 'Chặn: lịch học sai dạng báo lỗi, không đoán (Q-187)');
select is(pg_temp.err($$select pg_temp.sched('Thứ 5 (25h00-21h00)', '2026-11-17')$$), 'HMT_NAP_LICH_SAI', 'Chặn: giờ vượt 23');
select is(pg_temp.err($$select pg_temp.sched(null, '2026-11-17')$$), 'HMT_NAP_LICH_SAI', 'Chặn: thiếu lịch học');

-- ================= Quyền và hợp đồng (Q-188) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.import_training_records('LOP', '[{"ma_lop_cu":"X"}]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ Admin nạp dữ liệu cũ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.import_training_records('KHAC', '[{"a":1}]'::jsonb)$$), 'HMT_LOAI_NAP_SAI', 'Chặn: loại nạp không hợp lệ');
select is(pg_temp.err($$select app.import_training_records('LOP', '[]'::jsonb)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: không có dòng nào');

-- ================= Nạp Lớp (Q-187, Q-199, R-V2-30) =================
create temp table rows_lop (j jsonb);
grant all on rows_lop to public;
insert into rows_lop values ('[
 {"row":2,"ma_lop_cu":"T4M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"4","lich_hoc":"Thứ 7 (14h30-17h00)","thoi_luong_buoi":"2.5","ma_gv":"2001","ngay_khai_giang":"2026-07-18","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"20","nam_hoc":"2627"},
 {"row":3,"ma_lop_cu":"T8M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"8","lich_hoc":"Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)","thoi_luong_buoi":"2","ma_gv":"9999","ngay_khai_giang":"2026-08-06","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"NC","trinh_do":"B","so_buoi":"10","nam_hoc":"2627"},
 {"row":4,"ma_lop_cu":"T9M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"9","lich_hoc":"Thứ 3 (18h00-20h00)","ma_gv":"2001","ngay_khai_giang":"2026-08-06","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","nam_hoc":"2627"},
 {"row":5,"ma_lop_cu":"T7M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"7","lich_hoc":"Thứ 3 18h","ma_gv":"2001","ngay_khai_giang":"2026-08-06","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"5","nam_hoc":"2627"},
 {"row":6,"ma_lop_cu":"T6M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"6","lich_hoc":"Thứ 4 (18h00-20h00)","ma_gv":"2001","ngay_khai_giang":"2026-08-06","tinh_trang":"Đã đóng","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"4","nam_hoc":"2627"},
 {"row":7,"ma_lop_cu":"T5M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"5","lich_hoc":"Thứ 4 (18h00-20h00)","ma_gv":"2001","ngay_khai_giang":"2026-08-06","tinh_trang":"Đang chạy","co_so":"CS1","so_buoi":"4","nam_hoc":"2627"}
]'::jsonb);
-- Xem trước không ghi gì.
create temp table prev (j jsonb);
grant all on prev to public;
insert into prev select app.import_training_records('LOP', (select j from rows_lop), false, 'lop.xlsx');
select is((select j ->> 'mode' from prev), 'XEM_TRUOC', 'Xem trước: chế độ XEM_TRUOC');
select is((select j ->> 'imported' from prev), '3', 'Xem trước: 3 dòng hợp lệ (T4M1, T8M1, T6M1)');
select is((select j ->> 'errors' from prev), '3', 'Xem trước: 3 dòng lỗi');
select is((select count(*)::int from app.class where legacy_ref in ('T4M1', 'T8M1', 'T6M1')), 0, 'Xem trước hoàn tác, chưa ghi lớp nào');
select is(((select j from prev) -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_THIEU_COT')::text, '[4, 7]', 'Báo cáo: dòng 4 (thiếu so_buoi) và 7 (lớp chung thiếu phan_loai) cùng loại lỗi thiếu cột (Q-187)');
select is(((select j from prev) -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_LICH_SAI')::text, '[5]', 'Báo cáo: dòng 5 lỗi lịch học sai dạng (Q-187)');
select is(((select j from prev) -> 'summary' -> 'classes_without_teacher')::text, '["T8M1"]', 'Báo cáo liệt kê riêng lớp chưa có giáo viên (Q-187)');
-- Nạp thật.
create temp table done1 (j jsonb);
grant all on done1 to public;
insert into done1 select app.import_training_records('LOP', (select j from rows_lop), true, 'lop.xlsx');
select is((select j ->> 'imported' from done1), '3', 'Nạp thật: 3 lớp');
select is((select count(*)::int from app.class where legacy_ref in ('T4M1', 'T8M1', 'T6M1')), 3, 'Ba lớp đã ghi, giữ mã lớp cũ trong legacy_ref (R-V2-30)');
select is((select status_code from app.class where legacy_ref = 'T4M1'), 'DA_DUYET', 'Lớp đang chạy được duyệt sẵn');
select is((select status_code from app.class where legacy_ref = 'T6M1'), 'DA_DONG', 'Lớp đã đóng nạp ở tình trạng Đã đóng');
select is((select count(*)::int from app.class_session s join app.class c on c.id = s.class_id where c.legacy_ref = 'T4M1' and s.status_code <> 'DA_THAY'), 20, 'Lớp T4M1 có đúng so_buoi = 20 buổi còn lại (Q-199)');
select is((select count(*)::int from app.class_session s join app.class c on c.id = s.class_id
            where c.legacy_ref in ('T4M1', 'T8M1', 'T6M1') and s.session_date < pg_temp.cutover()), 0, 'Không sinh buổi nào trước ngày chốt (Q-199)');
select is((select min(s.session_date) from app.class_session s join app.class c on c.id = s.class_id where c.legacy_ref = 'T4M1'), '2026-11-21'::date, 'T4M1 học thứ Bảy: buổi đầu là 21/11/2026, thứ Bảy đầu tiên sau ngày chốt (Q-199)');
select is((select count(*)::int from app.class_slot sl join app.class c on c.id = sl.class_id where c.legacy_ref = 'T4M1' and sl.teacher_id = pg_temp.uid('gv1')), 1, 'Giáo viên ghép bằng GV + ma_gv (Q-187)');
select is((select code from app.class where legacy_ref = 'T4M1'), 'CS1-2627-TOAN-K04-CB-A-001', 'Mã lớp mới cấp theo cơ sở, năm, môn, khối, phân loại, trình độ');
-- Chạy lại: trùng mã cũ thì bỏ qua (R-V2-30).
select is((select app.import_training_records('LOP', (select j from rows_lop), true, 'lop.xlsx') ->> 'duplicates'), '3', 'Nạp lại: 3 lớp trùng mã cũ bị bỏ qua, không ghi đè (R-V2-30)');
select is((select kind from app.import_log order by created_at desc limit 1), 'LOP', 'Nhật ký nạp ghi loại LOP');

-- ================= Nạp Ghi danh và số dư giờ đầu kỳ (R-V2-32, R-V2-33, Q-177) =================
create temp table rows_gd (j jsonb);
grant all on rows_gd to public;
insert into rows_gd values ('[
 {"row":2,"hoc_sinh_ma_cu":"M-HS-0001","ma_lop_cu":"T4M1","tinh_trang_moi":"Đang học","ngay_vao_lop":"2026-07-18","thoi_luong_buoi":"2.5","gio_da_hoc_cu":"0","gio_du_kien":"60","gio_da_hoc":"37.5","gio_con_lai":"22.5","nguon_tab":"1. Thông tin HS","nguon_dong":"3"},
 {"row":3,"hoc_sinh_ma_cu":"M-HS-0002","ma_lop_cu":"T4M1","tinh_trang_moi":"Đang học","ngay_vao_lop":"2026-08-01","thoi_luong_buoi":"2.5","gio_da_hoc_cu":"5","gio_du_kien":"50","gio_da_hoc":"30","gio_con_lai":"20","nguon_dong":"4"},
 {"row":4,"hoc_sinh_ma_cu":"M-HS-0001","ma_lop_cu":"T8M1","tinh_trang_moi":"Đang học","ngay_vao_lop":"2026-08-06","thoi_luong_buoi":"2","gio_du_kien":"10","gio_da_hoc":"4","gio_con_lai":"5"},
 {"row":5,"hoc_sinh_ma_cu":"M-KHONG-CO","ma_lop_cu":"T4M1","tinh_trang_moi":"Đang học","ngay_vao_lop":"2026-08-01","thoi_luong_buoi":"2.5","gio_du_kien":"10","gio_da_hoc":"4","gio_con_lai":"6"},
 {"row":6,"hoc_sinh_ma_cu":"M-HS-0002","ma_lop_cu":"L-KHONG-CO","tinh_trang_moi":"Đang học","ngay_vao_lop":"2026-08-01","thoi_luong_buoi":"2.5","gio_du_kien":"10","gio_da_hoc":"4","gio_con_lai":"6"},
 {"row":7,"hoc_sinh_ma_cu":"M-HS-0002","ma_lop_cu":"T8M1","tinh_trang_moi":"Không rõ","ngay_vao_lop":"2026-08-01","thoi_luong_buoi":"2","gio_du_kien":"10","gio_da_hoc":"4","gio_con_lai":"6"}
]'::jsonb);
insert into prev select app.import_training_records('GHI_DANH', (select j from rows_gd), false, 'gd.xlsx');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from prev where j ->> 'kind' = 'GHI_DANH'), '2/4', 'Xem trước ghi danh: 2 hợp lệ, 4 lỗi');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_GIO_LECH' from prev where j ->> 'kind' = 'GHI_DANH')::text, '[4]', 'Báo cáo: dòng 4 lỗi giờ lệch (còn lại ≠ dự kiến − đã học, R-V2-32)');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_HOC_SINH_CHUA_CO' from prev where j ->> 'kind' = 'GHI_DANH')::text, '[5]', 'Báo cáo: dòng 5 học sinh chưa nạp');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_LOP_CHUA_CO' from prev where j ->> 'kind' = 'GHI_DANH')::text, '[6]', 'Báo cáo: dòng 6 lớp chưa nạp');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_TINH_TRANG_SAI' from prev where j ->> 'kind' = 'GHI_DANH')::text, '[7]', 'Báo cáo: dòng 7 tình trạng không thuộc danh mục');
select is((select count(*)::int from app.enrollment where legacy_ref like 'M-HS-%'), 0, 'Xem trước ghi danh hoàn tác');
select is((select app.import_training_records('GHI_DANH', (select j from rows_gd), true, 'gd.xlsx') ->> 'imported'), '2', 'Nạp thật: 2 ghi danh');
select is(app.enrollment_hours_balance((select id from app.enrollment where legacy_ref = 'M-HS-0001|T4M1')), 22.50::numeric, 'Số dư giờ đầu kỳ = gio_con_lai = 22,5 giờ (R-V2-33)');
select is(app.enrollment_hours_balance((select id from app.enrollment where legacy_ref = 'M-HS-0002|T4M1')), 20.00::numeric, 'Ghi danh thứ hai có số dư riêng 20 giờ: mỗi GHI DANH một dòng (Q-177)');
select is((select count(*)::int from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.legacy_ref like 'M-HS-%' and l.entry_type = 'DAU_KY'), 2, 'Mỗi ghi danh đúng một dòng Số dư đầu kỳ');
select is((select l.entry_date from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.legacy_ref = 'M-HS-0001|T4M1' and l.entry_type = 'DAU_KY'), pg_temp.cutover(), 'Dòng Số dư đầu kỳ mang ngày chốt 17/11/2026 (Q-177, Q-200)');
select is((select count(*)::int from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id where e.legacy_ref like 'M-HS-%' and ec.end_date is null), 2, 'Hai ghi danh đang học có dòng xếp lớp đang mở');
select is((select app.import_training_records('GHI_DANH', (select j from rows_gd), true, 'gd.xlsx') ->> 'duplicates'), '2', 'Nạp lại: ghi danh trùng (mã học sinh cũ, mã lớp cũ) bị bỏ qua (R-V2-30)');
-- Q-199: số dư đầu kỳ không bị trừ thêm khi hệ thống tự chốt, tự Done.
select pg_temp.sudo($$select app.auto_close_sessions()$$);
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select is((select count(*)::int from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.legacy_ref like 'M-HS-%' and l.entry_type = 'TRU_BUOI'), 0, 'Sau tự chốt, tự Done: chưa có dòng trừ giờ nào (Q-199)');
select is(app.enrollment_hours_balance((select id from app.enrollment where legacy_ref = 'M-HS-0001|T4M1')), 22.50::numeric, 'Số dư đầu kỳ nguyên vẹn sau tự chốt, tự Done (Q-199)');
select is((select count(*)::int from app.class_session s join app.class c on c.id = s.class_id where c.legacy_ref like 'T%M1' and s.status_code in ('DA_CHOT', 'DONE')), 0, 'Không có buổi Đã chốt hay Done nào từ lớp nạp (buổi nằm sau ngày chốt)');

-- ================= Buổi học và Điểm danh cũ chỉ để đối soát (R-V2-33, Q-186) =================
create temp table rows_bh (j jsonb);
grant all on rows_bh to public;
insert into rows_bh values ('[
 {"row":2,"ma_lop_cu":"T4M1","ngay":"2026-07-18","ma_gv":"2001","ten_bai":"Bài mẫu 1","so_x":"2","so_P":"0","so_KP":"0","so_N":"0","so_M":"0","tinh_trang":"Đã học"},
 {"row":3,"ma_lop_cu":"T4M1","ngay":"2026-08-15","ma_gv":"2001","ten_bai":"Nghỉ lễ","so_x":"0","so_P":"0","so_KP":"0","so_N":"2","so_M":"0","tinh_trang":"Huỷ không tính phí"},
 {"row":4,"ma_lop_cu":"T4M1","ngay":"2026-13-45","tinh_trang":"Đã học"},
 {"row":5,"ma_lop_cu":"L-KHONG-CO","ngay":"2026-08-15","tinh_trang":"Đã học"}
]'::jsonb);
create temp table r2 (j jsonb);
grant all on r2 to public;
insert into r2 select app.import_training_records('BUOI_HOC', (select j from rows_bh), true, 'bh.xlsx');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from r2), '2/2', 'Nạp buổi cũ: 2 hợp lệ, 2 lỗi (ngày sai, lớp chưa nạp)');
select is((select is_cancelled from app.legacy_session_record where class_legacy_ref = 'T4M1' and session_date = '2026-08-15'), true, 'Buổi nghỉ lễ nạp thành huỷ không tính phí, không điểm danh (Q-186)');
select is((select count(*)::int from app.class_session s join app.class c on c.id = s.class_id where c.legacy_ref = 'T4M1' and s.session_date < pg_temp.cutover()), 0, 'Buổi cũ không tạo buổi học mới, không tạo buổi bù (Q-186)');
create temp table rows_dd (j jsonb);
grant all on rows_dd to public;
insert into rows_dd values ('[
 {"row":2,"ma_lop_cu":"T4M1","hoc_sinh_ma_cu":"M-HS-0001","ngay":"2026-07-18","ky_hieu":"x","trang_thai_moi":"Có mặt","tinh_gio":"Có","diem_btvn":"8","diem_btvn_goc":"8","nhan_xet":"Nhận xét mẫu"},
 {"row":3,"ma_lop_cu":"T4M1","hoc_sinh_ma_cu":"M-HS-0001","ngay":"2026-07-25","ky_hieu":"P","trang_thai_moi":"Vắng có phép","tinh_gio":"Có"},
 {"row":4,"ma_lop_cu":"T4M1","hoc_sinh_ma_cu":"M-HS-0001","ngay":"2026-08-15","ky_hieu":"N","trang_thai_moi":"Nghỉ","tinh_gio":"Không"},
 {"row":5,"ma_lop_cu":"T4M1","hoc_sinh_ma_cu":"M-HS-0002","ngay":"2026-07-18","ky_hieu":"x","trang_thai_moi":"Có mặt"}
]'::jsonb);
insert into r2 select app.import_training_records('DIEM_DANH', (select j from rows_dd), true, 'dd.xlsx');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from r2 where j ->> 'kind' = 'DIEM_DANH'), '3/1', 'Nạp điểm danh cũ: 3 hợp lệ, 1 lỗi thiếu cột tinh_gio');
select is((select count(*)::int from app.legacy_attendance_record where counts_hours), 2, 'x, P tính giờ; N không tính giờ (R-V2-33)');
select is((select count(*)::int from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.legacy_ref like 'M-HS-%' and l.entry_type = 'TRU_BUOI'), 0, 'Điểm danh cũ không ghi sổ giờ (R-V2-33)');
-- Đối soát: em 1 có 2 buổi tính giờ × 2,5 = 5 giờ, file ghi 37,5 giờ → lệch 32,5.
select is((select attendance_hours from app.legacy_hours_reconciliation('T4M1') where student_legacy_ref = 'M-HS-0001'), 5.00::numeric, 'Đối soát: giờ tính từ điểm danh cũ = 2 buổi × 2,5');
select is((select diff_hours from app.legacy_hours_reconciliation('T4M1') where student_legacy_ref = 'M-HS-0001'), 32.50::numeric, 'Đối soát: lệch so với giờ đã học ghi trong file ghi danh = 32,5');
select is((select count(*)::int from app.legacy_hours_reconciliation('T4M1', true)), 2, 'Chỉ liệt kê dòng lệch: cả hai em lệch');

-- ================= RLS =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.legacy_attendance_record), 0, 'RLS: CSKH không đọc điểm danh cũ');
select is((select count(*)::int from app.legacy_session_record), 0, 'RLS: CSKH không đọc buổi cũ');
select is((select count(*)::int from app.legacy_hours_reconciliation()), 0, 'RLS: CSKH không thấy báo cáo đối soát');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select cmp_ok((select count(*)::int from app.legacy_attendance_record), '>', 0, 'Admin đọc được điểm danh cũ');
select is(pg_temp.err($$insert into app.legacy_attendance_record (branch_id, class_legacy_ref, class_id, student_legacy_ref, student_id, session_date)
  select branch_id, class_legacy_ref, class_id, student_legacy_ref, student_id, session_date + 1 from app.legacy_attendance_record limit 1$$), '42501', 'Chặn: không ghi thẳng bảng điểm danh cũ, chỉ qua hàm nạp');

select * from finish();
rollback;
