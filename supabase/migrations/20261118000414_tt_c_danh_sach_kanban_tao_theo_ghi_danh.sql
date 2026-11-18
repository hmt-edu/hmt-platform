-- TT-C Phiếu tái tục, đọc danh sách, Kanban và tạo tay theo mã ghi danh (Code C, 18/11/2026; sau TT-A migration 410). Canvas 9933 TT01, TT01_kanban, TT03_tao.
-- Làm gì: app.upsale_ticket_row (một dòng cho danh sách, Kanban), app.list_upsale_tickets (phân trang ở máy chủ), app.upsale_board (Kanban một lần gọi),
-- app.preview_upsale_enrollment (xem học sinh, lớp trước khi tạo), app.create_upsale_ticket_from_enrollment (hộp «Tạo phiếu tái tục thủ công»: nhập MÃ GHI DANH
-- của em trong lớp, phiếu tạo theo (học sinh, lớp)). Các hàm đọc không security definer: RLS của phiếu lọc theo quyền người gọi.
-- Nhãn campaign «Tái tục MM/YYYY» là nhãn tháng TÍNH RA từ ngày hết giờ dự kiến (Chat 11:55 chốt), không có bản ghi chiến dịch.
select set_config('hmt.migration', 'on', false);

-- Một dòng phiếu cho danh sách và thẻ Kanban. Ghi danh (n) là số ghi danh đang hiệu lực của em ở đúng lớp đó.
create or replace function app.upsale_ticket_row(t app.upsale_ticket)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'code', t.code, 'branch_code', b.code,
    'student_id', t.student_id, 'student_name', s.full_name,
    'class_id', t.class_id, 'class_code', c.code,
    'enrollment_count', (select count(*)::int from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                          where e.student_id = t.student_id and ec.class_id = t.class_id and ec.end_date is null),
    'hours_left', t.hours_left, 'expected_end_date', t.expected_end_date,
    'campaign_label', case when t.expected_end_date is null then null else 'Tái tục ' || to_char(t.expected_end_date, 'MM/YYYY') end,
    'stage_code', t.stage_code, 'substage_code', t.substage_code,
    'owner_id', t.owner_id, 'owner_name', app.staff_display_name(t.owner_id),
    'risk_flag', t.risk_flag, 'origin_code', t.origin_code, 'created_at', t.created_at)
  from app.branch b, app.student s, app.class c
 where b.id = t.branch_id and s.id = t.student_id and c.id = t.class_id;
$$;

-- ---------------------------------------------------------------------------
-- app.list_upsale_tickets(bộ lọc, số dòng, bỏ qua): danh sách phân trang ở máy chủ (TT-01). RLS lọc theo quyền người gọi.
-- Bộ lọc (jsonb, đều tuỳ chọn): stage_code, branch_id, owner (mine hoặc unassigned), campaign_month (YYYY-MM theo ngày hết giờ dự kiến), risk (true), q (mã phiếu,
-- tên học sinh, mã lớp). Số dòng mặc định list_page_size_default, tối đa list_page_size_max. Kết quả {total, rows[]}; ngày hết giờ gần nhất trước.
-- ---------------------------------------------------------------------------
create or replace function app.list_upsale_tickets(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_owner text := nullif(p_filters ->> 'owner', '');
  v_month text := nullif(p_filters ->> 'campaign_month', '');
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select t.id, t.expected_end_date, t.created_at from app.upsale_ticket t
      join app.student s on s.id = t.student_id
      join app.class c on c.id = t.class_id
     where (p_filters ->> 'stage_code' is null or t.stage_code = p_filters ->> 'stage_code')
       and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
       and (v_owner is null or (v_owner = 'mine' and t.owner_id = auth.uid()) or (v_owner = 'unassigned' and t.owner_id is null))
       and (v_month is null or to_char(t.expected_end_date, 'YYYY-MM') = v_month)
       and (coalesce((p_filters ->> 'risk')::boolean, false) = false or t.risk_flag)
       and (v_q is null or t.code ilike '%' || v_q || '%' or s.full_name ilike '%' || v_q || '%' or c.code ilike '%' || v_q || '%'))
  select (select count(*) from f),
         coalesce((select jsonb_agg(app.upsale_ticket_row(u) order by x.expected_end_date nulls last, x.created_at desc, x.id)
                     from (select * from f order by expected_end_date nulls last, created_at desc, id
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x
                     join app.upsale_ticket u on u.id = x.id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.upsale_board(bộ lọc, số dòng mỗi cột): Kanban L1..L8 một lần gọi (TT-01 Kanban). Mỗi cột {stage_code, name, total, rows[]}; bộ lọc như list_upsale_tickets.
create or replace function app.upsale_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default 20)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('stage_code', s.code, 'name', s.name,
           'total', (app.list_upsale_tickets((p_filters - 'stage_code') || jsonb_build_object('stage_code', s.code), 1, 0) ->> 'total')::bigint,
           'rows', app.list_upsale_tickets((p_filters - 'stage_code') || jsonb_build_object('stage_code', s.code), least(greatest(p_per_column, 1), 50), 0) -> 'rows') -- allow-number: trần 50 dòng mỗi cột Kanban
         order by s.sort_order), '[]'::jsonb)
    from app.catalog_item s where s.catalog_code = 'UPSALE_STAGE' and s.is_active;
