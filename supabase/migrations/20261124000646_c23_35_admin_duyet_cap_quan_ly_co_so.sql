-- C-23-35 (Chat 17:52, anh Trường chốt 24/11/2026 00:52, N0 #18; rủi ro CAO: quyền; migration 646).
-- Làm gì: phiếu nghiệp vụ cấp «Quản lý cơ sở» do Trưởng cơ sở đúng cơ sở HOẶC Admin duyệt; Kế toán KHÔNG duyệt cấp này (Kế toán chỉ duyệt cấp KE_TOAN).
-- Sửa bốn hàm: (1) app.approve_ticket_task (bản 568): thêm kiểm vai trò Trưởng cơ sở/Admin cho cấp Quản lý cơ sở; (2) app.get_ticket_task (bản 634) và (3) app.list_ticket_tasks (bản 428): can_approve và «Chờ tôi duyệt» theo cấp; (4) app.my_approval_items (bản 559): Kế toán hết thấy phiếu cấp quản lý cơ sở ở «Việc chờ tôi duyệt».
-- Giữ nguyên: Trưởng cơ sở khác cơ sở bị chặn (assert_can theo cơ sở phiếu); phiếu tiền (có cấp Kế toán) cấp quản lý vẫn chỉ Trưởng cơ sở duyệt, Admin không duyệt tiền (R-HT-01); người tạo không tự duyệt; một người không duyệt hai cấp.
-- Ai gọi: giao diện qua rpc, quyền kiểm trong hàm. Không đổi cấu trúc bảng, không thêm chỉ mục.
select set_config('hmt.migration', 'on', false);

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
  if v_level = 'QUAN_LY_CO_SO_DICH' then
    -- CS-07: cấp quản lý cơ sở ĐẾN: đúng quản lý (vai trò Quản lý cơ sở) của cơ sở đích, và đã chọn lớp mới ở bước này.
    if k.dest_branch_id is null or not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'BRANCH_MANAGER') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở đích.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', k.dest_branch_id);
    if nullif(k.payload ->> 'to_class_id', '') is null or nullif(k.payload ->> 'start_date', '') is null then
      perform app.raise_error('HMT_PHIEU_CHUA_CHON_LOP', 'Chọn lớp mới và buổi bắt đầu ở cơ sở đích trước khi duyệt.');
    end if;
  elsif v_level = 'KE_TOAN' then
    -- Luật R-HT-01, R-TIEN-01: cấp kế toán chỉ vai trò Kế toán duyệt (Admin không duyệt tiền).
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
    -- Luật R-CS-07 (anh chốt 24/11/2026, N0 #18): cấp Quản lý cơ sở do Trưởng cơ sở (đúng cơ sở, đã kiểm ở assert_can) hoặc Admin duyệt; Kế toán không duyệt cấp này.
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN')) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho Trưởng cơ sở hoặc Admin.');
    end if;
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

create or replace function app.get_ticket_task(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  -- Luật R-CS-07 (N0 #18): cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy nút Duyệt; Kế toán không.
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
begin
  select * into k from app.ticket_task where id = p_id;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  return jsonb_build_object(
    'task', jsonb_build_object(
      'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code, 'reason', k.reason, 'payload', k.payload, 'result', k.result,
      'level', k.current_level, 'level_total', cardinality(k.levels), 'levels', to_jsonb(k.levels),
      'reject_reason', k.reject_reason, 'cancel_reason', k.cancel_reason, 'branch_id', k.branch_id,
      'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
      'created_at', k.created_at, 'submitted_at', k.submitted_at, 'approved_at', k.approved_at, 'executed_at', k.executed_at,
      'created_by_name', app.staff_display_name(k.created_by),
      -- C60: người duyệt dự kiến của cấp đang chờ (CSN-05, CSN-06).
      'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
      'can_approve', k.status_code = 'CHO_DUYET' and k.created_by is distinct from auth.uid() and app.has_permission('TICKET', 'DUYET')
                      and case when k.levels[k.current_level] = 'KE_TOAN' then v_is_acc else v_is_mgr end,
      'is_creator', k.created_by is not distinct from auth.uid()),
    'ticket', jsonb_build_object('id', t.id, 'code', t.code, 'title', t.title, 'status_code', t.status_code,
                                  'student_name', (select s.full_name from app.student s where s.id = t.student_id)),
    -- C-23-23 (CSN07_duyet_chuyen_lop): tóm tắt cho hộp Duyệt phiếu Chuyển lớp: lớp hiện tại, lớp mới, ngày bắt đầu, giờ còn lại (chỉ đọc, giờ do sổ giờ tính).
    'transfer', case when k.task_type = 'CHUYEN_LOP' then jsonb_build_object(
      'from_class', app.task_class_summary((select ec.class_id from app.enrollment_class ec
                                              where ec.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid and ec.end_date is null limit 1)),
      'to_class', app.task_class_summary(nullif(k.payload ->> 'to_class_id', '')::uuid),
      'start_date', k.payload ->> 'start_date',
      'hours_left', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid), 0)::numeric(6, 2)) end,
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_task_event e where e.task_id = k.id), '[]'::jsonb));
end;
$$;

