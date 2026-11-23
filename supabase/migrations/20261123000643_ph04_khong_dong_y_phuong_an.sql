-- Code F (23/11/2026), thẻ PH-2 → PR-C, migration 643: cổng Phụ huynh, PH-04 «Không đồng ý phương án».
-- Luật: docs/spec/de-xuat-luat-aftersale.md (AS-02 luồng trạng thái, AS-03 mở lại, AS-07 hạn chụp lúc tạo), R-CS-06 (mở lại khiếu nại), GHI_CHU_CHO_CODE.md của gói Học tập, Phụ huynh (mục PH-04).
-- Làm gì: thêm nguồn tiếp nhận «Phụ huynh không đồng ý» và loại thông báo cùng tên; hàm app.ph_reject_proposal cho phụ huynh bấm «Không đồng ý» trên màn phương án.
-- Không tạo bảng phương án mới: «phương án» là kết quả xử lý của ticket đang ở Đã xử lý (chờ phụ huynh xác nhận).
select set_config('hmt.migration', 'on', false);

-- Danh mục hệ thống: nguồn ticket và loại thông báo mới.
insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values ('TICKET_CHANNEL', 'PH_KHONG_DONG_Y', 'Phụ huynh không đồng ý', 90, false),
       ('NOTIFICATION_KIND', 'PH_KHONG_DONG_Y', 'Phụ huynh không đồng ý phương án', 3, false)
on conflict (catalog_code, code) do nothing;

-- Chỉ mục: tìm ticket «theo dõi» đang mở của một ticket gốc (related_ticket_id đã có chỉ mục ticket_related_idx, đủ dùng); không thêm chỉ mục mới.

