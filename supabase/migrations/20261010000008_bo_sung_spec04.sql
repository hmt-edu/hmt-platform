-- Bổ sung theo docs/spec/04-luat-nghiep-vu.md (cập nhật 10/10/2026):
-- tham số hoàn phí, trần chiết khấu, SLA ticket, số ngày mở lại khiếu nại;
-- danh mục hệ thống trạng thái BTVN (R-GV-11); loại chứng từ DN, KN cho ticket (R-CS-01).

select set_config('hmt.migration', 'on', false);

-- R-GV-11: mỗi em mỗi bài BTVN đúng một trạng thái; danh mục hệ thống (đổi tên được, không thêm bớt).
insert into app.catalog (code, name, kind, description, sort_order) values
  ('HOMEWORK_STATUS', 'Trạng thái BTVN', 'HE_THONG',
   'R-GV-11. Đã chấm, Làm chưa xong có điểm; Nộp sau sửa điểm được mà không mở lại buổi cũ; Không áp dụng không tính vào số bài phải làm (R-GV-12).',
   (select coalesce(max(sort_order), 0) + 1 from app.catalog));

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('HOMEWORK_STATUS', 'DA_CHAM', 'Đã chấm', 1),
  ('HOMEWORK_STATUS', 'LAM_CHUA_XONG', 'Làm chưa xong', 2),
  ('HOMEWORK_STATUS', 'KHONG_LAM', 'Không làm', 3),
  ('HOMEWORK_STATUS', 'NOP_SAU', 'Nộp sau', 4),
  ('HOMEWORK_STATUS', 'KHONG_AP_DUNG', 'Không áp dụng', 5);

-- R-CS-01: mã ticket DN-<CS>-<YYMM>-<STT>, KN-<CS>-<YYMM>-<STT>, cấp như chứng từ.
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('DOC_TYPE', 'DN', 'Ticket đề nghị', 5),
  ('DOC_TYPE', 'KN', 'Ticket khiếu nại', 6);

-- Tham số mới (spec 04 mục 8).
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('refund_processing_fee_percent', 'Phí xử lý hoàn phí', 'NUMERIC', '%', 0, 100, '10', false, 'BAN_HANG', 'R-TIEN-28',
   'Phần trăm trừ trên số tiền còn lại khi hoàn phí (sau khi trừ giờ đã học theo giá gốc).'),
  ('discount_total_cap_percent', 'Trần tổng chiết khấu', 'NUMERIC', '%', 0, 100, '20', false, 'BAN_HANG', 'R-TIEN-29',
   'Tổng các chiết khấu cộng dồn trên một dòng không quá mức này; vượt trần phải quản lý cơ sở duyệt.'),
  ('sla_complaint_response_hours', 'SLA khiếu nại thường: phản hồi', 'INT', 'giờ', 1, 168, '24', true, 'CSKH', 'R-CS-08',
   'Hạn phản hồi khiếu nại mức Thấp, Trung bình, Cao.'),
  ('sla_complaint_resolve_days', 'SLA khiếu nại thường: xử lý xong', 'INT', 'ngày', 1, 30, '3', true, 'CSKH', 'R-CS-08',
   'Hạn xử lý xong khiếu nại mức Thấp, Trung bình, Cao.'),
  ('sla_complaint_critical_response_hours', 'SLA khiếu nại nghiêm trọng: phản hồi', 'INT', 'giờ', 1, 168, '2', true, 'CSKH', 'R-CS-08',
   'Hạn phản hồi khiếu nại mức Nghiêm trọng (đồng thời báo Ban giám đốc ngay).'),
  ('sla_complaint_critical_resolve_days', 'SLA khiếu nại nghiêm trọng: xử lý xong', 'INT', 'ngày', 1, 30, '1', true, 'CSKH', 'R-CS-08',
   'Hạn xử lý xong khiếu nại mức Nghiêm trọng.'),
  ('sla_request_response_hours', 'SLA đề nghị: phản hồi', 'INT', 'giờ', 1, 168, '24', true, 'CSKH', 'R-CS-08',
   'Hạn phản hồi ticket đề nghị.'),
  ('sla_request_resolve_days', 'SLA đề nghị: xử lý xong', 'INT', 'ngày', 1, 30, '2', true, 'CSKH', 'R-CS-08',
   'Hạn xử lý xong ticket đề nghị (trừ hoàn tiền).'),
  ('sla_refund_resolve_days', 'SLA đề nghị hoàn tiền: xử lý xong', 'INT', 'ngày', 1, 60, '7', true, 'CSKH', 'R-CS-08',
   'Hạn xử lý xong ticket đề nghị nhóm Hoàn tiền.'),
  ('complaint_reopen_max_days', 'Mở lại khiếu nại tối đa', 'INT', 'ngày', 0, 90, '7', true, 'CSKH', 'R-CS-06',
   'Khiếu nại đã đóng được mở lại trong số ngày này.');

select set_config('hmt.migration', '', false);
