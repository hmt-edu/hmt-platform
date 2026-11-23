-- B-23-14 (migration 627): đổi tên điều khoản COC_VA_CHIA_DOT cho đúng số lần đóng; không đổi code, số đợt, số tiền.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select name from app.payment_term where code = 'COC_VA_CHIA_DOT' and version = 1), 'Cọc rồi đóng phần còn lại',
          'Điều khoản cọc đã đổi tên: không còn «chia hai đợt»');
select is((select count(*)::int from app.payment_term where name = 'Cọc rồi chia hai đợt'), 0, 'Không còn điều khoản mang tên cũ');
select is((select count(*)::int from app.payment_term_installment i join app.payment_term t on t.id = i.term_id where t.code = 'COC_VA_CHIA_DOT'),
          2, 'Số đợt giữ nguyên: cọc và một đợt còn lại (hai lần đóng)');
select is((select fixed_amount from app.payment_term_installment i join app.payment_term t on t.id = i.term_id where t.code = 'COC_VA_CHIA_DOT' and i.seq = 1),
          1000000::bigint, 'Số tiền cọc giữ nguyên');
-- Trigger chặn đổi tên vẫn bật cho các lần sau (luật «bản đã tạo không sửa, tạo bản mới»).
select is((select tgenabled::text from pg_trigger where tgname = 'payment_term_fixed' and tgrelid = 'app.payment_term'::regclass), 'O',
          'Trigger chặn sửa điều khoản đã được bật lại sau khi đổi tên');
select throws_ok($$update app.payment_term set name = 'Tên khác' where code = 'COC_VA_CHIA_DOT'$$, null, null,
                 'Chặn: đổi tên điều khoản lần nữa vẫn bị trigger từ chối');

select * from finish();
rollback;
