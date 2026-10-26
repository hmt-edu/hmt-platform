-- Dữ liệu giả cho local và môi trường thử nghiệm (hmt-staging). KHÔNG chạy trên bản chạy thật.
-- CHỈ dữ liệu giả: không bao giờ đưa tên, số điện thoại thật của học sinh, phụ huynh vào đây.
-- Chạy lại nhiều lần không nhân đôi dữ liệu (on conflict do nothing / where not exists).

-- Phòng học giả: mỗi cơ sở dạy học 3 phòng (Hội sở là văn phòng, không có phòng).
insert into app.room (branch_id, code, name, capacity, sort_order)
select b.id, r.code, r.name, r.capacity, r.sort_order
  from app.branch b
 cross join (values
   ('P101', 'Phòng 101 (giả)', 12, 1),
   ('P102', 'Phòng 102 (giả)', 8, 2),
   ('ONL1', 'Phòng online 1 (giả)', 20, 3)
 ) as r (code, name, capacity, sort_order)
 where not b.is_office
on conflict (branch_id, code) do nothing;

-- Ngày nghỉ giả để thử: một ngày chung, một ngày riêng CS5.
insert into app.holiday (holiday_date, name, branch_id)
values (date '2026-11-20', 'Ngày Nhà giáo (thử nghiệm)', null)
on conflict (holiday_date, branch_id) do nothing;
insert into app.holiday (holiday_date, name, branch_id)
select date '2026-12-24', 'Nghỉ riêng CS5 (thử nghiệm)', id from app.branch where code = 'CS5'
on conflict (holiday_date, branch_id) do nothing;

-- Bật thử phân hệ Bán hàng ở CS5 (cơ sở chạy trước) để thử công tắc.
insert into app.feature_flag (module_code, branch_id, enabled)
select 'BAN_HANG', id, true from app.branch where code = 'CS5'
on conflict (module_code, branch_id) do nothing;

-- Ghi đè thử một tham số cho CS5.
insert into app.setting_branch (setting_key, branch_id, value)
select 'quotation_validity_days', id, '7' from app.branch where code = 'CS5'
on conflict (setting_key, branch_id) do nothing;

-- Ghi chú giả gắn vào phòng P101 của CS1.
insert into app.note (entity_type, entity_id, body)
select 'ROOM', r.id, 'Ghi chú thử nghiệm: máy chiếu phòng này cần kiểm tra.'
  from app.room r join app.branch b on b.id = r.branch_id
 where b.code = 'CS1' and r.code = 'P101'
   and not exists (select from app.note n where n.entity_type = 'ROOM' and n.entity_id = r.id);

-- ---------------------------------------------------------------------------
-- Cấu hình bán hàng giả (P5a-DB0): vài gói, giá, chính sách, điều khoản để thử. Giá thật nạp ở bước chuyển dữ liệu.
-- ---------------------------------------------------------------------------
insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code)
values ('LC-TOAN-K09', 'Lớp chung Toán 9', 'LC', 'TOAN', 'K09', null),
       ('VIP-TOAN-K03K07', 'VIP Toán 3 đến 7', 'VIP', 'TOAN', 'K03', 'K07'),
       ('VNN-TOAN-K09', 'VIP nhóm nhỏ Toán 9', 'VNN', 'TOAN', 'K09', null)
on conflict (code) do nothing;
insert into app.sales_package (code, name, package_type_code) values
  ('DV-CSGK', 'Dịch vụ chăm sóc giữa kỳ', 'DV'), ('TL-MATOAN', 'Bộ tài liệu Toán', 'TL')
on conflict (code) do nothing;
insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
select p.id, v.mode, v.price, date '2026-09-01'
  from (values ('LC-TOAN-K09', 'OFF', 220000), ('LC-TOAN-K09', 'ONL', 120000), ('VIP-TOAN-K03K07', 'ONL', 500000),
               ('VNN-TOAN-K09', 'OFF', 300000), ('DV-CSGK', 'OFF', 300000), ('TL-MATOAN', 'OFF', 150000)) v(code, mode, price)
  join app.sales_package p on p.code = v.code
on conflict (package_id, delivery_mode_code, effective_from) do nothing;
insert into app.discount_policy (code, name, kind, max_value, fixed_value, requires_approval, valid_from)
values ('GIAM_6_THANG', 'Giảm khi đóng 6 tháng', 'PERCENT', 5, true, false, date '2026-09-01'),
       ('GIAM_THUONG_LUONG', 'Giảm thương lượng', 'PERCENT', 10, false, true, date '2026-09-01'),
       ('TANG_GIO', 'Tặng giờ học', 'GIFT_HOURS', 4, false, false, date '2026-09-01')
on conflict (code) do nothing;
insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from)
select 'QUA_TAI_LIEU', 'Tặng bộ tài liệu Toán', p.id, 1, date '2026-09-01' from app.sales_package p where p.code = 'TL-MATOAN'
on conflict (code) do nothing;
insert into app.payment_term (code, version, name, valid_from) values
  ('COC_VA_CHIA_DOT', 1, 'Cọc rồi chia hai đợt', date '2026-09-01'), ('CHIA_3_DOT', 1, 'Chia ba đợt 40, 30, 30', date '2026-09-01')
on conflict (code, version) do nothing;
insert into app.payment_term_installment (term_id, seq, share_percent, fixed_amount, due_days)
select t.id, v.seq, v.pct, v.amt, v.due
  from (values ('COC_VA_CHIA_DOT', 1, null::numeric, 1000000::bigint, 0), ('COC_VA_CHIA_DOT', 2, 100::numeric, null::bigint, 30),
               ('CHIA_3_DOT', 1, 40::numeric, null::bigint, 0), ('CHIA_3_DOT', 2, 30::numeric, null::bigint, 30),
               ('CHIA_3_DOT', 3, 30::numeric, null::bigint, 60)) v(code, seq, pct, amt, due)
  join app.payment_term t on t.code = v.code and t.version = 1
on conflict (term_id, seq) do nothing;
