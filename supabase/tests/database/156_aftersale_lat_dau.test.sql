-- Aftersale lát đầu (migration 156, 157): cấu hình, tạo ticket, mã, hạn SLA, luồng 7 trạng thái, quyền, RLS, danh sách, Kanban. Dữ liệu giả.
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
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

-- ================= Cấu hình (migration 156) =================
select is((select count(*)::int from app.ticket_category where kind = 'SUBGROUP' and ticket_type = 'DN'), 21, 'Đề nghị có 21 nhóm con nạp sẵn');
select is((select count(*)::int from app.ticket_category where kind = 'SUBGROUP' and ticket_type = 'GV' and nature_code = 'HO_TRO'), 15, 'Ticket giáo viên: 15 nhóm con mang tính chất Cần hỗ trợ (gắn sẵn, giáo viên không chọn)');
select is((select count(*)::int from app.ticket_category where kind = 'SUBGROUP' and ticket_type = 'GV' and nature_code is null), 0, 'Mọi nhóm con của ticket giáo viên đều có tính chất');
select is((select count(*)::int from app.ticket_sla_rule), 12, 'Bảng hạn xử lý có 12 dòng (3 loại × 4 mức độ)');
select is((select resolve_hours from app.ticket_sla_rule where ticket_type = 'KN' and priority_code = 'KHAN'), 24, 'Khiếu nại Khẩn: xử lý xong 1 ngày (R-CS-08)');
select is((select count(*)::int from app.catalog_item where catalog_code = 'TICKET_STATUS'), 7, 'Có 7 trạng thái ticket');
select is((select enabled from app.feature_flag f join app.branch b on b.id = f.branch_id where f.module_code = 'AFTERSALE' and b.code = 'CS5'), null, 'Phân hệ Aftersale chưa bật cho cơ sở nào (không có dòng công tắc)');

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');

-- ================= Công tắc phân hệ =================
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'))$$), 'HMT_TINH_NANG_TAT', 'Chặn: phân hệ Aftersale tắt ở cơ sở thì không tạo ticket');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Tạo ticket =================
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));
select alike((select j ->> 'code' from t1), 'KN-CS5-____-0001', 'Mã khiếu nại KN-CS5-YYMM-0001 (AS-01)');
select is((select priority_code from app.ticket where code = (select j ->> 'code' from t1)), 'KHAN', 'Nhóm con Bắt nạt: mức độ mặc định Khẩn (AS-08)');
select is((select resolve_due_at - created_at from app.ticket where code = (select j ->> 'code' from t1)), interval '24 hours', 'Khiếu nại Khẩn: hạn xử lý 24 giờ chụp lúc tạo (AS-07)');
select is((select response_due_at - created_at from app.ticket where code = (select j ->> 'code' from t1)), interval '2 hours', 'Khiếu nại Khẩn: hạn phản hồi đầu 2 giờ (R-CS-08)');
select is((select status_code from app.ticket where code = (select j ->> 'code' from t1)), 'MOI', 'Ticket mới ở trạng thái Mới');
select is((select (app.create_ticket(pg_temp.mk('KN', 'KN_02_02')) ->> 'code')), (select 'KN-CS5-' || to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'YYMM') || '-0002'), 'Số thứ tự liên tục theo cơ sở và tháng, không nhảy số');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('DN', 'DN_01_03'))$$), 'HMT_TICKET_THIEU_HOC_SINH', 'Chặn: đề nghị có nghiệp vụ (Chuyển lớp cùng môn) bắt buộc học sinh (AS-10)');
create temp table hp (id uuid);
grant all on hp to public;
insert into hp select (app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501')))) ->> 'id')::uuid;
select is((select resolve_due_at - created_at from app.ticket where id = (select id from hp)), interval '168 hours', 'Hoàn học phí: hạn riêng nhóm con 7 ngày đè bảng loại × mức độ (AS-07)');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_99_99'))$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: nhóm con không có');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('DN', 'KN_02_02'))$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: nhóm con thuộc loại ticket khác');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_02_02', '{"title":""}'))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thiếu tiêu đề');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_02_02', '{"parent_id":null}'))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: đề nghị, khiếu nại thiếu phụ huynh (người gửi)');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_02_02', '{"channel_code":"KHONG_CO"}'))$$) is not null, true, 'Chặn: kênh không có trong danh mục');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('GV', 'GV_01_01'))$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: CSKH không tạo được ticket giáo viên (AS-05)');

