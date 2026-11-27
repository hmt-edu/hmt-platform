-- Migration 703 (E-27-04, anh Trường OK 27/11/2026): «VIỆC CỦA TÔI» thêm hai tín hiệu: ticket quá hạn và công nợ quá hạn,
-- để Trang chủ rút gọn dùng. Hai hàm con mới; app.list_my_work và app.snooze_work chỉ thêm hai nguồn.
-- «Để sau»: hai tín hiệu mới hoãn được như các việc thường (chỉ cấm việc chờ duyệt và buổi chưa điểm danh).
-- Chỉ mục: không thêm; đi theo ticket_assignee_status_idx, ticket_branch_status_due_idx, sales_order_creator_idx,
--   sales_order_branch_status_idx, sales_order_installment (order_id, seq), money_in_order_idx (EXPLAIN trong mô tả PR).

-- app.work_tickets_overdue: ticket chưa xử lý xong đã quá hạn xử lý (đúng công thức QUA_HAN của app.ticket_row). Hàm trong.
-- Quyền Ticket · Xem, đúng phạm vi chính sách ticket_read (kể cả Được phân công: ticket mình tạo hoặc phụ trách). «Của tôi» = người phụ trách.
create function app.work_tickets_overdue(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('TICKET', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO', 'DUOC_PHAN_CONG') then
    return;
  end if;
  return query
  select 'TICKET_OVERDUE', 'TICKET', t.id, t.parent_id, null::text, 'NOW',
         'Ticket ' || t.code || ' · ' || t.title, 'Ticket quá hạn xử lý', t.resolve_due_at,
         'OPEN_TICKET', t.assignee_id, t.branch_id
    from app.ticket t
   where t.status_code not in ('DA_XU_LY', 'DA_DONG', 'DA_HUY') and t.resolve_due_at < now()
     and (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and t.branch_id = v_my)
          or (v_scope = 'DUOC_PHAN_CONG' and (t.created_by = v_me or t.assignee_id = v_me)))
     and (p_branch is null or t.branch_id = p_branch)
     and (not p_mine or t.assignee_id = v_me);
end;
$$;

-- app.work_debts_overdue: đơn đã duyệt còn đợt quá hạn chưa thu đủ, MỘT việc mỗi đơn (quyền Đơn hàng · Xem, như app.list_receivables).
-- «Của tôi» = người lập đơn (anh chốt: Trưởng cơ sở thấy cả đội ở chế độ cả đội; Kế toán không nhận nhắc từng khoản).
-- Tiền: đã thu (money_in) trừ dần theo thứ tự đợt như app.list_receivables. Nợ đầu kỳ chưa tính. Hàm trong.
create function app.work_debts_overdue(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  with o as (
    select so.id, so.code, so.branch_id, so.parent_id, so.created_by
      from app.sales_order so
     where so.status_code = 'DA_DUYET'
       and (v_scope = 'TOAN_HE_THONG' or so.branch_id = v_my)
       and (p_branch is null or so.branch_id = p_branch)
       and (not p_mine or so.created_by = v_me)
       and exists (select from app.sales_order_installment i where i.order_id = so.id and i.due_date < v_today)
  )
  select 'DEBT_OVERDUE', 'SALES_ORDER', o.id, o.parent_id, null::text, 'NOW',
         'Công nợ ' || o.code,
         'Quá hạn ' || (v_today - d.first_due) || ' ngày, còn ' || replace(to_char(d.owed, 'FM999G999G999G999'), ',', '.') || ' đ',
         (d.first_due::timestamp at time zone 'Asia/Ho_Chi_Minh'), 'OPEN_ORDER', o.created_by, o.branch_id
    from o
   cross join lateral (
     select coalesce(sum(m.amount), 0)::bigint as paid from app.money_in m where m.order_id = o.id
   ) p
   cross join lateral (
     select min(c.due_date) as first_due,
            sum(c.amount - greatest(least(c.amount, p.paid - c.before), 0))::bigint as owed
       from (
         select i.due_date, i.amount,
                coalesce(sum(i.amount) over (order by i.seq rows between unbounded preceding and 1 preceding), 0) as before
           from app.sales_order_installment i
          where i.order_id = o.id and i.due_date is not null
       ) c
      where c.due_date < v_today and c.amount > greatest(least(c.amount, p.paid - c.before), 0)
   ) d
   where d.first_due is not null;
end;
$$;
revoke execute on function app.work_tickets_overdue(boolean, uuid), app.work_debts_overdue(boolean, uuid) from public, anon, authenticated;

-- «Để sau» nhận thêm hai tín hiệu.
alter table app.work_snooze drop constraint work_snooze_signal_check;
alter table app.work_snooze add constraint work_snooze_signal_check
  check (signal in ('APPOINTMENT', 'TEST', 'SESSION_PENDING', 'ABSENT_TODAY', 'RENEWAL', 'TICKET_OVERDUE', 'DEBT_OVERDUE'));

-- app.snooze_work: như migration 691, thêm hai nguồn ticket và công nợ quá hạn.
create or replace function app.snooze_work(p_signal text, p_entity_id uuid, p_until timestamptz, p_note text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_my uuid := app.current_branch_id();
  v_window integer;
  v_until timestamptz;
  v_branch uuid;
  v_days integer;
  v_times integer;
  v_count integer;
begin
  if auth.uid() is null or not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem việc của tôi.');
  end if;
  -- R1: việc chờ duyệt và buổi đang chờ điểm danh không được hoãn.
  if p_signal in ('APPROVAL', 'SESSION_NO_ATTENDANCE') then
    perform app.raise_error('HMT_VIEC_KHONG_HOAN', 'Việc chờ duyệt và buổi chưa điểm danh không được để sau.');
  end if;

  v_window := app.get_setting_int('work_now_window_hours', v_my);
  v_until := (((now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('work_soon_days', v_my)::integer + 1)::timestamp
              at time zone 'Asia/Ho_Chi_Minh');
  select w.branch_id into v_branch
    from (
      select * from app.work_appointments(true, null, v_until, v_window) where p_signal = 'APPOINTMENT'
      union all select * from app.work_tests(true, null, v_until, v_window) where p_signal = 'TEST'
      union all select * from app.work_sessions(true, null, v_window) where p_signal = 'SESSION_PENDING'
      union all select * from app.work_absent_today(true, null) where p_signal = 'ABSENT_TODAY'
      union all select * from app.work_renewals(true, null) where p_signal = 'RENEWAL'
      union all select * from app.work_tickets_overdue(true, null) where p_signal = 'TICKET_OVERDUE'
      union all select * from app.work_debts_overdue(true, null) where p_signal = 'DEBT_OVERDUE'
    ) w
   where w.signal = p_signal and w.entity_id = p_entity_id
   limit 1;
  if v_branch is null then
    perform app.raise_error('HMT_VIEC_KHONG_CON', 'Việc này không còn trong danh sách việc của bạn.');
  end if;
  -- R1 (tiếp): buổi đã hết giờ mà chưa điểm danh cũng không được hoãn.
  if p_signal = 'SESSION_PENDING' and not exists (
       select from app.session_attendance a where a.session_id = p_entity_id and a.is_active and a.teacher_status_code is not null) then
    perform app.raise_error('HMT_VIEC_KHONG_HOAN', 'Việc chờ duyệt và buổi chưa điểm danh không được để sau.');
  end if;

  v_days := app.get_setting_int('work_snooze_max_days', v_branch);
  v_times := app.get_setting_int('work_snooze_max_times', v_branch);
  -- R2: hạn hiện lại.
  if p_until is null or p_until <= now() or p_until > now() + make_interval(days => v_days) then
    perform app.raise_error('HMT_HAN_DE_SAU_SAI', 'Hạn để sau phải sau lúc này và không quá ' || v_days || ' ngày.');
  end if;
  -- R3: số lần. Ghi một câu để hai lần bấm cùng lúc không vượt giới hạn.
  insert into app.work_snooze as z (user_id, signal, entity_id, snooze_until, note)
  select auth.uid(), p_signal, p_entity_id, p_until, nullif(btrim(p_note), '') where v_times >= 1
  on conflict (user_id, signal, entity_id) do update
    set snooze_until = excluded.snooze_until, note = excluded.note, snooze_count = z.snooze_count + 1
    where z.snooze_count < v_times
  returning z.snooze_count into v_count;
  if v_count is null then
    perform app.raise_error('HMT_HET_LUOT_DE_SAU', 'Việc này đã hết lượt để sau (tối đa ' || v_times || ' lần).');
  end if;
  return jsonb_build_object('snooze_until', p_until, 'snooze_count', v_count, 'remaining', greatest(v_times - v_count, 0));
end;
$$;

-- app.list_my_work: như migration 691 (ai gọi, đầu vào, kết quả, «Để sau»), thêm hai nguồn ticket và công nợ quá hạn.
create or replace function app.list_my_work(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, true);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_my uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_window integer := app.get_setting_int('work_now_window_hours', v_my);
  v_until timestamptz := (((now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('work_soon_days', v_my)::integer + 1)::timestamp
                          at time zone 'Asia/Ho_Chi_Minh');
  v_result jsonb;
begin
  if auth.uid() is null or not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem việc của tôi.');
  end if;
  with i as materialized (
    select w.*, z.snoozed_until, coalesce('P:' || w.parent_id, 'T:' || w.phone, w.signal || ':' || w.entity_id) as group_key,
           case w.urgency when 'NOW' then 1 when 'TODAY' then 2 else 3 end as rank -- allow-number: thứ tự ba nhóm gấp
      from (
        select * from app.work_appointments(v_mine, v_branch, v_until, v_window)
        union all select * from app.work_tests(v_mine, v_branch, v_until, v_window)
        union all select * from app.work_approvals(v_branch)
        union all select * from app.work_sessions(v_mine, v_branch, v_window)
        union all select * from app.work_absent_today(v_mine, v_branch)
        union all select * from app.work_renewals(v_mine, v_branch)
        union all select * from app.work_tickets_overdue(v_mine, v_branch)
        union all select * from app.work_debts_overdue(v_mine, v_branch)
      ) w
      left join lateral (
        select max(sn.snooze_until) as snoozed_until, bool_or(sn.user_id = auth.uid()) as by_me
          from app.work_snooze sn
         where sn.signal = w.signal and sn.entity_id = w.entity_id and sn.snooze_until > now()
      ) z on true
     -- Lọc theo người chỉ ở chế độ cả đội; việc chờ duyệt là của người gọi nên không theo bộ lọc này.
     where (v_mine or v_owner is null or (w.owner_id = v_owner and w.signal <> 'APPROVAL'))
       -- «Để sau»: chỉ ẩn với chính người đã hoãn, ở chế độ của tôi.
       and not (v_mine and coalesce(z.by_me, false))
  ), cards as (
    select i.group_key, min(i.rank) as rank, min(i.due_at) as due_at,
           (array_agg(i.parent_id) filter (where i.parent_id is not null))[1] as parent_id, max(i.phone) as phone
      from i group by i.group_key
  ), page as (
    select * from cards order by rank, due_at nulls last, group_key limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'counts', (select jsonb_build_object('now', count(*) filter (where rank = 1), 'today', count(*) filter (where rank = 2), -- allow-number: thứ tự ba nhóm gấp
                                                'soon', count(*) filter (where rank = 3)) from i), -- allow-number: thứ tự ba nhóm gấp
           'total_cards', (select count(*) from cards),
           'cards', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'group_key', p.group_key, 'parent_id', p.parent_id, 'parent_name', par.full_name, 'phone', coalesce(par.phone, p.phone),
                      'urgency', case p.rank when 1 then 'NOW' when 2 then 'TODAY' else 'SOON' end, -- allow-number: thứ tự ba nhóm gấp
                      'items', (select jsonb_agg(jsonb_build_object(
                                         'signal', x.signal, 'entity_type', x.entity_type, 'entity_id', x.entity_id, 'urgency', x.urgency,
                                         'title', x.title, 'why', x.why, 'due_at', x.due_at, 'action', x.action, 'snoozed_until', x.snoozed_until,
                                         'owner_name', app.staff_display_name(x.owner_id), 'branch_code', b.code)
                                         order by x.rank, x.due_at nulls last, x.signal, x.entity_id)
                                  from i x left join app.branch b on b.id = x.branch_id where x.group_key = p.group_key))
                      order by p.rank, p.due_at nulls last, p.group_key)
               from page p left join app.parent par on par.id = p.parent_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;
