-- PR 6a: sửa các chỗ danh mục đã nạp lệch spec 06 (đối chiếu 16/10/2026) và thêm hai cột cho mục danh mục.
-- Nguồn: docs/spec/06 mục 1 (cột "Khoá"), mục 1.2; anh Trường chốt 16/10: Môn, Khối, Trình độ là Khoá.
-- Không đổi mã, không đổi nghĩa mã nào: chỉ đổi loại danh mục, khoá mục, tên hiển thị.

select set_config('hmt.migration', 'on', false);

-- Hai cột mới cho mục danh mục (B12 của docs/nghiep-vu/doi-chieu-luat-1210.md).
-- requires_note: chọn mục này thì bắt buộc ghi chú (mục "Khác" của danh mục lý do; R-HT-04). Cờ chỉ khai báo;
--   hàm nghiệp vụ dùng danh mục đó là nơi kiểm.
-- applies_to: danh sách loại đối tượng mà mục áp dụng (danh mục 24 "Lý do từ chối": báo giá, đơn, phiếu thu, lớp,
--   ticket, yêu cầu buổi). Mảng rỗng = áp dụng mọi nơi.
alter table app.catalog_item
  add column requires_note boolean not null default false,
  add column applies_to text[] not null default '{}';

comment on column app.catalog_item.requires_note is
  'Chọn mục này thì bắt buộc ghi chú (mục "Khác" của danh mục lý do). Hàm nghiệp vụ dùng danh mục là nơi kiểm.';
comment on column app.catalog_item.applies_to is
  'Loại đối tượng mà mục áp dụng (vd lý do từ chối: báo giá, đơn, phiếu thu). Rỗng = mọi nơi.';

-- "Khác" của danh mục 33 bắt buộc ghi chú (R-CRM-14).
update app.catalog_item set requires_note = true
where catalog_code = 'TEST_SKIP_REASON' and code = 'KHAC';

-- Môn, Khối, Trình độ: Khoá = không thêm, không Ngừng; chỉ đổi tên hiển thị và thứ tự.
update app.catalog set kind = 'HE_THONG' where code in ('SUBJECT', 'GRADE', 'LEVEL');

-- Giai đoạn lead và giai đoạn cơ hội: "Khoá mục cha" = C1–C4 và L1–L8 không thêm, không Ngừng;
-- mục con (nhóm con) vẫn thêm, đổi tên, Ngừng được.
update app.catalog set kind = 'HE_THONG' where code in ('LEAD_STAGE', 'OPP_STAGE');

-- C4D "Tạo cơ hội thành công" do hệ thống tự gắn (R-CRM-09): khoá, đổi tên được, không Ngừng được.
update app.catalog_item set is_locked = true where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4D';

-- Tên hiển thị: chữ "opp" thành "cơ hội" (spec 06 mục 1.2, chốt 12/10).
update app.catalog_item set name = 'Đủ điều kiện tạo cơ hội' where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4C';
update app.catalog_item set name = 'Tạo cơ hội thành công' where catalog_code = 'LEAD_SUBSTAGE' and code = 'C4D';

select set_config('hmt.migration', '', false);
