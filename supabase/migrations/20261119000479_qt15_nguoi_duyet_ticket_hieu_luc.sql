-- Migration 479 (Code D, 19/11/2026): QT-15 Cấu hình người duyệt ticket (phiếu nghiệp vụ) theo nhóm con, CÓ NGÀY HIỆU LỰC. Anh Trường duyệt 23:05. CAO (quyền duyệt).
-- Luật: R-CS-07 (ai duyệt theo nhóm con, sửa được trong cấu hình), R-CS-11 (cấu hình có hiệu lực như ma trận quyền), R-V2-24 (việc duyệt nằm ở phiếu nghiệp vụ). CLAUDE.md cấu hình mục 3:
-- bản ghi nghiệp vụ chụp giá trị lúc tạo: app.ticket_task.levels đã chụp cấp duyệt khi lập phiếu, nên đổi cấu hình KHÔNG đổi phiếu đã lập.
-- (1) app.ticket_task_rule_version: các phiên bản cấp duyệt của từng loại phiếu, theo ngày hiệu lực; chỉ thêm (trigger audit chuẩn ghi lịch sử). Phiên bản đầu = cấu hình hiện có.
-- (2) app.ticket_task_levels(loại, ngày): cấp duyệt có hiệu lực tại ngày (nội bộ). (3) app.save_ticket_task_rule: Admin thêm phiên bản (hiệu lực từ hôm nay trở đi).
-- (4) app.list_ticket_approver_config: màn QT-15 đọc một lần (loại phiếu, nhóm con áp dụng, cấp hiện hành, phiên bản sắp hiệu lực, lịch sử). (5) app.create_ticket_task (thân bản migration 424)
-- đọc cấp duyệt qua app.ticket_task_levels. Chỉ mục: unique (loại, ngày hiệu lực) phục vụ tra phiên bản mới nhất theo ngày. Quyền: Admin (ADMIN · Sửa để thêm, ADMIN · Xem để đọc).
select set_config('hmt.migration', 'on', false);
create table app.ticket_task_rule_version (
  id uuid primary key default gen_random_uuid(),
  task_type text not null references app.ticket_task_rule (task_type),
  levels text[] not null check (cardinality(levels) between 1 and 3 and levels <@ array['QUAN_LY_CO_SO', 'KE_TOAN']), -- allow-number: tối đa 3 cấp như ticket_task_rule
  valid_from date not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (task_type, valid_from)
);
comment on table app.ticket_task_rule_version is 'Phiên bản cấp duyệt của loại phiếu nghiệp vụ theo ngày hiệu lực (QT-15, R-CS-11). Chỉ thêm.';
select app.apply_standard('app.ticket_task_rule_version');
insert into app.ticket_task_rule_version (task_type, levels, valid_from)
select r.task_type, r.levels, date '2026-01-01' from app.ticket_task_rule r;
select set_config('hmt.migration', '', false);
alter table app.ticket_task_rule_version enable row level security;
revoke all on app.ticket_task_rule_version from public, anon, authenticated;
grant select on app.ticket_task_rule_version to authenticated;
create policy ticket_task_rule_version_read on app.ticket_task_rule_version for select to authenticated using ((select app.has_permission('ADMIN', 'XEM')));
-- Chỉ thêm: không sửa, không xoá phiên bản (kể cả hàm nghiệp vụ), trừ lúc chạy migration.
create or replace function app.tg_ticket_task_rule_version_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() then
    perform app.raise_error('HMT_CHI_THEM', 'Phiên bản cấp duyệt chỉ thêm, không sửa hay xoá.');
  end if;
  return coalesce(new, old);
end;
$$;
create trigger ticket_task_rule_version_append_only before update or delete on app.ticket_task_rule_version
  for each row execute function app.tg_ticket_task_rule_version_append_only();

-- app.ticket_task_levels(loại, ngày): phiên bản mới nhất có hiệu lực từ ngày trở về trước; chưa có phiên bản thì cấu hình gốc của loại phiếu. Nội bộ.
create or replace function app.ticket_task_levels(p_type text, p_on date)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select v.levels from app.ticket_task_rule_version v where v.task_type = p_type and v.valid_from <= p_on order by v.valid_from desc limit 1),
    (select r.levels from app.ticket_task_rule r where r.task_type = p_type));