-- ================= Giáo viên (AS-05, AS-09) =================
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
-- Từ migration 501 (R-GV-13) giáo viên chỉ đọc học sinh trong lớp mình; lấy id học sinh bằng hàm quyền chủ DB để bài kiểm luật ticket không phụ thuộc phạm vi đọc.
select pg_temp.sudo($$create function pg_temp.hs_id() returns uuid language sql stable security definer as 'select id from app.student where code = ''HSAS501'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.hs_id() to public$$);
select is(pg_temp.err($$select app.create_ticket(jsonb_build_object('ticket_type', 'GV', 'title', 'Giả', 'description', 'Giả', 'channel_code', 'GIAO_VIEN_BAO', 'category_code', 'GV_01_01'))$$), 'HMT_TICKET_THIEU_HOC_SINH', 'Chặn: ticket giáo viên "học kém" bắt buộc học sinh (AS-05)');
select is(pg_temp.err($$select app.create_ticket(jsonb_build_object('ticket_type', 'GV', 'title', 'Giả', 'description', 'Giả', 'channel_code', 'GIAO_VIEN_BAO', 'category_code', 'GV_01_01', 'student_id', pg_temp.hs_id()))$$), 'HMT_TICKET_THIEU_LOP', 'Chặn: ticket giáo viên "học kém" bắt buộc cả lớp (AS-05)');
create temp table t2 (j jsonb);
grant all on t2 to public;
insert into t2 select app.create_ticket(jsonb_build_object('ticket_type', 'GV', 'title', 'Giả', 'description', 'Giả', 'channel_code', 'GIAO_VIEN_BAO', 'category_code', 'GV_02_01'));
select alike((select j ->> 'code' from t2), 'GV-CS5-____-0001', 'Giáo viên tạo ticket giáo viên: mã GV-CS5-YYMM-0001');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'))$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: giáo viên không tạo khiếu nại (chỉ ticket giáo viên)');
select is((select (app.list_tickets('{}'::jsonb) ->> 'total')::int), 1, 'Giáo viên chỉ thấy ticket mình tạo (RLS Được phân công)');
select is(pg_temp.err($$select app.assign_ticket((select id from app.ticket where ticket_type = 'GV' limit 1), 'CSKH', (select id from u where key = 'cskh5'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không giao, không xử lý ticket (chỉ tạo, xem)');
select pg_temp.claims(pg_temp.uid('gv5b'), 'aal1');
select is((select (app.list_tickets('{}'::jsonb) ->> 'total')::int), 0, 'Giáo viên khác không thấy ticket của giáo viên này');

-- ================= Cơ sở khác =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select (app.list_tickets('{}'::jsonb) ->> 'total')::int), 0, 'CSKH cơ sở khác không thấy ticket CS5 (RLS theo cơ sở)');
select is(pg_temp.err($$select app.assign_ticket((select id from app.ticket where ticket_type = 'KN' limit 1), 'CSKH', (select id from u where key = 'cskh5'))$$) is not null, true, 'Chặn: CSKH cơ sở khác không giao ticket CS5');

-- ================= Luồng trạng thái (AS-02, AS-03, AS-04, AS-07) =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table kn (id uuid);
grant all on kn to public;
insert into kn select id from app.ticket where code = (select j ->> 'code' from t1);
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DANG_XU_LY')$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: Mới không sang Đang xử lý thẳng (phải qua Đã giao)');
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DA_GIAO')$$), 'HMT_TICKET_CHUA_GIAO', 'Chặn: Đã giao cần đội và người phụ trách');
select is(pg_temp.err($$select app.assign_ticket((select id from kn), 'KHONG_CO', (select id from u where key = 'cskh5'))$$) is not null, true, 'Chặn: đội không có trong danh mục');
select is(pg_temp.err($$select app.assign_ticket((select id from kn), 'CSKH', (select id from u where key = 'cskh1'))$$) is not null, true, 'Chặn: người phụ trách khác cơ sở');
select lives_ok($$select app.assign_ticket((select id from kn), 'CSKH', (select id from u where key = 'cskh5'))$$, 'Giao ticket cho CSKH cùng cơ sở');
select is((select status_code from app.ticket where id = (select id from kn)), 'DA_GIAO', 'Giao xong: Mới thành Đã giao');
select lives_ok($$select app.change_ticket_status((select id from kn), 'DANG_XU_LY')$$, 'Đã giao sang Đang xử lý');
select isnt((select first_response_at from app.ticket where id = (select id from kn)), null, 'Lần đầu Đang xử lý: ghi thời điểm phản hồi đầu');
select lives_ok($$select app.change_ticket_status((select id from kn), 'CHO_THONG_TIN', 'Chờ phụ huynh gửi ảnh')$$, 'Đang xử lý sang Chờ thông tin');
select pg_temp.sudo($$update app.ticket set paused_at = now() - interval '5 hours', resolve_due_at = now() + interval '10 hours' where id = (select id from kn)$$);
select lives_ok($$select app.change_ticket_status((select id from kn), 'DANG_XU_LY')$$, 'Chờ thông tin về Đang xử lý');
select ok((select resolve_due_at from app.ticket where id = (select id from kn)) > now() + interval '14 hours 59 minutes', 'Ra khỏi Chờ thông tin: hạn xử lý dời đúng thời gian đã chờ 5 giờ (AS-07)');
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DA_XU_LY')$$), 'HMT_TICKET_THIEU_KET_QUA', 'Chặn: Đã xử lý cần kết quả');
select lives_ok($$select app.change_ticket_status((select id from kn), 'DA_XU_LY', null, null, 'Đã xin lỗi phụ huynh, đổi giáo viên')$$, 'Đã xử lý kèm kết quả');
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DA_DONG')$$), 'HMT_TICKET_THIEU_HAI_LONG', 'Chặn: đóng khiếu nại cần mức hài lòng 1 đến 5 (AS-04)');
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DA_DONG', null, 6)$$), 'HMT_TICKET_THIEU_HAI_LONG', 'Chặn: mức hài lòng 6 ngoài thang');
select lives_ok($$select app.change_ticket_status((select id from kn), 'DA_DONG', null, 4)$$, 'Đóng khiếu nại với mức hài lòng 4');
select is((select satisfaction::int from app.ticket where id = (select id from kn)), 4, 'Mức hài lòng được ghi');
select pg_temp.sudo($$update app.ticket set closed_at = now() - interval '8 days' where id = (select id from kn)$$);
select is(pg_temp.err($$select app.change_ticket_status((select id from kn), 'DANG_XU_LY')$$), 'HMT_TICKET_QUA_HAN_MO_LAI', 'Chặn: mở lại sau quá 7 ngày kể từ lúc đóng (AS-03)');
select pg_temp.sudo($$update app.ticket set closed_at = now() - interval '2 days' where id = (select id from kn)$$);
select lives_ok($$select app.change_ticket_status((select id from kn), 'DANG_XU_LY')$$, 'Mở lại trong 7 ngày');
select is((select closed_at from app.ticket where id = (select id from kn)), null, 'Mở lại: bỏ thời điểm đóng');
select is((select count(*)::int from app.ticket_event where ticket_id = (select id from kn) and event_type = 'DOI_TRANG_THAI'), 6, 'Nhật ký ghi từng lần đổi trạng thái (sáu lần, chưa tính lần giao)');
select is(pg_temp.err($$select pg_temp.sudo('update app.ticket_event set note = ''x''')$$), 'HMT_NHAT_KY_CHI_THEM', 'Chặn: nhật ký ticket chỉ thêm dòng');

-- Huỷ cần lý do; đóng ticket có nghiệp vụ cần ghi chú làm tay.
create temp table dn (id uuid);
grant all on dn to public;
insert into dn select (app.create_ticket(pg_temp.mk('DN', 'DN_01_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501')))) ->> 'id')::uuid;
select is(pg_temp.err($$select app.change_ticket_status((select id from dn), 'DA_HUY')$$), 'HMT_TICKET_THIEU_LY_DO', 'Chặn: huỷ ticket cần lý do');
select pg_temp.sudo($$update app.ticket set status_code = 'DA_XU_LY', resolution = 'Xong', resolved_at = now() where id = (select id from dn)$$);
select is(pg_temp.err($$select app.change_ticket_status((select id from dn), 'DA_DONG')$$), 'HMT_TICKET_THIEU_GHI_CHU', 'Chặn: đóng ticket Bảo lưu (có nghiệp vụ, chưa có phiếu) cần ghi chú làm tay (AS-03)');
select lives_ok($$select app.change_ticket_status((select id from dn), 'DA_DONG', 'Làm tay: đã bảo lưu trên ghi danh')$$, 'Đóng ticket có nghiệp vụ kèm ghi chú làm tay');

