-- G1 (Soát S14, Chat duyệt 19/11/2026, docs/de-xuat/g1-quy-gio-khi-chot.md): chốt danh sách phải tính giờ đã «giữ chỗ» ở các buổi Đã chốt chưa Done của cùng ghi danh.
-- Lỗi: build_session_roster kiểm quỹ theo sổ giờ, mà dòng trừ chỉ ghi lúc Done nên em còn 1,5 giờ vào được cả buổi 1 và buổi 2; buổi 1 Done trừ hết, buổi 2 báo HMT_QUY_GIO_AM và KẸT ở Đã chốt cho cả lớp.
-- Luật: R-GIO-03 (không đủ giờ thì không vào danh sách), R-GIO-01 (trừ khi Done, không đổi), R-V2-18 (kiểm tra trừ như buổi Chính, nên cũng giữ chỗ), R-BUOI-03 (học bù, bổ trợ, kiểm tra bù không trừ nên không giữ chỗ).
-- Không đổi app.deduct_session_hours (vẫn chặn âm như lớp bảo vệ cuối). Không viết lại dữ liệu cũ: chỉ áp cho lần chốt từ khi có migration.

-- app.enrollment_hours_reserved(ghi danh, buổi đang chốt) -> giờ đang «giữ chỗ»: tổng giờ của các buổi KHÁC mà ghi danh nằm trong danh sách (đang hoạt động, không học thử),
-- buổi trừ giờ (app.session_deducts_hours), đang Đã chốt (chưa Done, chưa huỷ), và diễn ra TRƯỚC buổi đang chốt (ngày, giờ bắt đầu, rồi mã buổi) để chốt buổi sớm sau buổi muộn không đẩy em khỏi buổi sớm.
create or replace function app.enrollment_hours_reserved(p_enrollment_id uuid, p_session_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(app.session_hours(cs.id)), 0)
    from app.session_attendance sa
    join app.class_session cs on cs.id = sa.session_id
    join app.class_session me on me.id = p_session_id
   where sa.enrollment_id = p_enrollment_id and sa.is_active and not sa.is_trial
     and cs.id <> p_session_id and cs.status_code = 'DA_CHOT' and app.session_deducts_hours(cs)
     and (cs.session_date, cs.start_time, cs.id) < (me.session_date, me.start_time, me.id);
$$;
revoke execute on function app.enrollment_hours_reserved(uuid, uuid) from public, anon, authenticated;

-- app.build_session_roster: giữ nguyên bản ở migration 303, chỉ đổi điều kiện đủ giờ (một dòng G1).
create or replace function app.build_session_roster(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_hours numeric := app.session_hours(p_session_id);
  v_deducts boolean;
  v_ahead integer := app.get_setting_int('max_sessions_ahead', (select branch_id from app.class_session where id = p_session_id));
  r record;
  v_pick uuid;
  v_reason text;
  v_n integer := 0;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.status_code <> 'NHAP' then
    perform app.raise_error('HMT_BUOI_KHONG_CHOT_DUOC', 'Chỉ chốt danh sách buổi đang ở Nháp.');
  end if;
  v_deducts := app.session_deducts_hours(s);
  for r in
    select e.student_id,
           (array_agg(e.id order by ec.start_date, e.created_at, e.id)) as enr_ids
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
     where ec.class_id = s.class_id and (ec.end_date is null or ec.end_date >= s.session_date)
       -- Luật R-GIO-02: ghi danh sinh sau ngày buổi không lọt vào danh sách.
       and (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date <= s.session_date
       -- Luật R-BUOI-05, R-BUOI-03 (BUOI-09, BUOI-07): buổi học bổ trợ và học bù chỉ có các em yếu được chọn trong yêu cầu (không phải cả lớp).
       and (not (s.type_code in ('BO_TRO', 'HOC_BU') or s.no_charge)
            or e.student_id in (select rs.student_id from app.session_request_student rs
                                  join app.session_request q on q.id = rs.request_id where q.created_session_id = s.id and rs.is_active))
     group by e.student_id
  loop
    v_pick := null;
    v_reason := null;
    -- Mỗi em chọn một ghi danh đủ điều kiện, ưu tiên ghi danh vào lớp sớm nhất (R-GIO-04).
    select e.id into v_pick
      from unnest(r.enr_ids) with ordinality as t (eid, ord)
      join app.enrollment e on e.id = t.eid
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = s.class_id
     where ec.start_date <= s.session_date and (ec.end_date is null or ec.end_date >= s.session_date)
       and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
       and (not v_deducts
            -- G1: trừ giờ đã giữ chỗ ở các buổi Đã chốt chưa Done diễn ra trước (R-GIO-03).
            or app.enrollment_hours_balance(e.id) - app.enrollment_hours_reserved(e.id, s.id) + case when e.pay_later_enabled then v_ahead * v_hours else 0 end >= v_hours)
     order by t.ord
     limit 1;
    if v_pick is null then
      -- Lý do của ghi danh đầu tiên (Luật R-GIO-03).
      select case
               when ec.start_date > s.session_date then 'CHUA_TOI_NGAY_VAO'
               when e.status_code = 'BAO_LUU' then 'BAO_LUU'
               when e.status_code in ('DUNG', 'HOAN_PHI', 'HOAN_THANH', 'CHUYEN_LOP') then 'KET_THUC'
               else 'HET_GIO'
             end into v_reason
        from unnest(r.enr_ids) with ordinality as t (eid, ord)
        join app.enrollment e on e.id = t.eid
        join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = s.class_id
       order by t.ord limit 1;
      insert into app.session_attendance (session_id, class_id, branch_id, student_id, is_active, excluded_reason)
      values (s.id, s.class_id, s.branch_id, r.student_id, false, v_reason);
    else
      insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id)
      values (s.id, s.class_id, s.branch_id, r.student_id, v_pick);
      v_n := v_n + 1;
    end if;
  end loop;
  update app.class_session set status_code = 'DA_CHOT' where id = s.id;
  return v_n;
end;
$$;