$$;

-- Tìm (học sinh, lớp hiện tại) từ mã ghi danh (hàm nội bộ cho hai hàm bên dưới).
create or replace function app.upsale_target_of_enrollment(p_code text)
returns table (enrollment_id uuid, student_id uuid, class_id uuid, branch_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.student_id, ec.class_id, ec.branch_id
    from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
   where e.code = upper(btrim(p_code));
$$;

-- ---------------------------------------------------------------------------
-- app.preview_upsale_enrollment(mã ghi danh): hộp TT-03 hiện học sinh, lớp, số ghi danh và phiếu đang mở (nếu có) trước khi bấm Tạo.
-- Ai gọi: người có quyền Phiếu tái tục · Tạo ở cơ sở của lớp. Kết quả: {found, student_name, class_code, enrollment_count, open_ticket_code}.
-- ---------------------------------------------------------------------------
create or replace function app.preview_upsale_enrollment(p_enrollment_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  select * into v from app.upsale_target_of_enrollment(p_enrollment_code);
  if v.enrollment_id is null then
    return jsonb_build_object('found', false);
  end if;
  perform app.assert_can('UPSALE', 'TAO', v.branch_id);
  return jsonb_build_object('found', true,
    'student_name', (select full_name from app.student where id = v.student_id),
    'class_code', (select code from app.class where id = v.class_id),
    'enrollment_count', (select count(*)::int from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                          where e.student_id = v.student_id and ec.class_id = v.class_id and ec.end_date is null),
    'open_ticket_code', (select code from app.upsale_ticket where student_id = v.student_id and class_id = v.class_id and stage_code not in ('L5', 'L8')));
end;
$$;

-- app.create_upsale_ticket_from_enrollment(mã ghi danh, ghi chú): hộp «Tạo phiếu tái tục thủ công» (TT-03). Tìm (học sinh, lớp) từ ghi danh rồi dùng
-- app.create_upsale_ticket (mọi luật R-GD-13 của TT-A). Ghi danh không tìm thấy hoặc đã rời lớp: HMT_KHONG_TIM_THAY.
create or replace function app.create_upsale_ticket_from_enrollment(p_enrollment_code text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  select * into v from app.upsale_target_of_enrollment(p_enrollment_code);
  if v.enrollment_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh đang học với mã này. Kiểm lại mã ghi danh.');
  end if;
  return app.create_upsale_ticket(v.student_id, v.class_id, p_note);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.list_upsale_assignees(phiếu): hộp «Giao người phụ trách» (TT-01) liệt kê nhân sự cơ sở của phiếu nhận giao được (đang hoạt động, vào được CRM).
-- Ai gọi: người có quyền Phiếu tái tục · Giao việc ở cơ sở của phiếu. Kết quả: [{id, name}], tối đa list_page_size_max người.
-- ---------------------------------------------------------------------------
create or replace function app.list_upsale_assignees(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from app.upsale_ticket where id = p_ticket_id;
  if v_branch is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'GIAO_VIEC', v_branch);
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.display_name) order by x.display_name, x.id)
                     from (select u.id, u.display_name from app.user_account u
                            where u.branch_id = v_branch and not u.is_locked and u.student_code is null
                              and exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                                           where ur.user_id = u.id and ur.is_active and 'crm' = any (r.portals))
                            order by u.display_name, u.id limit app.get_setting_int('list_page_size_max')) x), '[]'::jsonb);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.upsale_target_of_enrollment(text) from public, anon, authenticated;
revoke execute on function app.upsale_ticket_row(app.upsale_ticket), app.list_upsale_tickets(jsonb, integer, integer), app.upsale_board(jsonb, integer),
  app.preview_upsale_enrollment(text), app.create_upsale_ticket_from_enrollment(text, text), app.list_upsale_assignees(uuid) from public, anon;
grant execute on function app.upsale_ticket_row(app.upsale_ticket), app.list_upsale_tickets(jsonb, integer, integer), app.upsale_board(jsonb, integer),
  app.preview_upsale_enrollment(text), app.create_upsale_ticket_from_enrollment(text, text), app.list_upsale_assignees(uuid) to authenticated;
