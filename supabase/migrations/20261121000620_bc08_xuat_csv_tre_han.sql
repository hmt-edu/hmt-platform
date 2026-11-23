-- BC-08 Xuất CSV (thẻ F-23-08; khung BC08_pc, BC08_khong_xuat_pc): danh sách giáo viên, trợ giảng có buổi trễ hạn trong tháng, mọi dòng (không phân trang).
-- Luật: quyền Báo cáo · Xuất (hàm app.log_export kiểm và ghi nhật ký xuất file cùng giao dịch: ai, phân hệ, bộ lọc, số dòng); phạm vi như báo cáo xem
-- (Báo cáo · Xem; phạm vi hẹp thì chỉ cơ sở mình). BC-08 chỉ ghi số liệu, không tính vi phạm (R-GV-06); tháng theo ngày buổi diễn ra.
-- Tối đa export_max_rows dòng mỗi lần (tham số Cài đặt); quá thì truncated = true.
-- Không viết lại truy vấn: gọi từng trang của app.report_teacher_late (một nguồn số liệu duy nhất, xuất và xem luôn khớp nhau).
-- Ai gọi: người có quyền Báo cáo · Xuất. Đầu vào: p_month (ngày bất kỳ trong tháng; null = tháng hiện tại), p_branch_id (null = theo phạm vi quyền).
-- Kết quả: {month, total, exported, truncated, rows: [{user_id, code, role, name, branch_code, late_sessions, late_hours, done_sessions}]}.
create or replace function app.export_teacher_late(p_month date default null, p_branch_id uuid default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('export_max_rows');
  v_page integer := app.get_setting_int('list_page_size_max');
  v_offset integer := 0;
  v_part jsonb;
  v_total bigint;
  v_month date;
  v_rows jsonb := '[]'::jsonb;
begin
  -- Luật quyền xuất + nhật ký: kiểm Báo cáo · Xuất và ghi nhật ký (số dòng ghi sau khi biết); kiểm quyền trước để người không có quyền không tốn công.
  if not app.has_permission('REPORT', 'XUAT') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất file ở phân hệ này.');
  end if;
  loop
    -- Phạm vi cơ sở và quyền xem do chính app.report_teacher_late kiểm.
    v_part := app.report_teacher_late(p_month, p_branch_id, v_page, v_offset);
    v_total := (v_part ->> 'total')::bigint;
    v_month := (v_part ->> 'month')::date;
    v_rows := v_rows || (v_part -> 'rows');
    v_offset := v_offset + v_page;
    exit when v_offset >= v_total or v_offset >= v_max;
  end loop;
  if jsonb_array_length(v_rows) > v_max then
    v_rows := (select coalesce(jsonb_agg(e.x order by e.n), '[]'::jsonb)
                 from jsonb_array_elements(v_rows) with ordinality as e (x, n) where e.n <= v_max);
  end if;
  perform app.log_export('REPORT', jsonb_build_object('report', 'BC08', 'month', v_month, 'branch_id', p_branch_id), jsonb_array_length(v_rows));
  return jsonb_build_object('month', v_month, 'total', v_total, 'exported', jsonb_array_length(v_rows),
                            'truncated', v_total > jsonb_array_length(v_rows), 'rows', v_rows);
end;
$$;
comment on function app.export_teacher_late(date, uuid) is 'BC-08: xuất mọi dòng giáo viên, trợ giảng trễ hạn trong tháng; quyền Báo cáo · Xuất, ghi nhật ký xuất file.';
revoke execute on function app.export_teacher_late(date, uuid) from public, anon;
grant execute on function app.export_teacher_late(date, uuid) to authenticated;
