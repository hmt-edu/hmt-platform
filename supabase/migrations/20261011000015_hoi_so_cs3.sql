-- Hội sở = CS3 (chốt với anh Trường 11/10/2026; sửa spec 02 mục Cơ sở): đơn vị văn phòng, chỉ để gắn tài khoản
-- nhân viên (Admin, Kế toán, vận hành chung). Không có phòng học, lớp, học sinh.
-- Kèm: Trưởng cơ sở được Xuất file phiếu tái tục (danh sách sắp hết giờ của cơ sở mình để giao sale, CSKH).

select set_config('hmt.migration', 'on', false);

comment on table app.branch is 'Cơ sở (danh mục mở). CS3 là Hội sở (văn phòng); không đánh số lại.';

-- ---------------------------------------------------------------------------
-- Cơ sở văn phòng
-- ---------------------------------------------------------------------------
alter table app.branch add column is_office boolean not null default false;
comment on column app.branch.is_office is 'Văn phòng (Hội sở): chỉ gắn tài khoản nhân viên, không có phòng học, lớp, học sinh.';

insert into app.branch (code, name, sort_order, is_office) values ('CS3', 'Hội sở', 5, true);

-- Luật: phòng học, lớp, học sinh chỉ thuộc cơ sở dạy học, không thuộc văn phòng.
-- Ai gọi: trigger bảng phòng (bước này), hàm cấp mã lớp; các bảng lớp, ghi danh sau này gọi lại hàm này.
create or replace function app.assert_teaching_branch(p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select from app.branch where id = p_branch_id and is_office) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG',
      'Hội sở là văn phòng: không có phòng học, lớp, học sinh. Hãy chọn cơ sở dạy học.');
  end if;
end;
$$;

create or replace function app.tg_room_teaching_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.assert_teaching_branch(new.branch_id);
  return new;
end;
$$;

create trigger room_teaching_branch before insert or update of branch_id on app.room
  for each row execute function app.tg_room_teaching_branch();

-- Luật: không đổi một cơ sở đang có phòng học thành văn phòng (dữ liệu cũ sẽ sai luật).
create or replace function app.tg_branch_office_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_office and not old.is_office and exists (select from app.room where branch_id = new.id) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG', 'Cơ sở đang có phòng học, không đổi thành văn phòng được.');
  end if;
  return new;
end;
$$;

create trigger branch_office_rules before update of is_office on app.branch
  for each row execute function app.tg_branch_office_rules();

-- Cấp mã lớp (như migration 004), thêm luật: không cấp mã lớp cho văn phòng.
create or replace function app.issue_class_code(
  p_branch_code text, p_year_code text, p_subject_code text, p_grade_code text,
  p_class_type text, p_level_code text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('LOP');
  v_branch_id uuid;
  v_prefix text;
  v_number bigint;
begin
  -- Luật: cơ sở, năm học đang dùng.
  select id into v_branch_id from app.branch where code = p_branch_code and is_active;
  if v_branch_id is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Cơ sở %s không có hoặc đã Ngừng.', p_branch_code));
  end if;
  -- Luật: lớp chỉ mở ở cơ sở dạy học.
  perform app.assert_teaching_branch(v_branch_id);
  if not exists (select from app.academic_year where code = p_year_code and is_active) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Năm học %s không có hoặc đã Ngừng.', p_year_code));
  end if;

  -- Luật: môn, khối, phân loại lớp đúng danh mục.
  perform app.assert_catalog_code_active('SUBJECT', p_subject_code);
  perform app.assert_catalog_code_active('GRADE', p_grade_code);
  perform app.assert_catalog_code_active('CLASS_TYPE', p_class_type);

  -- Luật: lớp riêng (LR) không có trình độ; lớp CB, NC bắt buộc có trình độ.
  if p_class_type = 'LR' and p_level_code is not null then
    perform app.raise_error('HMT_MA_LOP_SAI', 'Lớp riêng không có trình độ.');
  end if;
  if p_class_type <> 'LR' then
    if p_level_code is null then
      perform app.raise_error('HMT_MA_LOP_SAI', 'Lớp cơ bản, nâng cao phải có trình độ.');
    end if;
    perform app.assert_catalog_code_active('LEVEL', p_level_code);
  end if;

  v_prefix := concat_ws('-', p_branch_code, p_year_code, p_subject_code, p_grade_code, p_class_type, p_level_code);
  v_number := app.next_counter_value('LOP:' || v_prefix, v_format.start_value);
  return v_prefix || '-' || lpad(v_number::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Trưởng cơ sở Xuất file phiếu tái tục trong cơ sở mình (L1; mỗi lần xuất ghi nhật ký xuất file).
-- Phân hệ Kế toán giữ chỉ Xem.
-- ---------------------------------------------------------------------------
insert into app.permission (role_code, module_code, action_code, scope_code)
values ('BRANCH_MANAGER', 'UPSALE', 'XUAT', 'CO_SO');

select set_config('hmt.migration', '', false);
