-- Migration 698 (Code C, 27/11/2026, C-27-05): người và lý do nhập thay chỉ trả cho người đọc được nhật ký nhập thay
-- (R-GIO-11; ghi chú Tester và ra-soat ở #814). app.session_done_info: lấy từ 20261127000692, chỉ thêm điều kiện lọc proxies.
-- Các trường khác (cách hoàn tất, cờ Thiếu nhận xét, điều còn thiếu) giữ cho mọi người xem được bản ghi buổi.

create or replace function app.session_done_info(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'XEM', true);
  return jsonb_build_object(
    'done_mode', s.done_mode,
    'done_by_name', (select u.display_name from app.user_account u where u.id = s.done_by),
    'done_reason', s.done_reason,
    'missing_review', s.done_missing_review,
    'missing', case when s.status_code = 'DA_CHOT' then to_jsonb(app.session_missing(s.id)) else '[]'::jsonb end,
    -- Nhật ký nhập thay theo chỉ mục (session_id, created_at); một buổi chỉ có vài dòng.
    -- Cùng phạm vi với chính sách session_proxy_entry_read (mig 688): chỉ Điểm danh · Duyệt toàn hệ thống hoặc đúng cơ sở mình.
    'proxies', coalesce((
      select jsonb_agg(jsonb_build_object('kind', p.kind, 'reason', p.reason, 'by_name', u.display_name, 'at', p.created_at)
             order by p.created_at)
        from app.session_proxy_entry p left join app.user_account u on u.id = p.created_by
       where p.session_id = s.id and app.can_see_branch_wide('ATTENDANCE', 'DUYET', s.branch_id)), '[]'::jsonb));
end;
$$;
