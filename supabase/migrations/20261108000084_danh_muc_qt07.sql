-- QT-06, QT-07 Danh mục (canvas bổ sung v2 `1794108604-3066`; Q-104..Q-106, Q-109..Q-112, Q-116, Q-119, Q-122; R-V2-42, R-V2-43).
-- Làm gì:
--  (1) Cột app.catalog.is_read_only: danh mục chỉ xem (Tỉnh/Thành phố, Phường/Xã; Q-110). Trigger mục danh mục chặn mọi sửa ngoài migration.
--  (2) Q-122: nhóm con của Giai đoạn lead và Giai đoạn cơ hội chuyển sang danh mục "Hệ thống": trên màn chỉ đổi tên, thêm hoặc Ngừng nhóm
--      con chỉ làm bằng migration (trigger đã có cho phép migration, như L5P, L5Q ở migration 067).
--  (3) app.catalog_move_item: đổi thứ tự bằng nút ▲▼ (đổi chỗ với mục kề trong cùng danh mục, cùng cha); chỉ danh mục mở.
--  (4) app.catalog_add_item: thêm kiểm tra có câu tiếng Việt cho mã sai dạng, tên trống, mã trùng (hộp Thêm mục hiện thẳng).
--  (5) app.list_catalog_summary, app.get_catalog_tree: danh sách danh mục (QT-06) và cây mục của một danh mục gốc (QT-07).
-- Chỉ mục: không thêm. Bảng catalog ít dòng (khoảng 56), catalog_item đã có unique (catalog_code, code) và chỉ mục parent_id.

select set_config('hmt.migration', 'on', false);

alter table app.catalog add column is_read_only boolean not null default false;
comment on column app.catalog.is_read_only is 'Danh mục chỉ xem: nạp từ file chuẩn, không sửa trên màn hình (Q-110); chỉ migration sửa được.';
update app.catalog set is_read_only = true where code in ('PROVINCE', 'WARD');

-- Luật Q-110: thêm điều kiện danh mục chỉ xem vào trigger mục danh mục (các luật cũ giữ nguyên).
create or replace function app.tg_catalog_item_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_catalog app.catalog%rowtype;
  v_parent app.catalog_item%rowtype;
  v_linked app.catalog_item%rowtype;
begin
  select * into v_catalog from app.catalog where code = new.catalog_code;

  -- Luật Q-110 (QT-07, anh chốt 08/11): danh mục chỉ xem (Tỉnh, phường: nạp từ file chuẩn) không thêm, đổi tên, Ngừng ngoài migration.
  if v_catalog.is_read_only and not app.is_migration() then
    perform app.raise_error('HMT_DANH_MUC_CHI_XEM',
      format('Danh mục "%s" nạp từ file chuẩn, chỉ xem, không sửa trên màn hình.', v_catalog.name));
  end if;

  -- Luật: mục không chuyển sang danh mục khác.
  if TG_OP = 'UPDATE' and new.catalog_code is distinct from old.catalog_code then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không chuyển mục sang danh mục khác được.');
  end if;

  -- Luật: danh mục hệ thống không thêm mục (trừ migration).
  if v_catalog.kind = 'HE_THONG' and TG_OP = 'INSERT' and not app.is_migration() then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG',
      format('Danh mục hệ thống "%s" không thêm mục được; chỉ đổi tên hiển thị và thứ tự.', v_catalog.name));
  end if;

  -- Luật: danh mục hệ thống không Ngừng mục, không đổi mục cha/mục nối (trừ migration).
  if v_catalog.kind = 'HE_THONG' and TG_OP = 'UPDATE' and not app.is_migration()
     and (new.is_active is distinct from old.is_active
          or new.parent_id is distinct from old.parent_id
          or new.linked_item_id is distinct from old.linked_item_id
          or new.is_locked is distinct from old.is_locked) then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG',
      format('Danh mục hệ thống "%s" chỉ đổi được tên hiển thị và thứ tự.', v_catalog.name));
  end if;

  -- Luật: mục bị khoá (có luật trong code bám vào) không Ngừng được.
  if TG_OP = 'UPDATE' and old.is_locked and old.is_active and not new.is_active and not app.is_migration() then
    perform app.raise_error('HMT_MUC_BI_KHOA',
      format('Mục "%s" đang được luật nghiệp vụ dùng nên không Ngừng được.', old.name));
  end if;

  -- Luật: danh mục nhiều tầng phải có mục cha đúng danh mục cha; một tầng thì không có mục cha.
  if v_catalog.parent_catalog is null and new.parent_id is not null then
    perform app.raise_error('HMT_MUC_CHA_SAI', format('Danh mục "%s" không có tầng cha.', v_catalog.name));
  end if;
  if v_catalog.parent_catalog is not null then
    select * into v_parent from app.catalog_item where id = new.parent_id;
    if v_parent.id is null or v_parent.catalog_code <> v_catalog.parent_catalog then
      perform app.raise_error('HMT_MUC_CHA_SAI',
        format('Mục "%s" phải thuộc một mục của danh mục %s.', new.name, v_catalog.parent_catalog));
    end if;
  end if;

  -- Luật: mục nối phải thuộc đúng danh mục được khai báo để nối.
  if new.linked_item_id is not null then
    select * into v_linked from app.catalog_item where id = new.linked_item_id;
    if v_catalog.linked_catalog is null or v_linked.catalog_code is distinct from v_catalog.linked_catalog then
      perform app.raise_error('HMT_MUC_NOI_SAI',
        format('Mục "%s" nối sai danh mục.', new.name));
    end if;
  end if;

  return new;
