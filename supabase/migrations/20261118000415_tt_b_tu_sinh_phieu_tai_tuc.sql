-- TT-B Phiếu tái tục, tự sinh và đối soát (Code C, 18/11/2026; Chat 11:55 chốt thứ tự TT-A, TT-C, TT-B; TT-B tự viết hàm ngày hết giờ dự kiến).
-- Luật R-GD-13 (làm lại sau R-V2-25): phiếu sinh theo (học sinh, lớp) khi chạm một trong hai ngưỡng (giờ còn <= upsale_hours_left_threshold hoặc hết giờ dự kiến còn
-- <= upsale_days_left_threshold ngày; giờ âm hoặc 0 cũng tính); mỗi cặp tối đa một phiếu mở; L5 Không tái tục thì KHÔNG tự sinh lại; bảo lưu thì dừng sinh;
-- dừng học thì đóng phiếu đang mở (L5, lý do Khác kèm ghi chú «Học sinh đã dừng học»); chuyển lớp thì phiếu mở chuyển theo lớp mới; vắng >= absence_risk_sessions buổi trong
-- absence_risk_window_days ngày ở lớp đó thì gắn cờ rủi ro. Giờ còn và ngày hết giờ dự kiến tính CÙNG CÁCH với GD-07 (migration 142): tổng sổ giờ của mọi ghi danh
-- còn hiệu lực của em ở lớp; hết giờ dự kiến = hôm nay + giờ còn / giờ học mỗi tuần của lớp * 7 ngày.
-- CỜ TẮT MẶC ĐỊNH: upsale_auto_generate_enabled (ghi đè theo cơ sở). Lịch pg_cron KHÔNG tự đăng ký: gọi app.sync_upsale_cron() sau khi anh duyệt.
-- Sửa hai nhắc nhỏ của Chat: (1) create_upsale_ticket kiểm học sinh cùng cơ sở với lớp; (2) preview_upsale_enrollment kiểm quyền trước, người không có quyền
-- nhận cùng một câu cho mã có và mã không có (không dò được mã ghi danh).
select set_config('hmt.migration', 'on', false);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('upsale_auto_generate_enabled', 'Tự sinh phiếu tái tục', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-GD-13',
   'Tắt: hệ thống không tự sinh, đối soát phiếu tái tục ở cơ sở. Bật: mỗi đêm tự sinh phiếu cho học sinh chạm ngưỡng giờ hoặc ngày, đóng phiếu khi dừng học, chuyển phiếu khi chuyển lớp.'),
  ('absence_risk_window_days', 'Số ngày xét vắng gắn cờ rủi ro', 'INT', 'ngày', 1, 180, '30', true, 'VAN_HANH_LOP', 'R-GD-13',
   'Vắng từ «Số buổi vắng gắn cờ rủi ro» buổi trở lên trong chừng này ngày gần nhất ở một lớp thì phiếu tái tục của em ở lớp đó gắn cờ rủi ro.');

