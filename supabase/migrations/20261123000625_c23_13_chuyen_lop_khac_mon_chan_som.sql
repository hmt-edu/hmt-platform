-- C-23-13 (Chat 14:15, Tester 2 tìm lỗi CAO; migration 625 vì 624 đã có PR mở). Phiếu Chuyển lớp/Chuyển cơ sở khác môn bị chặn quá muộn (sau khi duyệt hai cấp mới báo HMT_CHUYEN_LOP_KHAC_MON ở bước Thực hiện).
-- Sửa: (1) app.enrollment_current_subject: môn của lớp đang học của ghi danh (đúng thứ app.apply_class_transfer so sánh), (2) create_ticket_task (bản 621) chặn lớp mới khác môn ngay lúc tạo phiếu cùng cơ sở,
-- (3) set_task_destination_class (bản 568) chặn khi quản lý cơ sở đích chọn lớp khác môn, (4) get_task_for_destination (bản 568) chỉ liệt kê lớp cùng môn theo môn của lớp đang học (trước đây dùng enrollment.subject_code, có thể trống nên hiện mọi môn).
-- Luật: R-CS-03, R-V2-24. Chỉ mục: không thêm (không bảng, cột mới).
select set_config('hmt.migration', 'on', false);

-- app.enrollment_current_subject(ghi danh): môn của lớp đang học (enrollment_class chưa kết thúc); chưa có lớp thì dùng môn lưu trên ghi danh. NỘI BỘ (các hàm khác gọi).
create or replace function app.enrollment_current_subject(p_enrollment_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select c.subject_code from app.enrollment_class ec join app.class c on c.id = ec.class_id
      where ec.enrollment_id = p_enrollment_id and ec.end_date is null limit 1),
    (select e.subject_code from app.enrollment e where e.id = p_enrollment_id));
$$;
revoke execute on function app.enrollment_current_subject(uuid) from public, anon, authenticated;

