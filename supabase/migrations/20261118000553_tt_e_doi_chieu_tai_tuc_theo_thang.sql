-- TT-E (Code F, 18/11/2026; Chat 12:35 giao): màn TT-04 «Đối chiếu tái tục theo tháng». Mức THẤP: chỉ đọc, không bảng mới, không đổi hàm cũ.
-- Phụ thuộc TT-A (410: bảng upsale_ticket) và TT-B (415: app.upsale_candidates), nên PR này xếp sau hai PR đó.
-- Luật R-GD-13: «hết giờ trong tháng» tính theo NGÀY HẾT GIỜ DỰ KIẾN (cùng cột với TT-01): phiếu đang mở lấy ngày đã chụp trong phiếu; (học sinh, lớp)
-- chưa có phiếu lấy ngày tính từ app.upsale_candidates() (cùng cách GD-07). Em đã hết giờ (giờ còn <= 0, chưa có ngày) tính là hết giờ HÔM NAY (giờ Việt Nam).
-- «Đã có phiếu» = có phiếu đang mở (L1..L4, L6, L7). Lý do chưa có phiếu: có phiếu L5 gần đây (L5 không tự sinh lại), lớp chưa có lịch (không tính được
-- ngày), hoặc chờ đợt quét đêm. Campaign là nhãn tháng tính ra, không có bản ghi chiến dịch. Nút «Tạo phiếu tái tục sớm» dùng hàm tạo tay create_upsale_ticket (TT-03).
-- Hai hàm báo cáo là security definer: quyền và phạm vi cơ sở kiểm trong hàm nội bộ (upsale_reconcile_base), không dựa RLS.
-- Ai gọi: người có quyền Phiếu tái tục · Xem; phạm vi cơ sở theo quyền (toàn hệ thống hoặc cơ sở của mình).
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- app.upsale_reconcile_base(tháng, cơ sở): hàm nội bộ, mỗi dòng một (học sinh, lớp) hết giờ trong tháng, đã áp phạm vi cơ sở của người gọi.
-- Không mở cho người dùng; hai hàm báo cáo bên dưới gọi.
-- ---------------------------------------------------------------------------
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
      left join app.upsale_ticket t on t.student_id = c.student_id and t.class_id = c.class_id and t.stage_code not in ('L5', 'L8')
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
revoke execute on function app.upsale_reconcile_base(date, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.upsale_reconcile_summary(tháng, cơ sở): số tổng và số theo cơ sở cho thẻ đầu màn TT-04.
-- Kết quả {total, with_ticket, missing, manual, branches:[{branch_code, total, with_ticket, missing}]}; «tạo tay» là phiếu đang mở có nguồn TAY.
-- ---------------------------------------------------------------------------
create or replace function app.upsale_reconcile_summary(p_month date, p_branch_id uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with b as (select * from app.upsale_reconcile_base(p_month, p_branch_id))
  select jsonb_build_object(
    'total', (select count(*) from b),
    'with_ticket', (select count(*) from b where ticket_id is not null),
    'missing', (select count(*) from b where ticket_id is null),
    'manual', (select count(*) from b where ticket_origin = 'TAY'),
    'branches', coalesce((select jsonb_agg(jsonb_build_object('branch_code', br.code, 'total', x.total, 'with_ticket', x.with_ticket, 'missing', x.total - x.with_ticket)
                                         order by br.code)
                            from (select branch_id, count(*) as total, count(ticket_id) as with_ticket from b group by branch_id) x
                            join app.branch br on br.id = x.branch_id), '[]'::jsonb));
$$;

-- ---------------------------------------------------------------------------
-- app.list_upsale_reconcile(tháng, bộ lọc, số dòng, bỏ qua): bảng TT-04, phân trang ở máy chủ. Bộ lọc (jsonb, tuỳ chọn): branch_id,
-- only_missing (true: chỉ dòng chưa có phiếu), q (tên học sinh, mã học sinh, mã lớp). Số dòng mặc định list_page_size_default, tối đa list_page_size_max.
-- Kết quả {total, rows[]}; thiếu phiếu lên trước, rồi ngày hết giờ gần nhất.
-- ---------------------------------------------------------------------------
create or replace function app.list_upsale_reconcile(p_month date, p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_only_missing boolean := coalesce((p_filters ->> 'only_missing')::boolean, false);
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select b.*, s.code as student_code, s.full_name as student_name, c.code as class_code, br.code as branch_code
      from app.upsale_reconcile_base(p_month, nullif(p_filters ->> 'branch_id', '')::uuid) b
      join app.student s on s.id = b.student_id
      join app.class c on c.id = b.class_id
      join app.branch br on br.id = b.branch_id
     where (not v_only_missing or b.ticket_id is null)
       and (v_q is null or s.full_name ilike '%' || v_q || '%' or s.code ilike '%' || v_q || '%' or c.code ilike '%' || v_q || '%')
  ), pg as (
    select * from f order by (ticket_id is not null), expected_end_date, student_code, class_code
     limit v_limit offset greatest(coalesce(p_offset, 0), 0)
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                     'student_id', student_id, 'student_code', student_code, 'student_name', student_name,
                     'class_id', class_id, 'class_code', class_code,
                     'enrollment_codes', enrollment_codes, 'branch_code', branch_code,
                     'hours_left', hours_left, 'expected_end_date', expected_end_date,
                     'campaign_label', 'Tái tục ' || to_char(date_trunc('month', p_month), 'MM/YYYY'),
                     'ticket_id', ticket_id, 'ticket_code', ticket_code, 'ticket_origin', ticket_origin, 'missing_reason', missing_reason)
                   order by (ticket_id is not null), expected_end_date, student_code, class_code) from pg), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.upsale_reconcile_summary(date, uuid), app.list_upsale_reconcile(date, jsonb, integer, integer) from public, anon;
grant execute on function app.upsale_reconcile_summary(date, uuid) to authenticated;
grant execute on function app.list_upsale_reconcile(date, jsonb, integer, integer) to authenticated;
