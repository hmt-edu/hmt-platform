-- Dữ liệu mẫu staging: buổi dạy HÔM NAY cho giáo viên (Code E, 24/11/2026; thẻ E-23-44). CAO: dữ liệu đào tạo (chỉ staging).
-- Vấn đề: lớp mẫu không có giáo viên, hai buổi đầu ở quá khứ, các buổi còn lại từ một tuần sau; nên cổng Giáo viên (GV-02 Lịch dạy) trống với tài khoản tập.
-- Làm gì: app.demo_make_teaching_today chọn một giáo viên đang dùng của cơ sở (người bấm nếu là giáo viên; không thì giáo viên đầu theo tên đăng nhập),
--   gán làm giáo viên các buổi chưa dạy của lớp Toán mẫu và dời buổi kế tiếp (buổi 3, Nháp) về HÔM NAY (giờ theo lịch lớp). Không có giáo viên thì bỏ qua và ghi notice.
-- Không đổi nhận xét chờ gửi (CS-16): bộ từ migration 666 đã có 1 nhận xét chờ gửi ở buổi Done; bài test 668 kiểm cả hai.
-- Luật an toàn: như 666 (khoá STAGING, chỉ từ hàm tạo bộ, hàm con không cấp cho giao diện).
select set_config('hmt.migration', 'on', false);

create or replace function app.demo_make_teaching_today(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_class uuid;
  v_teacher uuid;
  v_next uuid;
begin
  select c.id into v_class from app.class c
   where c.is_demo and c.status_code = 'DA_DUYET'
     and c.id in (select entity_id from app.demo_data_item where set_id = p_set_id and entity_type = 'CLASS')
   order by c.created_at limit 1;
  if v_class is null then
    return;
  end if;
  -- Giáo viên: người bấm nếu có vai Giáo viên đang dùng; không thì giáo viên đang dùng đầu tiên của cơ sở.
  select u.id into v_teacher
    from app.user_account u join app.user_role r on r.user_id = u.id and r.role_code = 'TEACHER' and r.is_active
   where u.branch_id = p_branch_id and not u.is_locked
   order by (u.id = auth.uid()) desc, u.login_name limit 1;
  if v_teacher is null then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Cơ sở chưa có giáo viên đang dùng.');
  end if;
  update app.class_session set teacher_id = v_teacher
   where class_id = v_class and status_code = 'NHAP' and session_date >= v_today;
  select s.id into v_next from app.class_session s
   where s.class_id = v_class and s.status_code = 'NHAP' and s.session_date > v_today
   order by s.session_date, s.session_no limit 1;
  if v_next is not null then
    update app.class_session set session_date = v_today, is_manual = true where id = v_next;
  end if;
end;
$$;
revoke all on function app.demo_make_teaching_today(uuid, uuid) from public, anon, authenticated;

create or replace function app.demo_make_p1(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_skipped text[] := '{}';
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, null);
  perform set_config('hmt.demo_sales', 'on', true);
  begin
    perform app.demo_make_student_test(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'phiếu kiểm tra'::text);
  end;
  begin
    perform app.demo_submit_receipt(p_set_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'phiếu thu chờ duyệt'::text);
  end;
  begin
    perform app.demo_make_waiting_enrollments(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'ghi danh chờ xếp lớp'::text);
  end;
  begin
    perform app.demo_make_hold_and_refund(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'bảo lưu và hoàn phí chờ duyệt'::text);
  end;
  begin
    perform app.demo_make_pending_review(p_set_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'nhận xét chờ gửi'::text);
  end;
  begin
    perform app.demo_make_teaching_today(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'buổi dạy hôm nay cho giáo viên'::text);
  end;
  if array_length(v_skipped, 1) is not null then
    update app.demo_data_set set notice = concat_ws(' ', notice, 'Đã bỏ qua: ' || array_to_string(v_skipped, ', ') || ' (thiếu danh mục, quyền hoặc công tắc).')
     where id = p_set_id;
  end if;
  perform set_config('hmt.demo_sales', '', true);
exception when others then
  perform set_config('hmt.demo_sales', '', true);
  raise;
end;
$$;
revoke all on function app.demo_make_p1(uuid, uuid) from public, anon, authenticated;

select set_config('hmt.migration', '', false);
