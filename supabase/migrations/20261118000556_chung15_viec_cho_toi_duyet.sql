-- CHUNG-15 «Việc chờ tôi duyệt» PHẦN DB (Code F, 18/11/2026; thẻ F11; canvas 1aab CHUNG15*). Mức CAO (quyền duyệt, nhiều loại chứng từ). Chỉ đọc, không bảng mới.
-- MỘT hàm gộp việc chờ duyệt của người gọi, mỗi loại theo ĐÚNG điều kiện của hàm duyệt sẵn có (không sinh luật mới):
--   DON_HANG (đơn DA_TRINH, 1/1; app.can_approve_as_manager: quản lý trực tiếp, Trưởng cơ sở route TRUONG_CS, Admin duyệt thay đơn: R-V2-12, R-HT-01),
--   PHIEU_THU (DA_GUI: quản lý, 1/2; CHO_KE_TOAN: Kế toán có ACCOUNTING·Duyệt, 2/2; Admin KHÔNG duyệt tiền, R-HT-01),
--   LOP (DA_TRINH: Xác nhận 1/2; DA_XAC_NHAN: Duyệt 2/2; CLASS·Duyệt: R-LOP-02),
--   YEU_CAU_BUOI (CHO_DUYET, 1/1; SESSION·Duyệt: R-BUOI-03),
--   HOAN_PHI, DUNG_HOC (CHO_QL: ENROLLMENT·Duyệt 1/2; CHO_KE_TOAN: ACCOUNTING·Duyệt 2/2), BAO_LUU (CHO_DUYET, ENROLLMENT·Duyệt 1/1),
--   CHUYEN_LOP (CHO_DUYET: ENROLLMENT·Duyệt ở cơ sở đi hoặc đến chưa duyệt), PHIEU_NGHIEP_VU (ticket_task CHO_DUYET: cấp KE_TOAN cho Kế toán hoặc Admin có TICKET·Duyệt,
--   cấp khác TICKET·Duyệt ở cơ sở; R-CS-07, R-V2-24; khiếu nại, phiếu tái tục không có bước duyệt nên không có ở đây).
-- Người tạo không tự duyệt phiếu của mình (như các hàm duyệt; Admin được duyệt thay ở các loại đã có luật). Không có loại «chiết khấu vượt trần» (R-V2-11 bỏ).
-- Dòng việc chỉ để mở bản ghi; Duyệt, Từ chối nằm trong màn từng loại, không duyệt hàng loạt.
-- Hiệu năng: mỗi nguồn chỉ quét dòng đang chờ nhờ chỉ mục sẵn có (branch_id, status_code, ...) ở từng bảng; không thêm chỉ mục mới.
select set_config('hmt.migration', 'on', false);

