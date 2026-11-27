-- Migration 692 (Code C, 27/11/2026, C-27-04, giao diện DD2): đọc thông tin Done của một buổi cho BUOI-02.
-- app.session_done_info: cách hoàn tất, người bấm, lý do, cờ Thiếu nhận xét, mọi điều còn thiếu và các lượt nhập thay
-- (R-GIO-06, 09, 11, 12). Ai gọi: người xem được bản ghi buổi (quyền SESSION · Xem phía vận hành, như app.session_record).
-- Vào: buổi. Ra: {done_mode, done_by_name, done_reason, missing_review, missing: [câu], proxies: [{kind, reason, by_name, at}]}.

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
    'proxies', coalesce((
      select jsonb_agg(jsonb_build_object('kind', p.kind, 'reason', p.reason, 'by_name', u.display_name, 'at', p.created_at)
             order by p.created_at)
        from app.session_proxy_entry p left join app.user_account u on u.id = p.created_by
       where p.session_id = s.id), '[]'::jsonb));
end;
$$;

revoke execute on function app.session_done_info(uuid) from public, anon;
grant execute on function app.session_done_info(uuid) to authenticated;