end;
$$;

-- Luật Q-122 (R-V2-42): nhóm con của hai giai đoạn khoá chỉ đổi tên trên màn hình; thêm, Ngừng bằng migration.
update app.catalog set kind = 'HE_THONG' where code in ('LEAD_SUBSTAGE', 'OPP_SUBSTAGE');

select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- Thêm mục vào danh mục mở (thay bản ở migration 002: thêm câu lỗi tiếng Việt cho nhập sai).
-- Ai gọi: Admin (assert_config_writer). Đầu vào: danh mục, mã, tên, thứ tự (trống thì đặt cuối), mục cha, mục nối. Kết quả: id mục mới.
-- Luật: mã viết hoa không dấu, không trùng trong danh mục, tên không trống; danh mục hệ thống và danh mục chỉ xem bị trigger chặn.
-- ---------------------------------------------------------------------------
create or replace function app.catalog_add_item(
  p_catalog_code text, p_code text, p_name text,
  p_sort_order integer default null, p_parent_id uuid default null, p_linked_item_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_name text := btrim(coalesce(p_name, ''));
begin
  perform app.assert_config_writer();
  -- Luật: tên hiển thị bắt buộc.
  if v_name = '' then
    perform app.raise_error('HMT_TEN_TRONG', 'Nhập tên hiển thị.');
  end if;
  -- Luật: mã viết hoa, không dấu (chữ A-Z, số, gạch dưới; không bắt đầu bằng gạch dưới).
  if v_code !~ '^[A-Z0-9][A-Z0-9_]*$' then
    perform app.raise_error('HMT_MA_SAI_DANG', 'Mã chỉ gồm chữ viết hoa không dấu, số và gạch dưới, không bắt đầu bằng gạch dưới.');
  end if;
  -- Luật: mã không trùng trong danh mục (mã Ngừng cũng tính, vì mã không đổi và không xoá).
  if exists (select from app.catalog_item where catalog_code = p_catalog_code and code = v_code) then
    perform app.raise_error('HMT_MA_TRUNG', format('Mã %s đã có trong danh mục này.', v_code));
  end if;
  insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, linked_item_id)
  values (p_catalog_code, v_code, v_name,
          coalesce(p_sort_order,
                   (select coalesce(max(sort_order), 0) + 1 from app.catalog_item
                     where catalog_code = p_catalog_code and parent_id is not distinct from p_parent_id)),
          p_parent_id, p_linked_item_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Đổi chỗ một mục với mục kề (nút ▲▼ ở QT-07). Ai gọi: Admin. Đầu vào: id mục, hướng 'LEN' hoặc 'XUONG'.
-- Luật: đổi chỗ trong cùng danh mục và cùng cha (danh mục nhiều cấp); mục đầu bấm lên, mục cuối bấm xuống thì không làm gì;
-- danh mục hệ thống và danh mục chỉ xem không đổi thứ tự (Q-122, Q-110). Nếu hai mục đang trùng số thứ tự thì đánh số lại cả nhóm rồi đổi chỗ.
-- ---------------------------------------------------------------------------
create or replace function app.catalog_move_item(p_item_id uuid, p_direction text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item app.catalog_item%rowtype;
  v_cat app.catalog%rowtype;
  v_other app.catalog_item%rowtype;
  v_tmp integer;
begin
  perform app.assert_config_writer();
  if p_direction not in ('LEN', 'XUONG') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Hướng đổi thứ tự phải là LEN hoặc XUONG.');
  end if;
  select * into v_item from app.catalog_item where id = p_item_id;
  if v_item.id is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy mục danh mục.');
  end if;
  select * into v_cat from app.catalog where code = v_item.catalog_code;
  -- Luật Q-110, Q-122: danh mục chỉ xem hoặc danh mục hệ thống không đổi thứ tự trên màn hình.
  if v_cat.is_read_only then
    perform app.raise_error('HMT_DANH_MUC_CHI_XEM', format('Danh mục "%s" chỉ xem, không đổi thứ tự.', v_cat.name));
  end if;
  if v_cat.kind = 'HE_THONG' then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG', format('Danh mục "%s" chỉ đổi tên, không đổi thứ tự.', v_cat.name));
  end if;
  -- Mục kề theo thứ tự (sort_order, id) trong cùng danh mục và cùng cha.
  select * into v_other from app.catalog_item o
   where o.catalog_code = v_item.catalog_code and o.parent_id is not distinct from v_item.parent_id and o.id <> v_item.id
     and ((p_direction = 'LEN' and (o.sort_order, o.id) < (v_item.sort_order, v_item.id))
       or (p_direction = 'XUONG' and (o.sort_order, o.id) > (v_item.sort_order, v_item.id)))
   order by case when p_direction = 'LEN' then o.sort_order end desc, case when p_direction = 'LEN' then o.id end desc,
            case when p_direction = 'XUONG' then o.sort_order end, case when p_direction = 'XUONG' then o.id end
   limit 1;
  if v_other.id is null then
    return;
  end if;
  -- Hai mục trùng số thứ tự: đánh số lại cả nhóm theo (sort_order, id) rồi đọc lại hai mục.
  if v_other.sort_order = v_item.sort_order then
    update app.catalog_item c set sort_order = r.n
      from (select i.id, row_number() over (order by i.sort_order, i.id)::integer as n from app.catalog_item i
             where i.catalog_code = v_item.catalog_code and i.parent_id is not distinct from v_item.parent_id) r
     where c.id = r.id and c.sort_order is distinct from r.n;
    select * into v_item from app.catalog_item where id = p_item_id;
    select * into v_other from app.catalog_item where id = v_other.id;
  end if;
  v_tmp := v_item.sort_order;
  update app.catalog_item set sort_order = v_other.sort_order where id = v_item.id;
  update app.catalog_item set sort_order = v_tmp where id = v_other.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách danh mục gốc cho cột trái QT-06 (QT-07): mỗi danh mục gốc kèm các tầng con (vd Giai đoạn cơ hội kèm nhóm con).
-- Ai gọi: Admin (Quản trị · Xem). Đầu vào: từ khoá tên (trống thì lấy hết, tìm không dấu, không phân biệt hoa thường). Kết quả: mảng jsonb
-- {code, name, kind, is_read_only, description, levels: [{code, name, total, active}]}, theo sort_order. Chỉ đọc.
-- ---------------------------------------------------------------------------
create or replace function app.list_catalog_summary(p_q text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := app.fold_text(nullif(btrim(coalesce(p_q, '')), ''));
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được xem danh mục.');
  end if;
  return coalesce((
    with recursive tree as (
      select c.code as root_code, c.code, c.name, 0 as depth, c.sort_order
        from app.catalog c where c.parent_catalog is null
      union all
      select t.root_code, c.code, c.name, t.depth + 1, c.sort_order
        from app.catalog c join tree t on c.parent_catalog = t.code
    ),
    counts as (
      select i.catalog_code, count(*)::int as total, count(*) filter (where i.is_active)::int as active
        from app.catalog_item i group by i.catalog_code
    )
    select jsonb_agg(jsonb_build_object(
             'code', r.code, 'name', r.name, 'kind', r.kind, 'is_read_only', r.is_read_only, 'description', r.description,
             'levels', (select jsonb_agg(jsonb_build_object('code', t.code, 'name', t.name,
                                                            'total', coalesce(k.total, 0), 'active', coalesce(k.active, 0))
                                         order by t.depth, t.sort_order)
                          from tree t left join counts k on k.catalog_code = t.code where t.root_code = r.code))
           order by r.sort_order, r.code)
      from app.catalog r
     where r.parent_catalog is null
       and (v_q is null or app.fold_text(r.name) like '%' || v_q || '%')
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- Cây mục của một danh mục gốc cho bảng bên phải QT-07: các mục của danh mục gốc và của các tầng con, kèm cha.
-- Ai gọi: Admin (Quản trị · Xem). Đầu vào: mã danh mục gốc. Kết quả: {root: {code, name, kind, is_read_only, description},
-- levels: [{code, name}], items: [{id, catalog_code, code, name, sort_order, is_active, is_locked, parent_id}]}. Chỉ đọc.
-- Danh mục là dữ liệu cấu hình nhỏ (lớn nhất khoảng 160 dòng: Tỉnh, phường), nên trả cả cây một lần, không phân trang.
-- ---------------------------------------------------------------------------
create or replace function app.get_catalog_tree(p_root_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_root app.catalog%rowtype;
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được xem danh mục.');
  end if;
  select * into v_root from app.catalog where code = p_root_code and parent_catalog is null;
  if v_root.code is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy danh mục.');
  end if;
  return jsonb_build_object(
    'root', jsonb_build_object('code', v_root.code, 'name', v_root.name, 'kind', v_root.kind,
                               'is_read_only', v_root.is_read_only, 'description', v_root.description),
    'levels', (with recursive tree as (
                 select c.code, c.name, 0 as depth, c.sort_order from app.catalog c where c.code = v_root.code
                 union all
                 select c.code, c.name, t.depth + 1, c.sort_order from app.catalog c join tree t on c.parent_catalog = t.code)
               select jsonb_agg(jsonb_build_object('code', code, 'name', name) order by depth, sort_order) from tree),
    'items', coalesce((
      with recursive tree as (
        select c.code from app.catalog c where c.code = v_root.code
        union all
        select c.code from app.catalog c join tree t on c.parent_catalog = t.code)
      select jsonb_agg(jsonb_build_object('id', i.id, 'catalog_code', i.catalog_code, 'code', i.code, 'name', i.name,
                                          'sort_order', i.sort_order, 'is_active', i.is_active, 'is_locked', i.is_locked,
                                          'parent_id', i.parent_id)
                       order by i.sort_order, i.id)
        from app.catalog_item i where i.catalog_code in (select code from tree)
    ), '[]'::jsonb));
end;
$$;

revoke execute on function app.catalog_move_item(uuid, text), app.list_catalog_summary(text), app.get_catalog_tree(text) from public, anon;
grant execute on function app.catalog_move_item(uuid, text), app.list_catalog_summary(text), app.get_catalog_tree(text) to authenticated;