$$;
revoke execute on function app.ticket_task_levels(text, date) from public, anon, authenticated;

-- app.save_ticket_task_rule(loại, cấp duyệt, ngày hiệu lực): thêm phiên bản cấp duyệt. Ai gọi: Admin (ADMIN · Sửa).
-- Cấp duyệt: danh sách theo thứ tự duyệt, mỗi phần tử QUAN_LY_CO_SO hoặc KE_TOAN, không lặp, 1 đến 3 cấp. Ngày hiệu lực: từ hôm nay trở đi (không viết lại quá khứ).
-- Lỗi: HMT_KHONG_CO_QUYEN, HMT_PHIEU_LOAI_SAI, HMT_CAP_DUYET_SAI, HMT_HIEU_LUC_QUA_KHU, HMT_HIEU_LUC_TRUNG. Kết quả: id phiên bản. Phiếu đã lập giữ cấp duyệt lúc lập.
create or replace function app.save_ticket_task_rule(p_type text, p_levels text[], p_valid_from date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  if not exists (select from app.ticket_task_rule r where r.task_type = p_type) then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-CS-07: cấp duyệt chỉ là Quản lý cơ sở và Kế toán, 1 đến 3 cấp, không lặp.
  if p_levels is null or cardinality(p_levels) < 1 or cardinality(p_levels) > 3 -- allow-number: tối đa 3 cấp
     or not p_levels <@ array['QUAN_LY_CO_SO', 'KE_TOAN'] or (select count(distinct x) from unnest(p_levels) x) <> cardinality(p_levels) then
    perform app.raise_error('HMT_CAP_DUYET_SAI', 'Cấp duyệt gồm Quản lý cơ sở và Kế toán, theo thứ tự duyệt, không lặp lại.');
  end if;
  -- Luật R-CS-11 (có hiệu lực): không viết lại quá khứ.
  if p_valid_from is null or p_valid_from < v_today then
    perform app.raise_error('HMT_HIEU_LUC_QUA_KHU', 'Ngày hiệu lực phải từ hôm nay trở đi.');
  end if;
  begin
    insert into app.ticket_task_rule_version (task_type, levels, valid_from) values (p_type, p_levels, p_valid_from) returning id into v_id;
  exception when unique_violation then
    perform app.raise_error('HMT_HIEU_LUC_TRUNG', 'Đã có cấu hình với ngày hiệu lực này. Chọn ngày khác.');
  end;
  return v_id;
end;
$$;

-- app.list_ticket_approver_config(): QT-15, một lần gọi. Ai gọi: Admin (ADMIN · Xem). Mỗi loại phiếu: nhóm con ticket dùng loại đó, cấp duyệt hiện hành (hôm nay),
-- phiên bản sắp hiệu lực (từ ngày mai) và toàn bộ lịch sử phiên bản (mới nhất trước).
create or replace function app.list_ticket_approver_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên xem cấu hình người duyệt.');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'task_type', r.task_type,
      'categories', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.sort_order, c.code)
                                from app.ticket_category c where c.business_type = r.task_type and c.kind = 'SUBGROUP' and c.is_active), '[]'::jsonb),
      'current_levels', to_jsonb(app.ticket_task_levels(r.task_type, v_today)),
      'upcoming', coalesce((select jsonb_agg(jsonb_build_object('levels', to_jsonb(v.levels), 'valid_from', v.valid_from) order by v.valid_from)
                              from app.ticket_task_rule_version v where v.task_type = r.task_type and v.valid_from > v_today), '[]'::jsonb),
      'history', coalesce((select jsonb_agg(jsonb_build_object('levels', to_jsonb(v.levels), 'valid_from', v.valid_from, 'created_at', v.created_at,
                                                                'created_by_name', app.staff_display_name(v.created_by)) order by v.valid_from desc)
                             from app.ticket_task_rule_version v where v.task_type = r.task_type), '[]'::jsonb))
      order by r.task_type)
      from app.ticket_task_rule r), '[]'::jsonb);
end;
$$;
revoke execute on function app.save_ticket_task_rule(text, text[], date), app.list_ticket_approver_config() from public, anon;
grant execute on function app.save_ticket_task_rule(text, text[], date), app.list_ticket_approver_config() to authenticated;

