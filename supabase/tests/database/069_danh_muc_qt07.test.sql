-- QT-06, QT-07 Danh mục (migration 084; Q-110, Q-116, Q-122; R-V2-42, R-V2-43): thêm mục có câu lỗi, đổi chỗ ▲▼, danh mục chỉ xem, nhóm con khoá chỉ đổi tên,
-- danh sách danh mục và cây mục. Mỗi luật có ca đúng và ca bị chặn; Admin trong phạm vi, Sale ngoài phạm vi.
-- Mỗi luật có ca đúng và ca bị chặn; vai đọc, ghi trong và ngoài phạm vi. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Phiếu Thu', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u)$$);
-- Trợ giúp: id mục theo (danh mục, mã); trạng thái, tên, thứ tự đọc bằng quyền chủ DB.
select pg_temp.sudo($$create function pg_temp.iid(p_cat text, p_code text) returns uuid language sql stable security definer as
  'select id from app.catalog_item where catalog_code = p_cat and code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.act(p_cat text, p_code text) returns boolean language sql stable security definer as
  'select is_active from app.catalog_item where catalog_code = p_cat and code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.nm(p_cat text, p_code text) returns text language sql stable security definer as
  'select name from app.catalog_item where catalog_code = p_cat and code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.so(p_cat text, p_code text) returns integer language sql stable security definer as
  'select sort_order from app.catalog_item where catalog_code = p_cat and code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.seq(p_cat text, p_parent uuid) returns text language sql stable security definer as
  'select string_agg(code, '','' order by sort_order, id) from app.catalog_item where catalog_code = p_cat and parent_id is not distinct from p_parent'$$);
select pg_temp.sudo($$grant execute on function pg_temp.iid(text, text), pg_temp.act(text, text), pg_temp.nm(text, text), pg_temp.so(text, text), pg_temp.seq(text, uuid) to public$$);

set local role authenticated;

-- ================= (1) Danh sách danh mục (QT-06) và cây mục (QT-07): chỉ Admin đọc =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_typeof(app.list_catalog_summary()), 'array', 'QT-06: danh sách danh mục trả mảng');
select ok(jsonb_array_length(app.list_catalog_summary()) > 20, 'QT-06: có nhiều danh mục gốc');
select is((select count(*)::int from jsonb_array_elements(app.list_catalog_summary('giai doan co hoi')) e where e ->> 'code' = 'OPP_STAGE'), 1,
  'QT-06: tìm không dấu theo tên "giai doan co hoi" ra Giai đoạn cơ hội');
select is((select (e -> 'levels' -> 1 ->> 'total')::int from jsonb_array_elements(app.list_catalog_summary()) e where e ->> 'code' = 'OPP_STAGE'), 62,
  'QT-06: Giai đoạn cơ hội kèm 62 nhóm con (60 đang dùng, 2 Ngừng)');
select is((select (e -> 'levels' -> 1 ->> 'active')::int from jsonb_array_elements(app.list_catalog_summary()) e where e ->> 'code' = 'OPP_STAGE'), 60,
  'QT-06: 60 nhóm con đang dùng');
select is((select e ->> 'is_read_only' from jsonb_array_elements(app.list_catalog_summary()) e where e ->> 'code' = 'PROVINCE'), 'true', 'Q-110: Tỉnh, phường là danh mục chỉ xem');
select is((select count(*)::int from jsonb_array_elements(app.list_catalog_summary()) e where e ->> 'code' in ('SOURCE', 'WARD', 'OPP_SUBSTAGE')), 0,
  'QT-06: danh mục con (Nguồn, Phường, Nhóm con) không tách thành mục gốc, nằm trong tầng của danh mục gốc');