-- app.my_approval_items(): hàm nội bộ, mọi việc đến lượt người gọi: {kind, ref_id, code, subject_name, subject_code, detail, level_no, level_total, level_label, creator_id, waiting_since, branch_id}.
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
     and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id)
  union all
  -- Phiếu thu, cấp quản lý (R-V2-12); Admin không duyệt phiếu thu.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 1, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case r.approval_route when 'TRUONG_CS' then 'Trưởng cơ sở → Kế toán' else 'Quản lý trực tiếp → Kế toán' end, r.created_by, coalesce(r.submitted_at, r.created_at), r.branch_id
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'DA_GUI'
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id)
  union all
  -- Phiếu thu, cấp Kế toán.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 2, 2, 'Kế toán', r.created_by, coalesce(r.manager_approved_at, r.submitted_at, r.created_at), r.branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', r.branch_id)
  union all
  -- Lớp: Đã trình chờ Xác nhận, Đã xác nhận chờ Duyệt (R-LOP-02).
  select 'LOP', c.id, c.code, null::text, null::text, null::text, case c.status_code when 'DA_TRINH' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case c.status_code when 'DA_TRINH' then 'Xác nhận' else 'Duyệt' end, c.submitted_by,
         coalesce((select max(e.created_at) from app.class_event e where e.class_id = c.id and e.to_status = c.status_code), c.updated_at), c.branch_id
    from app.class c
   where c.status_code in ('DA_TRINH', 'DA_XAC_NHAN') and app.can_see_branch('CLASS', 'DUYET', c.branch_id)
  union all
  -- Yêu cầu buổi (R-BUOI-03).
  select 'YEU_CAU_BUOI', q.id, q.code, null::text, null::text, c.code || ' · ' || to_char(q.session_date, 'DD/MM/YYYY'), 1, 1, 'Trưởng cơ sở', q.created_by,
         coalesce(q.submitted_at, q.created_at), q.branch_id
    from app.session_request q join app.class c on c.id = q.class_id
   where q.status_code = 'CHO_DUYET' and app.can_see_branch('SESSION', 'DUYET', q.branch_id)
     and (q.created_by is distinct from v_me or v_admin)
  union all
  -- Hoàn phí hai cấp.
  select 'HOAN_PHI', f.id, e.code, s.full_name, s.code, null::text, case f.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case f.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, f.created_by,
         case f.status_code when 'CHO_QL' then f.created_at else coalesce(f.manager_at, f.created_at) end, f.branch_id
    from app.refund_request f join app.enrollment e on e.id = f.enrollment_id join app.student s on s.id = f.student_id
   where (f.status_code = 'CHO_QL' and app.can_see_branch('ENROLLMENT', 'DUYET', f.branch_id) and (f.created_by is distinct from v_me or v_admin))
      or (f.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', f.branch_id))
  union all
  -- Dừng học hai cấp.
  select 'DUNG_HOC', d.id, e.code, s.full_name, s.code, null::text, case d.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case d.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, d.created_by,
         case d.status_code when 'CHO_QL' then d.created_at else coalesce(d.manager_at, d.created_at) end, d.branch_id
    from app.enrollment_stop d join app.enrollment e on e.id = d.enrollment_id join app.student s on s.id = d.student_id
   where (d.status_code = 'CHO_QL' and app.can_see_branch('ENROLLMENT', 'DUYET', d.branch_id) and (d.created_by is distinct from v_me or v_admin))
      or (d.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', d.branch_id))
  union all
  -- Bảo lưu.
  select 'BAO_LUU', h.id, e.code, s.full_name, s.code, null::text, 1, 1, 'Trưởng cơ sở', h.created_by, h.created_at, h.branch_id
    from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id join app.student s on s.id = h.student_id
   where h.status_code = 'CHO_DUYET' and app.can_see_branch('ENROLLMENT', 'DUYET', h.branch_id) and (h.created_by is distinct from v_me or v_admin)
  union all
  -- Chuyển lớp: duyệt ở cơ sở đi và cơ sở đến (mỗi cơ sở một lần).
  select 'CHUYEN_LOP', t.id, e.code, s.full_name, s.code, null::text, 1 + (t.approved_from_at is not null)::int + (t.approved_to_at is not null)::int,
         case when t.from_branch_id = t.to_branch_id then 1 else 2 end, 'Trưởng cơ sở', t.created_by, coalesce(t.approved_from_at, t.approved_to_at, t.created_at), t.from_branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.class_transfer t join app.enrollment e on e.id = t.enrollment_id join app.student s on s.id = t.student_id
   where t.status_code = 'CHO_DUYET' and (t.created_by is distinct from v_me or v_admin)
     and ((t.approved_from_at is null and app.can_see_branch('ENROLLMENT', 'DUYET', t.from_branch_id))
          or (t.approved_to_at is null and app.can_see_branch('ENROLLMENT', 'DUYET', t.to_branch_id)))
  union all
  -- Phiếu nghiệp vụ Aftersale có bước duyệt (R-CS-07, R-V2-24).
  select 'PHIEU_NGHIEP_VU', k.id, k.code, null::text, null::text, k.task_type, k.current_level, cardinality(k.levels),
         case k.levels[k.current_level] when 'KE_TOAN' then 'Kế toán' else 'Trưởng cơ sở' end, k.created_by, coalesce(k.submitted_at, k.created_at), k.branch_id
    from app.ticket_task k
   where k.status_code = 'CHO_DUYET' and k.created_by is distinct from v_me
     and ((k.levels[k.current_level] = 'KE_TOAN'
           and exists (select from app.user_role ur where ur.user_id = v_me and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'))
           and app.has_permission('TICKET', 'DUYET'))
          or (k.levels[k.current_level] is distinct from 'KE_TOAN' and app.can_see_branch('TICKET', 'DUYET', k.branch_id)));
end;
$$;
revoke execute on function app.my_approval_items() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.list_my_approvals(bộ lọc, số dòng, bỏ qua): {total, counts{kind: số}, rows[]}. Bộ lọc (jsonb, tuỳ chọn): kind (mã loại việc), branch_id.
-- Mỗi dòng: {kind, ref_id, code, subject_name, subject_code, detail, level_no, level_total, level_label, creator_name, waiting_since, branch_code}.
-- Chờ lâu nhất lên đầu. Số dòng mặc định list_page_size_default, tối đa list_page_size_max. counts đếm theo bộ lọc cơ sở, không theo loại (cho ô lọc loại việc).
-- ---------------------------------------------------------------------------
create or replace function app.list_my_approvals(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_counts jsonb;
  v_total bigint;
  v_rows jsonb;
begin
  with i as materialized (select * from app.my_approval_items() x where v_branch is null or x.branch_id = v_branch),
       f as (select * from i where v_kind is null or i.kind = v_kind)
  select coalesce((select jsonb_object_agg(kind, n) from (select kind, count(*) as n from i group by kind) c), '{}'::jsonb),
         (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object('kind', x.kind, 'ref_id', x.ref_id, 'code', x.code, 'subject_name', x.subject_name, 'subject_code', x.subject_code,
                                                       'detail', x.detail, 'level_no', x.level_no, 'level_total', x.level_total, 'level_label', x.level_label,
                                                       'creator_name', app.staff_display_name(x.creator_id), 'waiting_since', x.waiting_since,
                                                       'branch_code', (select b.code from app.branch b where b.id = x.branch_id))
                                    order by x.waiting_since, x.code, x.ref_id)
                     from (select * from f order by waiting_since, code, ref_id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_counts, v_total, v_rows;
  return jsonb_build_object('total', v_total, 'counts', v_counts, 'rows', v_rows);
end;
$$;
revoke execute on function app.list_my_approvals(jsonb, integer, integer) from public, anon, authenticated;
grant execute on function app.list_my_approvals(jsonb, integer, integer) to authenticated;