-- app.create_ticket_task: thân bản migration 424 (C31); chỉ đổi dòng đọc cấp duyệt.
create or replace function app.create_ticket_task(p_ticket_id uuid, p_type text, p_reason text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_biz text;
  v_levels text[];
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_entity text;
  v_key text;
  v_enr app.enrollment;
  v_enr_id uuid;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không tạo phiếu được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập lý do của phiếu.');
  end if;
  -- QT-15: cấp duyệt theo phiên bản có hiệu lực tại ngày lập phiếu (app.ticket_task_levels); phiếu chụp lại cấp duyệt lúc tạo (ticket_task.levels).
  v_levels := app.ticket_task_levels(p_type, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  if v_levels is null then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-V2-24: nhóm con của ticket phải có phiếu nghiệp vụ đúng loại.
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_type then
    perform app.raise_error('HMT_PHIEU_KHAC_NHOM', 'Nhóm con của ticket này không dùng loại phiếu đã chọn.');
  end if;
  -- Luật AS-10: mỗi ticket một phiếu đang mở.
  if exists (select from app.ticket_task k where k.ticket_id = t.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO', 'Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.');
  end if;
  -- Kiểm sớm dữ liệu phiếu Cập nhật hồ sơ.
  if p_type = 'CAP_NHAT_HO_SO' then
    v_entity := p_payload ->> 'entity';
    if v_entity is null or v_entity not in ('PARENT', 'STUDENT') or jsonb_typeof(p_payload -> 'changes') is distinct from 'object' or (p_payload -> 'changes') = '{}'::jsonb then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.');
    end if;
    if v_entity = 'STUDENT' and t.student_id is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.');
    end if;
    for v_key in select jsonb_object_keys(p_payload -> 'changes') loop
      if not exists (select from app.ticket_task_field f where f.entity = v_entity and f.field_code = v_key and f.is_active) then
        perform app.raise_error('HMT_PHIEU_TRUONG_SAI', 'Trường này không được sửa bằng phiếu Cập nhật hồ sơ.');
      end if;
    end loop;
  -- Luật R-V2-24, R-CS-02: phiếu Bảo lưu, Chuyển lớp mang dữ liệu để thực hiện bằng hàm của cụm Ghi danh (migration 234); kiểm sớm để báo lỗi ngay lúc tạo.
  elsif p_type in ('BAO_LUU', 'CHUYEN_LOP') then
    begin
      v_enr_id := nullif(p_payload ->> 'enrollment_id', '')::uuid;
    exception when others then
      v_enr_id := null;
    end;
    select * into v_enr from app.enrollment where id = v_enr_id;
    if v_enr.id is null or t.student_id is null or v_enr.student_id is distinct from t.student_id or v_enr.branch_id <> t.branch_id then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lý do.');
    end if;
    if p_type = 'BAO_LUU' then
      if p_payload ->> 'resume' = 'true' then
        -- C30/C31 (R-GD-09, R-CS-02): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu; ghi danh phải đang có bảo lưu chạy.
        if not exists (select from app.enrollment_hold h where h.enrollment_id = v_enr.id and h.status_code = 'DANG_BAO_LUU') then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
        end if;
      elsif coalesce(nullif(p_payload ->> 'months', '')::integer, 0) < 1 then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Nhập số tháng bảo lưu (từ 1).');
      end if;
    else
      if nullif(p_payload ->> 'to_class_id', '') is null or nullif(p_payload ->> 'start_date', '') is null or nullif(p_payload ->> 'kind_code', '') is null then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp mới, ngày bắt đầu và loại chuyển.');
      end if;
      -- Chuyển cơ sở cần quản lý của cả hai cơ sở duyệt (R-CS-07): chưa làm ở phiếu, chặn ngay lúc tạo.
      if p_payload ->> 'kind_code' = 'CHUYEN_CO_SO' then
        perform app.raise_error('HMT_PHIEU_CHUA_LAM', 'Chuyển cơ sở cần quản lý của cả hai cơ sở duyệt: chưa làm ở bản hiện tại.');
      end if;
    end if;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels) returning id into v_id;
  perform app.ticket_task_log((select k from app.ticket_task k where k.id = v_id), 'TAO', null, 'NHAP', null);
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;
