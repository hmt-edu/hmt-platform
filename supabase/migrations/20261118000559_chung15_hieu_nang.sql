-- CHUNG-15 hiệu năng (Code F, 18/11/2026; thẻ F19): app.my_approval_items chậm (2,2 đến 2,8 giây ở 3.500 việc chờ) vì gọi hàm quyền (can_see_branch) và
-- can_approve_as_manager từng dòng. Sửa: tính phạm vi quyền MỘT lần ở đầu hàm, lọc rẻ (người duyệt đã chốt, route) trước khi gọi can_approve_as_manager.
-- Kết quả không đổi (cùng luật, cùng cột); chỉ đọc. Thân list_my_approvals giữ nguyên (557).
select set_config('hmt.migration', 'on', false);

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
          or (k.levels[k.current_level] is distinct from 'KE_TOAN' and (v_s_tk is not null and (v_s_tk = 'TOAN_HE_THONG' or k.branch_id is not distinct from v_my_branch))));
end;
$$;
revoke execute on function app.my_approval_items() from public, anon, authenticated;

