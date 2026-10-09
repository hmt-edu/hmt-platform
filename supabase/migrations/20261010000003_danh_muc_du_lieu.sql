-- GĐ0 bước 2: nạp dữ liệu danh mục thật (chạy cả trên bản chạy thật).
-- Nguồn: docs/spec/02-chuan-ma-va-danh-muc.md, docs/seed/*.csv (đã làm sạch, xem
-- docs/nghiep-vu/lam-sach-du-lieu-cu.md), danh sách 126 phường/xã Hà Nội theo NQ 1656/NQ-UBTVQH15.
-- File này sinh bằng script một lần; sửa dữ liệu sau này bằng migration mới hoặc màn quản trị.

select set_config('hmt.migration', 'on', false);

insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('STUDENT_STATUS', 'Tình trạng học sinh', 'HE_THONG', null, null, null, 1),
  ('ENROLLMENT_STATUS', 'Tình trạng ghi danh', 'HE_THONG', null, null, null, 2),
  ('ATTENDANCE_STATUS', 'Điểm danh', 'HE_THONG', null, null, 'Ô trống = chưa điểm danh. N cũ = buổi Huỷ, không phải điểm danh.', 3),
  ('SESSION_TYPE', 'Loại buổi', 'HE_THONG', null, null, 'CHINH, CUNG_CO trừ giờ; HOC_BU, BO_TRO không trừ giờ. Huỷ là tình trạng buổi, không phải loại buổi.', 4),
  ('CLASS_TYPE', 'Phân loại lớp', 'HE_THONG', null, null, null, 5),
  ('STUDY_MODE', 'Hình thức', 'HE_THONG', null, null, 'Thuộc ghi danh; lớp OMO nhận cả hai.', 6),
  ('TEST_STATUS', 'Tình trạng lịch test', 'HE_THONG', null, null, null, 7),
  ('DOC_TYPE', 'Loại chứng từ', 'HE_THONG', null, null, 'Tiền tố mã chứng từ Loại-CS-NămTháng-STT.', 8),
  ('MODULE', 'Phân hệ', 'HE_THONG', null, null, 'Dùng cho công tắc tính năng theo cơ sở.', 9),
  ('SUBJECT', 'Môn', 'MO', null, null, 'DAI, HINH chỉ dùng cho lớp (Toán từ khối 7).', 10),
  ('GRADE', 'Khối', 'MO', null, null, null, 11),
  ('LEVEL', 'Trình độ', 'MO', null, null, 'S cao nhất. Chỉ cho lớp CB, NC.', 12),
  ('FRAMEWORK_LEVEL', 'Cấp độ khung chương trình', 'MO', null, null, null, 13),
  ('SOURCE_TYPE', 'Loại nguồn', 'MO', null, null, 'Tầng 1 của nguồn khách.', 14),
  ('SOURCE', 'Nguồn', 'MO', 'SOURCE_TYPE', null, 'Tầng 2 của nguồn khách.', 15),
  ('SOURCE_CHANNEL', 'Kênh', 'MO', 'SOURCE', null, 'Tầng 3 của nguồn khách (không bắt buộc).', 16),
  ('LEAD_STAGE', 'Giai đoạn lead', 'MO', null, null, null, 17),
  ('LEAD_SUBSTAGE', 'Giai đoạn con lead', 'MO', 'LEAD_STAGE', null, null, 18),
  ('OPP_STAGE', 'Giai đoạn cơ hội', 'MO', null, null, null, 19),
  ('OPP_SUBSTAGE', 'Giai đoạn con cơ hội', 'MO', 'OPP_STAGE', null, null, 20),
  ('TEST_CANCEL_REASON', 'Lý do huỷ test', 'MO', null, 'OPP_SUBSTAGE', 'Mỗi lý do nối với một giai đoạn con L5x của cơ hội.', 21),
  ('ACTIVITY_TYPE', 'Loại hoạt động', 'MO', null, null, null, 22),
  ('PROVINCE', 'Tỉnh/Thành phố', 'MO', null, null, '34 tỉnh, thành sau sắp xếp 2025.', 23),
  ('WARD', 'Phường/Xã', 'MO', 'PROVINCE', null, 'Hiện nạp đủ 126 phường/xã Hà Nội; tỉnh khác chưa nạp.', 24);

-- STUDENT_STATUS
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('STUDENT_STATUS', 'TIEM_NANG', 'Tiềm năng', 1, null),
  ('STUDENT_STATUS', 'DANG_HOC', 'Đang học', 2, null),
  ('STUDENT_STATUS', 'BAO_LUU', 'Bảo lưu', 3, null),
  ('STUDENT_STATUS', 'DUNG_HOC', 'Dừng học', 4, null);

-- ENROLLMENT_STATUS
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('ENROLLMENT_STATUS', 'CHO_XEP_LOP', 'Chờ xếp lớp', 1, null),
  ('ENROLLMENT_STATUS', 'DANG_HOC', 'Đang học', 2, null),
  ('ENROLLMENT_STATUS', 'BAO_LUU', 'Bảo lưu', 3, null),
  ('ENROLLMENT_STATUS', 'HOAN_THANH', 'Hoàn thành', 4, null),
  ('ENROLLMENT_STATUS', 'CHUYEN_LOP', 'Chuyển lớp', 5, null),
  ('ENROLLMENT_STATUS', 'DUNG', 'Dừng', 6, null),
  ('ENROLLMENT_STATUS', 'HOAN_PHI', 'Hoàn phí', 7, null);

-- ATTENDANCE_STATUS
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('ATTENDANCE_STATUS', 'CO_MAT', 'Có mặt', 1, 'X'),
  ('ATTENDANCE_STATUS', 'DI_MUON', 'Đi muộn', 2, null),
  ('ATTENDANCE_STATUS', 'VANG_CO_PHEP', 'Vắng có phép', 3, 'P'),
  ('ATTENDANCE_STATUS', 'VANG_KHONG_PHEP', 'Vắng không phép', 4, 'KP');

-- SESSION_TYPE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('SESSION_TYPE', 'CHINH', 'Buổi chính', 1, null),
  ('SESSION_TYPE', 'CUNG_CO', 'Buổi củng cố', 2, null),
  ('SESSION_TYPE', 'HOC_BU', 'Học bù', 3, null),
  ('SESSION_TYPE', 'BO_TRO', 'Học bổ trợ', 4, null);

-- CLASS_TYPE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('CLASS_TYPE', 'CB', 'Cơ bản', 1, null),
  ('CLASS_TYPE', 'NC', 'Nâng cao', 2, null),
  ('CLASS_TYPE', 'LR', 'Lớp riêng', 3, null);

-- STUDY_MODE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('STUDY_MODE', 'OFF', 'Offline', 1, null),
  ('STUDY_MODE', 'ONL', 'Online', 2, null);

-- TEST_STATUS
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('TEST_STATUS', 'DRAFT', 'Nháp', 1, 'Draft'),
  ('TEST_STATUS', 'TESTING', 'Đang test', 2, 'Testing'),
  ('TEST_STATUS', 'TEACHER_REVIEW', 'Chờ giáo viên nhận xét', 3, 'Teacher Review'),
  ('TEST_STATUS', 'COMPLETED', 'Hoàn thành', 4, 'Completed'),
  ('TEST_STATUS', 'CANCELLED', 'Đã huỷ', 5, 'Cancelled'),
  ('TEST_STATUS', 'REJECTED', 'Từ chối', 6, 'Rejected');

-- DOC_TYPE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('DOC_TYPE', 'BG', 'Báo giá', 1, null),
  ('DOC_TYPE', 'DH', 'Đơn hàng', 2, null),
  ('DOC_TYPE', 'PT', 'Phiếu thu', 3, null),
  ('DOC_TYPE', 'PC', 'Phiếu chi (hoàn phí)', 4, null);

-- MODULE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('MODULE', 'BAN_HANG', 'Bán hàng (lead, cơ hội, test, báo giá, đơn, phiếu thu)', 1, null),
  ('MODULE', 'VAN_HANH_LOP', 'Vận hành lớp (ghi danh, lớp, buổi, điểm danh)', 2, null),
  ('MODULE', 'CONG_GIAO_VIEN', 'Cổng giáo viên', 3, null),
  ('MODULE', 'HOC_TAP', 'Học tập (LMS)', 4, null),
  ('MODULE', 'BAO_CAO', 'Báo cáo', 5, null);

-- SUBJECT
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('SUBJECT', 'TOAN', 'Toán', 1, null),
  ('SUBJECT', 'DAI', 'Đại số', 2, null),
  ('SUBJECT', 'HINH', 'Hình học', 3, null),
  ('SUBJECT', 'LY', 'Vật lý', 4, null),
  ('SUBJECT', 'HOA', 'Hoá học', 5, null),
  ('SUBJECT', 'VAN', 'Ngữ văn', 6, null),
  ('SUBJECT', 'ANH', 'Tiếng Anh', 7, null),
  ('SUBJECT', 'KHTN', 'Khoa học tự nhiên', 8, null),
  ('SUBJECT', 'TRUNG', 'Tiếng Trung', 9, null),
  ('SUBJECT', 'SAT', 'SAT', 10, null);

-- GRADE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('GRADE', 'K02', 'Khối 2', 1, null),
  ('GRADE', 'K03', 'Khối 3', 2, null),
  ('GRADE', 'K04', 'Khối 4', 3, null),
  ('GRADE', 'K05', 'Khối 5', 4, null),
  ('GRADE', 'K06', 'Khối 6', 5, null),
  ('GRADE', 'K07', 'Khối 7', 6, null),
  ('GRADE', 'K08', 'Khối 8', 7, null),
  ('GRADE', 'K09', 'Khối 9', 8, null),
  ('GRADE', 'K10', 'Khối 10', 9, null),
  ('GRADE', 'K11', 'Khối 11', 10, null),
  ('GRADE', 'K12', 'Khối 12', 11, null);

-- LEVEL
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('LEVEL', 'S', 'S', 1, null),
  ('LEVEL', 'A', 'A', 2, null),
  ('LEVEL', 'B', 'B', 3, null),
  ('LEVEL', 'C', 'C', 4, null);

-- FRAMEWORK_LEVEL
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('FRAMEWORK_LEVEL', 'CB', 'Cơ bản', 1, null),
  ('FRAMEWORK_LEVEL', 'NC', 'Nâng cao', 2, null);

-- SOURCE_TYPE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('SOURCE_TYPE', 'MARKETING', 'Marketing', 1, 'Marketing'),
  ('SOURCE_TYPE', 'TELEMARKETING', 'Telemarketing', 2, 'Telemarketing'),
  ('SOURCE_TYPE', 'EVENT', 'Event', 3, 'Event'),
  ('SOURCE_TYPE', 'REFERRAL', 'Referral', 4, 'Referral'),
  ('SOURCE_TYPE', 'UPSALE', 'Upsale', 5, 'Upsale'),
  ('SOURCE_TYPE', 'BAN_GIAM_DOC', 'Ban Giám Đốc', 6, 'Ban Giám Đốc');

-- SOURCE (mục cha thuộc SOURCE_TYPE)
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, legacy_ref)
select v.catalog_code, v.code, v.name, v.sort_order, p.id, v.legacy_ref from (values
  ('SOURCE', 'FACEBOOK_ADS', 'Facebook Ads', 1, 'MARKETING', 'Facebook Ads'),
  ('SOURCE', 'GOOGLE_ADS', 'Google Ads', 2, 'MARKETING', 'Google Ads'),
  ('SOURCE', 'WEBSITE', 'Website', 3, 'MARKETING', 'Website'),
  ('SOURCE', 'HOTLINE', 'Hotline', 4, 'MARKETING', 'Hotline'),
  ('SOURCE', 'WALK_IN', 'Walk-in', 5, 'MARKETING', 'Walk-in'),
  ('SOURCE', 'ZALO', 'Zalo', 6, 'MARKETING', 'Zalo'),
  ('SOURCE', 'COLD_CALL', 'Cold Call', 7, 'TELEMARKETING', 'Cold Call'),
  ('SOURCE', 'EVENT', 'Event', 8, 'EVENT', 'Event'),
  ('SOURCE', 'REFERRAL', 'Referral', 9, 'REFERRAL', 'Referral'),
  ('SOURCE', 'UPSALE', 'Upsale', 10, 'UPSALE', 'Upsale'),
  ('SOURCE', 'BAN_GIAM_DOC', 'Ban Giám Đốc', 11, 'BAN_GIAM_DOC', 'Ban Giám Đốc')
) as v (catalog_code, code, name, sort_order, parent_code, legacy_ref)
join app.catalog_item p on p.catalog_code = 'SOURCE_TYPE' and p.code = v.parent_code
order by v.sort_order;

-- SOURCE_CHANNEL (mục cha thuộc SOURCE)
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, legacy_ref)
select v.catalog_code, v.code, v.name, v.sort_order, p.id, v.legacy_ref from (values
  ('SOURCE_CHANNEL', 'FACEBOOK_ADS_CHAT', 'Chat', 1, 'FACEBOOK_ADS', 'Facebook Ads: Chat'),
  ('SOURCE_CHANNEL', 'FACEBOOK_ADS_COMMENT', 'Comment', 2, 'FACEBOOK_ADS', 'Facebook Ads: Comment'),
  ('SOURCE_CHANNEL', 'FACEBOOK_ADS_INBOX', 'Inbox', 3, 'FACEBOOK_ADS', 'Facebook Ads: Inbox'),
  ('SOURCE_CHANNEL', 'FACEBOOK_ADS_LEAD_FORM', 'Lead Form', 4, 'FACEBOOK_ADS', 'Facebook Ads: Lead Form'),
  ('SOURCE_CHANNEL', 'COLD_CALL_BUY', 'Buy', 5, 'COLD_CALL', 'Cold Call: Buy'),
  ('SOURCE_CHANNEL', 'COLD_CALL_CRAWL', 'Crawl', 6, 'COLD_CALL', 'Cold Call: Crawl'),
  ('SOURCE_CHANNEL', 'COLD_CALL_FLYER', 'Flyer', 7, 'COLD_CALL', 'Cold Call: Flyer'),
  ('SOURCE_CHANNEL', 'EVENT_INDOOR', 'Indoor', 8, 'EVENT', 'Event: Indoor'),
  ('SOURCE_CHANNEL', 'EVENT_OUTDOOR', 'Outdoor', 9, 'EVENT', 'Event: Outdoor'),
  ('SOURCE_CHANNEL', 'REFERRAL_BY_CUSTOMER', 'By Customer', 10, 'REFERRAL', 'Referral: By Customer'),
  ('SOURCE_CHANNEL', 'REFERRAL_BY_HMT', 'By HMT', 11, 'REFERRAL', 'Referral: By HMT'),
  ('SOURCE_CHANNEL', 'UPSALE_RENEW_LOST', 'Renew Lost', 12, 'UPSALE', 'Upsale: Renew Lost'),
  ('SOURCE_CHANNEL', 'UPSALE_NEW_OPP', 'New Opp', 13, 'UPSALE', 'Upsale: New Opp'),
  ('SOURCE_CHANNEL', 'UPSALE_CROSS_SALE', 'Cross-Sale', 14, 'UPSALE', 'Upsale: Cross-Sale')
) as v (catalog_code, code, name, sort_order, parent_code, legacy_ref)
join app.catalog_item p on p.catalog_code = 'SOURCE' and p.code = v.parent_code
order by v.sort_order;

-- LEAD_STAGE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('LEAD_STAGE', 'C1', 'Data mới', 1, null),
  ('LEAD_STAGE', 'C2', 'Chưa liên hệ được', 2, null),
  ('LEAD_STAGE', 'C3', 'Không có nhu cầu', 3, null),
  ('LEAD_STAGE', 'C4', 'Khách hàng tiềm năng', 4, null);

-- LEAD_SUBSTAGE (mục cha thuộc LEAD_STAGE)
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, legacy_ref)
select v.catalog_code, v.code, v.name, v.sort_order, p.id, v.legacy_ref from (values
  ('LEAD_SUBSTAGE', 'C2A', 'Không nghe máy', 1, 'C2', null),
  ('LEAD_SUBSTAGE', 'C2B', 'Không liên lạc được', 2, 'C2', null),
  ('LEAD_SUBSTAGE', 'C2C', 'Bận gọi lại sau', 3, 'C2', null),
  ('LEAD_SUBSTAGE', 'C3A', 'Không có nhu cầu', 4, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3B', 'Chưa có nhu cầu ở thời điểm hiện tại', 5, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3C', 'Đang học ở nơi khác', 6, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3D', 'Không phù hợp về sản phẩm', 7, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3E', 'Không phù hợp về giá', 8, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3F', 'Không phù hợp về độ tuổi', 9, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3G', 'Không phù hợp về địa điểm', 10, 'C3', null),
  ('LEAD_SUBSTAGE', 'C3H', 'Không nghe máy nhiều lần', 11, 'C3', null),
  ('LEAD_SUBSTAGE', 'C4A', 'Cần gửi thêm thông tin', 12, 'C4', null),
  ('LEAD_SUBSTAGE', 'C4B', 'Cần trao đổi thêm', 13, 'C4', null),
  ('LEAD_SUBSTAGE', 'C4C', 'Đủ điều kiện tạo opp', 14, 'C4', null),
  ('LEAD_SUBSTAGE', 'C4D', 'Tạo opp thành công', 15, 'C4', null)
) as v (catalog_code, code, name, sort_order, parent_code, legacy_ref)
join app.catalog_item p on p.catalog_code = 'LEAD_STAGE' and p.code = v.parent_code
order by v.sort_order;

-- OPP_STAGE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('OPP_STAGE', 'L1', 'Khách hàng mới', 1, null),
  ('OPP_STAGE', 'L2', 'Chưa liên hệ được', 2, null),
  ('OPP_STAGE', 'L3', 'Không có nhu cầu', 3, null),
  ('OPP_STAGE', 'L4', 'Khách hàng tiềm năng', 4, null),
  ('OPP_STAGE', 'L5', 'Đồng ý tham gia test', 5, null),
  ('OPP_STAGE', 'L6', 'Đã tham gia test', 6, null),
  ('OPP_STAGE', 'L7', 'Tư vấn', 7, null),
  ('OPP_STAGE', 'L8', 'Đăng ký học', 8, null);

-- OPP_SUBSTAGE (mục cha thuộc OPP_STAGE)
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, legacy_ref)
select v.catalog_code, v.code, v.name, v.sort_order, p.id, v.legacy_ref from (values
  ('OPP_SUBSTAGE', 'L2A', 'Không nghe máy', 1, 'L2', null),
  ('OPP_SUBSTAGE', 'L2B', 'Không liên lạc được', 2, 'L2', null),
  ('OPP_SUBSTAGE', 'L2C', 'Bận gọi lại sau', 3, 'L2', null),
  ('OPP_SUBSTAGE', 'L3A', 'Không có nhu cầu', 4, 'L3', null),
  ('OPP_SUBSTAGE', 'L3B', 'Chưa có nhu cầu ở thời điểm hiện tại', 5, 'L3', null),
  ('OPP_SUBSTAGE', 'L3C', 'Đang học ở nơi khác', 6, 'L3', null),
  ('OPP_SUBSTAGE', 'L3D', 'Không phù hợp về sản phẩm', 7, 'L3', null),
  ('OPP_SUBSTAGE', 'L3E', 'Không phù hợp về giá', 8, 'L3', null),
  ('OPP_SUBSTAGE', 'L3F', 'Không phù hợp về độ tuổi', 9, 'L3', null),
  ('OPP_SUBSTAGE', 'L3G', 'Không phù hợp về địa điểm', 10, 'L3', null),
  ('OPP_SUBSTAGE', 'L3H', 'Không nghe máy nhiều lần', 11, 'L3', 'L3I'),
  ('OPP_SUBSTAGE', 'L4A', 'Tiềm năng, cần gửi thêm thông tin', 12, 'L4', null),
  ('OPP_SUBSTAGE', 'L4B', 'Tiềm năng, cần tư vấn thêm', 13, 'L4', null),
  ('OPP_SUBSTAGE', 'L4C', 'Tiềm năng, cần tham khảo ý kiến', 14, 'L4', null),
  ('OPP_SUBSTAGE', 'L4D', 'Tiềm năng, cần gọi lại vào dịp khác', 15, 'L4', null),
  ('OPP_SUBSTAGE', 'L5A', 'Đồng ý tham gia test', 16, 'L5', null),
  ('OPP_SUBSTAGE', 'L5B', 'Đồng ý tham gia test, đã xếp lớp thành công', 17, 'L5', null),
  ('OPP_SUBSTAGE', 'L5C', 'Huỷ test, không liên hệ được', 18, 'L5', null),
  ('OPP_SUBSTAGE', 'L5D', 'Huỷ test, PH bận không đưa đón được', 19, 'L5', null),
  ('OPP_SUBSTAGE', 'L5E', 'Huỷ test, con bận không tham gia được', 20, 'L5', null),
  ('OPP_SUBSTAGE', 'L5F', 'Huỷ test, con không muốn tham gia', 21, 'L5', null),
  ('OPP_SUBSTAGE', 'L5G', 'Huỷ test, con đang ôn thi', 22, 'L5', null),
  ('OPP_SUBSTAGE', 'L5H', 'Huỷ test, con ốm', 23, 'L5', null),
  ('OPP_SUBSTAGE', 'L5I', 'Huỷ test, gia đình đi du lịch', 24, 'L5', null),
  ('OPP_SUBSTAGE', 'L5K', 'Huỷ test, thời tiết không thuận lợi', 25, 'L5', null),
  ('OPP_SUBSTAGE', 'L5N', 'Huỷ test, con đang ở quê', 26, 'L5', null),
  ('OPP_SUBSTAGE', 'L5M', 'Huỷ test, lý do khác', 27, 'L5', null),
  ('OPP_SUBSTAGE', 'L5O', 'Huỷ test nhiều lần', 28, 'L5', null),
  ('OPP_SUBSTAGE', 'L6A', 'Đã tham gia test, chưa có kết quả test', 29, 'L6', null),
  ('OPP_SUBSTAGE', 'L6B', 'Đã tham gia test, có kết quả test, cần phân loại', 30, 'L6', null),
  ('OPP_SUBSTAGE', 'L6C', 'Đã tham gia test, học xuất sắc', 31, 'L6', null),
  ('OPP_SUBSTAGE', 'L6D', 'Đã tham gia test, học tốt', 32, 'L6', null),
  ('OPP_SUBSTAGE', 'L6E', 'Đã tham gia test, học khá', 33, 'L6', null),
  ('OPP_SUBSTAGE', 'L6F', 'Đã tham gia test, học trung bình', 34, 'L6', null),
  ('OPP_SUBSTAGE', 'L6G', 'Đã tham gia test, học yếu', 35, 'L6', null),
  ('OPP_SUBSTAGE', 'L7A', 'Cần đặt lịch tư vấn', 36, 'L7', null),
  ('OPP_SUBSTAGE', 'L7B', 'Đã tư vấn, khách hàng tiềm năng', 37, 'L7', null),
  ('OPP_SUBSTAGE', 'L7C', 'Đã tư vấn, dự thu', 38, 'L7', null),
  ('OPP_SUBSTAGE', 'L7D', 'Đã tư vấn, cần trao đổi thêm', 39, 'L7', null),
  ('OPP_SUBSTAGE', 'L7E', 'Đã tư vấn, PH cân nhắc học phí', 40, 'L7', null),
  ('OPP_SUBSTAGE', 'L7F', 'Đã tư vấn, PH cân nhắc chương trình học', 41, 'L7', null),
  ('OPP_SUBSTAGE', 'L7G', 'Đã tư vấn, PH cân nhắc thời gian học', 42, 'L7', null),
  ('OPP_SUBSTAGE', 'L7H', 'Đã tư vấn, PH cân nhắc địa điểm học', 43, 'L7', null),
  ('OPP_SUBSTAGE', 'L7I', 'Đã tư vấn, PH cân nhắc hình thức học', 44, 'L7', null),
  ('OPP_SUBSTAGE', 'L7K', 'Đã tư vấn, PH cần trao đổi với người thân', 45, 'L7', null),
  ('OPP_SUBSTAGE', 'L7L', 'Đã tư vấn, PH cần trao đổi với con', 46, 'L7', null),
  ('OPP_SUBSTAGE', 'L8A', 'PH đặt cọc', 47, 'L8', null),
  ('OPP_SUBSTAGE', 'L8B', 'PH thanh toán chia để trả', 48, 'L8', null),
  ('OPP_SUBSTAGE', 'L8C', 'PH hoàn thành 100% học phí', 49, 'L8', null)
) as v (catalog_code, code, name, sort_order, parent_code, legacy_ref)
join app.catalog_item p on p.catalog_code = 'OPP_STAGE' and p.code = v.parent_code
order by v.sort_order;

-- TEST_CANCEL_REASON (nối với giai đoạn con L5x của cơ hội; mã lý do = mã giai đoạn con)
insert into app.catalog_item (catalog_code, code, name, sort_order, linked_item_id)
select 'TEST_CANCEL_REASON', v.code, v.name, v.sort_order, l.id from (values
  ('L5C', 'Huỷ test, không liên hệ được', 1),
  ('L5D', 'Huỷ test, PH bận không đưa đón được', 2),
  ('L5E', 'Huỷ test, con bận không tham gia được', 3),
  ('L5F', 'Huỷ test, con không muốn tham gia', 4),
  ('L5G', 'Huỷ test, con đang ôn thi', 5),
  ('L5H', 'Huỷ test, con ốm', 6),
  ('L5I', 'Huỷ test, gia đình đi du lịch', 7),
  ('L5K', 'Huỷ test, thời tiết không thuận lợi', 8),
  ('L5N', 'Huỷ test, con đang ở quê', 9),
  ('L5M', 'Huỷ test, lý do khác', 10),
  ('L5O', 'Huỷ test nhiều lần', 11)
) as v (code, name, sort_order)
join app.catalog_item l on l.catalog_code = 'OPP_SUBSTAGE' and l.code = v.code
order by v.sort_order;

-- ACTIVITY_TYPE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('ACTIVITY_TYPE', 'GOI_DIEN', 'Gọi điện', 1, 'Call'),
  ('ACTIVITY_TYPE', 'ZALO', 'Zalo', 2, 'Zalo'),
  ('ACTIVITY_TYPE', 'EMAIL', 'Email', 3, 'Email'),
  ('ACTIVITY_TYPE', 'GAP_TRUC_TIEP', 'Gặp trực tiếp', 4, null),
  ('ACTIVITY_TYPE', 'SMS', 'SMS', 5, null),
  ('ACTIVITY_TYPE', 'NHAC_THU_TIEN', 'Nhắc thu tiền', 6, 'Thu tiền');

-- PROVINCE
insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('PROVINCE', 'HA_NOI', 'Hà Nội', 1, null),
  ('PROVINCE', 'AN_GIANG', 'An Giang', 2, null),
  ('PROVINCE', 'BAC_NINH', 'Bắc Ninh', 3, null),
  ('PROVINCE', 'CAO_BANG', 'Cao Bằng', 4, null),
  ('PROVINCE', 'CA_MAU', 'Cà Mau', 5, null),
  ('PROVINCE', 'CAN_THO', 'Cần Thơ', 6, null),
  ('PROVINCE', 'GIA_LAI', 'Gia Lai', 7, null),
  ('PROVINCE', 'HUE', 'Huế', 8, null),
  ('PROVINCE', 'HA_TINH', 'Hà Tĩnh', 9, null),
  ('PROVINCE', 'HUNG_YEN', 'Hưng Yên', 10, null),
  ('PROVINCE', 'HAI_PHONG', 'Hải Phòng', 11, null),
  ('PROVINCE', 'KHANH_HOA', 'Khánh Hòa', 12, null),
  ('PROVINCE', 'LAI_CHAU', 'Lai Châu', 13, null),
  ('PROVINCE', 'LAO_CAI', 'Lào Cai', 14, null),
  ('PROVINCE', 'LAM_DONG', 'Lâm Đồng', 15, null),
  ('PROVINCE', 'LANG_SON', 'Lạng Sơn', 16, null),
  ('PROVINCE', 'NGHE_AN', 'Nghệ An', 17, null),
  ('PROVINCE', 'NINH_BINH', 'Ninh Bình', 18, null),
  ('PROVINCE', 'PHU_THO', 'Phú Thọ', 19, null),
  ('PROVINCE', 'QUANG_NGAI', 'Quảng Ngãi', 20, null),
  ('PROVINCE', 'QUANG_NINH', 'Quảng Ninh', 21, null),
  ('PROVINCE', 'QUANG_TRI', 'Quảng Trị', 22, null),
  ('PROVINCE', 'SON_LA', 'Sơn La', 23, null),
  ('PROVINCE', 'TP_HO_CHI_MINH', 'TP. Hồ Chí Minh', 24, null),
  ('PROVINCE', 'THANH_HOA', 'Thanh Hóa', 25, null),
  ('PROVINCE', 'THAI_NGUYEN', 'Thái Nguyên', 26, null),
  ('PROVINCE', 'TUYEN_QUANG', 'Tuyên Quang', 27, null),
  ('PROVINCE', 'TAY_NINH', 'Tây Ninh', 28, null),
  ('PROVINCE', 'VINH_LONG', 'Vĩnh Long', 29, null),
  ('PROVINCE', 'DIEN_BIEN', 'Điện Biên', 30, null),
  ('PROVINCE', 'DA_NANG', 'Đà Nẵng', 31, null),
  ('PROVINCE', 'DAK_LAK', 'Đắk Lắk', 32, null),
  ('PROVINCE', 'DONG_NAI', 'Đồng Nai', 33, null),
  ('PROVINCE', 'DONG_THAP', 'Đồng Tháp', 34, null);

-- WARD (mục cha thuộc PROVINCE)
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, legacy_ref)
select v.catalog_code, v.code, v.name, v.sort_order, p.id, v.legacy_ref from (values
  ('WARD', 'HN_BA_DINH', 'Phường Ba Đình', 1, 'HA_NOI', 'Ba Đình'),
  ('WARD', 'HN_BACH_MAI', 'Phường Bạch Mai', 2, 'HA_NOI', 'Bạch Mai'),
  ('WARD', 'HN_BO_DE', 'Phường Bồ Đề', 3, 'HA_NOI', 'Bồ Đề'),
  ('WARD', 'HN_CAU_GIAY', 'Phường Cầu Giấy', 4, 'HA_NOI', 'Cầu Giấy'),
  ('WARD', 'HN_CHUONG_MY', 'Phường Chương Mỹ', 5, 'HA_NOI', 'Chương Mỹ'),
  ('WARD', 'HN_CUA_NAM', 'Phường Cửa Nam', 6, 'HA_NOI', 'Cửa Nam'),
  ('WARD', 'HN_DUONG_NOI', 'Phường Dương Nội', 7, 'HA_NOI', 'Dương Nội'),
  ('WARD', 'HN_DAI_MO', 'Phường Đại Mỗ', 8, 'HA_NOI', 'Đại Mỗ'),
  ('WARD', 'HN_DINH_CONG', 'Phường Định Công', 9, 'HA_NOI', null),
  ('WARD', 'HN_DONG_NGAC', 'Phường Đông Ngạc', 10, 'HA_NOI', 'Đông Ngạc'),
  ('WARD', 'HN_DONG_DA', 'Phường Đống Đa', 11, 'HA_NOI', 'Đống Đa'),
  ('WARD', 'HN_GIANG_VO', 'Phường Giảng Võ', 12, 'HA_NOI', 'Giảng Võ'),
  ('WARD', 'HN_HAI_BA_TRUNG', 'Phường Hai Bà Trưng', 13, 'HA_NOI', 'Hai Bà Trưng'),
  ('WARD', 'HN_HA_DONG', 'Phường Hà Đông', 14, 'HA_NOI', 'Hà Đông'),
  ('WARD', 'HN_HOAN_KIEM', 'Phường Hoàn Kiếm', 15, 'HA_NOI', 'Hoàn Kiếm'),
  ('WARD', 'HN_HOANG_LIET', 'Phường Hoàng Liệt', 16, 'HA_NOI', null),
  ('WARD', 'HN_HOANG_MAI', 'Phường Hoàng Mai', 17, 'HA_NOI', 'Hoàng Mai'),
  ('WARD', 'HN_HONG_HA', 'Phường Hồng Hà', 18, 'HA_NOI', 'Hồng Hà'),
  ('WARD', 'HN_KHUONG_DINH', 'Phường Khương Đình', 19, 'HA_NOI', null),
  ('WARD', 'HN_KIEN_HUNG', 'Phường Kiến Hưng', 20, 'HA_NOI', 'Kiến Hưng'),
  ('WARD', 'HN_KIM_LIEN', 'Phường Kim Liên', 21, 'HA_NOI', 'Kim Liên'),
  ('WARD', 'HN_LANG', 'Phường Láng', 22, 'HA_NOI', 'Láng'),
  ('WARD', 'HN_LINH_NAM', 'Phường Lĩnh Nam', 23, 'HA_NOI', 'Lĩnh Nam'),
  ('WARD', 'HN_LONG_BIEN', 'Phường Long Biên', 24, 'HA_NOI', 'Long Biên'),
  ('WARD', 'HN_NGHIA_DO', 'Phường Nghĩa Đô', 25, 'HA_NOI', 'Nghĩa Đô'),
  ('WARD', 'HN_NGOC_HA', 'Phường Ngọc Hà', 26, 'HA_NOI', 'Ngọc Hà'),
  ('WARD', 'HN_O_CHO_DUA', 'Phường Ô Chợ Dừa', 27, 'HA_NOI', 'Ô Chợ Dừa'),
  ('WARD', 'HN_PHU_DIEN', 'Phường Phú Diễn', 28, 'HA_NOI', 'Phú Diễn'),
  ('WARD', 'HN_PHU_LUONG', 'Phường Phú Lương', 29, 'HA_NOI', 'Phú Lương'),
  ('WARD', 'HN_PHU_THUONG', 'Phường Phú Thượng', 30, 'HA_NOI', 'Phú Thượng'),
  ('WARD', 'HN_PHUC_LOI', 'Phường Phúc Lợi', 31, 'HA_NOI', 'Phúc Lợi'),
  ('WARD', 'HN_PHUONG_LIET', 'Phường Phương Liệt', 32, 'HA_NOI', null),
  ('WARD', 'HN_SON_TAY', 'Phường Sơn Tây', 33, 'HA_NOI', 'Sơn Tây'),
  ('WARD', 'HN_TAY_HO', 'Phường Tây Hồ', 34, 'HA_NOI', 'Tây Hồ'),
  ('WARD', 'HN_TAY_MO', 'Phường Tây Mỗ', 35, 'HA_NOI', 'Tây Mỗ'),
  ('WARD', 'HN_TAY_TUU', 'Phường Tây Tựu', 36, 'HA_NOI', null),
  ('WARD', 'HN_THANH_LIET', 'Phường Thanh Liệt', 37, 'HA_NOI', 'Thanh Liệt'),
  ('WARD', 'HN_THANH_XUAN', 'Phường Thanh Xuân', 38, 'HA_NOI', null),
  ('WARD', 'HN_THUONG_CAT', 'Phường Thượng Cát', 39, 'HA_NOI', 'Thượng Cát'),
  ('WARD', 'HN_TUNG_THIEN', 'Phường Tùng Thiện', 40, 'HA_NOI', 'Tùng Thiện'),
  ('WARD', 'HN_TUONG_MAI', 'Phường Tương Mai', 41, 'HA_NOI', 'Tương Mai'),
  ('WARD', 'HN_TU_LIEM', 'Phường Từ Liêm', 42, 'HA_NOI', 'Từ Liêm'),
  ('WARD', 'HN_VAN_MIEU_QUOC_TU_GIAM', 'Phường Văn Miếu - Quốc Tử Giám', 43, 'HA_NOI', 'Văn Miếu - Quốc Tử Giám'),
  ('WARD', 'HN_VIET_HUNG', 'Phường Việt Hưng', 44, 'HA_NOI', 'Việt Hưng'),
  ('WARD', 'HN_VINH_HUNG', 'Phường Vĩnh Hưng', 45, 'HA_NOI', 'Vĩnh Hưng'),
  ('WARD', 'HN_VINH_TUY', 'Phường Vĩnh Tuy', 46, 'HA_NOI', 'Vĩnh Tuy'),
  ('WARD', 'HN_XUAN_DINH', 'Phường Xuân Đỉnh', 47, 'HA_NOI', 'Xuân Đỉnh'),
  ('WARD', 'HN_XUAN_PHUONG', 'Phường Xuân Phương', 48, 'HA_NOI', null),
  ('WARD', 'HN_YEN_HOA', 'Phường Yên Hòa', 49, 'HA_NOI', 'Yên Hòa'),
  ('WARD', 'HN_YEN_NGHIA', 'Phường Yên Nghĩa', 50, 'HA_NOI', 'Yên Nghĩa'),
  ('WARD', 'HN_YEN_SO', 'Phường Yên Sở', 51, 'HA_NOI', 'Yên Sở'),
  ('WARD', 'HN_AN_KHANH', 'Xã An Khánh', 52, 'HA_NOI', null),
  ('WARD', 'HN_BA_VI', 'Xã Ba Vì', 53, 'HA_NOI', 'Ba Vì'),
  ('WARD', 'HN_BAT_TRANG', 'Xã Bát Tràng', 54, 'HA_NOI', null),
  ('WARD', 'HN_BAT_BAT', 'Xã Bất Bạt', 55, 'HA_NOI', null),
  ('WARD', 'HN_BINH_MINH', 'Xã Bình Minh', 56, 'HA_NOI', 'Bình Minh'),
  ('WARD', 'HN_CHUYEN_MY', 'Xã Chuyên Mỹ', 57, 'HA_NOI', null),
  ('WARD', 'HN_CHUONG_DUONG', 'Xã Chương Dương', 58, 'HA_NOI', 'Chương Dương'),
  ('WARD', 'HN_CO_DO', 'Xã Cổ Đô', 59, 'HA_NOI', null),
  ('WARD', 'HN_DAN_HOA', 'Xã Dân Hòa', 60, 'HA_NOI', 'Dân Hòa'),
  ('WARD', 'HN_DUONG_HOA', 'Xã Dương Hòa', 61, 'HA_NOI', 'Dương Hòa'),
  ('WARD', 'HN_DA_PHUC', 'Xã Đa Phúc', 62, 'HA_NOI', 'Đa Phúc'),
  ('WARD', 'HN_DAN_PHUONG', 'Xã Đan Phượng', 63, 'HA_NOI', 'Đan Phượng'),
  ('WARD', 'HN_DAI_THANH', 'Xã Đại Thanh', 64, 'HA_NOI', 'Đại Thanh'),
  ('WARD', 'HN_DAI_XUYEN', 'Xã Đại Xuyên', 65, 'HA_NOI', null),
  ('WARD', 'HN_DOAI_PHUONG', 'Xã Đoài Phương', 66, 'HA_NOI', 'Đoài Phương'),
  ('WARD', 'HN_DONG_ANH', 'Xã Đông Anh', 67, 'HA_NOI', 'Đông Anh'),
  ('WARD', 'HN_GIA_LAM', 'Xã Gia Lâm', 68, 'HA_NOI', 'Gia Lâm'),
  ('WARD', 'HN_HAT_MON', 'Xã Hát Môn', 69, 'HA_NOI', 'Hát Môn'),
  ('WARD', 'HN_HA_BANG', 'Xã Hạ Bằng', 70, 'HA_NOI', 'Hạ Bằng'),
  ('WARD', 'HN_HOAI_DUC', 'Xã Hoài Đức', 71, 'HA_NOI', 'Hoài Đức'),
  ('WARD', 'HN_HOA_LAC', 'Xã Hòa Lạc', 72, 'HA_NOI', 'Hòa Lạc'),
  ('WARD', 'HN_HOA_PHU', 'Xã Hòa Phú', 73, 'HA_NOI', null),
  ('WARD', 'HN_HOA_XA', 'Xã Hòa Xá', 74, 'HA_NOI', null),
  ('WARD', 'HN_HONG_SON', 'Xã Hồng Sơn', 75, 'HA_NOI', null),
  ('WARD', 'HN_HONG_VAN', 'Xã Hồng Vân', 76, 'HA_NOI', 'Hồng Vân'),
  ('WARD', 'HN_HUNG_DAO', 'Xã Hưng Đạo', 77, 'HA_NOI', null),
  ('WARD', 'HN_HUONG_SON', 'Xã Hương Sơn', 78, 'HA_NOI', null),
  ('WARD', 'HN_KIEU_PHU', 'Xã Kiều Phú', 79, 'HA_NOI', null),
  ('WARD', 'HN_KIM_ANH', 'Xã Kim Anh', 80, 'HA_NOI', 'Kim Anh'),
  ('WARD', 'HN_LIEN_MINH', 'Xã Liên Minh', 81, 'HA_NOI', 'Liên Minh'),
  ('WARD', 'HN_ME_LINH', 'Xã Mê Linh', 82, 'HA_NOI', 'Mê Linh'),
  ('WARD', 'HN_MINH_CHAU', 'Xã Minh Châu', 83, 'HA_NOI', null),
  ('WARD', 'HN_MY_DUC', 'Xã Mỹ Đức', 84, 'HA_NOI', null),
  ('WARD', 'HN_NAM_PHU', 'Xã Nam Phù', 85, 'HA_NOI', 'Nam Phù'),
  ('WARD', 'HN_NGOC_HOI', 'Xã Ngọc Hồi', 86, 'HA_NOI', 'Ngọc Hồi'),
  ('WARD', 'HN_NOI_BAI', 'Xã Nội Bài', 87, 'HA_NOI', 'Nội Bài'),
  ('WARD', 'HN_O_DIEN', 'Xã Ô Diên', 88, 'HA_NOI', 'Ô Diên'),
  ('WARD', 'HN_PHU_CAT', 'Xã Phú Cát', 89, 'HA_NOI', null),
  ('WARD', 'HN_PHU_NGHIA', 'Xã Phú Nghĩa', 90, 'HA_NOI', null),
  ('WARD', 'HN_PHU_XUYEN', 'Xã Phú Xuyên', 91, 'HA_NOI', 'Phú Xuyên'),
  ('WARD', 'HN_PHUC_LOC', 'Xã Phúc Lộc', 92, 'HA_NOI', 'Phúc Lộc'),
  ('WARD', 'HN_PHUC_SON', 'Xã Phúc Sơn', 93, 'HA_NOI', null),
  ('WARD', 'HN_PHUC_THINH', 'Xã Phúc Thịnh', 94, 'HA_NOI', 'Phúc Thịnh'),
  ('WARD', 'HN_PHUC_THO', 'Xã Phúc Thọ', 95, 'HA_NOI', 'Phúc Thọ'),
  ('WARD', 'HN_PHU_DONG', 'Xã Phù Đổng', 96, 'HA_NOI', 'Phù Đổng'),
  ('WARD', 'HN_PHUONG_DUC', 'Xã Phượng Dực', 97, 'HA_NOI', null),
  ('WARD', 'HN_QUANG_MINH', 'Xã Quang Minh', 98, 'HA_NOI', 'Quang Minh'),
  ('WARD', 'HN_QUANG_BI', 'Xã Quảng Bị', 99, 'HA_NOI', 'Quảng Bị'),
  ('WARD', 'HN_QUANG_OAI', 'Xã Quảng Oai', 100, 'HA_NOI', 'Quảng Oai'),
  ('WARD', 'HN_QUOC_OAI', 'Xã Quốc Oai', 101, 'HA_NOI', 'Quốc Oai'),
  ('WARD', 'HN_SOC_SON', 'Xã Sóc Sơn', 102, 'HA_NOI', 'Sóc Sơn'),
  ('WARD', 'HN_SON_DONG', 'Xã Sơn Đồng', 103, 'HA_NOI', null),
  ('WARD', 'HN_SUOI_HAI', 'Xã Suối Hai', 104, 'HA_NOI', 'Suối Hai'),
  ('WARD', 'HN_TAM_HUNG', 'Xã Tam Hưng', 105, 'HA_NOI', 'Tam Hưng'),
  ('WARD', 'HN_TAY_PHUONG', 'Xã Tây Phương', 106, 'HA_NOI', null),
  ('WARD', 'HN_THANH_OAI', 'Xã Thanh Oai', 107, 'HA_NOI', 'Thanh Oai'),
  ('WARD', 'HN_THANH_TRI', 'Xã Thanh Trì', 108, 'HA_NOI', 'Thanh Trì'),
  ('WARD', 'HN_THACH_THAT', 'Xã Thạch Thất', 109, 'HA_NOI', 'Thạch Thất'),
  ('WARD', 'HN_THIEN_LOC', 'Xã Thiên Lộc', 110, 'HA_NOI', 'Thiên Lộc'),
  ('WARD', 'HN_THUAN_AN', 'Xã Thuận An', 111, 'HA_NOI', 'Thuận An'),
  ('WARD', 'HN_THU_LAM', 'Xã Thư Lâm', 112, 'HA_NOI', 'Thư Lâm'),
  ('WARD', 'HN_THUONG_TIN', 'Xã Thường Tín', 113, 'HA_NOI', 'Thường Tín'),
  ('WARD', 'HN_THUONG_PHUC', 'Xã Thượng Phúc', 114, 'HA_NOI', 'Thượng Phúc'),
  ('WARD', 'HN_TIEN_THANG', 'Xã Tiến Thắng', 115, 'HA_NOI', 'Tiến Thắng'),
  ('WARD', 'HN_TRAN_PHU', 'Xã Trần Phú', 116, 'HA_NOI', 'Trần Phú'),
  ('WARD', 'HN_TRUNG_GIA', 'Xã Trung Giã', 117, 'HA_NOI', 'Trung Giã'),
  ('WARD', 'HN_UNG_HOA', 'Xã Ứng Hòa', 118, 'HA_NOI', null),
  ('WARD', 'HN_UNG_THIEN', 'Xã Ứng Thiên', 119, 'HA_NOI', null),
  ('WARD', 'HN_VAN_DINH', 'Xã Vân Đình', 120, 'HA_NOI', null),
  ('WARD', 'HN_VAT_LAI', 'Xã Vật Lại', 121, 'HA_NOI', 'Vật Lại'),
  ('WARD', 'HN_VINH_THANH', 'Xã Vĩnh Thanh', 122, 'HA_NOI', null),
  ('WARD', 'HN_XUAN_MAI', 'Xã Xuân Mai', 123, 'HA_NOI', 'Xuân Mai'),
  ('WARD', 'HN_YEN_BAI', 'Xã Yên Bài', 124, 'HA_NOI', 'Yên Bài'),
  ('WARD', 'HN_YEN_LANG', 'Xã Yên Lãng', 125, 'HA_NOI', 'Yên Lãng'),
  ('WARD', 'HN_YEN_XUAN', 'Xã Yên Xuân', 126, 'HA_NOI', 'Yên Xuân')
) as v (catalog_code, code, name, sort_order, parent_code, legacy_ref)
join app.catalog_item p on p.catalog_code = 'PROVINCE' and p.code = v.parent_code
order by v.sort_order;

-- Cơ sở (spec 02). Không có CS3.
insert into app.branch (code, name, sort_order) values
  ('CS1', 'Nguyễn Chí Thanh', 1),
  ('CS2', 'Đỗ Quang', 2),
  ('CS4', 'Hà Đông', 3),
  ('CS5', 'Mỹ Đình', 4);

-- Năm học: từ tháng 6 tới tháng 5 năm sau.
insert into app.academic_year (code, name, start_date, end_date, sort_order) values
  ('2627', '2026-2027', date '2026-06-01', date '2027-05-31', 1);

select set_config('hmt.migration', '', false);
