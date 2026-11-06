-- Dữ liệu GIẢ LỚN cho bảng phiếu thu, chỉ để thử tốc độ ở máy local (CLAUDE.md, Hiệu năng). KHÔNG chạy ở thử nghiệm hay chạy thật,
-- KHÔNG nằm trong seed.sql thường, KHÔNG dùng dữ liệu thật. Cần chạy trước: npm run db:seed-users rồi npm run db:seed-lon (có phụ huynh giả PHL…, đơn giả DHL…).
-- Chạy: npm run db:seed-lon-phieu-thu. Dùng 8.000 đơn giả của seed-lon (mã DHL…), tạo 20.000 phiếu thu (mã PTL…) hai cơ sở CS1, CS5, đủ năm trạng thái, 2 đến 3 đợt mỗi đơn.
-- Chạy lại sẽ báo lỗi (đã có), muốn làm lại thì npm run db:reset.
\set ON_ERROR_STOP on
\timing on

do $$
begin
  if exists (select from app.receipt where code like 'PTL%') then
    raise exception 'Đã có phiếu thu giả lớn. Dựng lại DB bằng npm run db:reset rồi chạy lại.';
  end if;
  if (select count(*) from app.sales_order where code like 'DHL%') < 8000 then
    raise exception 'Chưa có đơn giả. Chạy npm run db:seed-users rồi npm run db:seed-lon trước.';
  end if;
end $$;

select setseed(0.42);
-- Bỏ qua trigger và ràng buộc khoá ngoại trong lúc nạp (dữ liệu giả sạch, giữ created_at rải đều).
set session_replication_role = replica;

-- 20.000 phiếu thu: đợt 1, 2 cho mọi đơn, đợt 3 cho một nửa. Trạng thái tuỳ số thứ tự (phần lớn Đã duyệt).
insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, receiver_id, status_code, amount, payment_method_code, txn_ref, paid_on,
                         approval_route, assigned_approver_id, submitted_at, manager_approved_at, accountant_approved_at, created_at, created_by)
select 'PTL' || lpad(row_number() over (order by o.code, d)::text, 6, '0'),
       o.id, o.parent_id, o.branch_id, o.branch_id, o.created_by,
       case (row_number() over (order by o.code, d)) % 10 when 0 then 'NHAP' when 1 then 'DA_GUI' when 2 then 'CHO_KE_TOAN' when 3 then 'HUY' else 'DA_DUYET' end,
       1000000 + (d * 250000), (array['TIEN_MAT', 'CHUYEN_KHOAN', 'QUET_THE'])[1 + (d % 3)],
       case when d % 3 = 1 then 'FT' || o.code || d end,
       current_date - ((row_number() over (order by o.code, d))::int % 100),
       'QUAN_LY', (select id from app.user_account where login_name like 'truongcs.cs5@%' limit 1),
       now(), now(), now(),
       now() - (((row_number() over (order by o.code, d))::int % 100) || ' days')::interval, o.created_by
  from app.sales_order o
  cross join lateral generate_series(1, case when substr(o.code, 4)::int % 2 = 0 then 2 else 3 end) d
 where o.code like 'DHL%'
 limit 20000;

set session_replication_role = origin;
-- Chữ để tìm của phiếu thu (trigger đã tắt lúc nạp).
update app.receipt r set search_text = app.receipt_search_text(r) where r.code like 'PTL%';

analyze app.receipt;
analyze app.sales_order;
select status_code, count(*) from app.receipt where code like 'PTL%' group by 1 order by 1;
