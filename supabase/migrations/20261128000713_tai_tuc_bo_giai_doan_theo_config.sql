-- C-27-20, 20b, 20c, 20d (anh Trường 28/11/2026 09:46 đến 10:02; rủi ro CAO: dữ liệu).
-- (1) Thay bộ giai đoạn và giai đoạn con của phiếu tái tục theo bảng Config của anh (docs/spec/06 mục 1.4). Mã giai đoạn giữ nguyên, tên và nghĩa đổi.
--     L8 chỉ theo TIẾN ĐỘ ĐƠN (không theo tiền; cơ hội giữ nguyên L8 theo tiền): L8A Chờ lên đơn, L8B Đã lên đơn chờ duyệt, L8C Đơn đã duyệt. Hệ thống tự đặt.
-- (2) Phiếu KẾT THÚC khi L5 (mọi giai đoạn con) hoặc L8C. L8A, L8B còn xử lý.
-- (3) Chuyển giai đoạn: bắt buộc chọn giai đoạn con thuộc giai đoạn đích; L5 không còn bắt lý do (L5A..L5G là lý do).
-- (4) Dữ liệu cũ: xem khối «Dữ liệu cũ» bên dưới.
select set_config('hmt.migration', 'on', false);

update app.catalog_item i set name = v.name
  from (values
  ('L1', 'Chờ tái tục'),
  ('L2', 'Tổng hợp thông tin'),
  ('L3', 'Chưa liên hệ được'),
  ('L4', 'Đang tư vấn'),
  ('L5', 'Không tái tục'),
  ('L6', 'Tiềm năng tái tục'),
  ('L7', 'Dự thu'),
  ('L8', 'Hoàn thành tái tục')
  ) v (code, name)
 where i.catalog_code = 'UPSALE_STAGE' and i.code = v.code;

-- Giai đoạn con: mã đã có thì đổi tên, thứ tự; mã mới thì thêm.
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, extra)
select 'UPSALE_SUBSTAGE', v.code,
       v.name, v.sort_order, p.id,
       case when v.stage = 'L5' or v.code = 'L8C' then '{"terminal": true}'::jsonb else '{}'::jsonb end
  from (values
  ('L1A', 'Hệ thống sinh tự động', 1, 'L1'),
  ('L1B', 'Tạo thủ công', 2, 'L1'),
  ('L1C', 'Đã tiếp nhận, chờ xếp lịch gọi', 3, 'L1'),
  ('L2A', 'Chờ nhận xét của giáo viên', 4, 'L2'),
  ('L2B', 'Chờ kết quả kiểm tra định kỳ', 5, 'L2'),
  ('L2C', 'Chờ xác nhận lộ trình tiếp theo', 6, 'L2'),
  ('L2D', 'Đã đủ thông tin, sẵn sàng tư vấn', 7, 'L2'),
  ('L3A', 'Không nghe máy', 8, 'L3'),
  ('L3B', 'Máy bận, hẹn gọi lại', 9, 'L3'),
  ('L3C', 'Sai số điện thoại', 10, 'L3'),
  ('L3D', 'Đã nhắn tin, chờ phản hồi', 11, 'L3'),
  ('L3E', 'Quá 3 lần không liên hệ được', 12, 'L3'),
  ('L4A', 'Phụ huynh đang cân nhắc', 13, 'L4'),
  ('L4B', 'Chờ phụ huynh họp gia đình', 14, 'L4'),
  ('L4C', 'Đang thương lượng học phí', 15, 'L4'),
  ('L4D', 'Vướng lịch học, cần đổi khung giờ', 16, 'L4'),
  ('L4E', 'Hẹn gặp trực tiếp tại cơ sở', 17, 'L4'),
  ('L5A', 'Học phí vượt khả năng', 18, 'L5'),
  ('L5B', 'Không sắp xếp được lịch', 19, 'L5'),
  ('L5C', 'Chuyển nơi ở, chuyển trường', 20, 'L5'),
  ('L5D', 'Không hài lòng chất lượng', 21, 'L5'),
  ('L5E', 'Đã đạt mục tiêu, không học tiếp', 22, 'L5'),
  ('L5F', 'Chuyển sang trung tâm khác', 23, 'L5'),
  ('L5G', 'Lý do khác', 24, 'L5'),
  ('L6A', 'Đồng ý học tiếp, chưa chốt gói', 25, 'L6'),
  ('L6B', 'Muốn đổi môn hoặc đổi lớp', 26, 'L6'),
  ('L6C', 'Muốn học thêm bổ trợ', 27, 'L6'),
  ('L6D', 'Hẹn tái tục vào kỳ sau', 28, 'L6'),
  ('L7A', 'Đã gửi báo giá', 29, 'L7'),
  ('L7B', 'Đã chốt gói, hẹn ngày đóng', 30, 'L7'),
  ('L7C', 'Quá hẹn đóng, cần nhắc lại', 31, 'L7'),
  ('L8A', 'Chờ lên đơn', 32, 'L8'),
  ('L8B', 'Đã lên đơn, chờ duyệt', 33, 'L8'),
  ('L8C', 'Đơn đã duyệt', 34, 'L8')
  ) v (code, name, sort_order, stage)
  join app.catalog_item p on p.catalog_code = 'UPSALE_STAGE' and p.code = v.stage
