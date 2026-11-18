-- Code B (18/11/2026), Aftersale B6 (CS-05), migration 353: nối phiếu Hoàn học phí với hàm áp dụng app.apply_refund_request (Code D, migration 235) và SIẾT cấp duyệt phiếu tiền.
-- Luật: R-V2-24 (một nơi duyệt: phiếu đủ hai cấp rồi thực hiện thẳng, không duyệt lần hai ở yêu cầu hoàn phí), R-TIEN-28, 31, 34 (tính hoàn, phiếu chi), R-CS-02 (gắn mã ticket),
-- R-HT-01 (Admin không duyệt tiền), R-TIEN-01 (hai người duyệt khác nhau), R-CS-07 (cấp duyệt theo loại phiếu). Sửa theo góp ý Soát 18/11 21:57 (Q1c).
-- Làm gì: (1) approve_ticket_task: cấp kế toán chỉ vai ACCOUNTANT, cấp quản lý của phiếu tiền chỉ BRANCH_MANAGER, một người không duyệt hai cấp (HMT_PHIEU_MOT_NGUOI_HAI_CAP);
-- (2) apply_refund_request nhận người duyệt quản lý và kế toán của phiếu và ghi đúng vào yêu cầu (thay hàm cũ cùng tên, thêm hai tham số có mặc định null);
-- (3) execute_ticket_task: thực hiện HOAN_PHI thẳng; kiểm dữ liệu phiếu lúc thực hiện (HMT_PHIEU_DU_LIEU_SAI). Xây trên bản execute của migration 262. Không đổi bảng, quyền gọi, cấp duyệt (ticket_task_rule đã hai cấp).
-- Khoá payload: enrollment_id, kind (TOAN_BO | MOT_PHAN), hours (chỉ MOT_PHAN), reason_code (danh mục REFUND_REASON), note.
select set_config('hmt.migration', 'on', false);

drop function if exists app.apply_refund_request(uuid, text, numeric, text, text, text);

create or replace function app.apply_refund_request(
  p_enrollment_id uuid, p_kind text, p_hours numeric, p_reason_code text, p_note text default null, p_ticket_ref text default null,
  p_manager_by uuid default null, p_accountant_by uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
  v_pv uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để hoàn phí.');
  end if;
  perform app.assert_catalog_code_active('REFUND_REASON', p_reason_code);
  if exists (select from app.refund_request where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET')) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  v := app.compute_refund(e.id, p_kind, p_hours);
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, ticket_ref,
                                  hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net,
                                  base_amount, fee_percent, fee_amount, refund_amount, status_code, manager_by, manager_at)
  values (e.id, e.student_id, e.branch_id, p_kind, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_refund')::numeric, (v ->> 'paid_amount')::bigint, (v ->> 'hours_used')::numeric,
          (v ->> 'unit_price_base')::bigint, round((v ->> 'unit_price_net')::numeric, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
          (v ->> 'base_amount')::bigint,
          (v ->> 'fee_percent')::numeric, (v ->> 'fee_amount')::bigint, (v ->> 'refund_amount')::bigint,
          'CHO_KE_TOAN', p_manager_by, now())
  returning id into v_id;
  v_pv := app.finish_refund_request(v_id);
  -- Ghi kế toán duyệt đúng người đã duyệt cấp kế toán ở phiếu (lõi ghi người gọi; người gọi ở đây là người bấm Thực hiện).
  if p_accountant_by is not null then
    update app.refund_request set accountant_by = p_accountant_by where id = v_id;
  end if;
  return v_pv;
end;
$$;


create or replace function app.approve_ticket_task(p_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_level text;
  v_last boolean;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  if k.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ duyệt phiếu đang Chờ duyệt.');
  end if;
  v_level := k.levels[k.current_level];
  if v_level = 'KE_TOAN' then
    -- Luật R-HT-01, R-TIEN-01: cấp kế toán chỉ vai trò Kế toán duyệt (Admin không duyệt tiền).
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
    -- Luật R-HT-01, R-CS-07: phiếu có cấp kế toán là phiếu tiền; cấp quản lý cơ sở của phiếu tiền do quản lý cơ sở duyệt (không Admin, không kế toán thay).
    if 'KE_TOAN' = any (k.levels) and not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'BRANCH_MANAGER') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở.');
    end if;
  end if;
  if k.created_by is not distinct from auth.uid() then
    perform app.raise_error('HMT_PHIEU_TU_DUYET', 'Người tạo phiếu không tự duyệt phiếu của mình.');
  end if;
  -- Luật R-TIEN-01: một người không duyệt hai cấp của cùng một phiếu.
  if exists (select from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' and ev.created_by = auth.uid()) then
    perform app.raise_error('HMT_PHIEU_MOT_NGUOI_HAI_CAP', 'Một người không duyệt hai cấp của cùng một phiếu.');
  end if;
  v_last := k.current_level >= cardinality(k.levels);
  update app.ticket_task set
    status_code = case when v_last then 'DA_DUYET' else 'CHO_DUYET' end,
    current_level = case when v_last then current_level else current_level + 1 end,
    approved_at = case when v_last then now() else approved_at end
   where id = k.id;
  perform app.ticket_task_log(k, 'DUYET', 'CHO_DUYET', case when v_last then 'DA_DUYET' else 'CHO_DUYET' end, nullif(btrim(coalesce(p_note, '')), ''));
end;
$$;


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
    v_new := app.apply_enrollment_hold((k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'months')::integer, k.payload ->> 'reason_code',
                                       nullif(k.payload ->> 'note', ''), t.code, nullif(k.payload ->> 'extends_hold_id', '')::uuid);
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


revoke execute on function app.apply_refund_request(uuid, text, numeric, text, text, text, uuid, uuid) from public, anon, authenticated;

select set_config('hmt.migration', '', false);
