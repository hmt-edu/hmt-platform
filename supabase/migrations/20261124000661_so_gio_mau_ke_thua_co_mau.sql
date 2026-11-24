-- E-23-36 (CAO: sổ giờ). Dòng sổ giờ sinh ra khi buổi của lớp mẫu tự Done phải mang cờ mẫu.
-- Lỗi gốc (ra-soát xác nhận trên staging): cron tự Done buổi mẫu → deduct_session_hours chèn dòng TRU_BUOI với is_demo = false và
--   không vào demo_data_item → lọt báo cáo giờ, xoá bộ không gỡ được.
-- Làm gì: (1) trigger trước khi chèn dòng sổ giờ: nếu ghi danh là ghi danh mẫu thì dòng mang is_demo = true và vào demo_data_item
--   đúng bộ của ghi danh; (2) dọn dữ liệu đã lọt (dòng sổ giờ của ghi danh mẫu còn is_demo = false).
-- Không đổi luật trừ giờ, không đổi hàm deduct_session_hours. Dòng của ghi danh thật không bị đụng.
-- Chỉ mục: dùng demo_data_item_entity_idx (entity_type, entity_id) để tìm bộ của ghi danh; hour_ledger_demo_idx đã có từ 657.

-- (1) Trigger kế thừa cờ mẫu.
create or replace function app.hour_ledger_inherit_demo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_set uuid;
begin
  -- Luật: dòng đã mang cờ mẫu (mảnh 657 tự ghi demo_data_item) thì giữ nguyên.
  if new.is_demo then
    return new;
  end if;
  -- Luật: chỉ ghi danh mẫu truyền cờ cho dòng sổ giờ; ghi danh thật không bị gắn cờ.
  select i.set_id into v_set
    from app.demo_data_item i
    join app.enrollment e on e.id = new.enrollment_id and e.is_demo
   where i.entity_type = 'ENROLLMENT' and i.entity_id = new.enrollment_id
   limit 1;
  if v_set is not null then
    new.is_demo := true;
    insert into app.demo_data_item (set_id, entity_type, entity_id, created_by, updated_by)
    values (v_set, 'HOUR_LEDGER', new.id, auth.uid(), auth.uid())
    on conflict (set_id, entity_type, entity_id) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function app.hour_ledger_inherit_demo() from public, anon, authenticated;

create trigger hour_ledger_inherit_demo
  before insert on app.hour_ledger
  for each row execute function app.hour_ledger_inherit_demo();

-- (2) Dọn dòng đã lọt (một lần). Sổ giờ chặn sửa bằng trigger append-only: tắt trigger đó chỉ trong migration này, chỉ đổi cột is_demo
--   của dòng thuộc ghi danh mẫu, rồi bật lại.
alter table app.hour_ledger disable trigger hour_ledger_no_update;

insert into app.demo_data_item (set_id, entity_type, entity_id)
select i.set_id, 'HOUR_LEDGER', g.id
  from app.hour_ledger g
  join app.enrollment e on e.id = g.enrollment_id and e.is_demo
  join app.demo_data_item i on i.entity_type = 'ENROLLMENT' and i.entity_id = e.id
 where not g.is_demo
on conflict (set_id, entity_type, entity_id) do nothing;

update app.hour_ledger g
   set is_demo = true
  from app.enrollment e
 where e.id = g.enrollment_id and e.is_demo and not g.is_demo;

alter table app.hour_ledger enable trigger hour_ledger_no_update;