-- app.ph_reject_proposal(mã ticket gốc, lý do): phụ huynh «Không đồng ý» phương án đang chờ xác nhận.
-- Ai gọi: tài khoản phụ huynh (có mã PH), chỉ với ticket của chính phụ huynh đó. Đầu vào: id ticket đang ở Đã xử lý, lý do bắt buộc.
-- Kết quả: {id, code, reopened}: ticket theo dõi vừa tạo hoặc vừa mở lại.
-- Luật: công tắc AFTERSALE (AS-13); lý do bắt buộc; chỉ ticket của chính mình, đang Đã xử lý; «đã có» = ticket nguồn «Phụ huynh không đồng ý» cùng ticket gốc
-- (cùng học sinh, cùng đề xuất) chưa Đã huỷ: có thì mở lại (Đã xử lý hoặc Đã đóng trong hạn mở lại → Đang xử lý, AS-03) hoặc ghi thêm lý do, không có thì tạo mới
-- giao đội CSKH của cơ sở, hạn chụp lúc tạo (AS-07); báo Trưởng cơ sở. Không giới hạn số lần.
create or replace function app.ph_reject_proposal(p_ticket_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_parent_code text;
  v_parent_id uuid;
  s app.ticket;
  f app.ticket;
  v_resp_hours integer;
  v_res_hours integer;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_now timestamptz := now();
  v_reopened boolean := false;
begin
  -- Chỉ tài khoản phụ huynh còn dùng được (không khoá, không bị thu hồi phiên: app.current_user_ready, như các hàm cổng).
  select ua.parent_code into v_parent_code from app.user_account ua where ua.id = auth.uid() and (select app.current_user_ready());
  select p.id into v_parent_id from app.parent p where p.code = v_parent_code;
  if v_parent_id is null then
    perform app.raise_error('HMT_PH_KHONG_PHAI_PHU_HUYNH', 'Chỉ tài khoản phụ huynh mới dùng được chức năng này.');
  end if;
  -- Luật: lý do bắt buộc.
  if v_reason is null then
    perform app.raise_error('HMT_PH_THIEU_LY_DO', 'Quý phụ huynh vui lòng nhập lý do không đồng ý.');
  end if;
  select * into s from app.ticket where id = p_ticket_id for update;
  -- Luật: chỉ ticket của chính phụ huynh (không lộ ticket người khác: báo như không tìm thấy).
  if s.id is null or s.parent_id is distinct from v_parent_id then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đề nghị này.');
  end if;
  perform app.require_feature('AFTERSALE', s.branch_id);
  -- Luật: phải có phương án đang chờ xác nhận (ticket Đã xử lý).
  if s.status_code <> 'DA_XU_LY' then
    perform app.raise_error('HMT_PH_KHONG_CO_PHUONG_AN', 'Đề nghị này chưa có phương án chờ xác nhận.');
  end if;

  -- Luật «đã có»: ticket theo dõi cùng ticket gốc, nguồn Phụ huynh không đồng ý, chưa huỷ.
  select * into f from app.ticket
   where related_ticket_id = s.id and channel_code = 'PH_KHONG_DONG_Y' and status_code <> 'DA_HUY'
   order by created_at desc limit 1 for update;

  if f.id is not null then
    -- Mở lại (AS-03): Đã xử lý → Đang xử lý; Đã đóng chỉ trong số ngày cho phép.
    if f.status_code = 'DA_DONG'
       and (f.closed_at is null or v_now > f.closed_at + make_interval(days => app.get_setting_int('complaint_reopen_max_days')::integer)) then
      f := null; -- quá hạn mở lại: coi như chưa có, tạo mới ở dưới
    end if;
  end if;

  if f.id is not null then
    if f.status_code in ('DA_XU_LY', 'DA_DONG') then
      update app.ticket set status_code = 'DANG_XU_LY', resolved_at = null, closed_at = null where id = f.id;
      v_reopened := true;
    end if;
    insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status, note)
    values (f.id, f.branch_id, 'DOI_TRANG_THAI', f.status_code, case when v_reopened then 'DANG_XU_LY' else f.status_code end,
            'Phụ huynh không đồng ý phương án: ' || v_reason);
    v_id := f.id;
    v_code := f.code;
  else
    -- Tạo mới (AS-01, AS-07): cùng loại, nhóm con, học sinh với ticket gốc; hạn chụp lúc tạo.
    select r.response_hours into v_resp_hours from app.ticket_sla_rule r where r.ticket_type = s.ticket_type and r.priority_code = s.priority_code;
    v_res_hours := app.ticket_resolve_hours(s.ticket_type, s.priority_code, s.category_code);
    select code into v_branch_code from app.branch where id = s.branch_id;
    v_code := app.issue_document_number(s.ticket_type, v_branch_code);
    insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, team_code, parent_id,
                            student_id, class_id, enrollment_id, related_ticket_id, response_due_at, resolve_due_at)
    values (v_code, s.ticket_type, s.branch_id, left('Phụ huynh không đồng ý phương án ' || s.code, 200), -- allow-number: 200 là độ dài tối đa tiêu đề ticket
            v_reason, 'PH_KHONG_DONG_Y', s.category_code,
            s.priority_code, 'CSKH', v_parent_id, s.student_id, s.class_id, s.enrollment_id, s.id,
            v_now + make_interval(hours => v_resp_hours), v_now + make_interval(hours => v_res_hours))
    returning id into v_id;
    insert into app.ticket_event (ticket_id, branch_id, event_type, to_status, note)
    values (v_id, s.branch_id, 'TAO', 'MOI', 'Phụ huynh không đồng ý phương án: ' || v_reason);
  end if;

  -- Báo Trưởng cơ sở của cơ sở có ticket.
  insert into app.notification (user_id, kind, title, entity_id, actor_id)
  select ua.id, 'PH_KHONG_DONG_Y', 'Phụ huynh không đồng ý phương án của ' || s.code, v_id, auth.uid()
    from app.user_account ua
    join app.user_role ur on ur.user_id = ua.id and ur.is_active and ur.role_code = 'BRANCH_MANAGER'
   where ua.branch_id = s.branch_id and not ua.is_locked;

  return jsonb_build_object('id', v_id, 'code', v_code, 'reopened', v_reopened);
end;
$$;
revoke execute on function app.ph_reject_proposal(uuid, text) from public, anon;
grant execute on function app.ph_reject_proposal(uuid, text) to authenticated;

select set_config('hmt.migration', '', false);
