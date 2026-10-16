-- PR 6b: nạp các danh mục một tầng còn thiếu của spec 06 mục 1 (đối chiếu 16/10/2026).
-- #8 Loại gói, #14 Hình thức test, #15 Cấp độ đề test, #17 Lý do liên hệ khi điểm danh, #21 Mức độ khiếu nại,
-- #22 Kênh tiếp nhận ticket, #23 Lý do huỷ buổi, #24 Lý do từ chối, #25 Lý do điều chỉnh giờ, #26 Hình thức thu tiền,
-- #28 Lý do không tái tục, #31 Lý do đảo khoản tiền, #32 Lý do khoá tài khoản.
-- Không nạp: #27 Tài khoản nhận tiền (kế toán khai, làm cùng phiếu thu), #2 Phòng học (để rỗng ở bản chạy thật),
-- #30 (nạp dần theo từng giai đoạn), #12, #19, #20 (hai tầng, PR 6c).
-- Loại: #8, #21 là Khoá (HE_THONG); các danh mục còn lại là Mở. Danh mục lý do luôn có "Khác" bắt buộc ghi chú
-- (R-HT-04): cờ requires_note, hàm nghiệp vụ dùng danh mục là nơi kiểm.

select set_config('hmt.migration', 'on', false);

insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('PACKAGE_TYPE', 'Loại gói', 'HE_THONG', null, null, 'Tiền tố mã gói (spec 02): LC, VIP, VNN, KR, DV, TL.', 26),
  ('TEST_MODE', 'Hình thức test', 'MO', null, null, 'Riêng với danh mục Hình thức học (spec 06 #14).', 27),
  ('TEST_LEVEL', 'Cấp độ đề test', 'MO', null, null, 'Riêng với Cấp độ khung chương trình (spec 06 #15).', 28),
  ('ATTENDANCE_CONTACT_REASON', 'Lý do liên hệ khi điểm danh', 'MO', null, null, null, 29),
  ('COMPLAINT_SEVERITY', 'Mức độ khiếu nại', 'HE_THONG', null, null, 'SLA theo mức độ là tham số Cài đặt (R-CS-11).', 30),
  ('TICKET_CHANNEL', 'Kênh tiếp nhận ticket', 'MO', null, null, null, 31),
  ('SESSION_CANCEL_REASON', 'Lý do huỷ buổi', 'MO', null, null, 'Mã TT_ là lý do của trung tâm, HS_ là lý do của học sinh.', 32),
  ('REJECT_REASON', 'Lý do từ chối', 'MO', null, null,
   'Có cột "Áp dụng cho" (applies_to): báo giá, đơn, phiếu thu, lớp, ticket, yêu cầu buổi; để trống = áp dụng mọi nơi (R-HT-04).', 33),
  ('HOURS_ADJUST_REASON', 'Lý do điều chỉnh giờ', 'MO', null, null, null, 34),
  ('PAYMENT_METHOD', 'Hình thức thu tiền', 'MO', null, null, null, 35),
  ('RENEWAL_LOST_REASON', 'Lý do không tái tục', 'MO', null, null, 'Dùng khi phiếu tái tục chuyển L5 Không tái tục (R-GD-13).', 36),
  ('REVERSAL_REASON', 'Lý do đảo khoản tiền', 'MO', null, null, null, 37),
  ('ACCOUNT_LOCK_REASON', 'Lý do khoá tài khoản', 'MO', null, null, 'Chọn từ danh mục khi khoá tài khoản (R-HT-04).', 38);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  -- #8 Loại gói (Khoá)
  ('PACKAGE_TYPE', 'LC', 'Lớp chung', 1, false),
  ('PACKAGE_TYPE', 'VIP', 'VIP 1:1 và 1:2', 2, false),
  ('PACKAGE_TYPE', 'VNN', 'VIP nhóm nhỏ', 3, false),
  ('PACKAGE_TYPE', 'KR', 'Kèm riêng', 4, false),
  ('PACKAGE_TYPE', 'DV', 'Dịch vụ', 5, false),
  ('PACKAGE_TYPE', 'TL', 'Tài liệu', 6, false),
  -- #14 Hình thức test
  ('TEST_MODE', 'OFFLINE', 'Offline', 1, false),
  ('TEST_MODE', 'ONLINE', 'Online', 2, false),
  -- #15 Cấp độ đề test
  ('TEST_LEVEL', 'CO_BAN', 'Cơ bản', 1, false),
  ('TEST_LEVEL', 'NANG_CAO', 'Nâng cao', 2, false),
  -- #17 Lý do liên hệ khi điểm danh
  ('ATTENDANCE_CONTACT_REASON', 'KHONG_NGHE_MAY', 'Không nghe máy', 1, false),
  ('ATTENDANCE_CONTACT_REASON', 'DA_NHAC_VAO_LOP', 'Đã nhắc vào lớp', 2, false),
  ('ATTENDANCE_CONTACT_REASON', 'DA_VAO_LOP', 'Đã vào lớp', 3, false),
  ('ATTENDANCE_CONTACT_REASON', 'XIN_NGHI_HOC', 'Xin nghỉ học', 4, false),
  ('ATTENDANCE_CONTACT_REASON', 'KHAC', 'Khác', 5, true),
  -- #21 Mức độ khiếu nại (Khoá)
  ('COMPLAINT_SEVERITY', 'THAP', 'Thấp', 1, false),
  ('COMPLAINT_SEVERITY', 'TRUNG_BINH', 'Trung bình', 2, false),
  ('COMPLAINT_SEVERITY', 'CAO', 'Cao', 3, false),
  ('COMPLAINT_SEVERITY', 'NGHIEM_TRONG', 'Nghiêm trọng', 4, false),
  -- #22 Kênh tiếp nhận ticket
  ('TICKET_CHANNEL', 'GOI_DIEN', 'Gọi điện', 1, false),
  ('TICKET_CHANNEL', 'ZALO', 'Zalo', 2, false),
  ('TICKET_CHANNEL', 'TRUC_TIEP', 'Trực tiếp', 3, false),
  ('TICKET_CHANNEL', 'EMAIL', 'Email', 4, false),
  ('TICKET_CHANNEL', 'GIAO_VIEN_BAO', 'Giáo viên báo', 5, false),
  ('TICKET_CHANNEL', 'KHAC', 'Khác', 6, false),
  -- #23 Lý do huỷ buổi: trung tâm (TT_), học sinh (HS_)
  ('SESSION_CANCEL_REASON', 'TT_NGHI_LE_DOT_XUAT', 'Nghỉ lễ đột xuất', 1, false),
  ('SESSION_CANCEL_REASON', 'TT_GIAO_VIEN_NGHI', 'Giáo viên nghỉ', 2, false),
  ('SESSION_CANCEL_REASON', 'TT_SU_CO_CO_SO_VAT_CHAT', 'Sự cố cơ sở vật chất', 3, false),
  ('SESSION_CANCEL_REASON', 'TT_THOI_TIET', 'Thời tiết', 4, false),
  ('SESSION_CANCEL_REASON', 'HS_OM', 'Ốm', 5, false),
  ('SESSION_CANCEL_REASON', 'HS_VIEC_GIA_DINH', 'Việc gia đình', 6, false),
  ('SESSION_CANCEL_REASON', 'HS_THI_O_TRUONG', 'Thi ở trường', 7, false),
  ('SESSION_CANCEL_REASON', 'HS_KHAC', 'Khác', 8, true),
  -- #24 Lý do từ chối
  ('REJECT_REASON', 'THIEU_THONG_TIN', 'Thiếu thông tin', 1, false),
  ('REJECT_REASON', 'SAI_SO_TIEN', 'Sai số tiền', 2, false),
  ('REJECT_REASON', 'SAI_CHUNG_TU', 'Sai chứng từ', 3, false),
  ('REJECT_REASON', 'KHONG_DUNG_CHINH_SACH', 'Không đúng chính sách', 4, false),
  ('REJECT_REASON', 'KHAC', 'Khác', 5, true),
  -- #25 Lý do điều chỉnh giờ
  ('HOURS_ADJUST_REASON', 'SUA_SAI_DANH_SACH_DIEM_DANH', 'Sửa sai danh sách/điểm danh', 1, false),
  ('HOURS_ADJUST_REASON', 'BU_GIO_LOI_TRUNG_TAM', 'Bù giờ do lỗi trung tâm', 2, false),
  ('HOURS_ADJUST_REASON', 'TANG_GIO_CHAM_SOC', 'Tặng giờ chăm sóc (cần duyệt)', 3, false),
  ('HOURS_ADJUST_REASON', 'CHUYEN_DU_LIEU_CU', 'Chuyển dữ liệu từ hệ thống cũ', 4, false),
  ('HOURS_ADJUST_REASON', 'KHAC', 'Khác', 5, true),
  -- #26 Hình thức thu tiền
  ('PAYMENT_METHOD', 'TIEN_MAT', 'Tiền mặt', 1, false),
  ('PAYMENT_METHOD', 'CHUYEN_KHOAN', 'Chuyển khoản', 2, false),
  ('PAYMENT_METHOD', 'QUET_THE', 'Quẹt thẻ', 3, false),
  -- #28 Lý do không tái tục
  ('RENEWAL_LOST_REASON', 'HOC_PHI', 'Học phí', 1, false),
  ('RENEWAL_LOST_REASON', 'CHAT_LUONG', 'Chất lượng', 2, false),
  ('RENEWAL_LOST_REASON', 'LICH_HOC', 'Lịch học', 3, false),
  ('RENEWAL_LOST_REASON', 'CHUYEN_NHA', 'Chuyển nhà', 4, false),
  ('RENEWAL_LOST_REASON', 'HOC_NOI_KHAC', 'Học nơi khác', 5, false),
  ('RENEWAL_LOST_REASON', 'DU_MUC_TIEU', 'Đủ mục tiêu', 6, false),
  ('RENEWAL_LOST_REASON', 'KHAC', 'Khác', 7, true),
  -- #31 Lý do đảo khoản tiền
  ('REVERSAL_REASON', 'NHAP_SAI_SO_TIEN', 'Nhập sai số tiền', 1, false),
  ('REVERSAL_REASON', 'TRUNG_PHIEU', 'Trùng phiếu', 2, false),
  ('REVERSAL_REASON', 'SAI_DON_HOAC_SAI_KHACH', 'Sai đơn hoặc sai khách', 3, false),
  ('REVERSAL_REASON', 'KHAC', 'Khác', 4, true),
  -- #32 Lý do khoá tài khoản
  ('ACCOUNT_LOCK_REASON', 'NGHI_VIEC', 'Nghỉ việc', 1, false),
  ('ACCOUNT_LOCK_REASON', 'DUNG_HOC', 'Dừng học', 2, false),
  ('ACCOUNT_LOCK_REASON', 'TAM_NGHI', 'Tạm nghỉ', 3, false),
  ('ACCOUNT_LOCK_REASON', 'NGHI_LO_MAT_KHAU', 'Nghi lộ mật khẩu', 4, false),
  ('ACCOUNT_LOCK_REASON', 'KHAC', 'Khác', 5, true);

select set_config('hmt.migration', '', false);