on conflict (catalog_code, code) do update
  set name = excluded.name, sort_order = excluded.sort_order, parent_id = excluded.parent_id, extra = excluded.extra, is_active = true;

update app.catalog set description = 'L5 Không tái tục và L8C là kết thúc phiếu; mỗi giai đoạn đều có giai đoạn con.' where code = 'UPSALE_STAGE';

-- app.upsale_l8_substage(phiếu): giai đoạn con L8 theo đơn của phiếu. Luật R-GD-13 (28/11): không có đơn còn sống (khác Huỷ) là L8A; mọi đơn còn sống đã
-- duyệt là L8C; còn lại (Nháp, Đã trình) là L8B. Nội bộ.
create function app.upsale_l8_substage(p_ticket_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when count(*) = 0 then 'L8A' when bool_and(o.status_code = 'DA_DUYET') then 'L8C' else 'L8B' end
    from app.sales_order o where o.renewal_ticket_id = p_ticket_id and o.status_code <> 'HUY';
$$;
revoke execute on function app.upsale_l8_substage(uuid) from public, anon, authenticated;

-- app.upsale_sync_l8(phiếu): phiếu đang ở L8 thì đặt giai đoạn con theo đơn. Chỉ đi tới (L8A, L8B, L8C), không lùi khi huỷ đơn; L8C ghi thời điểm kết thúc;
-- ghi lịch sử «Hệ thống chuyển L8B/L8C». Nội bộ: gọi từ trigger của đơn hàng, cùng giao dịch lúc tạo, trình, duyệt, huỷ đơn.
create function app.upsale_sync_l8(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_sub text;
begin
  select * into t from app.upsale_ticket where id = p_ticket_id for update;
  if t.id is null or t.stage_code <> 'L8' then
    return;
  end if;
  v_sub := app.upsale_l8_substage(t.id);
  if v_sub <= coalesce(t.substage_code, '') then
    return;
  end if;
  update app.upsale_ticket
     set substage_code = v_sub, closed_at = case when app.upsale_is_closed('L8', v_sub) then coalesce(closed_at, now()) else closed_at end
   where id = t.id;
  perform app.upsale_add_event(t.id, 'DOI_GIAI_DOAN', 'L8', 'L8', 'Hệ thống chuyển ' || v_sub);
end;
$$;
revoke execute on function app.upsale_sync_l8(uuid) from public, anon, authenticated;

create function app.tg_sales_order_upsale_l8()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.upsale_sync_l8(new.renewal_ticket_id);
  return null;
end;
$$;
revoke execute on function app.tg_sales_order_upsale_l8() from public, anon, authenticated;
create trigger sales_order_upsale_l8 after insert or update of status_code, renewal_ticket_id on app.sales_order
  for each row when (new.renewal_ticket_id is not null) execute function app.tg_sales_order_upsale_l8();

-- app.upsale_is_closed(giai đoạn, giai đoạn con): phiếu đã kết thúc chưa. Luật R-GD-13 (28/11): L5, hoặc L8C.
create function app.upsale_is_closed(p_stage text, p_substage text)
returns boolean
language sql
immutable
set search_path = ''
as $$ select p_stage = 'L5' or (p_stage = 'L8' and p_substage is not distinct from 'L8C'); $$;
revoke execute on function app.upsale_is_closed(text, text) from public, anon, authenticated;

-- ---- Dữ liệu cũ ----
-- L5 không còn bắt buộc lý do danh mục (giữ cột).
do $$
declare c text;
begin
  for c in select conname from pg_constraint where conrelid = 'app.upsale_ticket'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%lost_reason_code%' loop
    execute format('alter table app.upsale_ticket drop constraint %I', c); -- tên ràng buộc do Postgres tự đặt
  end loop;
end $$;
drop index app.upsale_ticket_open_uq;

-- Giai đoạn con rỗng hoặc không thuộc giai đoạn: đặt giai đoạn con đầu. L5 theo lý do cũ (không rõ thì L5G). L8 cũ nghĩa «đã đóng đủ» nên là L8C, giữ đóng (anh Trường OK 29/11 00:18).
update app.upsale_ticket t
   set substage_code = case
         when t.stage_code = 'L5' then case t.lost_reason_code
                when 'HOC_PHI' then 'L5A' when 'LICH_HOC' then 'L5B' when 'CHUYEN_NHA' then 'L5C' when 'CHAT_LUONG' then 'L5D'
                when 'DU_MUC_TIEU' then 'L5E' when 'HOC_NOI_KHAC' then 'L5F' else 'L5G' end
         when t.stage_code = 'L8' then 'L8C'
         else t.stage_code || 'A' end
 where t.stage_code in ('L5', 'L8')
    or t.substage_code is null or left(t.substage_code, 2) <> t.stage_code;
update app.upsale_ticket t set closed_at = coalesce(t.closed_at, t.updated_at)
 where app.upsale_is_closed(t.stage_code, t.substage_code) and t.closed_at is null;

-- Mỗi (học sinh, lớp) tối đa một phiếu chưa kết thúc (R-GD-13); cũng là chỗ tra khi tự sinh.
create unique index upsale_ticket_open_uq on app.upsale_ticket (student_id, class_id) where closed_at is null;

-- app.change_upsale_stage(phiếu, giai đoạn mới, lý do, ghi chú, giai đoạn con): người có Phiếu tái tục · Sửa đổi giai đoạn BẰNG TAY giữa mọi giai đoạn.
-- Luật R-GD-13 (28/11): giai đoạn con bắt buộc và thuộc giai đoạn đích. Lý do danh mục không bắt buộc (chỉ lưu khi vào L5). Trả {id, stage_code, substage_code}.
create or replace function app.change_upsale_stage(p_id uuid, p_to text, p_reason_code text default null, p_note text default null, p_substage text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_sub text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  if p_to is null or p_to not in ('L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8') then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Giai đoạn mới không hợp lệ.');
  end if;
  -- Giai đoạn con: bắt buộc, đang dùng, thuộc đúng giai đoạn đích (docs/spec/06 mục 1.4). Riêng L8 hệ thống đặt theo đơn của phiếu, người dùng không chọn.
  v_sub := case when p_to = 'L8' then app.upsale_l8_substage(t.id) else p_substage end;
  if not exists (select from app.catalog_item s join app.catalog_item p on p.id = s.parent_id
                  where s.catalog_code = 'UPSALE_SUBSTAGE' and s.code = v_sub and s.is_active and p.code = p_to) then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Chọn giai đoạn con của giai đoạn mới.');
  end if;
  -- Cùng giai đoạn chỉ được đổi giai đoạn con; đang ở L8 thì không chuyển tay vào L8 nữa.
  if p_to = t.stage_code and (p_to = 'L8' or v_sub is not distinct from t.substage_code) then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Phiếu đang ở giai đoạn này.');
  end if;
  -- Luật R-GD-13: mỗi học sinh ở mỗi lớp tối đa một phiếu đang mở; mở lại phiếu đã kết thúc thì kiểm trước.
  if t.closed_at is not null and not app.upsale_is_closed(p_to, v_sub)
     and exists (select from app.upsale_ticket o
                  where o.student_id = t.student_id and o.class_id = t.class_id and o.id <> t.id and o.closed_at is null) then
    perform app.raise_error('HMT_DA_CO_PHIEU_TAI_TUC', 'Học sinh này đã có phiếu tái tục đang mở ở lớp này.');
  end if;
  -- L5, L8C là kết thúc: ghi thời điểm đóng; rời khỏi thì bỏ ngày đóng. Rời L5 thì bỏ lý do.
  update app.upsale_ticket
     set stage_code = p_to, substage_code = v_sub,
         lost_reason_code = case when p_to = 'L5' then p_reason_code end,
         lost_note = case when p_to = 'L5' then v_note end,
         closed_at = case when app.upsale_is_closed(p_to, v_sub) then coalesce(closed_at, now()) end
   where id = p_id;
  perform app.upsale_add_event(p_id, 'DOI_GIAI_DOAN', t.stage_code, p_to, p_note);
  return jsonb_build_object('id', p_id, 'stage_code', p_to, 'substage_code', v_sub);
end;
$$;

-- Các hàm dưới: «phiếu đang mở» = closed_at rỗng (trước đây: giai đoạn khác L5, L8).
-- app.assign_upsale_ticket: giao phiếu cho người phụ trách. Phiếu đã kết thúc (L5, L8C) không giao nữa; L8A, L8B vẫn giao được.
create or replace function app.assign_upsale_ticket(p_id uuid, p_owner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'GIAO_VIEC', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  if t.closed_at is not null then
    perform app.raise_error('HMT_PHIEU_DA_KET_THUC', 'Phiếu tái tục đã kết thúc, không giao nữa.');
  end if;
  -- Luật: người nhận phải thuộc cơ sở của phiếu.
  perform app.assert_staff_in_branch(p_owner_id, t.branch_id);
  update app.upsale_ticket set owner_id = p_owner_id where id = p_id;
  perform app.upsale_add_event(p_id, 'GIAO', t.stage_code, t.stage_code, 'Giao cho ' || coalesce(app.staff_display_name(p_owner_id), '(chưa rõ)'));
  return jsonb_build_object('id', p_id, 'owner_id', p_owner_id);
end;
$$;

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
  if exists (select from app.upsale_ticket where student_id = p_student_id and class_id = p_class_id and closed_at is null) then
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

-- Đợt quét: đóng do dừng học là L5G; không sinh phiếu mới khi còn phiếu chưa kết thúc (kể cả L8A, L8B) hoặc đã từng L5.
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
    update app.upsale_ticket set stage_code = 'L5', substage_code = 'L5G', lost_reason_code = 'KHAC',
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
       and not exists (select from app.upsale_ticket o where o.student_id = t.student_id and o.class_id = n.class_id and o.closed_at is null)
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
                        and (t.stage_code = 'L5' or t.closed_at is null))
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
    'open_ticket_code', (select code from app.upsale_ticket where student_id = v.student_id and class_id = v.class_id and closed_at is null));
end;
$$;

create or replace function app.get_upsale_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_open boolean;
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.closed_at is null;
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by),
      'branch_id', t.branch_id), -- cho form báo giá từ phiếu: hạn hiệu lực theo cơ sở của phiếu
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', p.email)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name, 'birth_year', s.birth_year)
                  from app.student s where s.id = t.student_id),
    'class', app.upsale_class_info(t),
    'enrollments', app.upsale_enrollments(t),
    'last_review', app.upsale_last_review(t),
    'hours', app.upsale_hours_info(t),
    'contact', app.upsale_contact_info(t),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end,
      -- Luật R-GD-13 (28/11): tạo báo giá ở mọi giai đoạn; tạo đơn chỉ ở L8 (thu tiền trước, chuyển L8 rồi mới tạo đơn).
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when t.stage_code = 'L8' and app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;

