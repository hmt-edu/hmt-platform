-- B-26-03 PR-DB2 (2/2), RỦI RO CAO (giờ học): DÒNG TẶNG ĐƯỢC CẤP GIỜ (anh Trường chốt H, 26/11; sửa R-TIEN-21).
-- Dòng tặng không có tiền để chia: cấp toàn bộ giờ như giờ tặng (CAP_TANG) khi đơn thu đủ phần có thu tiền.
-- Hoàn tác phiếu thu làm đơn không còn đủ tiền thì sổ giờ ghi dòng ngược (sync_enrollment_hours, R-GD-04).
-- Giữ nguyên: đơn tổng 0 đồng (chỉ gồm dòng tặng) chưa cấp giờ (chờ anh quyết).

-- Lấy từ 20261110000101_d1b_ghi_danh_so_gio.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.enrollment_target_hours(p_order_line_id uuid, p_kind text)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_kind = 'CAP_MUA' then
             case when l.line_total = 0 or l.is_gift_line then 0
                  else round(l.quantity * least(coalesce(a.paid, 0), l.line_total)::numeric / l.line_total, 2) end -- allow-number: làm tròn 2 chữ số thập phân của giờ (numeric(6,2))
           else
             case when o.total_amount > 0 and coalesce(op.paid, 0) >= o.total_amount
                  then l.gifted_quantity + case when l.is_gift_line then l.quantity else 0 end else 0 end
         end
    from app.sales_order_line l
    join app.sales_order o on o.id = l.order_id
    left join lateral (select sum(m.amount) paid from app.money_in_allocation m where m.order_line_id = l.id) a on true
    left join lateral (select sum(m.amount) paid from app.money_in m where m.order_id = o.id) op on true
   where l.id = p_order_line_id;
$$;

-- Lấy từ 20261116000250_bh09_cho_hoc_truoc.sql; chỉ đổi phần luật dòng tặng (B-26-03).
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
  v_pay_later boolean;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null or o.status_code <> 'DA_DUYET' then
    return jsonb_build_object('created', 0, 'queued', 0);
  end if;
  -- Luật R-GD-12 (BH-09): đơn được quản lý cơ sở bật «cho học trước, đóng tiền sau» thì tạo ghi danh sớm, không cần đủ cọc.
  v_pay_later := exists (select from app.order_pay_later where order_id = o.id and enabled);
  -- Luật R-TIEN-20: chưa đủ cọc thì chưa tạo ghi danh (trừ đơn cho học trước, R-GD-12).
  if not v_pay_later
     and coalesce((select sum(amount) from app.money_in where order_id = o.id), 0) < app.get_setting_int('deposit_min_amount', o.branch_id) then
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
            -- Dòng tặng: toàn bộ giờ là giờ tặng, không có giờ mua.
            case when l.is_gift_line then 0 else l.quantity end,
            l.gifted_quantity + case when l.is_gift_line then l.quantity else 0 end, l.enrol_start_date)
    returning id into v_id;
    v_created := v_created + 1;
    -- Ghi danh của đơn cho học trước: quỹ giờ được âm tới hạn mức max_sessions_ahead buổi (điểm danh trừ giờ kiểm hạn mức).
    if v_pay_later then
      update app.enrollment set pay_later_enabled = true where id = v_id;
    end if;
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

