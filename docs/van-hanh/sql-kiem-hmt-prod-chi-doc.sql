-- KIỂM hmt-prod, CHỈ ĐỌC (Q-196, Q-203). Chỉ có câu SELECT, không ghi gì.
-- Cách chạy: Supabase > project hmt-prod > SQL Editor > dán toàn bộ file > Run. Chạy từng khối (a), (b), (c) riêng cũng được.
-- Gửi Chat ảnh chụp kết quả (không có dữ liệu cá nhân, chỉ số đếm). Viết 10/11/2026.

-- ===== (a) Số migration cuối trên production =====
-- Bản chạy thật cũ nhất cần biết là 014 (tag staging-20261010-1642-75637cf). Bản mới nhất trên main: 086 (087 khi PR #210 gộp).
select max(version) as migration_cuoi, count(*) as so_migration_da_ap
  from supabase_migrations.schema_migrations;

-- ===== (b) Số dòng của các bảng chính =====
-- Bảng chưa có (production còn ở bản cũ) thì ghi "chưa có bảng", không báo lỗi.
select t.ten_bang,
       case when to_regclass('app.' || t.ten_bang) is null then 'chưa có bảng'
            else (xpath('/row/c/text()',
                        query_to_xml(format('select count(*) as c from app.%I', t.ten_bang), false, true, '')))[1]::text
       end as so_dong
  from (values ('lead'), ('opportunity'), ('parent'), ('student'), ('prospect_student'), ('appointment'),
               ('student_test'), ('quotation'), ('sales_order'), ('receipt'), ('user_account'), ('audit_log')) as t (ten_bang)
 order by t.ten_bang;
-- Ghi chú tên bảng: lead = lead, opportunity = cơ hội, parent = phụ huynh, student = học sinh, prospect_student = dòng em của lead/cơ hội,
-- student_test = phiếu kiểm tra, quotation = báo giá, sales_order = đơn, receipt = phiếu thu.

-- ===== (c) Số phiếu kiểm tra sẽ làm migration 043 dừng lỗi =====
-- 043 gắn mỗi phiếu kiểm tra vào dòng em của cơ hội; nếu cơ hội không có thông tin học sinh nào thì phiếu không gắn được và 043 dừng
-- ("Có phiếu kiểm tra chưa gắn được vào dòng em").
-- Bảng student_test ra đời ở migration 030, sau bản 014, nên nếu production còn ở 014 thì chưa có bảng và kết quả là 0 phiếu (043 không thể lỗi vì chuyện này).
-- Phép đếm dưới đây chỉ có nghĩa khi production CHƯA qua 043 (còn cột student_name của cơ hội). Đã qua 043 thì ghi "đã qua 043".
select case
         when to_regclass('app.student_test') is null then 'chưa có bảng student_test: 0 phiếu, 043 không dừng vì phiếu'
         when to_regclass('app.prospect_student') is not null then 'đã qua 043 (đã có bảng dòng em): không áp dụng'
         else (xpath('/row/c/text()', query_to_xml(
                'select count(*) as c from app.student_test t join app.opportunity o on o.id = t.opportunity_id
                  where o.student_id is null and o.student_name is null and o.student_birth_date is null
                    and o.student_birth_year is null and o.school is null and o.self_rating is null and o.goal is null',
                false, true, '')))[1]::text || ' phiếu sẽ làm 043 dừng lỗi (phải là 0)'
       end as ket_qua_043;
