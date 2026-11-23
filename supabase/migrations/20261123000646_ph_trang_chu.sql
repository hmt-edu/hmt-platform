-- Code F (24/11/2026), thẻ PH-3 → PH-01 Trang chủ cổng Phụ huynh, migration 646.
-- Một lần gọi cho cả màn (quy ước hiệu năng): các con, việc cần chú ý, buổi gần nhất, nhận xét mới, giờ còn. Chỉ xem.
-- Dựa trên app.portal_student_ids, portal_parent_ids, portal_low_hours_threshold (migration 637, 645). KHÔNG mở RLS cho vai PARENT.
-- Luật: docs/ke-hoach/cong-hoc-tap-phu-huynh.md mục 3; R-GD-13 (ngưỡng giờ còn thấp); R-DD-02 (ô của giáo viên quyết định điểm danh chính thức).

select set_config('hmt.migration', 'on', false);

-- 1. app.ph_home(): trang chủ phụ huynh.
-- Ai gọi: phụ huynh đăng nhập cổng /ph (các hồ sơ cùng SĐT, một tài khoản thấy nhiều con). Người khác, tài khoản khoá, phiên bị thu hồi: danh sách rỗng.
-- Kết quả: {children: [{id, full_name, classes: [mã lớp], hours_left, is_low, projected_end,
--           last_session: {date, class_code, status_name} hoặc null, new_reviews: số nhận xét trong 14 ngày}],
--           attention: [{kind: GIO_THAP|DE_NGHI, student_id, student_name, hours_left, projected_end, ticket_id, title, step, updated_at}]}.
-- Luật: giờ còn, ngày hết dự kiến, giờ còn thấp tính đúng như ph_hours_orders (một nguồn công thức); buổi gần nhất = buổi đã Done có điểm danh của em;
-- trạng thái buổi lấy theo ô giáo viên (R-DD-02), chưa có thì để trống; nhận xét mới = nhận xét có nội dung của buổi trong khoảng gần đây;
-- việc cần chú ý: giờ còn thấp, và đề nghị Đề nghị/Khiếu nại chưa Đóng (bước 1 đến 3).
create or replace function app.ph_home()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_children jsonb := '[]'::jsonb;
  v_attention jsonb := '[]'::jsonb;
  v_ticket jsonb;
  c record;
  v_h jsonb;
  v_last jsonb;
  v_new integer;
begin
  -- Không phải phụ huynh hoặc phiên không còn hiệu lực: không có gì để hiện.
  if (select count(*) from app.portal_parent_ids()) = 0 then
    return jsonb_build_object('children', v_children, 'attention', v_attention);
  end if;

  for c in
    select s.id, s.full_name, s.code
      from app.student s
     where s.id in (select app.portal_student_ids())
       and app.feature_enabled('HOC_TAP', s.branch_id)
     order by s.full_name, s.code
  loop
    -- Giờ còn (cùng công thức ph_hours_orders).
    v_h := app.ph_hours_orders(c.id);
    -- Buổi gần nhất đã Done có điểm danh.
    select jsonb_build_object('date', x.session_date, 'class_code', x.class_code, 'status_name', x.status_name) into v_last
      from (select cs.session_date, cl.code as class_code,
                   (select i.name from app.catalog_item i where i.catalog_code = 'ATTENDANCE_STATUS' and i.code = a.teacher_status_code) as status_name
              from app.session_attendance a
              join app.class_session cs on cs.id = a.session_id and cs.status_code = 'DONE'
              join app.class cl on cl.id = cs.class_id
             where a.student_id = c.id and a.is_active
             order by cs.session_date desc, cs.start_time desc limit 1) x;
    -- Nhận xét mới: nhận xét có nội dung trong 14 ngày gần đây.
    select count(*) into v_new
      from app.session_attendance a
      join app.class_session cs on cs.id = a.session_id and cs.session_date >= v_today - 14 -- allow-number: cửa sổ «mới» theo khung PH01
      join app.session_student_review r on r.attendance_id = a.id
     where a.student_id = c.id and a.is_active and nullif(btrim(coalesce(r.teacher_comment, '')), '') is not null;

    v_children := v_children || jsonb_build_object(
      'id', c.id, 'full_name', c.full_name,
      'classes', (select coalesce(jsonb_agg(cl.code order by cl.code), '[]'::jsonb)
                    from app.enrollment e
                    join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                    join app.class cl on cl.id = ec.class_id
                   where e.student_id = c.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')),
      'hours_left', v_h -> 'hours_left', 'is_low', v_h -> 'is_low', 'projected_end', v_h -> 'projected_end',
      'last_session', v_last, 'new_reviews', v_new);

    if (v_h ->> 'is_low')::boolean and (v_h ->> 'hours_left')::numeric > 0 then
      v_attention := v_attention || jsonb_build_object('kind', 'GIO_THAP', 'student_id', c.id, 'student_name', c.full_name,
                       'hours_left', v_h -> 'hours_left', 'projected_end', v_h -> 'projected_end');
    end if;
  end loop;

  -- Đề nghị, khiếu nại chưa đóng (bước 1 đến 3), mới cập nhật trước.
  for v_ticket in
    select jsonb_build_object('kind', 'DE_NGHI', 'ticket_id', t.id, 'title', t.title, 'student_id', t.student_id,
             'step', case t.status_code when 'DA_XU_LY' then 3 when 'MOI' then 1 else 2 end, -- allow-number: ba bước đầu của theo dõi 4 bước
             'updated_at', t.updated_at)
      from app.ticket t
     where t.parent_id in (select app.portal_parent_ids()) and t.ticket_type in ('DN', 'KN')
       and t.status_code not in ('DA_DONG', 'DA_HUY')
       and (t.student_id is null or t.student_id in (select app.portal_student_ids()))
     order by t.updated_at desc limit 5 -- allow-number: trần số việc hiện ở trang chủ
  loop
    v_attention := v_attention || v_ticket;
  end loop;

  return jsonb_build_object('children', v_children, 'attention', v_attention);
end;
$$;
comment on function app.ph_home() is 'PH-01: trang chủ phụ huynh (các con, việc cần chú ý). Chỉ xem.';

revoke execute on function app.ph_home() from public, anon;
grant execute on function app.ph_home() to authenticated;

select set_config('hmt.migration', '', false);