create or replace function app.list_ticket_tasks(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status_code', '');
  v_type text := nullif(p_filters ->> 'task_type', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_for_me boolean := coalesce((p_filters ->> 'cho_toi')::boolean, false);
  v_for_acc boolean := coalesce((p_filters ->> 'cho_ke_toan')::boolean, false);
  v_can_approve boolean := app.has_permission('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT');
  -- Luật R-CS-07 (N0 #18): cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy trong «Chờ tôi duyệt».
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select k.id, k.created_at
      from app.ticket_task k
      join app.ticket t on t.id = k.ticket_id
     where (v_status is null or k.status_code = v_status)
       and (v_type is null or k.task_type = v_type)
       and (v_branch is null or k.branch_id = v_branch)
       and (v_q is null or k.code ilike '%' || v_q || '%' or t.code ilike '%' || v_q || '%')
       and (not v_for_me or (k.status_code = 'CHO_DUYET' and v_can_approve and k.created_by is distinct from auth.uid()
                             and case when k.levels[k.current_level] = 'KE_TOAN' then v_is_acc else v_is_mgr end))
       and (not v_for_acc or (k.status_code = 'CHO_DUYET' and k.levels[k.current_level] = 'KE_TOAN')))
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code,
                    'level', k.current_level, 'level_total', cardinality(k.levels),
                    'next_role', case when k.status_code = 'CHO_DUYET' then k.levels[k.current_level] end,
                    'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
                    'ticket_id', k.ticket_id, 'ticket_code', t.code,
                    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
                    'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
                    'created_at', k.created_at, 'due_at', t.resolve_due_at) order by k.created_at desc, k.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.ticket_task k on k.id = x.id join app.ticket t on t.id = k.ticket_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

create or replace function app.my_approval_items()
returns table (kind text, ref_id uuid, code text, subject_name text, subject_code text, detail text, level_no integer, level_total integer, level_label text,
               creator_id uuid, waiting_since timestamptz, branch_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_admin boolean := 'ADMIN' = any (app.current_roles());
  -- Hiệu năng (F19): phạm vi quyền tính MỘT lần, không gọi hàm quyền từng dòng (cùng ý nghĩa app.can_see_branch).
  v_my_branch uuid := (select app.current_branch_id());
  v_s_acc text := app.permission_scope('ACCOUNTING', 'DUYET');
  v_s_class text := app.permission_scope('CLASS', 'DUYET');
  v_s_sess text := app.permission_scope('SESSION', 'DUYET');
  v_s_enr text := app.permission_scope('ENROLLMENT', 'DUYET');
  v_s_tk text := app.permission_scope('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  -- Luật R-CS-07 (N0 #18): phiếu nghiệp vụ cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy trong «Việc chờ tôi duyệt»; Kế toán không.
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
begin
  -- Luật quyền: người gọi phải đăng nhập, đã sẵn sàng (không bị khoá, đã qua đổi mật khẩu lần đầu).
  if v_me is null or not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem việc chờ duyệt.');
  end if;
  return query
  -- Đơn hàng chờ quản lý (R-V2-12).
  select 'DON_HANG', o.id, o.code, p.full_name, null::text, null::text, 1, 1,
         case o.approval_route when 'TRUONG_CS' then 'Trưởng cơ sở' else 'Quản lý trực tiếp' end, o.created_by, coalesce(o.submitted_at, o.created_at), o.branch_id
    from app.sales_order o join app.parent p on p.id = o.parent_id
   where o.status_code = 'DA_TRINH'
     and (v_admin or o.approval_route = 'TRUONG_CS' or o.assigned_approver_id is null or o.assigned_approver_id = v_me) -- lọc rẻ trước khi gọi hàm
     and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id)
  union all
  -- Phiếu thu, cấp quản lý (R-V2-12); Admin không duyệt phiếu thu.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 1, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case r.approval_route when 'TRUONG_CS' then 'Trưởng cơ sở → Kế toán' else 'Quản lý trực tiếp → Kế toán' end, r.created_by, coalesce(r.submitted_at, r.created_at), r.branch_id
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'DA_GUI'
     and (r.approval_route = 'TRUONG_CS' or r.assigned_approver_id is null or r.assigned_approver_id = v_me) -- lọc rẻ trước khi gọi hàm
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id)
  union all
  -- Phiếu thu, cấp Kế toán.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 2, 2, 'Kế toán', r.created_by, coalesce(r.manager_approved_at, r.submitted_at, r.created_at), r.branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or r.branch_id is not distinct from v_my_branch))
  union all
  -- Lớp: Đã trình chờ Xác nhận, Đã xác nhận chờ Duyệt (R-LOP-02).
  select 'LOP', c.id, c.code, null::text, null::text, null::text, case c.status_code when 'DA_TRINH' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case c.status_code when 'DA_TRINH' then 'Xác nhận' else 'Duyệt' end, c.submitted_by,
         coalesce((select max(e.created_at) from app.class_event e where e.class_id = c.id and e.to_status = c.status_code), c.updated_at), c.branch_id
    from app.class c
   where c.status_code in ('DA_TRINH', 'DA_XAC_NHAN') and (v_s_class is not null and (v_s_class = 'TOAN_HE_THONG' or c.branch_id is not distinct from v_my_branch))
  union all
  -- Yêu cầu buổi (R-BUOI-03).
  select 'YEU_CAU_BUOI', q.id, q.code, null::text, null::text, c.code || ' · ' || to_char(q.session_date, 'DD/MM/YYYY'), 1, 1, 'Trưởng cơ sở', q.created_by,
         coalesce(q.submitted_at, q.created_at), q.branch_id
    from app.session_request q join app.class c on c.id = q.class_id
   where q.status_code = 'CHO_DUYET' and (v_s_sess is not null and (v_s_sess = 'TOAN_HE_THONG' or q.branch_id is not distinct from v_my_branch))
     and (q.created_by is distinct from v_me or v_admin)
  union all
  -- Hoàn phí hai cấp.
  select 'HOAN_PHI', f.id, e.code, s.full_name, s.code, null::text, case f.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case f.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, f.created_by,
         case f.status_code when 'CHO_QL' then f.created_at else coalesce(f.manager_at, f.created_at) end, f.branch_id
    from app.refund_request f join app.enrollment e on e.id = f.enrollment_id join app.student s on s.id = f.student_id
   where (f.status_code = 'CHO_QL' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or f.branch_id is not distinct from v_my_branch)) and (f.created_by is distinct from v_me or v_admin))
      or (f.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or f.branch_id is not distinct from v_my_branch)))
  union all
  -- Dừng học hai cấp.
  select 'DUNG_HOC', d.id, e.code, s.full_name, s.code, null::text, case d.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case d.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, d.created_by,
         case d.status_code when 'CHO_QL' then d.created_at else coalesce(d.manager_at, d.created_at) end, d.branch_id
    from app.enrollment_stop d join app.enrollment e on e.id = d.enrollment_id join app.student s on s.id = d.student_id
   where (d.status_code = 'CHO_QL' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or d.branch_id is not distinct from v_my_branch)) and (d.created_by is distinct from v_me or v_admin))
      or (d.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or d.branch_id is not distinct from v_my_branch)))
  union all
  -- Bảo lưu.
  select 'BAO_LUU', h.id, e.code, s.full_name, s.code, null::text, 1, 1, 'Trưởng cơ sở', h.created_by, h.created_at, h.branch_id
    from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id join app.student s on s.id = h.student_id
   where h.status_code = 'CHO_DUYET' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or h.branch_id is not distinct from v_my_branch)) and (h.created_by is distinct from v_me or v_admin)
  union all
  -- Chuyển lớp: duyệt ở cơ sở đi và cơ sở đến (mỗi cơ sở một lần).
  select 'CHUYEN_LOP', t.id, e.code, s.full_name, s.code, null::text, 1 + (t.approved_from_at is not null)::int + (t.approved_to_at is not null)::int,
         case when t.from_branch_id = t.to_branch_id then 1 else 2 end, 'Trưởng cơ sở', t.created_by, coalesce(t.approved_from_at, t.approved_to_at, t.created_at), t.from_branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.class_transfer t join app.enrollment e on e.id = t.enrollment_id join app.student s on s.id = t.student_id
   where t.status_code = 'CHO_DUYET' and (t.created_by is distinct from v_me or v_admin)
     and ((t.approved_from_at is null and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or t.from_branch_id is not distinct from v_my_branch)))
          or (t.approved_to_at is null and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or t.to_branch_id is not distinct from v_my_branch))))
  union all
  -- Phiếu nghiệp vụ Aftersale có bước duyệt (R-CS-07, R-V2-24).
  select 'PHIEU_NGHIEP_VU', k.id, k.code, null::text, null::text, k.task_type, k.current_level, cardinality(k.levels),
         case k.levels[k.current_level] when 'KE_TOAN' then 'Kế toán' else 'Trưởng cơ sở' end, k.created_by, coalesce(k.submitted_at, k.created_at), k.branch_id
    from app.ticket_task k
   where k.status_code = 'CHO_DUYET' and k.created_by is distinct from v_me
     and ((k.levels[k.current_level] = 'KE_TOAN'
           and v_is_acc and v_s_tk is not null)
          or (k.levels[k.current_level] is distinct from 'KE_TOAN' and v_is_mgr and (v_s_tk is not null and (v_s_tk = 'TOAN_HE_THONG' or k.branch_id is not distinct from v_my_branch))));
end;
$$;

select set_config('hmt.migration', '', false);
