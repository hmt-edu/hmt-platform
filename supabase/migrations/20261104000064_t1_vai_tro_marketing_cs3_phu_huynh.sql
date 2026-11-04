-- T1 (Đ285 đến Đ290; spec 04 mục 14: R-V2-05, R-V2-08, R-V2-09, R-V2-10): vai trò Marketing, hồ sơ phụ huynh mọi cơ sở xem được,
-- CS3 thành cơ sở dạy học thường, hàm gợi ý tên đăng nhập.
-- Không đổi: quyền Xuất vẫn do ma trận quyền quyết định (R-V2-06); mặc định chỉ Admin có, anh cấp thêm trong màn Phân quyền.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Vai trò MARKETER, MARKETING_MANAGER, MARKETING (R-V2-09)
-- Làm gì: thêm ba vai trò, quyền giống SALES (tuyển sinh), phạm vi tất cả cơ sở. Anh chỉnh quyền sau trong màn Phân quyền.
-- ---------------------------------------------------------------------------
insert into app.role (code, name, default_scope, require_mfa, portals, view_only_portals, sort_order, legacy_ref) values
  ('MARKETER', 'Marketer', 'TOAN_HE_THONG', false, '{crm}', '{}', 10, null),
  ('MARKETING_MANAGER', 'Trưởng nhóm Marketing', 'TOAN_HE_THONG', false, '{crm}', '{}', 11, null),
  ('MARKETING', 'Marketing', 'TOAN_HE_THONG', false, '{crm}', '{}', 12, null);

-- Luật R-V2-09: quyền như SALES, phạm vi cơ sở của SALES (CO_SO) đổi thành tất cả cơ sở; phạm vi khác giữ nguyên.
select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', r.role, 'module', p.module_code, 'action', p.action_code,
                                        'scope', case when p.scope_code = 'CO_SO' then 'TOAN_HE_THONG' else p.scope_code end))
     from app.permission p
    cross join (values ('MARKETER'), ('MARKETING_MANAGER'), ('MARKETING')) as r(role)
    where p.role_code = 'SALES' and p.is_active),
  'Đ286, R-V2-09: thêm MARKETER, MARKETING_MANAGER, MARKETING; quyền như SALES, phạm vi tất cả cơ sở (anh chỉnh sau)');

-- ---------------------------------------------------------------------------
-- 2. Hồ sơ phụ huynh: mọi cơ sở xem được (R-V2-05, R-CRM-26)
-- Làm gì: ai có quyền xem phụ huynh (phạm vi bất kỳ) thì xem được mọi hồ sơ phụ huynh, không giới hạn theo cơ sở.
-- Sửa và gộp vẫn theo quyền và phạm vi của ma trận.
-- ---------------------------------------------------------------------------
drop policy parent_read on app.parent;
create policy parent_read on app.parent for select to authenticated
  using ((select app.permission_scope('PARENT', 'XEM')) is not null);

-- ---------------------------------------------------------------------------
-- 3. CS3 là cơ sở dạy học thường (R-V2-10): có lớp, phòng, học sinh; khối từ 1 đến 12.
-- Làm gì: bỏ cờ văn phòng của CS3. Ô chọn cơ sở và công tắc tính năng lấy danh sách cơ sở dạy học nên CS3 hiện ra ở đó.
-- Luật không đổi cho cờ: cơ sở đang có phòng học vẫn không đổi thành văn phòng được.
-- ---------------------------------------------------------------------------
update app.branch set is_office = false where code = 'CS3';
comment on table app.branch is 'Cơ sở (danh mục mở). CS3 từ 04/11/2026 là cơ sở dạy học thường (Đ286); không đánh số lại.';

-- ---------------------------------------------------------------------------
-- 4. app.suggest_username(họ tên): gợi ý tên đăng nhập (R-V2-08)
-- Làm gì: tên + chữ cái đầu của họ và tên đệm, không dấu, chữ thường (Nguyễn Văn An thành annv); trùng thì thêm số: annv1, annv2.
-- Ai gọi: hàm tạo tài khoản và nạp Người dùng (nội bộ, không mở cho API). Đầu vào: họ tên đầy đủ. Kết quả: tên chưa ai dùng.
-- Luật: tên đăng nhập không đổi được sau khi tạo (đã có ở `tg_user_account_fixed`).
-- Lỗi: HMT_THIEU_TEN khi họ tên không có chữ nào.
-- ---------------------------------------------------------------------------
create or replace function app.suggest_username(p_full_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_words text[];
  v_base text;
  v_name text;
  v_n integer := 0;
begin
  -- Luật: bỏ dấu, chữ thường, chỉ giữ chữ cái a-z và khoảng trắng.
  v_words := regexp_split_to_array(btrim(regexp_replace(app.fold_text(p_full_name), '[^a-z ]', '', 'g')), '\s+');
  if v_words is null or v_words[1] is null or v_words[1] = '' then
    perform app.raise_error('HMT_THIEU_TEN', 'Họ tên không có chữ nào để tạo tên đăng nhập.');
  end if;

  -- Luật: tên (từ cuối) + chữ cái đầu của họ và tên đệm theo thứ tự.
  v_base := v_words[cardinality(v_words)] || coalesce((
    select string_agg(left(w, 1), '' order by ord)
      from unnest(v_words[1:cardinality(v_words) - 1]) with ordinality as t(w, ord)), '');

  -- Luật: trùng thì thêm số tăng dần.
  v_name := v_base;
  while exists (select from app.user_account where login_name = v_name) loop
    v_n := v_n + 1;
    v_name := v_base || v_n;
  end loop;
  return v_name;
end;
$$;
comment on function app.suggest_username(text) is
  'Gợi ý tên đăng nhập: tên + chữ cái đầu họ và tên đệm, không dấu; trùng thì thêm số (R-V2-08). Nội bộ.';
revoke execute on function app.suggest_username(text) from public, anon, authenticated;

select set_config('hmt.migration', '', false);