-- 1. Sửa nhắc nhỏ (1): create_upsale_ticket kiểm cơ sở của học sinh khớp lớp (thân bản migration 410, thêm một luật).
create or replace function app.create_upsale_ticket(p_student_id uuid, p_class_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class app.class;
  v_student app.student;
  v_id uuid;
  v_code text;
begin
  select * into v_class from app.class where id = p_class_id;
  select * into v_student from app.student where id = p_student_id;
  if v_class.id is null or v_student.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh hoặc lớp.');
  end if;
  perform app.assert_can('UPSALE', 'TAO', v_class.branch_id);
  perform app.require_feature('BAN_HANG', v_class.branch_id);
  -- Luật (nhắc của Chat 12:25): học sinh cùng cơ sở với lớp.
  if v_student.branch_id is distinct from v_class.branch_id then
    perform app.raise_error('HMT_HOC_SINH_KHAC_CO_SO', 'Học sinh thuộc cơ sở khác với lớp nên chưa tạo được phiếu tái tục.');
  end if;
  -- Luật R-GD-13: học sinh phải đang học ở lớp này.
  if not exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                  where e.student_id = p_student_id and ec.class_id = p_class_id and ec.end_date is null) then
    perform app.raise_error('HMT_HOC_SINH_KHONG_O_LOP', 'Học sinh này hiện không học ở lớp đã chọn nên chưa tạo được phiếu tái tục.');
  end if;
  -- Luật R-GD-13: mỗi học sinh ở mỗi lớp tối đa một phiếu đang mở.
  if exists (select from app.upsale_ticket where student_id = p_student_id and class_id = p_class_id and stage_code not in ('L5', 'L8')) then
    perform app.raise_error('HMT_DA_CO_PHIEU_TAI_TUC', 'Học sinh này đã có phiếu tái tục đang mở ở lớp này.');
  end if;
  v_code := app.issue_upsale_code();
  insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  values (v_code, v_class.branch_id, p_student_id, v_student.parent_id, p_class_id, 'L1', 'L1B', 'TAY')
  returning id into v_id;
  perform app.upsale_add_event(v_id, 'TAO', null, 'L1', coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Tạo thủ công'));
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- 2. Sửa nhắc nhỏ (2): preview kiểm quyền Tạo (phạm vi người gọi) TRƯỚC khi nói mã có hay không.
create or replace function app.preview_upsale_enrollment(p_enrollment_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  -- Người không có quyền Tạo ở đâu cũng nhận cùng một lỗi, dù mã có hay không.
  if app.permission_scope('UPSALE', 'TAO') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này ở cơ sở này.');
  end if;
  select * into v from app.upsale_target_of_enrollment(p_enrollment_code);
  -- Mã ở cơ sở ngoài phạm vi báo như mã không có (không lộ ghi danh cơ sở khác).
  if v.enrollment_id is null or not app.can_see_branch('UPSALE', 'TAO', v.branch_id) then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object('found', true,
    'student_name', (select full_name from app.student where id = v.student_id),
    'class_code', (select code from app.class where id = v.class_id),
    'enrollment_count', (select count(*)::int from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                          where e.student_id = v.student_id and ec.class_id = v.class_id and ec.end_date is null),
    'open_ticket_code', (select code from app.upsale_ticket where student_id = v.student_id and class_id = v.class_id and stage_code not in ('L5', 'L8')));
end;
$$;

-- ---------------------------------------------------------------------------
-- app.upsale_candidates(): mỗi dòng là một (học sinh, lớp) có ghi danh còn hiệu lực (Đã xếp lớp, Đang học; không tính Bảo lưu, Dừng, Hoàn thành, Hoàn phí)
-- còn dòng xếp lớp đang mở. Cột: giờ còn (tổng sổ giờ, kể cả giờ tặng, giờ âm), ngày hết giờ dự kiến (cùng cách GD-07; null nếu hết giờ, giờ âm hoặc lớp chưa có
-- khung giờ), cờ rủi ro vắng. Hàm nội bộ cho hàm tự sinh và báo cáo TT-04 (gọi từ hàm security definer), KHÔNG mở cho người dùng.
-- ---------------------------------------------------------------------------
create or replace function app.upsale_candidates()
returns table (student_id uuid, class_id uuid, branch_id uuid, parent_id uuid, hours_left numeric, expected_end_date date, risk_flag boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with grp as (
    select e.student_id, ec.class_id, min(e.branch_id::text)::uuid as branch_id, min(e.parent_id::text)::uuid as parent_id,
           sum(coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) as hours_left
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
     where e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
     group by e.student_id, ec.class_id
  ), calc as (
    select g.*,
           coalesce((select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) -- allow-number: 3600 giây một giờ
                       from app.class_slot s where s.class_id = g.class_id and s.is_active), 0) as weekly_hours
      from grp g
  )
  select c.student_id, c.class_id, c.branch_id, c.parent_id, c.hours_left,
         case when c.hours_left > 0 and c.weekly_hours > 0
              then ((now() at time zone 'Asia/Ho_Chi_Minh')::date + ceil(c.hours_left / c.weekly_hours * 7)::integer) end, -- allow-number: 7 ngày một tuần
         (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
           where sa.student_id = c.student_id and s.class_id = c.class_id and sa.is_active
             and coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - app.get_setting_int('absence_risk_window_days', c.branch_id)::integer)
           >= app.get_setting_int('absence_risk_sessions', c.branch_id)
    from calc c;
$$;

-- ---------------------------------------------------------------------------
-- app.generate_upsale_tickets(): chạy mỗi đêm (pg_cron) hoặc Admin gọi tay. Làm bốn việc cho các cơ sở BẬT upsale_auto_generate_enabled và công tắc Bán hàng:
-- (a) đối soát: dừng học đóng phiếu mở (L5, lý do Dừng học); chuyển lớp chuyển phiếu mở sang lớp mới; (b) cập nhật giờ còn, ngày hết giờ, cờ rủi ro của phiếu mở L1 đến L4;
-- (c) sinh phiếu mới (L1A) cho (học sinh, lớp) chạm ngưỡng, chưa có phiếu mở, chưa từng L5; (d) kết quả {created, updated, closed, moved}.
-- Ai gọi: pg_cron (không có người đăng nhập) hoặc Admin đã xác thực hai bước. Phiếu sinh tự động KHÔNG có người phụ trách (giao tay sau).
-- ---------------------------------------------------------------------------
create or replace function app.generate_upsale_tickets()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_created integer := 0;
  v_updated integer := 0;
  v_closed integer := 0;
  v_moved integer := 0;
  r record;
  v_id uuid;
begin
  -- Luật: chỉ cron hoặc Admin (hai bước).
  if auth.uid() is not null and not ('ADMIN' = any (app.current_roles()) and app.mfa_satisfied()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin (đã xác thực hai bước) chạy tự sinh phiếu tái tục.');
  end if;
  -- (a1) Dừng học: em không còn ghi danh hiệu lực ở lớp, có ghi danh Dừng ở lớp đó và không còn chỗ nào khác để chuyển theo: đóng phiếu.
  for r in
    select t.id, t.stage_code from app.upsale_ticket t
     where t.stage_code in ('L1', 'L2', 'L3', 'L4', 'L6') and app.get_setting_bool('upsale_auto_generate_enabled', t.branch_id)
       and app.feature_enabled('BAN_HANG', t.branch_id)
       and not exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                        where e.student_id = t.student_id and ec.class_id = t.class_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU'))
       and not exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                        where e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC'))
       and exists (select from app.enrollment e
                    join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id
                   where e.student_id = t.student_id and e.status_code = 'DUNG')
     for update of t
  loop
    update app.upsale_ticket set stage_code = 'L5', substage_code = null, lost_reason_code = 'KHAC',
           lost_note = 'Học sinh đã dừng học (hệ thống đóng phiếu)', closed_at = now() where id = r.id;
    perform app.upsale_add_event(r.id, 'DOI_GIAI_DOAN', r.stage_code, 'L5', 'Hệ thống đóng phiếu: học sinh đã dừng học');
    v_closed := v_closed + 1;
  end loop;
  -- (a2) Chuyển lớp: phiếu mở ở lớp cũ, em không còn hiệu lực ở lớp cũ mà đang hiệu lực ở đúng một lớp mới chưa có phiếu mở: chuyển phiếu sang lớp mới.
  for r in
    select t.id, t.class_id as old_class, n.class_id as new_class
      from app.upsale_ticket t
      join lateral (select ec.class_id from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                     where e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') group by ec.class_id) n on true
     where t.stage_code in ('L1', 'L2', 'L3', 'L4', 'L6') and app.get_setting_bool('upsale_auto_generate_enabled', t.branch_id)
       and app.feature_enabled('BAN_HANG', t.branch_id)
       and not exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                        where e.student_id = t.student_id and ec.class_id = t.class_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU'))
       and (select count(distinct ec.class_id) from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
             where e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')) = 1
       and exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id
                    where e.student_id = t.student_id and e.status_code = 'CHUYEN_LOP')
       and not exists (select from app.upsale_ticket o where o.student_id = t.student_id and o.class_id = n.class_id and o.stage_code not in ('L5', 'L8'))
     for update of t
  loop
    update app.upsale_ticket set class_id = r.new_class where id = r.id;
    perform app.upsale_add_event(r.id, 'DOI_GIAI_DOAN', null, null, 'Hệ thống chuyển phiếu theo lớp mới (học sinh chuyển lớp)');
    v_moved := v_moved + 1;
  end loop;
  -- (b) Cập nhật phiếu mở L1 đến L4: giờ còn, ngày hết giờ, cờ rủi ro.
  update app.upsale_ticket t set hours_left = c.hours_left, expected_end_date = c.expected_end_date, risk_flag = c.risk_flag
    from app.upsale_candidates() c
   where c.student_id = t.student_id and c.class_id = t.class_id and t.stage_code in ('L1', 'L2', 'L3', 'L4')
     and app.get_setting_bool('upsale_auto_generate_enabled', t.branch_id) and app.feature_enabled('BAN_HANG', t.branch_id)
     and (t.hours_left, t.expected_end_date, t.risk_flag) is distinct from (c.hours_left, c.expected_end_date, c.risk_flag);
  get diagnostics v_updated = row_count;
  -- (c) Sinh phiếu mới cho (học sinh, lớp) chạm ngưỡng: chưa có phiếu mở, chưa từng L5 (R-GD-13: L5 không tự sinh lại).
  for r in
    select c.* from app.upsale_candidates() c
     where app.get_setting_bool('upsale_auto_generate_enabled', c.branch_id) and app.feature_enabled('BAN_HANG', c.branch_id)
       and (c.hours_left <= app.get_setting_numeric('upsale_hours_left_threshold', c.branch_id)
            or (c.expected_end_date is not null
                and c.expected_end_date - (now() at time zone 'Asia/Ho_Chi_Minh')::date <= app.get_setting_int('upsale_days_left_threshold', c.branch_id)))
       and not exists (select from app.upsale_ticket t where t.student_id = c.student_id and t.class_id = c.class_id
                        and t.stage_code <> 'L8')
  loop
    insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code, hours_left, expected_end_date, risk_flag)
    values (app.issue_upsale_code(), r.branch_id, r.student_id, r.parent_id, r.class_id, 'L1', 'L1A', 'HE_THONG', r.hours_left, r.expected_end_date, r.risk_flag)
    returning id into v_id;
    perform app.upsale_add_event(v_id, 'TAO', null, 'L1', 'Hệ thống sinh khi chạm ngưỡng giờ hoặc ngày');
    v_created := v_created + 1;
  end loop;
  return jsonb_build_object('created', v_created, 'updated', v_updated, 'closed', v_closed, 'moved', v_moved);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.sync_upsale_cron(): đăng ký (hoặc đăng ký lại) lịch đêm 02:00 giờ Việt Nam (19:00 UTC) cho app.generate_upsale_tickets. KHÔNG tự gọi trong migration:
-- chờ anh duyệt đăng ký. Ai gọi: Admin (hai bước) hoặc người vận hành migration. Cần pg_cron (xem migration 104).
-- ---------------------------------------------------------------------------
create or replace function app.sync_upsale_cron()
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if to_regnamespace('cron') is null then
    perform app.raise_error('HMT_PG_CRON_CHUA_BAT', 'pg_cron chưa được bật trên cơ sở dữ liệu này. Bật pg_cron rồi gọi lại.');
  end if;
  if auth.uid() is not null and not ('ADMIN' = any (app.current_roles()) and app.mfa_satisfied()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin (đã xác thực hai bước) đổi lịch tự sinh phiếu tái tục.');
  end if;
  perform cron.schedule('hmt-generate-upsale-tickets', '0 19 * * *', 'select app.generate_upsale_tickets()'); -- allow-number: 19 giờ UTC là 02 giờ sáng giờ Việt Nam
  return '0 19 * * * (02:00 giờ Việt Nam)';
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.upsale_candidates() from public, anon, authenticated;
revoke execute on function app.generate_upsale_tickets(), app.sync_upsale_cron() from public, anon;
grant execute on function app.generate_upsale_tickets(), app.sync_upsale_cron() to authenticated;
