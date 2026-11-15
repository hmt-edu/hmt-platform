-- Sửa lệch luật buổi Kiểm tra (Chat 15/11, R-V2-20): F3 và F4. Chỉ thay thân hai hàm của migration 103, không đổi chữ ký, quyền gọi giữ nguyên.
--  F3: app.exam_resolve_scores chặn điểm nhóm âm bằng mã HMT_DIEM_AM, không để lọt lỗi ràng buộc check của bảng exam_score.
--  F4: app.set_exam_config chặn ĐỔI cấu hình khi buổi đã có điểm chấm (HMT_KIEM_TRA_DA_CO_DIEM); gọi lại đúng cấu hình đang có thì cho qua.

-- F3: tính điểm một em từ dữ liệu nhập; kiểm giới hạn. Trả về (tổng, ghi nhớ, hiểu, vận dụng). Nội bộ.
create or replace function app.exam_resolve_scores(p_exam app.session_exam, p_entry jsonb)
returns numeric[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_total numeric;
  v_m numeric := nullif(p_entry ->> 'memory', '')::numeric;
  v_u numeric := nullif(p_entry ->> 'understand', '')::numeric;
  v_a numeric := nullif(p_entry ->> 'apply', '')::numeric;
begin
  if p_exam.entry_mode = 'TONG' then
    v_total := (p_entry ->> 'total')::numeric;
    v_m := null; v_u := null; v_a := null;
  else
    -- Luật R-V2-20: nhóm không có đề (tối đa 0) bỏ qua; tổng tự cộng.
    v_m := case when p_exam.max_memory = 0 then 0 else v_m end;
    v_u := case when p_exam.max_understand = 0 then 0 else v_u end;
    v_a := case when p_exam.max_apply = 0 then 0 else v_a end;
    if v_m is null or v_u is null or v_a is null then
      perform app.raise_error('HMT_DIEM_KHONG_HOP_LE', 'Nhập đủ điểm các nhóm có đề.');
    end if;
    -- F3: điểm một nhóm không được âm (trước đây chỉ chặn khi tổng âm, còn nhóm âm mà tổng dương thì lọt xuống ràng buộc của bảng).
    if v_m < 0 or v_u < 0 or v_a < 0 then
      perform app.raise_error('HMT_DIEM_AM', 'Điểm của một nhóm không được âm.');
    end if;
    if v_m > p_exam.max_memory or v_u > p_exam.max_understand or v_a > p_exam.max_apply then
      perform app.raise_error('HMT_DIEM_VUOT_TOI_DA', 'Điểm một nhóm vượt điểm tối đa của nhóm.');
    end if;
    v_total := v_m + v_u + v_a;
  end if;
  if v_total is null or v_total < 0 or v_total > p_exam.max_score then
    perform app.raise_error('HMT_DIEM_VUOT_TOI_DA', 'Điểm phải từ 0 đến điểm tối đa của buổi.');
  end if;
  return array[v_total, v_m, v_u, v_a];
end;
$$;

-- F4: app.set_exam_config(buổi, phạm vi, điểm tối đa, cách nhập, tối đa 3 nhóm): ai xếp lịch buổi thì đặt (không phải giáo viên). Buổi chưa Done.
-- Buổi đã có điểm chấm thì không đổi cấu hình (đổi điểm tối đa hay cách nhập làm điểm đã chấm sai nghĩa); gọi lại đúng cấu hình cũ thì cho qua.
create or replace function app.set_exam_config(p_session_id uuid, p_scope text, p_max_score numeric, p_mode text,
                                               p_max_memory numeric default 0, p_max_understand numeric default 0, p_max_apply numeric default 0)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_max numeric;
  v_old app.session_exam;
  v_scope text := nullif(btrim(p_scope), '');
  v_m numeric;
  v_u numeric;
  v_a numeric;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.type_code <> 'KIEM_TRA' then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', 'Buổi này không phải buổi kiểm tra.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ đặt cấu hình kiểm tra cho buổi chưa Done và chưa huỷ.');
  end if;
  if p_mode not in ('TONG', 'NHOM') then
    perform app.raise_error('HMT_CACH_NHAP_DIEM_SAI', 'Cách nhập điểm là Điểm tổng hoặc Theo 3 nhóm.');
  end if;
  v_max := coalesce(p_max_score, app.get_setting_int('exam_default_max_score', s.branch_id));
  if v_max <= 0 then
    perform app.raise_error('HMT_DIEM_TOI_DA_SAI', 'Điểm tối đa phải lớn hơn 0.');
  end if;
  -- Luật R-V2-20: theo 3 nhóm thì tổng tối đa 3 nhóm bằng điểm tối đa của buổi.
  if p_mode = 'NHOM' and coalesce(p_max_memory, 0) + coalesce(p_max_understand, 0) + coalesce(p_max_apply, 0) <> v_max then
    perform app.raise_error('HMT_DIEM_NHOM_KHONG_KHOP', 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.');
  end if;
  v_m := case when p_mode = 'NHOM' then coalesce(p_max_memory, 0) else 0 end;
  v_u := case when p_mode = 'NHOM' then coalesce(p_max_understand, 0) else 0 end;
  v_a := case when p_mode = 'NHOM' then coalesce(p_max_apply, 0) else 0 end;
  -- F4: đã có điểm chấm thì chặn mọi thay đổi cấu hình.
  select * into v_old from app.session_exam where session_id = p_session_id;
  if exists (select 1 from app.exam_score where session_id = p_session_id and graded)
     and (v_old.session_id is null
          or v_old.scope_text is distinct from v_scope or v_old.max_score is distinct from v_max or v_old.entry_mode is distinct from p_mode
          or v_old.max_memory is distinct from v_m or v_old.max_understand is distinct from v_u or v_old.max_apply is distinct from v_a) then
    perform app.raise_error('HMT_KIEM_TRA_DA_CO_DIEM', 'Buổi kiểm tra đã có điểm chấm, không đổi được cấu hình.');
  end if;
  insert into app.session_exam (session_id, branch_id, scope_text, max_score, entry_mode, max_memory, max_understand, max_apply)
  values (p_session_id, s.branch_id, v_scope, v_max, p_mode, v_m, v_u, v_a)
  on conflict (session_id) do update set scope_text = excluded.scope_text, max_score = excluded.max_score, entry_mode = excluded.entry_mode,
         max_memory = excluded.max_memory, max_understand = excluded.max_understand, max_apply = excluded.max_apply;
end;
$$;
