-- Migration 691 (E-26-04, anh Trường chốt 26/11/2026): «VIỆC CỦA TÔI», PR DB2: «Để sau».
-- Luật: hoãn tối đa work_snooze_max_days ngày (3), mỗi người hoãn một việc tối đa work_snooze_max_times lần (2);
--   KHÔNG hoãn việc chờ duyệt và buổi chưa điểm danh. Hoãn theo NGƯỜI DÙNG: người khác và chế độ cả đội vẫn thấy.

select set_config('hmt.migration', 'on', false);
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description) values
  ('work_snooze_max_days', 'Việc của tôi: «Để sau» tối đa bao nhiêu ngày', 'INT', 'ngày', 0, 30, '3', true, 'BAN_HANG', 'E-26-04',
   'Mỗi lần bấm «Để sau», hạn hiện lại không quá số ngày này tính từ lúc bấm. 0 = không cho hoãn.'),
  ('work_snooze_max_times', 'Việc của tôi: số lần được «Để sau» một việc', 'INT', 'lần', 0, 10, '2', true, 'BAN_HANG', 'E-26-04',
   'Mỗi người được hoãn một việc tối đa số lần này. 0 = không cho hoãn.');
select set_config('hmt.migration', '', false);

create table app.work_snooze (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.user_account (id),
  signal text not null check (signal in ('APPOINTMENT', 'TEST', 'SESSION_PENDING', 'ABSENT_TODAY', 'RENEWAL')),
  entity_id uuid not null,
  snooze_until timestamptz not null,
  snooze_count integer not null default 1 check (snooze_count >= 1),
  note text check (length(note) <= 500), -- allow-number: giới hạn độ dài ghi chú
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (user_id, signal, entity_id)
);
comment on table app.work_snooze is '«Để sau» ở Việc của tôi: mỗi người một dòng cho một việc. Chỉ ghi qua app.snooze_work.';
-- Chỉ mục: khoá duy nhất (user_id, ...) lo khoá ngoại và «dòng của tôi»; chỉ mục dưới cho app.list_my_work tra theo việc.
create index work_snooze_item_idx on app.work_snooze (signal, entity_id, snooze_until);
select app.apply_standard('app.work_snooze');
alter table app.work_snooze enable row level security;
revoke all on app.work_snooze from public, anon, authenticated;
grant select on app.work_snooze to authenticated;
create policy work_snooze_read_own on app.work_snooze for select to authenticated
  using (user_id = (select auth.uid()));

-- app.snooze_work: «Để sau» một việc của CHÍNH người gọi.
-- Ai gọi: nhân viên đã sẵn sàng, việc đang nằm trong danh sách «của tôi» của họ (quyền do hàm tín hiệu kiểm).
-- Vào: p_signal, p_entity_id (như app.list_my_work trả), p_until (lúc hiện lại), p_note. Ra: {snooze_until, snooze_count, remaining}.
-- Luật: R1 loại việc không hoãn; R2 hạn trong tương lai, không quá work_snooze_max_days; R3 không quá work_snooze_max_times lần.
--   Tham số đọc theo cơ sở của việc.
create function app.snooze_work(p_signal text, p_entity_id uuid, p_until timestamptz, p_note text default null)
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
revoke execute on function app.snooze_work(text, uuid, timestamptz, text) from public, anon;
grant execute on function app.snooze_work(text, uuid, timestamptz, text) to authenticated;

-- app.list_my_work: «Việc của tôi», gom theo phụ huynh, phân trang theo THẺ.
-- Ai gọi: nhân viên đã sẵn sàng; mỗi tín hiệu tự kiểm quyền. Vào: p_filters {mine (mặc định true; false = cả đội), branch_id, owner_id (khi cả đội)},
--   p_limit, p_offset. Ra: {counts {now, today, soon} (đếm việc), total_cards, cards [{group_key, parent_id, parent_name, phone, urgency, items []}]}.
-- «Để sau» (691): chế độ của tôi ẩn việc người gọi đang hoãn; cả đội vẫn thấy, mỗi việc có snoozed_until (null = không hoãn).
-- Thẻ: cùng phụ huynh; lead chưa có phụ huynh gom theo số điện thoại; việc không gắn phụ huynh đứng riêng. Sắp: nhóm gấp nhất, hạn sớm nhất, khoá thẻ.
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
