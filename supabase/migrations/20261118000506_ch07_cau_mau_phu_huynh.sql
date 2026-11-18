-- CH-07 tab «Câu mẫu lời nhắn phụ huynh»: đọc và sửa 24 câu theo LOẠI BUỔI × MỨC 1–4 × 3 câu (R-V2-39), bảng app.parent_phrase.
-- Chat chốt 18/11 (Câu 1): làm theo luật; canvas CH07_cau_mau vẽ theo tiêu chí × mức 1–5 nên VÊNH LUẬT, ghi vào PR cho anh Trường báo Design.
-- app.get_parent_phrases() -> jsonb [{kind, level, seq, phrase}]: Admin (Quản trị · Xem). 24 dòng, sắp loại buổi, mức, số thứ tự.
-- app.update_parent_phrases(p_items jsonb) -> integer: Admin (Quản trị · Sửa). p_items: [{kind, level, seq, phrase}], chỉ sửa câu CÓ SẴN (không thêm bớt:
-- đủ 24 câu là luật), câu không rỗng; một giao dịch, một ô sai thì quay lại. Lịch sử nằm ở audit_log của bảng (apply_standard).
create or replace function app.get_parent_phrases()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên xem được câu mẫu lời nhắn.');
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('kind', p.kind, 'level', p.level, 'seq', p.seq, 'phrase', p.phrase)
                                    order by p.kind, p.level, p.seq) from app.parent_phrase p), '[]'::jsonb);
end;
$$;

create or replace function app.update_parent_phrases(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_text text;
  v_count integer := 0;
  v_rows integer;
begin
  perform app.assert_config_writer();
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Danh sách câu mẫu không hợp lệ.');
  end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_text := nullif(btrim(coalesce(v_item ->> 'phrase', '')), '');
    -- Luật R-V2-39: mỗi câu mẫu không được để trống.
    if v_text is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Câu mẫu không được để trống.');
    end if;
    update app.parent_phrase set phrase = v_text
     where kind = v_item ->> 'kind' and level = (v_item ->> 'level')::integer and seq = (v_item ->> 'seq')::integer;
    get diagnostics v_rows = row_count;
    -- Luật R-V2-39: chỉ sửa câu có sẵn (24 câu cố định), không thêm bớt.
    if v_rows = 0 then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không có câu mẫu này (loại buổi, mức, số thứ tự).');
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function app.get_parent_phrases(), app.update_parent_phrases(jsonb) from public, anon, authenticated;
grant execute on function app.get_parent_phrases(), app.update_parent_phrases(jsonb) to authenticated;