create or replace function app.create_ticket_task(p_ticket_id uuid, p_type text, p_reason text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_biz text;
  v_levels text[];
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_entity text;
  v_key text;
  v_enr app.enrollment;
  v_enr_id uuid;
  v_dest uuid;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không tạo phiếu được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập lý do của phiếu.');
  end if;
  -- QT-15: cấp duyệt theo phiên bản có hiệu lực tại ngày lập phiếu (app.ticket_task_levels); phiếu chụp lại cấp duyệt lúc tạo (ticket_task.levels).
  v_levels := app.ticket_task_levels(p_type, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  if v_levels is null then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-V2-24: nhóm con của ticket phải có phiếu nghiệp vụ đúng loại.
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_type then
    perform app.raise_error('HMT_PHIEU_KHAC_NHOM', 'Nhóm con của ticket này không dùng loại phiếu đã chọn.');
  end if;
  -- Luật AS-10: mỗi ticket một phiếu đang mở.
  if exists (select from app.ticket_task k where k.ticket_id = t.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO', 'Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.');
  end if;
  -- CS-14 (anh chốt 23/11/2026, thẻ D-23-07): phiếu Dừng học chọn «Xử lý tiền còn lại» (HOAN_TIEN hoặc GIU_SO_DU, trống = GIU_SO_DU như trước) và «Ngày dừng»
  -- (chỉ ghi nhận, không đổi cách tính giờ; không sau hôm nay quá tham số stop_date_max_days_ahead). Luật R-GD-16, R-TIEN-28, R-TIEN-33.
  if p_type = 'DUNG_HOC' then
    if nullif(p_payload ->> 'money_mode', '') is not null and p_payload ->> 'money_mode' not in ('HOAN_TIEN', 'GIU_SO_DU') then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Xử lý tiền còn lại chỉ chọn Hoàn tiền hoặc Giữ số dư.');
    end if;
    if nullif(p_payload ->> 'stop_date', '') is not null then
      begin
        if (p_payload ->> 'stop_date')::date > (now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('stop_date_max_days_ahead', t.branch_id)::integer then
          perform app.raise_error('HMT_DUNG_HOC_NGAY_SAI', 'Ngày dừng không được sau hôm nay quá số ngày cho phép.');
        end if;
      exception when invalid_datetime_format or datetime_field_overflow then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ngày dừng không hợp lệ.');
      end;
    end if;
  end if;
  -- Kiểm sớm dữ liệu phiếu Cập nhật hồ sơ.
  if p_type = 'CAP_NHAT_HO_SO' then
    v_entity := p_payload ->> 'entity';
    if v_entity is null or v_entity not in ('PARENT', 'STUDENT') or jsonb_typeof(p_payload -> 'changes') is distinct from 'object' or (p_payload -> 'changes') = '{}'::jsonb then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.');
    end if;
    if v_entity = 'STUDENT' and t.student_id is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.');
    end if;
    for v_key in select jsonb_object_keys(p_payload -> 'changes') loop
      if not exists (select from app.ticket_task_field f where f.entity = v_entity and f.field_code = v_key and f.is_active) then
        perform app.raise_error('HMT_PHIEU_TRUONG_SAI', 'Trường này không được sửa bằng phiếu Cập nhật hồ sơ.');
      end if;
    end loop;
  -- Luật R-V2-24, R-CS-02: phiếu Bảo lưu, Chuyển lớp mang dữ liệu để thực hiện bằng hàm của cụm Ghi danh (migration 234); kiểm sớm để báo lỗi ngay lúc tạo.
  elsif p_type in ('BAO_LUU', 'CHUYEN_LOP', 'CHUYEN_PHI') then
    begin
      v_enr_id := nullif(p_payload ->> 'enrollment_id', '')::uuid;
    exception when others then
      v_enr_id := null;
    end;
    select * into v_enr from app.enrollment where id = v_enr_id;
    if v_enr.id is null or t.student_id is null or v_enr.student_id is distinct from t.student_id or v_enr.branch_id <> t.branch_id then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lý do.');
    end if;
    if p_type = 'CHUYEN_PHI' then
      -- CS-10 (anh chốt 23:17, R-GD-10 mục 9): ghi danh cũ phải còn hiệu lực; phụ huynh nhận số dư tuỳ chọn (anh chị em), trống thì giữ ở phụ huynh của ghi danh.
      if v_enr.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không còn hiệu lực để chuyển phí.');
      end if;
      if nullif(p_payload ->> 'to_parent_id', '') is not null
         and not exists (select from app.parent pa where pa.id = nullif(p_payload ->> 'to_parent_id', '')::uuid) then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phụ huynh nhận số dư không tồn tại.');
      end if;
      -- D-23-08 (Chat chốt 02:52): kiểu chuyển (môn khác, gói khác, anh chị em) và đơn nhận (tuỳ chọn) kiểm sớm; đơn nhận chỉ để tham khảo, KHÔNG trừ vào đơn lúc thực hiện.
      if nullif(p_payload ->> 'kind_code', '') is not null and p_payload ->> 'kind_code' not in ('SANG_MON', 'SANG_GOI', 'SANG_ANH_CHI_EM') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Kiểu chuyển chỉ chọn Sang môn khác, Sang gói khác hoặc Sang anh chị em.');
      end if;
      if nullif(p_payload ->> 'order_id', '') is not null then
        perform app.compute_fee_transfer(v_enr.id, nullif(p_payload ->> 'to_parent_id', '')::uuid, (p_payload ->> 'order_id')::uuid);
      end if;
    elsif p_type = 'BAO_LUU' then
      if p_payload ->> 'resume' = 'true' then
        -- C30/C31 (R-GD-09, R-CS-02): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu; ghi danh phải đang có bảo lưu chạy.
        if not exists (select from app.enrollment_hold h where h.enrollment_id = v_enr.id and h.status_code = 'DANG_BAO_LUU') then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
        end if;
      elsif coalesce(nullif(p_payload ->> 'months', '')::integer, 0) < 1 then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Nhập số tháng bảo lưu (từ 1).');
      end if;
    else
      -- CS-07 (anh chốt 23:17, R-GD-10, R-CS-07): Chuyển cơ sở đi hai cấp duyệt tuần tự (quản lý cơ sở ĐI rồi quản lý cơ sở ĐẾN); lớp mới và ngày bắt đầu do quản lý cơ sở ĐẾN chọn ở cấp của họ, nên lúc tạo chỉ cần cơ sở đích.
      if p_payload ->> 'kind_code' = 'CHUYEN_CO_SO' then
        begin
          v_dest := nullif(p_payload ->> 'dest_branch_id', '')::uuid;
        exception when others then
          v_dest := null;
        end;
        if v_dest is null or v_dest = t.branch_id
           or not exists (select from app.branch b where b.id = v_dest and b.is_active and not b.is_office) then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn cơ sở đích: cơ sở dạy học đang hoạt động, khác cơ sở của ticket.');
        end if;
        v_levels := array['QUAN_LY_CO_SO', 'QUAN_LY_CO_SO_DICH'];
      elsif nullif(p_payload ->> 'to_class_id', '') is null or nullif(p_payload ->> 'start_date', '') is null or nullif(p_payload ->> 'kind_code', '') is null then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp mới, ngày bắt đầu và loại chuyển.');
      end if;
      -- R-CS-03 (thẻ C-23-13): chuyển lớp cùng cơ sở chỉ sang lớp CÙNG MÔN; khác môn đi nhánh Chuyển phí. Chặn ngay lúc tạo phiếu.
      if p_payload ->> 'kind_code' is distinct from 'CHUYEN_CO_SO'
         and exists (select from app.class tc where tc.id = nullif(p_payload ->> 'to_class_id', '')::uuid
                      and tc.subject_code is distinct from app.enrollment_current_subject(v_enr.id)) then
        perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Khác môn: dùng Chuyển phí.');
      end if;
    end if;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels, dest_branch_id)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels, v_dest) returning id into v_id;
  perform app.ticket_task_log((select k from app.ticket_task k where k.id = v_id), 'TAO', null, 'NHAP', null);
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

create or replace function app.set_task_destination_class(p_id uuid, p_class_id uuid, p_start_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  c app.class;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null or k.dest_branch_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chuyển cơ sở.');
  end if;
  if k.status_code <> 'CHO_DUYET' or k.levels[k.current_level] <> 'QUAN_LY_CO_SO_DICH' then
    perform app.raise_error('HMT_PHIEU_CHUA_DEN_LUOT', 'Phiếu chưa đến lượt quản lý cơ sở đích chọn lớp.');
  end if;
  if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'BRANCH_MANAGER') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản lý cơ sở đích chọn lớp mới.');
  end if;
  perform app.assert_can('TICKET', 'DUYET', k.dest_branch_id);
  select * into c from app.class where id = p_class_id;
  if c.id is null or c.branch_id <> k.dest_branch_id or c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp đã duyệt của cơ sở đích.');
  end if;
  -- R-CS-03 (thẻ C-23-13): chuyển lớp chỉ cùng môn; khác môn đi nhánh Chuyển phí. Chặn ngay lúc chọn lớp, không để duyệt xong mới lỗi.
  if c.subject_code is distinct from app.enrollment_current_subject((k.payload ->> 'enrollment_id')::uuid) then
    perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Khác môn: dùng Chuyển phí.');
  end if;
  if coalesce(app.class_seats_left(c.id), 1) <= 0 then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Lớp đã hết chỗ.');
  end if;
  if p_start_date is null or not exists (select from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT') and x.session_date = p_start_date
                                           and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date) then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn một buổi sắp tới của lớp mới làm ngày bắt đầu.');
  end if;
  update app.ticket_task set payload = payload || jsonb_build_object('to_class_id', c.id, 'start_date', p_start_date) where id = k.id;
  perform app.ticket_task_log(k, 'CHON_LOP', 'CHO_DUYET', 'CHO_DUYET', 'Chọn lớp ' || c.code || ' ở cơ sở đích.');
end;
$$;

create or replace function app.get_task_for_destination(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  e app.enrollment;
begin
  select * into k from app.ticket_task where id = p_id;
  if k.id is null or k.dest_branch_id is null or k.status_code <> 'CHO_DUYET' or k.levels[k.current_level] <> 'QUAN_LY_CO_SO_DICH'
     or not app.can_see_branch('TICKET', 'DUYET', k.dest_branch_id)
     or not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'BRANCH_MANAGER') then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  select * into e from app.enrollment where id = nullif(k.payload ->> 'enrollment_id', '')::uuid;
  return jsonb_build_object(
    'task', jsonb_build_object('id', k.id, 'code', k.code, 'reason', k.reason, 'level', k.current_level, 'level_total', cardinality(k.levels),
      'from_branch_code', (select b.code from app.branch b where b.id = k.branch_id),
      'dest_branch_code', (select b.code from app.branch b where b.id = k.dest_branch_id),
      'to_class_id', k.payload ->> 'to_class_id', 'start_date', k.payload ->> 'start_date',
      'student_name', (select s.full_name from app.student s where s.id = t.student_id),
      'hours_left', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::numeric(6, 2),
      'subject_code', app.enrollment_current_subject(e.id),
      'approved_by_source', (select app.staff_display_name(ev.created_by) from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq limit 1)),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_code', c.subject_code, 'seats_left', app.class_seats_left(c.id),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date)
                                       from (select x.session_date, x.session_no from app.class_session x
                                              where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
                                              order by x.session_date limit 8) u), '[]'::jsonb)) -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
             order by c.code)
        from app.class c
       where c.branch_id = k.dest_branch_id and c.status_code = 'DA_DUYET' and coalesce(app.class_seats_left(c.id), 1) > 0
         and c.subject_code is not distinct from app.enrollment_current_subject(e.id)), '[]'::jsonb));
end;
$$;
select set_config('hmt.migration', '', false);
