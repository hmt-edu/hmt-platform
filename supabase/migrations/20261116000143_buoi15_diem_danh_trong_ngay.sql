-- BUOI-15 Điểm danh trong ngày (danh sách theo dõi, chỉ đọc), ĐỀ XUẤT docs/spec/de-xuat-luat-a.md (Chat 01:00: làm mã sau cờ tắt theo đề xuất, ghi lệch nếu Chat đổi).
-- Luật: R-DD-01..03 (điểm danh hai phía: vận hành ghi riêng, ô giáo viên quyết định trạng thái chính thức), R-GIO-02..04 (danh sách chỉ gồm em đang hiệu lực), R-BUOI-08.
-- Khác đề xuất mục 7: "báo nghỉ trước" KHÔNG thêm cột mới mà dùng sẵn lý do liên hệ XIN_NGHI_HOC (danh mục ATTENDANCE_CONTACT_REASON, ghi ở BUOI-03 bằng app.set_attendance_ops).
-- Thêm: phân hệ công tắc DIEM_DANH_TRONG_NGAY (tắt mặc định: không có dòng cờ = tắt), hàm app.session_day_attendance.
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'DIEM_DANH_TRONG_NGAY', 'Điểm danh trong ngày (theo dõi)', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

-- app.session_day_attendance(bộ lọc, giới hạn, vị trí) -> {total, rows}
-- Mỗi dòng là một buổi (không tính buổi Huỷ và buổi bị thay): lớp, buổi N, phòng, giờ, giáo viên, tình trạng buổi, số em trong danh sách (đang hiệu lực) và
-- hai bộ đếm: phía vận hành (ops) và phía giáo viên (teacher) theo trạng thái Có mặt, Đi muộn, Vắng có phép, Vắng không phép, Chưa ghi; notice = số em có lý do liên hệ XIN_NGHI_HOC.
-- Tình trạng ghi (state) theo ô giáo viên, chính thức (R-DD-02): CHUA_GHI (chưa em nào), GHI_DO (một phần), GHI_DU (mọi em đã có trạng thái); buổi Nháp chưa có danh sách (R-GIO-08) thì CHUA_CO_DANH_SACH.
-- Ai gọi: có quyền Buổi học · Xem (phạm vi cơ sở hoặc toàn hệ thống). Cần phân hệ DIEM_DANH_TRONG_NGAY bật (Admin chỉ thấy cơ sở đã bật). Bộ lọc: date (mặc định hôm nay giờ Việt Nam),
-- branch_id, teacher_id, state[], has_notice (true: chỉ buổi có em báo nghỉ). Sắp theo giờ bắt đầu, phân trang ở máy chủ.
create or replace function app.session_day_attendance(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_date date := coalesce(nullif(p_filters ->> 'date', '')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_state text[] := case when jsonb_typeof(p_filters -> 'state') = 'array' then array(select jsonb_array_elements_text(p_filters -> 'state')) end;
  v_notice boolean := (p_filters ->> 'has_notice')::boolean;
  v_total bigint;
  v_rows jsonb;
begin
  -- Cờ theo cơ sở: phạm vi cơ sở bị chặn rõ ràng khi tắt; Admin chỉ thấy cơ sở đã bật (điều kiện ở f).
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('DIEM_DANH_TRONG_NGAY', app.current_branch_id());
  end if;
  with f as (
    select s.id, s.class_id, s.branch_id, s.session_no, s.start_time, s.end_time, s.status_code, s.teacher_id, s.room_id,
           a.total, a.ops, a.teacher, a.notice
      from app.class_session s
      cross join lateral (
        select count(*) as total,
               jsonb_build_object('CO_MAT', count(*) filter (where x.ops_status_code = 'CO_MAT'), 'DI_MUON', count(*) filter (where x.ops_status_code = 'DI_MUON'),
                                  'VANG_CO_PHEP', count(*) filter (where x.ops_status_code = 'VANG_CO_PHEP'), 'VANG_KHONG_PHEP', count(*) filter (where x.ops_status_code = 'VANG_KHONG_PHEP'),
                                  'CHUA', count(*) filter (where x.ops_status_code is null)) as ops,
               jsonb_build_object('CO_MAT', count(*) filter (where x.teacher_status_code = 'CO_MAT'), 'DI_MUON', count(*) filter (where x.teacher_status_code = 'DI_MUON'),
                                  'VANG_CO_PHEP', count(*) filter (where x.teacher_status_code = 'VANG_CO_PHEP'), 'VANG_KHONG_PHEP', count(*) filter (where x.teacher_status_code = 'VANG_KHONG_PHEP'),
                                  'CHUA', count(*) filter (where x.teacher_status_code is null)) as teacher,
               count(*) filter (where x.contact_reason_code = 'XIN_NGHI_HOC') as notice
          from app.session_attendance x where x.session_id = s.id and x.is_active) a
     where s.session_date = v_date and s.status_code not in ('HUY_KHONG_PHI', 'HUY_CO_PHI', 'DA_THAY')
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = app.current_branch_id())
       and app.feature_enabled('DIEM_DANH_TRONG_NGAY', s.branch_id)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_notice is null or (a.notice > 0) = v_notice)
       and (v_state is null or (case when s.status_code = 'NHAP' then 'CHUA_CO_DANH_SACH'
                                     when a.total = 0 or a.total = (a.teacher ->> 'CHUA')::bigint then 'CHUA_GHI'
                                     when (a.teacher ->> 'CHUA')::bigint = 0 then 'GHI_DU' else 'GHI_DO' end) = any (v_state))
  ), page as (
    select * from f order by start_time, id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'session_id', p.id, 'class_id', p.class_id, 'class_code', c.code, 'session_no', p.session_no, 'branch_code', b.code,
           'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id), 'teacher_name', app.staff_display_name(p.teacher_id),
           'status_code', p.status_code, 'total', p.total, 'ops', p.ops, 'teacher', p.teacher, 'notice', p.notice,
           'state', case when p.status_code = 'NHAP' then 'CHUA_CO_DANH_SACH'
                         when p.total = 0 or p.total = (p.teacher ->> 'CHUA')::bigint then 'CHUA_GHI'
                         when (p.teacher ->> 'CHUA')::bigint = 0 then 'GHI_DU' else 'GHI_DO' end)
           order by p.start_time, p.id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id join app.branch b on b.id = p.branch_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.session_day_attendance(jsonb, integer, integer) from public, anon, authenticated;
grant execute on function app.session_day_attendance(jsonb, integer, integer) to authenticated;
