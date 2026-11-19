-- C30 (CS-09, canvas CSN06b_gia_han): thêm vào tuỳ chọn biểu mẫu phiếu (get_task_form_options, bản migration 350) ghi danh đang Bảo lưu và danh sách bảo lưu đang chạy, để tạo phiếu Gia hạn bảo lưu (R-GD-09).
-- Chỉ đọc; chỉ thêm khoá `holds` và trạng thái BAO_LUU vào danh sách ghi danh. Giao diện lọc: Bảo lưu mới chỉ cho ghi danh chưa bảo lưu; Gia hạn chỉ cho ghi danh có bản đang chạy.
create or replace function app.get_task_form_options(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  return jsonb_build_object(
    -- Ghi danh của học sinh gắn ticket, cùng cơ sở (đúng điều kiện create_ticket_task kiểm).
    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'code', e.code, 'status_code', e.status_code, 'subject_code', e.subject_code,
               'class_id', ec.class_id, 'class_code', c.code,
               'remaining_hours', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::numeric(6, 2))
             order by e.code)
        from app.enrollment e
        left join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
        left join app.class c on c.id = ec.class_id
       where e.student_id = t.student_id and e.branch_id = t.branch_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')), '[]'::jsonb),
    -- C30: bảo lưu đang chạy của học sinh (để chọn khi Gia hạn bảo lưu, R-GD-09); hàm áp dụng kiểm lại bản này đang chạy và đúng ghi danh.
    'holds', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'enrollment_id', h.enrollment_id, 'start_date', h.start_date, 'end_date', h.end_date) order by h.end_date)
                         from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id
                        where e.student_id = t.student_id and h.branch_id = t.branch_id and h.status_code = 'DANG_BAO_LUU'), '[]'::jsonb),
    'hold_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'HOLD_REASON' and i.is_active), '[]'::jsonb),
    'transfer_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'TRANSFER_REASON' and i.is_active), '[]'::jsonb),
    -- Lớp mới: lớp đã duyệt cùng cơ sở, còn chỗ; giao diện lọc theo môn của ghi danh. Hàm áp dụng kiểm lại trùng lớp, hết chỗ, trùng giờ.
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_code', c.subject_code, 'seats_left', app.class_seats_left(c.id),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date)
                                       from (select x.session_date, x.session_no from app.class_session x
                                              where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
                                              order by x.session_date limit 8) u), '[]'::jsonb)) -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
             order by c.code)
        from app.class c
       where c.branch_id = t.branch_id and c.status_code = 'DA_DUYET' and coalesce(app.class_seats_left(c.id), 1) > 0), '[]'::jsonb)
  );
end;
$$;
revoke all on function app.get_task_form_options(uuid) from public, anon;
grant execute on function app.get_task_form_options(uuid) to authenticated;
