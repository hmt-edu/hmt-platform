-- PR 6a: danh mục Khoá theo spec 06 (Môn, Khối, Trình độ, mục cha giai đoạn), C4D khoá, tên C4C/C4D, hai cột mới.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
-- Hàm mới mặc định không cấp quyền chạy cho ai (migration 014): cấp cho hàm trợ giúp của bài kiểm thử.
grant execute on all functions in schema pg_temp to public;

-- Spec 06 #3, #4, #6: Môn, Khối, Trình độ là Khoá.
select is((select array_agg(code order by code) from app.catalog where kind = 'HE_THONG' and code in ('SUBJECT', 'GRADE', 'LEVEL')),
          array['GRADE', 'LEVEL', 'SUBJECT'], 'Môn, Khối, Trình độ là danh mục Khoá');
select is(pg_temp.err($$select app.catalog_add_item('SUBJECT', 'TIN', 'Môn mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá: không thêm môn mới');
select is(pg_temp.err($$select app.catalog_add_item('GRADE', 'K13', 'Khối mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá: không thêm khối mới');
select is(pg_temp.err($$select app.catalog_add_item('LEVEL', 'D', 'Trình độ mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá: không thêm trình độ mới');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('SUBJECT', 'TOAN'), false)$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá: không Ngừng môn');
select is(pg_temp.err($$select app.catalog_rename_item(app.catalog_item_id('LEVEL', 'S'), 'Trình độ S')$$),
          null, 'Khoá: vẫn đổi được tên hiển thị');

-- Spec 06 #10, #11: khoá mục cha giai đoạn lead và giai đoạn cơ hội.
select is(pg_temp.err($$select app.catalog_add_item('LEAD_STAGE', 'C5', 'Giai đoạn lead mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá mục cha: không thêm giai đoạn lead');
select is(pg_temp.err($$select app.catalog_add_item('OPP_STAGE', 'L9', 'Giai đoạn cơ hội mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá mục cha: không thêm giai đoạn cơ hội');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('OPP_STAGE', 'L3'), false)$$),
          'HMT_DANH_MUC_HE_THONG', 'Khoá mục cha: không Ngừng giai đoạn cơ hội');
select is(pg_temp.err($$select app.catalog_add_item('LEAD_SUBSTAGE', 'C2Z', 'Nhóm con mới', null,
                                                    app.catalog_item_id('LEAD_STAGE', 'C2'))$$),
          null, 'Mục con vẫn thêm được dưới mục cha khoá');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('LEAD_SUBSTAGE', 'C2Z'), false)$$),
          null, 'Mục con vẫn Ngừng được');

-- C4D do hệ thống tự gắn (R-CRM-09): khoá, không Ngừng được, đổi tên được.
select is((select is_locked from app.catalog_item where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4D'), true, 'C4D bị khoá');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('LEAD_SUBSTAGE', 'C4D'), false)$$),
          'HMT_MUC_BI_KHOA', 'C4D không Ngừng được');
select is(pg_temp.err($$select app.catalog_rename_item(app.catalog_item_id('LEAD_SUBSTAGE', 'C4D'), 'Tạo cơ hội thành công')$$),
          null, 'C4D đổi được tên hiển thị');

-- Tên theo spec 06 mục 1.2: "cơ hội" thay cho "opp".
select is((select name from app.catalog_item where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4C'), 'Đủ điều kiện tạo cơ hội', 'C4C là "Đủ điều kiện tạo cơ hội"');
select is((select name from app.catalog_item where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4D'), 'Tạo cơ hội thành công', 'C4D là "Tạo cơ hội thành công"');
select ok(not exists (select from app.catalog_item where name ilike '%opp%' and catalog_code in ('LEAD_STAGE', 'LEAD_SUBSTAGE')),
          'Không còn chữ "opp" trong giai đoạn lead');

-- Hai cột mới của mục danh mục.
select is((select requires_note from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and code = 'KHAC'), true,
          'R-CRM-14: "Khác" của lý do bỏ qua test bắt buộc ghi chú');
select is((select count(*)::int from app.catalog_item where requires_note and is_active and catalog_code = 'TEST_SKIP_REASON'), 1,
          'Danh mục 33: chỉ một mục còn hiệu lực bắt buộc ghi chú (BQ5)');
select is((select applies_to from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TOAN'), '{}'::text[],
          '"Áp dụng cho" mặc định rỗng (mọi nơi)');

select * from finish();
rollback;
