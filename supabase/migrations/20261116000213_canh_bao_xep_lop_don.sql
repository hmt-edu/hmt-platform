-- Migration 213 (Code D, 16/11/2026): Q1 (SAU-17-11; Chat chốt 05:35 16/11): ghi danh tạo từ đơn mà lớp hoặc ngày vào lớp không còn hợp lệ
-- thì vẫn rơi vào Chờ xếp lớp (không đổi hành vi, không chặn thu tiền) nhưng phải CÓ CẢNH BÁO:
--   (1) cột app.enrollment.placement_warning_code: mã lý do (mã lỗi HMT_ của kiểm lớp), xoá khi ghi danh được xếp lớp;
--   (2) sự kiện CANH_BAO_XEP_LOP trong lịch sử đơn (giữ nguyên trạng thái đơn).
-- Luật: R-GD-06, R-GD-08, R-GD-15. Thay hàm app.create_enrollments_for_order (bản migration 101), chỉ thêm phần cảnh báo.

select set_config('hmt.migration', 'on', false);
alter table app.sales_order_event drop constraint sales_order_event_event_code_check;
alter table app.sales_order_event add constraint sales_order_event_event_code_check
  check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY', 'SUA', 'CANH_BAO_XEP_LOP'));
select set_config('hmt.migration', '', false);

alter table app.enrollment add column placement_warning_code text;
comment on column app.enrollment.placement_warning_code is 'Mã lý do ghi danh từ đơn chưa xếp được lớp dù đơn có chọn lớp (Q1); xoá khi được xếp lớp. Chỉ để cảnh báo.';

-- Xếp lớp được (mở dòng xếp lớp) thì xoá cảnh báo.
create or replace function app.tg_enrollment_class_clear_warning()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app.enrollment set placement_warning_code = null where id = new.enrollment_id and placement_warning_code is not null;
  return new;
end;
$$;
create trigger enrollment_class_clear_warning after insert on app.enrollment_class
  for each row execute function app.tg_enrollment_class_clear_warning();

create or replace function app.create_enrollments_for_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  l record;
  v_id uuid;
  v_created integer := 0;
  v_queued integer := 0;
  v_ok boolean;
  v_class app.class;
  v_err text;
  v_hint text;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null or o.status_code <> 'DA_DUYET' then
    return jsonb_build_object('created', 0, 'queued', 0);
  end if;
  -- Luật R-TIEN-20: chưa đủ cọc thì chưa tạo ghi danh.
  if coalesce((select sum(amount) from app.money_in where order_id = o.id), 0) < app.get_setting_int('deposit_min_amount', o.branch_id) then
    return jsonb_build_object('created', 0, 'queued', 0);
  end if;
  for l in select sl.*, p.subject_code as pkg_subject from app.sales_order_line sl
             left join app.sales_package p on p.id = sl.package_id
            where sl.order_id = o.id and sl.is_live and sl.line_kind = 'ENROL' and sl.unit_code = 'GIO' and sl.student_id is not null
              and not exists (select from app.enrollment e where e.order_line_id = sl.id)
            order by sl.line_no loop
    insert into app.enrollment (code, order_id, order_line_id, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code,
                                purchased_hours, gifted_hours, start_date)
    values (app.issue_enrollment_code(), o.id, l.id, l.student_id, o.parent_id, o.branch_id, l.package_id, l.pkg_subject, l.delivery_mode_code,
            l.quantity, l.gifted_quantity, l.enrol_start_date)
    returning id into v_id;
    v_created := v_created + 1;
    -- Có lớp: kiểm lần cuối rồi xếp (Đã xếp lớp); không thì Chờ xếp lớp.
    if l.class_id is not null then
      v_ok := true;
      begin
        perform app.assert_class_fits(l.class_id, l.package_id, o.branch_id, 'Ghi danh');
        perform app.assert_enrol_start_date(l.class_id, l.enrol_start_date, 'Ghi danh');
        perform app.assert_no_time_clash(l.student_id, l.class_id, l.enrol_start_date, v_id, 'Ghi danh');
      exception when others then
        v_ok := false;
        get stacked diagnostics v_err = message_text, v_hint = pg_exception_hint;
      end;
      if v_ok then
        select * into v_class from app.class where id = l.class_id;
        insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (v_id, l.class_id, v_class.branch_id, l.enrol_start_date);
        update app.enrollment set status_code = 'DA_XEP_LOP' where id = v_id;
      else
        v_queued := v_queued + 1;
        -- Q1 (Chat chốt 16/11): không đổi hành vi (ghi danh vẫn Chờ xếp lớp, không chặn thu tiền) nhưng KHÔNG im lặng:
        -- cờ trên ghi danh và dòng cảnh báo trong lịch sử đơn để vận hành và sale thấy mà xếp lớp tay.
        update app.enrollment set placement_warning_code = coalesce(nullif(v_hint, ''), 'KHONG_XEP_DUOC') where id = v_id;
        insert into app.sales_order_event (order_id, branch_id, event_code, from_status, to_status, note)
        values (o.id, o.branch_id, 'CANH_BAO_XEP_LOP', o.status_code, o.status_code,
                'Dòng ' || l.line_no || ': chưa xếp được lớp, ghi danh vào hàng chờ xếp lớp. ' || coalesce(v_err, ''));
      end if;
    end if;
  end loop;
  perform app.sync_enrollment_hours(o.id);
  return jsonb_build_object('created', v_created, 'queued', v_queued);
end;
$$;