-- ================= Danh sách, hạn, Kanban (AS-07) =================
select pg_temp.sudo($$update app.ticket set resolve_due_at = now() - interval '1 hour' where id = (select id from kn)$$);
select is((select (app.list_tickets('{"sla_state":"QUA_HAN"}'::jsonb) ->> 'total')::int), 1, 'Bộ lọc Quá hạn: ticket quá hạn xử lý');
select pg_temp.sudo($$update app.ticket set resolved_at = now() - interval '4 days', status_code = 'DA_XU_LY' where id = (select id from kn)$$);
select is((select (app.list_tickets('{"sla_state":"CHO_DONG"}'::jsonb) ->> 'total')::int), 1, 'Bộ lọc Chờ đóng: Đã xử lý quá 3 ngày chưa đóng');
select is((select (app.list_tickets('{"ticket_type":"DN"}'::jsonb) ->> 'total')::int), 2, 'Lọc theo loại Đề nghị');
select is((select jsonb_array_length(app.list_tickets('{}'::jsonb, 1, 0) -> 'rows')), 1, 'Phân trang: số dòng theo yêu cầu');
select is((select (app.list_tickets('{}'::jsonb, 1, 0) ->> 'total')::int), 5, 'Phân trang: tổng số ticket cơ sở (kể cả ticket giáo viên)');
select is((select (app.list_tickets('{"q":"Tiêu đề giả"}'::jsonb) ->> 'total')::int), 4, 'Tìm theo tiêu đề');
select is((select (app.list_tickets('{"mine":true}'::jsonb) ->> 'total')::int), 4, 'Ticket của tôi: tôi tạo hoặc tôi phụ trách');
select is((select (app.list_tickets('{"q":"Phụ huynh giả ticket"}'::jsonb) ->> 'total')::int), 0, 'Tìm theo tên phụ huynh không dùng (chỉ mã, tiêu đề)');
select is((select jsonb_array_length(app.ticket_board('{}'::jsonb, 20))), 7, 'Kanban: đủ 7 cột trạng thái, một lần gọi');
select is((select (c ->> 'total')::int from jsonb_array_elements(app.ticket_board('{}'::jsonb, 20)) c where c ->> 'status_code' = 'DA_XU_LY'), 1, 'Kanban: tổng cột Đã xử lý đúng');
select is((select r ->> 'sender_name' is not null from jsonb_array_elements(app.list_tickets('{}'::jsonb) -> 'rows') r limit 1), true, 'Danh sách có tên người gửi');

select * from finish();
rollback;
