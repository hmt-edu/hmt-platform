-- BH-09 Cho học trước, đóng tiền sau (Code C, 16/11/2026). Luật R-GD-12: quản lý cơ sở bật trên đơn ĐÃ DUYỆT, CHƯA THU TIỀN → ghi danh tạo sớm, quỹ giờ được âm tối đa
-- max_sessions_ahead buổi (mặc định 2; kiểm ở điểm danh trừ giờ, cột enrollment.pay_later_enabled đã có từ migration 102). Vượt hạn mức thì em bị loại khỏi danh sách các buổi sau
-- (R-GIO-03). Khi thu tiền: các buổi đã học vẫn tính là đã học và trừ vào giờ được cấp (sync_enrollment_hours giữ nguyên).
-- SỐ 250: phải lớn hơn 213 (migration 213 cũng thay ràng buộc event_code và hàm tạo ghi danh nên phải chạy trước); ngoài dải C 180-209 vì dải đã hết (ghi ở PR). Việc chạm quỹ giờ và ghi danh: cờ tắt mặc định (tham số pay_later_toggle_enabled, ghi đè theo cơ sở); Chat bật khi Tester đạt.
--  (1) Bảng app.order_pay_later: trạng thái bật/tắt theo đơn (đơn đã duyệt bị khoá nên không thêm cột vào sales_order). Chỉ ghi qua hàm; có nhật ký chuẩn.
--  (2) Hàm app.set_order_pay_later(đơn, bật, ghi chú): Admin hoặc Trưởng cơ sở (Đơn hàng · Duyệt, trong cơ sở); bật cần đơn Đã duyệt và CHƯA có khoản tiền vào; tắt cần mọi ghi danh còn quỹ giờ không âm.
--  (3) app.create_enrollments_for_order: đơn đã bật thì không đòi đủ cọc (R-TIEN-20) và đặt pay_later_enabled cho ghi danh mới (thân giữ nguyên bản migration 213, chỉ thêm hai chỗ).
--  (4) Dòng lịch sử đơn «CHO_HOC_TRUOC».

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('pay_later_toggle_enabled', 'Cho phép bật «cho học trước, đóng tiền sau» trên đơn', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-GD-12',
   'Tắt: không bật được cho học trước ở cơ sở. Bật: quản lý cơ sở bật trên đơn đã duyệt chưa thu tiền; quỹ giờ được âm tối đa «Cho học trước tối đa» buổi.');

alter table app.sales_order_event drop constraint sales_order_event_event_code_check;
alter table app.sales_order_event add constraint sales_order_event_event_code_check
  check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY', 'SUA', 'CANH_BAO_XEP_LOP', 'CHO_HOC_TRUOC'));

-- (1) Trạng thái cho học trước của đơn.
create table app.order_pay_later (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references app.sales_order (id),
  branch_id uuid not null references app.branch (id),
  enabled boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.order_pay_later is 'Cho học trước, đóng tiền sau theo đơn (R-GD-12). Một dòng mỗi đơn; tắt là enabled = false, không xoá.';
-- Chỉ mục (lý do): order_id đã có chỉ mục duy nhất; branch_id cho chính sách đọc theo cơ sở.
create index order_pay_later_branch_idx on app.order_pay_later (branch_id);
select app.apply_standard('app.order_pay_later');
alter table app.order_pay_later enable row level security;
revoke all on app.order_pay_later from public, anon, authenticated;
grant select on app.order_pay_later to authenticated;
create policy order_pay_later_read on app.order_pay_later for select to authenticated
  using ((select app.can_see_branch('SALES_ORDER', 'XEM', branch_id)));

-- (3) Tạo ghi danh cho đơn (thân giữ nguyên migration 213, thêm: đơn cho học trước không đòi đủ cọc, ghi danh mới đặt pay_later_enabled).
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
            l.quantity, l.gifted_quantity, l.enrol_start_date)
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

