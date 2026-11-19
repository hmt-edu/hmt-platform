-- C60 CS-14 (Chat 16:25): Thực hiện Dừng học từ ticket nhóm Dừng học (R-GD-16, R-TIEN-33, R-CS-02, R-V2-24). Phiếu DUNG_HOC có sẵn (cấp quản lý cơ sở rồi kế toán, migration 226); thiếu nhánh thực hiện.
-- Làm gì: (1) execute_ticket_task (bản migration 424) thêm nhánh DUNG_HOC gọi app.apply_enrollment_stop (migration 235); (2) get_task_form_options (bản 423) trả thêm stop_reasons.
-- Dừng học giữ số dư (không hoàn tiền): hoàn tiền đi qua phiếu Hoàn học phí (R-GD-16). Người duyệt hai cấp ở nhật ký phiếu; hàm áp dụng chưa nhận người duyệt (khác Hoàn học phí): ghi nhận trong PR.
select set_config('hmt.migration', 'on', false);

create or replace function app.execute_ticket_task(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_entity text;
  v_ch jsonb;
  v_target uuid;
  v_before jsonb;
  v_grade smallint;
  v_new uuid;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  if k.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ thực hiện phiếu đã duyệt.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  -- Luật R-V2-24: phiếu đã có cấp duyệt riêng nên áp dụng THẲNG bảo lưu, chuyển lớp (bản ghi đã duyệt, thực hiện ngay trong giao dịch này), không duyệt lần hai.
  -- Hàm áp dụng kiểm cờ BAO_LUU, CHUYEN_LOP và mọi luật như bản tạo thường (R-GD-09, R-GD-10). Mã ticket gắn vào bản ghi để truy ngược (R-CS-02).
  if k.task_type = 'BAO_LUU' then
    -- C31: Tiếp tục học (quay lại sớm): kết thúc bảo lưu, ghi danh về hàng chờ xếp lớp, giữ nguyên giờ (R-GD-09); không tự xếp lớp.
    if k.payload ->> 'resume' = 'true' then
      v_new := app.apply_enrollment_resume((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    else
      v_new := app.apply_enrollment_hold((k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'months')::integer, k.payload ->> 'reason_code',
                                         nullif(k.payload ->> 'note', ''), t.code, nullif(k.payload ->> 'extends_hold_id', '')::uuid);
    end if;
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('hold_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  elsif k.task_type = 'CHUYEN_LOP' then
    v_new := app.apply_class_transfer((k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'to_class_id')::uuid, (k.payload ->> 'start_date')::date,
                                      k.payload ->> 'kind_code', k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('transfer_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  -- Luật R-V2-24, R-TIEN-34, R-CS-02: phiếu Hoàn học phí đã qua cấp quản lý cơ sở và kế toán nên áp dụng THẲNG (tạo yêu cầu đã qua quản lý, tính tiền, ghi sổ giờ ngược dấu, lập phiếu chi), không duyệt lần hai. Cờ HOAN_PHI do hàm áp dụng kiểm (migration 235).
  -- Người duyệt từng cấp lấy từ nhật ký phiếu (cấp 1 quản lý cơ sở, cấp 2 kế toán) và ghi đúng vào yêu cầu hoàn phí, để luật hai người duyệt khác nhau còn hiệu lực (R-TIEN-01).
  elsif k.task_type = 'HOAN_PHI' then
    if nullif(k.payload ->> 'enrollment_id', '') is null or k.payload ->> 'kind' is null or k.payload ->> 'kind' not in ('TOAN_BO', 'MOT_PHAN')
       or nullif(btrim(coalesce(k.payload ->> 'reason_code', '')), '') is null
       or (k.payload ->> 'kind' = 'MOT_PHAN' and coalesce(nullif(k.payload ->> 'hours', '')::numeric, 0) <= 0) then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Hoàn học phí cần ghi danh, lý do, hình thức hoàn (toàn bộ hoặc một phần, một phần cần số giờ hoàn).');
    end if;
    v_new := app.apply_refund_request((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'kind', nullif(k.payload ->> 'hours', '')::numeric,
                                      k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code,
                                      (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq limit 1),
                                      (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq offset 1 limit 1));
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('payment_voucher_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  -- C60 CS-14 (R-GD-16, R-TIEN-33, R-V2-24, R-CS-02): phiếu Dừng học đã qua quản lý cơ sở và kế toán nên áp dụng THẲNG: huỷ giờ tặng, ghi sổ giờ ngược dấu, ghi danh sang Dừng, giờ còn lại giữ thành số dư khách hàng. Cờ DUNG_HOC kiểm trong hàm áp dụng.
  elsif k.task_type = 'DUNG_HOC' then
    if nullif(k.payload ->> 'enrollment_id', '') is null or nullif(btrim(coalesce(k.payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Dừng học cần ghi danh và lý do.');
    end if;
    v_new := app.apply_enrollment_stop((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('stop_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  elsif k.task_type <> 'CAP_NHAT_HO_SO' then
    perform app.raise_error('HMT_PHIEU_CHUA_LAM', 'Loại phiếu này chưa thực hiện được ở bản hiện tại.');
  end if;
  v_entity := k.payload ->> 'entity';
  v_ch := k.payload -> 'changes';
  if v_entity = 'STUDENT' then
    v_target := t.student_id;
    if v_target is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh.');
    end if;
    select jsonb_build_object('school', s.school, 'school_type', s.school_type, 'grade', s.grade, 'goal', s.goal, 'gender', s.gender) into v_before from app.student s where s.id = v_target;
    if v_ch ? 'grade' then
      v_grade := nullif(v_ch ->> 'grade', '')::smallint;
    end if;
    -- Luật: chỉ cập nhật khoá có trong phiếu; các trường khác giữ nguyên (không dùng SQL động).
    update app.student s set
      school = case when v_ch ? 'school' then nullif(btrim(v_ch ->> 'school'), '') else s.school end,
      school_type = case when v_ch ? 'school_type' then nullif(btrim(v_ch ->> 'school_type'), '') else s.school_type end,
      grade = case when v_ch ? 'grade' then v_grade else s.grade end,
      goal = case when v_ch ? 'goal' then nullif(btrim(v_ch ->> 'goal'), '') else s.goal end,
      gender = case when v_ch ? 'gender' then nullif(btrim(v_ch ->> 'gender'), '') else s.gender end
     where s.id = v_target;
  else
    -- PARENT: phụ huynh của ticket, hoặc phụ huynh của học sinh gắn ticket.
    v_target := coalesce(t.parent_id, (select s.parent_id from app.student s where s.id = t.student_id));
    if v_target is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không xác định được phụ huynh để cập nhật.');
    end if;
    select jsonb_build_object('full_name', p.full_name, 'address', p.address, 'relative_name', p.relative_name) into v_before from app.parent p where p.id = v_target;
    update app.parent p set
      full_name = case when v_ch ? 'full_name' then coalesce(nullif(btrim(v_ch ->> 'full_name'), ''), p.full_name) else p.full_name end,
      address = case when v_ch ? 'address' then nullif(btrim(v_ch ->> 'address'), '') else p.address end,
      relative_name = case when v_ch ? 'relative_name' then nullif(btrim(v_ch ->> 'relative_name'), '') else p.relative_name end
     where p.id = v_target;
  end if;
  update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(),
         result = jsonb_build_object('entity', v_entity, 'record_id', v_target, 'before', v_before, 'changes', v_ch)
   where id = k.id;
  perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
  perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
end;
$$;

create or replace function app.get_task_form_options(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  return jsonb_build_object(
    -- Ghi danh của học sinh gắn ticket, cùng cơ sở (đúng điều kiện create_ticket_task kiểm).
    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'code', e.code, 'status_code', e.status_code, 'subject_code', e.subject_code,
               'class_id', ec.class_id, 'class_code', c.code,
               'remaining_hours', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::numeric(6, 2))
             order by e.code)
        from app.enrollment e
        left join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
        left join app.class c on c.id = ec.class_id
       where e.student_id = t.student_id and e.branch_id = t.branch_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')), '[]'::jsonb),
    -- C30: bảo lưu đang chạy của học sinh (để chọn khi Gia hạn bảo lưu, R-GD-09); hàm áp dụng kiểm lại bản này đang chạy và đúng ghi danh.
    'holds', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'enrollment_id', h.enrollment_id, 'start_date', h.start_date, 'end_date', h.end_date) order by h.end_date)
                         from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id
                        where e.student_id = t.student_id and h.branch_id = t.branch_id and h.status_code = 'DANG_BAO_LUU'), '[]'::jsonb),
    -- C60: lý do dừng học (danh mục STOP_REASON) cho phiếu Dừng học.
    'stop_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'STOP_REASON' and i.is_active), '[]'::jsonb),
    'hold_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'HOLD_REASON' and i.is_active), '[]'::jsonb),
    'transfer_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'TRANSFER_REASON' and i.is_active), '[]'::jsonb),
    -- Lớp mới: lớp đã duyệt cùng cơ sở, còn chỗ; giao diện lọc theo môn của ghi danh. Hàm áp dụng kiểm lại trùng lớp, hết chỗ, trùng giờ.
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
       where c.branch_id = t.branch_id and c.status_code = 'DA_DUYET' and coalesce(app.class_seats_left(c.id), 1) > 0), '[]'::jsonb)
  );
end;
$$;
revoke all on function app.get_task_form_options(uuid) from public, anon;
grant execute on function app.get_task_form_options(uuid) to authenticated;
select set_config('hmt.migration', '', false);
