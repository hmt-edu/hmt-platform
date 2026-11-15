-- PR 6b: các danh mục một tầng nạp theo spec 06 (#8, 14, 15, 17, 21, 22, 23, 24, 25, 26, 28, 31, 32).
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
grant execute on all functions in schema pg_temp to public;

create function pg_temp.codes(p_catalog text) returns text[] language sql as $$
  select array_agg(code order by sort_order) from app.catalog_item where catalog_code = p_catalog;
$$;
create function pg_temp.names(p_catalog text) returns text[] language sql as $$
  select array_agg(name order by sort_order) from app.catalog_item where catalog_code = p_catalog;
$$;

-- Giá trị đúng spec 06.
select is(pg_temp.codes('PACKAGE_TYPE'), array['LC', 'VIP', 'VNN', 'KR', 'DV', 'TL'], 'Spec 06 #8: Loại gói LC, VIP, VNN, KR, DV, TL');
select is(pg_temp.names('TEST_MODE'), array['Offline', 'Online'], 'Spec 06 #14: Hình thức test Offline, Online');
select is(pg_temp.names('TEST_LEVEL'), array['Cơ bản', 'Nâng cao'], 'Spec 06 #15: Cấp độ đề test Cơ bản, Nâng cao');
select is(pg_temp.names('ATTENDANCE_CONTACT_REASON'),
          array['Không nghe máy', 'Đã nhắc vào lớp', 'Đã vào lớp', 'Xin nghỉ học', 'Khác'], 'Spec 06 #17: Lý do liên hệ khi điểm danh');
select is(pg_temp.names('COMPLAINT_SEVERITY'), array['Thấp', 'Trung bình', 'Cao', 'Nghiêm trọng'], 'Spec 06 #21: Mức độ khiếu nại');
select is(pg_temp.names('TICKET_CHANNEL'), array['Gọi điện', 'Zalo', 'Trực tiếp', 'Email', 'Giáo viên báo', 'Khác'], 'Spec 06 #22: Kênh tiếp nhận ticket');
select is(pg_temp.names('SESSION_CANCEL_REASON'),
          array['Nghỉ lễ đột xuất', 'Giáo viên nghỉ', 'Sự cố cơ sở vật chất', 'Thời tiết', 'Ốm', 'Việc gia đình', 'Thi ở trường', 'Khác'],
          'Spec 06 #23: Lý do huỷ buổi (trung tâm rồi học sinh)');
select is(pg_temp.names('REJECT_REASON'),
          array['Thiếu thông tin', 'Sai số tiền', 'Sai chứng từ', 'Không đúng chính sách', 'Khác', 'Không xếp được lịch'], 'Spec 06 #24: Lý do từ chối (thêm Không xếp được lịch cho yêu cầu buổi, migration 139)');
select is(pg_temp.names('HOURS_ADJUST_REASON'),
          array['Sửa sai danh sách/điểm danh', 'Bù giờ do lỗi trung tâm', 'Tặng giờ chăm sóc (cần duyệt)', 'Chuyển dữ liệu từ hệ thống cũ', 'Khác'],
          'Spec 06 #25: Lý do điều chỉnh giờ');
select is(pg_temp.names('PAYMENT_METHOD'), array['Tiền mặt', 'Chuyển khoản', 'Quẹt thẻ'], 'Spec 06 #26: Hình thức thu tiền');
select is(pg_temp.names('RENEWAL_LOST_REASON'),
          array['Học phí', 'Chất lượng', 'Lịch học', 'Chuyển nhà', 'Học nơi khác', 'Đủ mục tiêu', 'Khác'], 'Spec 06 #28: Lý do không tái tục');
select is(pg_temp.names('REVERSAL_REASON'),
          array['Nhập sai số tiền', 'Trùng phiếu', 'Sai đơn hoặc sai khách', 'Khác'], 'Spec 06 #31: Lý do đảo khoản tiền');
select is(pg_temp.names('ACCOUNT_LOCK_REASON'),
          array['Nghỉ việc', 'Dừng học', 'Tạm nghỉ', 'Nghi lộ mật khẩu', 'Khác'], 'Spec 06 #32: Lý do khoá tài khoản');

-- Loại khoá: #8 và #21 là Khoá; còn lại Mở.
select is((select array_agg(code order by code) from app.catalog where kind = 'HE_THONG' and code in ('PACKAGE_TYPE', 'COMPLAINT_SEVERITY')),
          array['COMPLAINT_SEVERITY', 'PACKAGE_TYPE'], 'Loại gói và Mức độ khiếu nại là danh mục Khoá');
select is(pg_temp.err($$select app.catalog_add_item('PACKAGE_TYPE', 'XX', 'Loại gói mới')$$), 'HMT_DANH_MUC_HE_THONG', 'Khoá: không thêm loại gói');
select is(pg_temp.err($$select app.catalog_add_item('PAYMENT_METHOD', 'VI_DIEN_TU', 'Ví điện tử')$$), null, 'Mở: thêm hình thức thu tiền được');

-- R-HT-04: danh mục lý do luôn có "Khác", chọn "Khác" thì bắt buộc ghi chú.
select is((select array_agg(c order by c) from (
             select r.code c from app.catalog r
             where r.code in ('ATTENDANCE_CONTACT_REASON', 'SESSION_CANCEL_REASON', 'REJECT_REASON', 'HOURS_ADJUST_REASON',
                              'RENEWAL_LOST_REASON', 'REVERSAL_REASON', 'ACCOUNT_LOCK_REASON', 'TEST_SKIP_REASON')
               and exists (select from app.catalog_item i where i.catalog_code = r.code and i.name = 'Khác' and i.requires_note)) t),
          array['ACCOUNT_LOCK_REASON', 'ATTENDANCE_CONTACT_REASON', 'HOURS_ADJUST_REASON', 'REJECT_REASON',
                'RENEWAL_LOST_REASON', 'REVERSAL_REASON', 'SESSION_CANCEL_REASON', 'TEST_SKIP_REASON'],
          'R-HT-04: mọi danh mục lý do có "Khác" bắt buộc ghi chú');
select is((select count(*)::int from app.catalog_item where requires_note and name <> 'Khác' and catalog_code not in ('TEST_CANCEL_REASON', 'TEST_SKIP_REASON')), 0,
          'Chỉ mục "Khác" bắt buộc ghi chú (ngoại lệ: "lý do khác" của huỷ test R-CRM-06 và của bỏ qua test BQ5 R-CRM-14)');

-- Lý do từ chối: "Áp dụng cho" để trống = mọi nơi. Từ P5a-DB0 (Đ103) ba mục gán riêng: Sai số tiền, Sai chứng từ (phiếu thu),
-- Không đúng chính sách (báo giá, đơn); hai mục còn lại dùng chung. Migration 139 thêm mục thứ tư gán riêng: Không xếp được lịch (yêu cầu buổi).
select is((select count(*)::int from app.catalog_item where catalog_code = 'REJECT_REASON' and applies_to <> '{}'), 4,
          'Lý do từ chối: bốn mục gán riêng (ba theo Đ103, một cho yêu cầu buổi), còn lại áp dụng mọi nơi (cột "Áp dụng cho" để trống)');

-- Không còn danh mục nào của spec 06 #8–#26, #28, #31, #32 thiếu (trừ #12, 19, 20, 27, 30).
select is((select count(*)::int from app.catalog where code in (
            'PACKAGE_TYPE', 'TEST_MODE', 'TEST_LEVEL', 'ATTENDANCE_CONTACT_REASON', 'COMPLAINT_SEVERITY', 'TICKET_CHANNEL',
            'SESSION_CANCEL_REASON', 'REJECT_REASON', 'HOURS_ADJUST_REASON', 'PAYMENT_METHOD', 'RENEWAL_LOST_REASON',
            'REVERSAL_REASON', 'ACCOUNT_LOCK_REASON')), 13, 'Đủ 13 danh mục nạp ở PR 6b');

select * from finish();
rollback;