-- (2) app.set_order_pay_later(đơn, bật, ghi chú): bật hoặc tắt «cho học trước» trên đơn. Ai gọi: Đơn hàng · Duyệt trong cơ sở của đơn (Admin, Trưởng cơ sở).
-- Kết quả: {order_id, enabled, enrollments (số ghi danh đã tạo hoặc cập nhật)}. Lỗi có mã: HMT_TINH_NANG_TAT, HMT_KHONG_CO_QUYEN, HMT_SAI_TRANG_THAI, HMT_DON_DA_THU, HMT_QUY_GIO_AM.
create or replace function app.set_order_pay_later(p_order_id uuid, p_enabled boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_n integer := 0;
  v_created jsonb;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  -- Luật R-GD-12: chỉ quản lý cơ sở (Đơn hàng · Duyệt trong cơ sở; Admin làm thay) bật, tắt.
  perform app.assert_can('SALES_ORDER', 'DUYET', o.branch_id);
  -- Công tắc: phân hệ Bán hàng và tham số pay_later_toggle_enabled (mặc định TẮT).
  perform app.require_feature('BAN_HANG', o.branch_id);
  if not app.get_setting_bool('pay_later_toggle_enabled', o.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Cho học trước, đóng tiền sau chưa được bật cho cơ sở này.');
  end if;
  if p_enabled then
    -- Luật R-GD-12: bật trên đơn đã duyệt, chưa thu tiền.
    if o.status_code <> 'DA_DUYET' then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ bật cho học trước trên đơn đã duyệt.');
    end if;
    if exists (select from app.money_in where order_id = o.id) then
      perform app.raise_error('HMT_DON_DA_THU', 'Đơn đã có tiền vào, không bật cho học trước (ghi danh tạo theo tiền đã thu).');
    end if;
    insert into app.order_pay_later (order_id, branch_id, enabled, note)
    values (o.id, o.branch_id, true, nullif(btrim(coalesce(p_note, '')), ''))
    on conflict (order_id) do update set enabled = true, note = excluded.note;
    -- Tạo ghi danh sớm (hàm nội bộ đã cho qua kiểm cọc vì đơn đã bật) rồi đặt cờ cho cả ghi danh đã có.
    v_created := app.create_enrollments_for_order(o.id);
    update app.enrollment set pay_later_enabled = true where order_id = o.id and not pay_later_enabled;
    get diagnostics v_n = row_count;
    v_n := v_n + coalesce((v_created ->> 'created')::integer, 0);
  else
    -- Luật: không tắt khi đã có ghi danh dùng quá quỹ giờ (số dư âm); thu tiền trước.
    if exists (select from app.enrollment e where e.order_id = o.id and app.enrollment_hours_balance(e.id) < 0) then
      perform app.raise_error('HMT_QUY_GIO_AM', 'Có ghi danh đã học trước (quỹ giờ âm): thu tiền trước khi tắt cho học trước.');
    end if;
    update app.order_pay_later set enabled = false, note = nullif(btrim(coalesce(p_note, '')), '') where order_id = o.id;
    update app.enrollment set pay_later_enabled = false where order_id = o.id and pay_later_enabled;
    get diagnostics v_n = row_count;
  end if;
  insert into app.sales_order_event (order_id, branch_id, event_code, from_status, to_status, note)
  values (o.id, o.branch_id, 'CHO_HOC_TRUOC', o.status_code, o.status_code,
          case when p_enabled then 'Bật cho học trước, đóng tiền sau.' else 'Tắt cho học trước, đóng tiền sau.' end
          || coalesce(' ' || nullif(btrim(coalesce(p_note, '')), ''), ''));
  return jsonb_build_object('order_id', o.id, 'enabled', p_enabled, 'enrollments', v_n);
end;
$$;
revoke execute on function app.set_order_pay_later(uuid, boolean, text) from public, anon;
grant execute on function app.set_order_pay_later(uuid, boolean, text) to authenticated;