select is(jsonb_array_length(app.get_catalog_tree('SOURCE_TYPE') -> 'levels'), 3, 'QT-07: Nguồn lead có ba tầng (loại nguồn, nguồn, kênh)');
select ok(jsonb_array_length(app.get_catalog_tree('SOURCE_TYPE') -> 'items') > 20, 'QT-07: cây Nguồn lead trả mục của cả ba tầng');
select is(pg_temp.err($$select app.get_catalog_tree('SOURCE')$$), 'HMT_DANH_MUC_KHONG_CO', 'QT-07: danh mục con không mở như danh mục gốc');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_catalog_summary()$$), 'HMT_KHONG_CO_QUYEN', 'Sale không xem được danh sách danh mục');
select is(pg_temp.err($$select app.get_catalog_tree('SOURCE_TYPE')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không xem được cây mục');

-- ================= (2) Thêm mục: câu lỗi tiếng Việt, ca đúng, ngoài phạm vi =================
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'video', 'Gọi video')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không thêm được mục danh mục');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'video', 'Gọi video')$$), null, 'Admin thêm mục vào danh mục mở');
select is(pg_temp.nm('ACTIVITY_TYPE', 'VIDEO'), 'Gọi video', 'Mã nhập chữ thường được đổi thành chữ hoa');
select is(pg_temp.so('ACTIVITY_TYPE', 'VIDEO'), 7, 'Mục mới đặt cuối (sau 6 mục có sẵn)');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'a b', 'Sai dạng')$$), 'HMT_MA_SAI_DANG', 'Mã có khoảng trắng bị chặn');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', '_ab', 'Sai dạng')$$), 'HMT_MA_SAI_DANG', 'Mã bắt đầu bằng gạch dưới bị chặn');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'MỚI', 'Có dấu')$$), 'HMT_MA_SAI_DANG', 'Mã có dấu bị chặn');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'VIDEO', 'Trùng mã')$$), 'HMT_MA_TRUNG', 'Mã trùng trong danh mục bị chặn');
select ok(pg_temp.msg($$select app.catalog_add_item('ACTIVITY_TYPE', 'VIDEO', 'Trùng mã')$$) like 'Mã VIDEO đã có%', 'Câu báo mã trùng nêu đúng mã');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'TRONG', '   ')$$), 'HMT_TEN_TRONG', 'Tên trống bị chặn');
-- Danh mục nhiều cấp: thêm kênh vào nguồn (mục cha đúng tầng).
select is(pg_temp.err($$select app.catalog_add_item('SOURCE_CHANNEL', 'KENH_THU', 'Kênh thử', null, pg_temp.iid('SOURCE', 'FACEBOOK_ADS'))$$), null, 'Admin thêm kênh vào một nguồn');
select is(pg_temp.err($$select app.catalog_add_item('SOURCE_CHANNEL', 'KENH_SAI', 'Kênh sai cha', null, pg_temp.iid('SOURCE_TYPE', 'MARKETING'))$$), 'HMT_MUC_CHA_SAI', 'Kênh gắn nhầm vào loại nguồn bị chặn (sai tầng cha)');

