-- CHUNG-15 giao diện (Code F, 18/11/2026; thẻ F16): thêm khoá `open_id` vào mỗi dòng của app.list_my_approvals: id bản ghi để MỞ khi bấm dòng.
-- Đơn hàng, phiếu thu, lớp, yêu cầu buổi, phiếu nghiệp vụ: chính ref_id. Hoàn phí, dừng học, bảo lưu, chuyển lớp: id GHI DANH (màn bản ghi ghi danh). Chỉ đọc; thân hàm giữ nguyên migration 556.
select set_config('hmt.migration', 'on', false);

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
                                                       'creator_name', app.staff_display_name(x.creator_id),
                                                       'open_id', case x.kind
                                                         when 'HOAN_PHI' then (select r.enrollment_id from app.refund_request r where r.id = x.ref_id)
                                                         when 'DUNG_HOC' then (select r.enrollment_id from app.enrollment_stop r where r.id = x.ref_id)
                                                         when 'BAO_LUU' then (select r.enrollment_id from app.enrollment_hold r where r.id = x.ref_id)
                                                         when 'CHUYEN_LOP' then (select r.enrollment_id from app.class_transfer r where r.id = x.ref_id)
                                                         else x.ref_id end, 'waiting_since', x.waiting_since,
                                                       'branch_code', (select b.code from app.branch b where b.id = x.branch_id))
                                    order by x.waiting_since, x.code, x.ref_id)
                     from (select * from f order by waiting_since, code, ref_id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_counts, v_total, v_rows;
  return jsonb_build_object('total', v_total, 'counts', v_counts, 'rows', v_rows);
end;
$$;
revoke execute on function app.list_my_approvals(jsonb, integer, integer) from public, anon, authenticated;
grant execute on function app.list_my_approvals(jsonb, integer, integer) to authenticated;