create or replace function app.list_expiring_enrollments(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_search text := nullif(btrim(coalesce(p_filters ->> 'search', '')), '');
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách sắp hết giờ.');
  end if;
  -- Cờ theo cơ sở: người có phạm vi cơ sở bị chặn rõ ràng khi tắt; Admin (toàn hệ thống) chỉ thấy các cơ sở đã bật (điều kiện ở base).
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('SAP_HET_GIO', app.current_branch_id());
  end if;
  with t as (
    select * from app.expiring_enrollment_rows(v_class, v_scope)
  ), f as (
    select t.* from t
      join app.student st on st.id = t.student_id
      join app.class c on c.id = t.class_id
     where t.status_code is not null
       and (v_status is null or t.status_code = any (v_status))
       and (v_search is null or st.full_name ilike '%' || v_search || '%' or c.code ilike '%' || v_search || '%')
  ), page as (
    select * from f order by projected_end nulls first, student_id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'student_id', p.student_id, 'student_name', st.full_name, 'class_id', p.class_id, 'class_code', c.code,
           'enrollment_codes', to_jsonb(p.enrollment_codes), 'hours_left', p.hours_left,
           'projected_end', p.projected_end, 'validity_date', p.validity_date, 'status_code', p.status_code,
           'upsale_id', (select u.id from app.upsale_ticket u where u.student_id = p.student_id and u.class_id = p.class_id and u.closed_at is null),
           'upsale_code', (select u.code from app.upsale_ticket u where u.student_id = p.student_id and u.class_id = p.class_id and u.closed_at is null))
           order by p.projected_end nulls first, p.student_id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.student st on st.id = p.student_id join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

create or replace function app.upsale_reconcile_base(p_month date, p_branch_id uuid default null)
returns table (student_id uuid, class_id uuid, branch_id uuid, hours_left numeric, expected_end_date date, ticket_id uuid, ticket_code text, ticket_origin text,
               missing_reason text, enrollment_codes text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('UPSALE', 'XEM');
  v_first date := date_trunc('month', p_month)::date;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_my_branch uuid := (select app.current_branch_id());
begin
  -- Luật quyền: phải có quyền Xem phiếu tái tục; phạm vi toàn hệ thống hoặc cơ sở của mình.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này ở cơ sở này.');
  end if;
  return query
  with cand as (
    select c.student_id, c.class_id, c.branch_id, c.hours_left as cand_hours,
           coalesce(c.expected_end_date, case when c.hours_left <= 0 then v_today end) as cand_end -- đã hết giờ: tính hôm nay
      from app.upsale_candidates() c
     where (v_scope = 'TOAN_HE_THONG' or c.branch_id = v_my_branch)
       and (p_branch_id is null or c.branch_id = p_branch_id)
  ), joined as (
    select c.student_id, c.class_id, c.branch_id,
           coalesce(t.hours_left, c.cand_hours) as hours_left,
           coalesce(t.expected_end_date, c.cand_end) as expected_end_date,
           t.id as ticket_id, t.code as ticket_code, t.origin_code as ticket_origin
      from cand c
      left join app.upsale_ticket t on t.student_id = c.student_id and t.class_id = c.class_id and t.closed_at is null
  ), inm as (
    -- Lọc tháng TRƯỚC khi tính lý do và mã ghi danh (chỉ làm cho dòng trong tháng).
    select j.* from joined j where j.expected_end_date >= v_first and j.expected_end_date < (v_first + interval '1 month')::date
  )
  select j.student_id, j.class_id, j.branch_id, j.hours_left, j.expected_end_date, j.ticket_id, j.ticket_code, j.ticket_origin,
         case when j.ticket_id is not null then null
              when l5.student_id is not null then 'CO_PHIEU_L5'
              when sl.class_id is null then 'LOP_CHUA_CO_LICH'
              else 'CHO_QUET_DEM' end,
         codes.codes
    from inm j
    left join (select distinct l.student_id, l.class_id from app.upsale_ticket l where l.stage_code = 'L5') l5 on l5.student_id = j.student_id and l5.class_id = j.class_id
    left join (select distinct s.class_id from app.class_slot s where s.is_active) sl on sl.class_id = j.class_id
    left join lateral (select string_agg(e.code, ', ' order by e.code) as codes
                         from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                        where e.student_id = j.student_id and ec.class_id = j.class_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')) codes on true;
end;
$$;

create or replace function app.work_renewals(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('UPSALE', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  with th as materialized (
    select br.id, app.get_setting_numeric('upsale_hours_left_threshold', br.id) as hours,
           app.get_setting_int('upsale_days_left_threshold', br.id)::integer as days
      from app.branch br
  )
  select 'RENEWAL', 'UPSALE_TICKET', u.id, u.parent_id, null::text,
         case when u.expected_end_date <= v_today or u.hours_left <= 0 then 'NOW' else 'SOON' end,
         'Tái tục ' || u.code || ' · ' || st.full_name,
         concat_ws(', ', 'Sắp hết giờ', 'còn ' || trim_scale(u.hours_left) || ' giờ', 'dự kiến hết ' || to_char(u.expected_end_date, 'DD/MM/YYYY')),
         (u.expected_end_date::timestamp at time zone 'Asia/Ho_Chi_Minh'), 'OPEN_RENEWAL', u.owner_id, u.branch_id
    from app.upsale_ticket u
    join app.student st on st.id = u.student_id
    join th on th.id = u.branch_id
   where u.closed_at is null
     and (u.hours_left <= th.hours or u.expected_end_date <= v_today + th.days)
     and (v_scope = 'TOAN_HE_THONG' or u.branch_id = v_my)
     and (p_branch is null or u.branch_id = p_branch)
     and (not p_mine or u.owner_id = v_me);
end;
$$;

-- app.order_group_counts: thêm bộ lọc upsale_ticket_id (thân còn lại giữ nguyên bản migration 604).
create or replace function app.order_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Sale».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_quo uuid := nullif(p_filters ->> 'quotation_id', '')::uuid;
  -- C-27-21: đơn của một phiếu tái tục (nút «Đơn hàng» trên phiếu).
  v_ticket uuid := nullif(p_filters ->> 'upsale_ticket_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_waiting boolean := coalesce((p_filters ->> 'waiting_me')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: quyền xem đơn hàng.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách đơn hàng.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch', 'sale'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở, sale).');
  end if;
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_creator is null or o.created_by = v_creator)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_ticket is null or o.renewal_ticket_id = v_ticket)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'sale' then f.created_by::text end as k1,
           case v_f2 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'sale' then f.created_by::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.order_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.order_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- app.list_orders: thêm bộ lọc upsale_ticket_id (thân còn lại giữ nguyên bản migration 604).
create or replace function app.list_orders(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Sale».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_quo uuid := nullif(p_filters ->> 'quotation_id', '')::uuid;
  -- C-27-21: đơn của một phiếu tái tục (nút «Đơn hàng» trên phiếu).
  v_ticket uuid := nullif(p_filters ->> 'upsale_ticket_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_waiting boolean := coalesce((p_filters ->> 'waiting_me')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách đơn hàng.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang).
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_creator is null or o.created_by = v_creator)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_ticket is null or o.renewal_ticket_id = v_ticket)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'total_desc' then f.total_amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = p.status_code),
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'opportunity_id', p.opportunity_id, 'opportunity_code', op.code,
             'quotation_id', p.quotation_id, 'quotation_code', q.code,
             'student_name', (select coalesce(s.full_name, v.full_name) from app.sales_order_line l
                                left join app.prospect_student_v v on v.id = l.prospect_student_id
                                left join app.student s on s.id = l.student_id
                               where l.order_id = p.id order by l.line_no limit 1),
             -- Tên các em theo thứ tự dòng, không trùng; chỉ gom cho các đơn của trang đang hiện (p là trang, không quét cả bảng).
             'student_names', (select coalesce(jsonb_agg(x.nm order by x.first_line), '[]'::jsonb)
                                 from (select coalesce(s.full_name, v.full_name) as nm, min(l.line_no) as first_line
                                         from app.sales_order_line l
                                         left join app.prospect_student_v v on v.id = l.prospect_student_id
                                         left join app.student s on s.id = l.student_id
                                        where l.order_id = p.id and coalesce(s.full_name, v.full_name) is not null
                                        group by coalesce(s.full_name, v.full_name)) x),
             'line_count', (select count(*) from app.sales_order_line l where l.order_id = p.id),
             'total_amount', p.total_amount, 'needs_acknowledgement', p.needs_acknowledgement,
             -- Tiền đã thu của đơn (khoản tiền vào, kể cả khoản âm hoàn tác) cho cột «Đã thu», «Còn phải thu», «Thu tiền» của canvas BH06; chỉ tính cho đơn của trang đang hiện.
             'paid_amount', (select coalesce(sum(m.amount), 0)::bigint from app.money_in m where m.order_id = p.id),
             'submitted_at', p.submitted_at, 'approved_at', p.approved_at, 'created_at', p.created_at, 'branch_code', b.code,
             'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id))
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'total_desc' then p.total_amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.opportunity op on op.id = p.opportunity_id
    left join app.quotation q on q.id = p.quotation_id;
  return v_result;
end;
$$;

select set_config('hmt.migration', '', false);