-- ================= (3) Đổi chỗ bằng ▲▼ (chỉ danh mục mở, cùng cấp, cùng cha) =================
select is(pg_temp.seq('ACTIVITY_TYPE', null), 'GOI_DIEN,ZALO,EMAIL,GAP_TRUC_TIEP,SMS,NHAC_THU_TIEN,VIDEO', 'Thứ tự ban đầu của Loại hoạt động');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'ZALO'), 'LEN')$$), null, '▲ trên mục thứ hai');
select is(pg_temp.seq('ACTIVITY_TYPE', null), 'ZALO,GOI_DIEN,EMAIL,GAP_TRUC_TIEP,SMS,NHAC_THU_TIEN,VIDEO', '▲: đổi chỗ với mục kề trên');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'GOI_DIEN'), 'XUONG')$$), null, '▼ trên mục thứ hai');
select is(pg_temp.seq('ACTIVITY_TYPE', null), 'ZALO,EMAIL,GOI_DIEN,GAP_TRUC_TIEP,SMS,NHAC_THU_TIEN,VIDEO', '▼: đổi chỗ với mục kề dưới');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'ZALO'), 'LEN')$$), null, '▲ ở mục đầu không lỗi');
select is(pg_temp.seq('ACTIVITY_TYPE', null), 'ZALO,EMAIL,GOI_DIEN,GAP_TRUC_TIEP,SMS,NHAC_THU_TIEN,VIDEO', '▲ ở mục đầu: không đổi gì');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'VIDEO'), 'XUONG')$$), null, '▼ ở mục cuối không lỗi');
select is(pg_temp.seq('ACTIVITY_TYPE', null), 'ZALO,EMAIL,GOI_DIEN,GAP_TRUC_TIEP,SMS,NHAC_THU_TIEN,VIDEO', '▼ ở mục cuối: không đổi gì');
-- Hai mục trùng số thứ tự: vẫn đổi chỗ được.
select pg_temp.sudo($$update app.catalog_item set sort_order = 3 where catalog_code = 'ACTIVITY_TYPE' and code in ('EMAIL', 'GOI_DIEN')$$);
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'GOI_DIEN'), 'LEN')$$), null, 'Trùng số thứ tự: ▲ không lỗi');
select ok(pg_temp.so('ACTIVITY_TYPE', 'GOI_DIEN') < pg_temp.so('ACTIVITY_TYPE', 'EMAIL'), 'Trùng số thứ tự: sau ▲ mục được bấm đứng trước mục kề');
-- Danh mục nhiều cấp: đổi chỗ trong cùng cha, không động tới nhóm khác.
select pg_temp.sudo($$update app.catalog_item set sort_order = 100 where catalog_code = 'SOURCE_CHANNEL'$$);
select pg_temp.sudo($$update app.catalog_item set sort_order = 101 where catalog_code = 'SOURCE_CHANNEL' and code = 'KENH_THU'$$);
select is(pg_temp.seq('SOURCE_CHANNEL', pg_temp.iid('SOURCE', 'FACEBOOK_ADS')) like '%,KENH_THU', true, 'Kênh thử đang đứng cuối trong nguồn Facebook Ads');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('SOURCE_CHANNEL', 'KENH_THU'), 'LEN')$$), null, 'Kênh: ▲ trong cùng nguồn');
select is(pg_temp.seq('SOURCE_CHANNEL', pg_temp.iid('SOURCE', 'FACEBOOK_ADS')) like '%,KENH_THU', false, 'Kênh: ▲ đưa kênh lên một bậc trong cùng nguồn (không còn đứng cuối)');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'GOI_DIEN'), 'LÊN')$$), 'HMT_THAM_SO_SAI', 'Hướng đổi thứ tự sai bị chặn');
select is(pg_temp.err($$select app.catalog_move_item('00000000-0000-0000-0000-000000000000', 'LEN')$$), 'HMT_DANH_MUC_KHONG_CO', 'Mục không có thì báo không tìm thấy');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('ACTIVITY_TYPE', 'GOI_DIEN'), 'LEN')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không đổi thứ tự được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ================= (4) Q-122: nhóm con giai đoạn khoá chỉ đổi tên =================
select is(pg_temp.err($$select app.catalog_rename_item(pg_temp.iid('OPP_SUBSTAGE', 'L5C'), 'Tên mới thử')$$), null, 'Q-122: đổi tên nhóm con giai đoạn cơ hội được');
select is(pg_temp.nm('OPP_SUBSTAGE', 'L5C'), 'Tên mới thử', 'Q-122: tên mới đã lưu');
select is(pg_temp.err($$select app.catalog_add_item('OPP_SUBSTAGE', 'L9X', 'Nhóm con thêm', null, pg_temp.iid('OPP_STAGE', 'L5'))$$), 'HMT_DANH_MUC_HE_THONG', 'Q-122: không thêm nhóm con ở màn hình');
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('OPP_SUBSTAGE', 'L5C'), false)$$), 'HMT_DANH_MUC_HE_THONG', 'Q-122: không Ngừng nhóm con ở màn hình');
select is(pg_temp.err($$select app.catalog_move_item(pg_temp.iid('OPP_SUBSTAGE', 'L5C'), 'LEN')$$), 'HMT_DANH_MUC_HE_THONG', 'Q-122: không đổi thứ tự nhóm con ở màn hình');
select is(pg_temp.err($$select app.catalog_rename_item(pg_temp.iid('LEAD_SUBSTAGE', 'C4A'), 'Tên lead thử')$$), null, 'Q-122: đổi tên nhóm con giai đoạn lead được');
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('LEAD_SUBSTAGE', 'C4A'), false)$$), 'HMT_DANH_MUC_HE_THONG', 'Q-122: không Ngừng nhóm con giai đoạn lead ở màn hình');
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('OPP_STAGE', 'L1'), false)$$), 'HMT_DANH_MUC_HE_THONG', 'Giai đoạn cha vẫn khoá: không Ngừng được');
-- Migration vẫn thêm, Ngừng được nhóm con (như L5P, L5Q ở migration 067): mô phỏng bằng cờ migration của phiên, quyền chủ DB.
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.catalog_item set is_active = false where catalog_code = 'OPP_SUBSTAGE' and code = 'L5C' and not is_locked$$);
select pg_temp.sudo($$insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
  select 'OPP_SUBSTAGE', 'L5ZZ', 'Nhóm con do migration thêm', 99, id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5'$$);
select is(pg_temp.nm('OPP_SUBSTAGE', 'L5ZZ'), 'Nhóm con do migration thêm', 'Q-122: migration vẫn thêm được nhóm con');
select pg_temp.sudo($$select set_config('hmt.migration', '', true)$$);

-- ================= (5) Q-110: Tỉnh, phường chỉ xem =================
select is(pg_temp.err($$select app.catalog_rename_item((select id from app.catalog_item where catalog_code = 'PROVINCE' order by code limit 1), 'Tên thử')$$), 'HMT_DANH_MUC_CHI_XEM', 'Q-110: không đổi tên tỉnh');
select is(pg_temp.err($$select app.catalog_add_item('PROVINCE', 'TINHTHU', 'Tỉnh thử')$$), 'HMT_DANH_MUC_CHI_XEM', 'Q-110: không thêm tỉnh');
select is(pg_temp.err($$select app.catalog_set_item_active((select id from app.catalog_item where catalog_code = 'WARD' order by code limit 1), false)$$), 'HMT_DANH_MUC_CHI_XEM', 'Q-110: không Ngừng phường');
select is(pg_temp.err($$select app.catalog_move_item((select id from app.catalog_item where catalog_code = 'WARD' order by code limit 1), 'LEN')$$), 'HMT_DANH_MUC_CHI_XEM', 'Q-110: không đổi thứ tự phường');
select is(pg_temp.err($$select app.get_catalog_tree('PROVINCE')$$), null, 'Q-110: vẫn xem được cây Tỉnh, phường');
select is(jsonb_array_length(app.get_catalog_tree('PROVINCE') -> 'levels'), 2, 'Q-110: cây Tỉnh, phường có hai tầng');

-- ================= (6) Ngừng, Dùng lại; R-V2-43: ngừng mục cha không đổi trạng thái kênh con =================
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('ACTIVITY_TYPE', 'VIDEO'), false)$$), null, 'Ngừng mục ở danh mục mở');
select is(pg_temp.act('ACTIVITY_TYPE', 'VIDEO'), false, 'Mục đã Ngừng');
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('ACTIVITY_TYPE', 'VIDEO'), true)$$), null, 'Dùng lại mục đã Ngừng');
select is(pg_temp.act('ACTIVITY_TYPE', 'VIDEO'), true, 'Mục dùng lại được');
select pg_temp.sudo($$update app.catalog_item set is_active = false where catalog_code = 'SOURCE_CHANNEL' and code = 'KENH_THU'$$);
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('SOURCE', 'FACEBOOK_ADS'), false)$$), null, 'R-V2-43: ngừng mục cha (nguồn) có kênh con');
select is(pg_temp.act('SOURCE', 'FACEBOOK_ADS'), false, 'R-V2-43: mục cha đã Ngừng');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE_CHANNEL' and parent_id = pg_temp.iid('SOURCE', 'FACEBOOK_ADS') and is_active), 4,
  'R-V2-43: trạng thái từng kênh con giữ nguyên (4 kênh đang dùng của Facebook Ads vẫn đang dùng; kênh thử Ngừng từ trước vẫn Ngừng)');
select is(pg_temp.act('SOURCE_CHANNEL', 'KENH_THU'), false, 'R-V2-43: kênh con đã Ngừng từ trước vẫn Ngừng');
select is(pg_temp.err($$select app.catalog_set_item_active(pg_temp.iid('SOURCE', 'FACEBOOK_ADS'), true)$$), null, 'R-V2-43: Dùng lại mục cha');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE_CHANNEL' and parent_id = pg_temp.iid('SOURCE', 'FACEBOOK_ADS') and is_active), 4,
  'R-V2-43: dùng lại mục cha thì các kênh đang dùng vẫn đang dùng (kênh Ngừng riêng không tự bật)');

select * from finish();
rollback;
