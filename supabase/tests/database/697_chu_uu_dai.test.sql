-- UD1 phần 3 (mig 697): chữ máy chủ trả về dùng «ưu đãi», không còn «chiết khấu» và «tích đồng ý».
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- Bỏ phần chú thích trong thân hàm trước khi dò.
create function pg_temp.body(p_name text) returns text language sql as
  $$ select regexp_replace(prosrc, '--[^\n]*', '', 'g') from pg_proc where oid = p_name::regproc $$;

select is(
  (select coalesce(string_agg(f, ', ' order by f), '')
     from unnest(array['app.tg_quotation_child_lock', 'app.price_apply_discounts', 'app.save_quotation', 'app.preview_quotation_lines',
                       'app.order_line_diff_text', 'app.edit_order', 'app.list_policy_history']) as f
    where pg_temp.body(f) ~* 'chiết khấu'),
  '', 'UD1: bảy hàm không còn câu chữ «chiết khấu»');
select ok(
  pg_temp.body('app.save_quotation') not like '%tích đồng ý%' and pg_temp.body('app.preview_quotation_lines') not like '%tích đồng ý%',
  'R-V2-11: cảnh báo vượt trần không còn đòi người duyệt tích đồng ý');
select is((select name from app.setting_def where key = 'discount_total_cap_percent'), 'Trần tổng ưu đãi', 'UD1: tên tham số trần');
select is(
  (select count(*)::int from app.setting_def
    where key in ('discount_total_cap_percent', 'flexible_discount_max_percent') and (name || description) ~* 'chiết khấu|quản lý cơ sở duyệt'),
  0, 'UD1, R-V2-11: mô tả tham số không còn «chiết khấu», không nói vượt trần phải duyệt');
select is(
  (select count(*)::int from app.catalog_item where catalog_code = 'PERM_MODULE' and code = 'CONFIG_SALES' and name like '%ưu đãi%'),
  1, 'UD1: tên phân hệ quyền Cấu hình bán hàng dùng «ưu đãi»');

select * from finish();
rollback;
