-- Code B (15/11/2026), Aftersale lát đầu (Đợt 2, PR Draft), migration 156: cấu hình ticket CS.
-- Luật: docs/spec/de-xuat-luat-aftersale.md (AS-01 đến AS-13, ĐÃ CHỐT 15/11), R-V2-23, R-V2-26, R-CS-11. Chưa bật cho cơ sở nào (công tắc phân hệ AFTERSALE mặc định tắt).
-- Làm gì: phân hệ AFTERSALE; loại chứng từ GV; danh mục trạng thái (7 bước), mức độ, đội xử lý; bảng nhóm, nhóm con (dữ liệu nạp ban đầu theo v2-aftersale.md,
-- sửa bằng migration cho đến khi có màn cấu hình); bảng hạn xử lý theo loại × mức độ (AS-07); tham số ngưỡng cảnh báo và số ngày chờ đóng.
-- Chỉ mục: mỗi chỉ mục ghi lý do dưới câu tạo. Không có dữ liệu cá nhân.
select set_config('hmt.migration', 'on', false);

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('MODULE', 'AFTERSALE', 'Aftersale (ticket đề nghị, khiếu nại, giáo viên)', 20),
  ('DOC_TYPE', 'GV', 'Ticket giáo viên', 7);

insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('TICKET_STATUS', 'Trạng thái ticket', 'HE_THONG', null, null, 'Luồng chung 7 bước của ticket (AS-02).', 40),
  ('TICKET_PRIORITY', 'Mức độ ticket', 'HE_THONG', null, null, 'Khẩn, Cao, Thường, Thấp (R-V2-26).', 41),
  ('TICKET_TEAM', 'Đội xử lý ticket', 'MO', null, null, 'CSKH, Đào tạo, Kế toán, Quản lý cơ sở.', 42);

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('TICKET_STATUS', 'MOI', 'Mới', 1), ('TICKET_STATUS', 'DA_GIAO', 'Đã giao', 2), ('TICKET_STATUS', 'DANG_XU_LY', 'Đang xử lý', 3),
  ('TICKET_STATUS', 'CHO_THONG_TIN', 'Chờ thông tin', 4), ('TICKET_STATUS', 'DA_XU_LY', 'Đã xử lý', 5), ('TICKET_STATUS', 'DA_DONG', 'Đã đóng', 6),
  ('TICKET_STATUS', 'DA_HUY', 'Đã huỷ', 7),
  ('TICKET_PRIORITY', 'KHAN', 'Khẩn', 1), ('TICKET_PRIORITY', 'CAO', 'Cao', 2), ('TICKET_PRIORITY', 'THUONG', 'Thường', 3), ('TICKET_PRIORITY', 'THAP', 'Thấp', 4),
  ('TICKET_TEAM', 'CSKH', 'CSKH', 1), ('TICKET_TEAM', 'DAO_TAO', 'Đào tạo', 2), ('TICKET_TEAM', 'KE_TOAN', 'Kế toán', 3), ('TICKET_TEAM', 'QL_CO_SO', 'Quản lý cơ sở', 4);

-- Nhóm và nhóm con (AS-06). business_type: loại phiếu nghiệp vụ đi kèm ([NV]); nhóm con [NV] đổi tên được, không Ngừng được (hàm cấu hình làm sau).
-- resolve_hours_override: hạn xử lý riêng theo nhóm con (AS-07), đè lên bảng loại × mức độ. nature_code: Cần hỗ trợ hoặc Phản ánh (chỉ ticket giáo viên, AS-05).
-- requires_student: bắt buộc gắn học sinh (đề nghị [NV]; ticket giáo viên "học kém", "nghỉ nhiều" còn bắt buộc lớp).
create table app.ticket_category (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null check (btrim(name) <> ''),
  kind text not null check (kind in ('GROUP', 'SUBGROUP')),
  parent_code text references app.ticket_category (code),
  ticket_type text not null check (ticket_type in ('DN', 'KN', 'GV')),
  nature_code text check (nature_code in ('HO_TRO', 'PHAN_ANH')),
  default_priority text check (default_priority in ('KHAN', 'CAO', 'THUONG', 'THAP')),
  business_type text check (business_type in ('CAP_NHAT_HO_SO', 'DOI_LICH', 'CHUYEN_LOP', 'BAO_LUU', 'DUNG_HOC', 'HOAN_PHI', 'CHUYEN_PHI')),
  resolve_hours_override integer check (resolve_hours_override is null or resolve_hours_override > 0),
  sort_order integer not null default 0,
  default_team text,
  requires_student boolean not null default false,
  requires_class boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((kind = 'GROUP') = (parent_code is null)),
  check (kind = 'SUBGROUP' or (nature_code is null and default_priority is null and business_type is null)),
  check (nature_code is null or ticket_type = 'GV')
);
comment on table app.ticket_category is 'Nhóm và nhóm con ticket CS (danh mục cấu hình, không xoá: chỉ Ngừng). Dữ liệu nạp ban đầu theo v2-aftersale.md.';
-- Chỉ mục (lý do): nhóm con theo nhóm cha và loại (ô chọn hai cấp khi tạo ticket); khoá ngoại parent_code.
create index ticket_category_parent_idx on app.ticket_category (parent_code, sort_order);
create index ticket_category_type_idx on app.ticket_category (ticket_type, kind, sort_order) where is_active;
select app.apply_standard('app.ticket_category');

insert into app.ticket_category (code, name, kind, parent_code, ticket_type, nature_code, default_priority, business_type, resolve_hours_override, sort_order, default_team) values
  ('DN_01', 'Học tập', 'GROUP', null, 'DN', null, null, null, null, 10, null),
  ('DN_01_01', 'Bảo lưu', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'BAO_LUU', 48, 10, null),
  ('DN_01_02', 'Tiếp tục học sau bảo lưu', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'BAO_LUU', 48, 20, null),
  ('DN_01_03', 'Chuyển lớp cùng môn', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'CHUYEN_LOP', 48, 30, null),
  ('DN_01_04', 'Chuyển cơ sở', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'CHUYEN_LOP', 48, 40, null),
  ('DN_01_05', 'Đổi lịch học, học bù', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'DOI_LICH', null, 50, null),
  ('DN_01_06', 'Dừng học', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', 'DUNG_HOC', 120, 60, null),
  ('DN_01_07', 'Chuyển giáo viên', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', null, null, 70, null),
  ('DN_01_08', 'Cung cấp kết quả, nhận xét', 'SUBGROUP', 'DN_01', 'DN', null, 'THUONG', null, null, 80, null),
  ('DN_02', 'Học phí', 'GROUP', null, 'DN', null, null, null, null, 20, null),
  ('DN_02_01', 'Hoàn học phí', 'SUBGROUP', 'DN_02', 'DN', null, 'THUONG', 'HOAN_PHI', 168, 10, null),
  ('DN_02_02', 'Chuyển phí sang môn khác, anh chị em, gói khác', 'SUBGROUP', 'DN_02', 'DN', null, 'THUONG', 'CHUYEN_PHI', 120, 20, null),
  ('DN_02_03', 'Gia hạn thanh toán', 'SUBGROUP', 'DN_02', 'DN', null, 'THUONG', null, null, 30, null),
  ('DN_02_04', 'Điều chỉnh học phí', 'SUBGROUP', 'DN_02', 'DN', null, 'THUONG', null, null, 40, null),
  ('DN_03', 'Quà tặng, ưu đãi', 'GROUP', null, 'DN', null, null, null, null, 30, null),
  ('DN_03_01', 'Nhận, đổi quà', 'SUBGROUP', 'DN_03', 'DN', null, 'THUONG', null, null, 10, null),
  ('DN_03_02', 'Áp dụng ưu đãi', 'SUBGROUP', 'DN_03', 'DN', null, 'THUONG', null, null, 20, null),
  ('DN_03_03', 'Bổ sung điểm thưởng', 'SUBGROUP', 'DN_03', 'DN', null, 'THUONG', null, null, 30, null),
  ('DN_04', 'Hồ sơ', 'GROUP', null, 'DN', null, null, null, null, 40, null),
  ('DN_04_01', 'Cập nhật thông tin học sinh, phụ huynh', 'SUBGROUP', 'DN_04', 'DN', null, 'THUONG', 'CAP_NHAT_HO_SO', 24, 10, null),
  ('DN_05', 'Hỗ trợ', 'GROUP', null, 'DN', null, null, null, null, 50, null),
  ('DN_05_01', 'Tư vấn lộ trình', 'SUBGROUP', 'DN_05', 'DN', null, 'THUONG', null, null, 10, null),
  ('DN_05_02', 'Trao đổi với giáo viên', 'SUBGROUP', 'DN_05', 'DN', null, 'THUONG', null, null, 20, null),
  ('DN_05_03', 'Hỗ trợ học sinh', 'SUBGROUP', 'DN_05', 'DN', null, 'THUONG', null, null, 30, null),
  ('DN_05_04', 'Cơ sở vật chất', 'SUBGROUP', 'DN_05', 'DN', null, 'THUONG', null, null, 40, null),
  ('DN_06', 'Khác', 'GROUP', null, 'DN', null, null, null, null, 60, null),
  ('DN_06_01', 'Yêu cầu khác', 'SUBGROUP', 'DN_06', 'DN', null, 'THUONG', null, null, 10, null),
  ('KN_01', 'Giảng dạy', 'GROUP', null, 'KN', null, null, null, null, 10, null),
  ('KN_01_01', 'Chất lượng, phương pháp', 'SUBGROUP', 'KN_01', 'KN', null, 'CAO', null, null, 10, null),
  ('KN_01_02', 'Chuyên môn giáo viên', 'SUBGROUP', 'KN_01', 'KN', null, 'CAO', null, null, 20, null),
  ('KN_01_03', 'Giáo viên đi muộn, nghỉ dạy, thay nhiều', 'SUBGROUP', 'KN_01', 'KN', null, 'CAO', null, null, 30, null),
  ('KN_01_04', 'Nội dung, tiến độ, tài liệu', 'SUBGROUP', 'KN_01', 'KN', null, 'THUONG', null, null, 40, null),
  ('KN_01_05', 'BTVN, kiểm tra đánh giá', 'SUBGROUP', 'KN_01', 'KN', null, 'THUONG', null, null, 50, null),
  ('KN_01_06', 'Kết quả học tập', 'SUBGROUP', 'KN_01', 'KN', null, 'THUONG', null, null, 60, null),
  ('KN_02', 'Học sinh trong lớp', 'GROUP', null, 'KN', null, null, null, null, 20, null),
  ('KN_02_01', 'Thái độ, hành vi', 'SUBGROUP', 'KN_02', 'KN', null, 'THUONG', null, null, 10, null),
  ('KN_02_02', 'Bắt nạt', 'SUBGROUP', 'KN_02', 'KN', null, 'KHAN', null, null, 20, null),
  ('KN_03', 'Tư vấn tuyển sinh', 'GROUP', null, 'KN', null, null, null, null, 30, null),
  ('KN_03_01', 'Thông tin sai, thiếu', 'SUBGROUP', 'KN_03', 'KN', null, 'THUONG', null, null, 10, null),
  ('KN_03_02', 'Không đúng cam kết', 'SUBGROUP', 'KN_03', 'KN', null, 'THUONG', null, null, 20, null),
  ('KN_03_03', 'Xếp lớp sai trình độ', 'SUBGROUP', 'KN_03', 'KN', null, 'THUONG', null, null, 30, null),
  ('KN_03_04', 'Thái độ, chậm phản hồi', 'SUBGROUP', 'KN_03', 'KN', null, 'THUONG', null, null, 40, null),
  ('KN_04', 'Vận hành', 'GROUP', null, 'KN', null, null, null, null, 40, null),
  ('KN_04_01', 'Lịch học, thông báo, đổi đột xuất', 'SUBGROUP', 'KN_04', 'KN', null, 'THUONG', null, null, 10, null),
  ('KN_04_02', 'Điểm danh', 'SUBGROUP', 'KN_04', 'KN', null, 'THUONG', null, null, 20, null),
  ('KN_04_03', 'Học bù', 'SUBGROUP', 'KN_04', 'KN', null, 'THUONG', null, null, 30, null),
  ('KN_04_04', 'Sĩ số, thời lượng', 'SUBGROUP', 'KN_04', 'KN', null, 'THUONG', null, null, 40, null),
  ('KN_04_05', 'Đưa đón, an toàn', 'SUBGROUP', 'KN_04', 'KN', null, 'KHAN', null, null, 50, null),
  ('KN_05', 'Học phí', 'GROUP', null, 'KN', null, null, null, null, 50, null),
  ('KN_05_01', 'Tính học phí, công nợ', 'SUBGROUP', 'KN_05', 'KN', null, 'CAO', null, null, 10, null),
  ('KN_05_02', 'Chính sách bảo lưu, chuyển lớp, hoàn phí', 'SUBGROUP', 'KN_05', 'KN', null, 'CAO', null, null, 20, null),
  ('KN_06', 'CSKH', 'GROUP', null, 'KN', null, null, null, null, 60, null),
  ('KN_06_01', 'Không phản hồi, chậm', 'SUBGROUP', 'KN_06', 'KN', null, 'THUONG', null, null, 10, null),
  ('KN_06_02', 'Thái độ', 'SUBGROUP', 'KN_06', 'KN', null, 'THUONG', null, null, 20, null),
  ('KN_06_03', 'Không gửi nhận xét, báo cáo', 'SUBGROUP', 'KN_06', 'KN', null, 'THUONG', null, null, 30, null),
  ('KN_06_04', 'Kết quả xử lý', 'SUBGROUP', 'KN_06', 'KN', null, 'THUONG', null, null, 40, null),
  ('KN_07', 'Cơ sở vật chất', 'GROUP', null, 'KN', null, null, null, null, 70, null),
  ('KN_07_01', 'Phòng học, thiết bị, vệ sinh', 'SUBGROUP', 'KN_07', 'KN', null, 'THUONG', null, null, 10, null),
  ('KN_08', 'Khác', 'GROUP', null, 'KN', null, null, null, null, 80, null),
  ('KN_08_01', 'Khiếu nại khác', 'SUBGROUP', 'KN_08', 'KN', null, 'THUONG', null, null, 10, null),
  ('GV_01', 'Học sinh', 'GROUP', null, 'GV', null, null, null, null, 10, null),
  ('GV_01_01', 'Học sinh học kém, không theo kịp lớp', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_01_02', 'Học sinh đi xuống rõ so với trước', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 20, null),
  ('GV_01_03', 'Học sinh nhiều lần không hoàn thành bài, cần báo phụ huynh', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 30, null),
  ('GV_01_04', 'Học sinh xếp sai trình độ lớp (quá khó hoặc quá dễ)', 'SUBGROUP', 'GV_01', 'GV', 'PHAN_ANH', 'THUONG', null, null, 40, null),
  ('GV_01_05', 'Học sinh nghỉ nhiều', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 50, null),
  ('GV_01_06', 'Học sinh hay đi muộn, về sớm', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 60, null),
  ('GV_01_07', 'Học sinh không hợp tác, thiếu tập trung', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'THUONG', null, null, 70, null),
  ('GV_01_08', 'Học sinh có dấu hiệu tâm lý, sức khoẻ bất thường', 'SUBGROUP', 'GV_01', 'GV', 'HO_TRO', 'KHAN', null, null, 80, null),
  ('GV_01_09', 'Học sinh có hành vi ảnh hưởng lớp, mâu thuẫn với bạn', 'SUBGROUP', 'GV_01', 'GV', 'PHAN_ANH', 'THUONG', null, null, 90, null),
  ('GV_02', 'Phụ huynh', 'GROUP', null, 'GV', null, null, null, null, 20, null),
  ('GV_02_01', 'Nhờ CSKH trao đổi với phụ huynh', 'SUBGROUP', 'GV_02', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_02_02', 'Phụ huynh không phối hợp, không làm như đã thống nhất', 'SUBGROUP', 'GV_02', 'GV', 'PHAN_ANH', 'THUONG', null, null, 20, null),
  ('GV_02_03', 'Phụ huynh yêu cầu vượt phạm vi giáo viên', 'SUBGROUP', 'GV_02', 'GV', 'PHAN_ANH', 'THUONG', null, null, 30, null),
  ('GV_03', 'Lịch dạy', 'GROUP', null, 'GV', null, null, null, null, 30, null),
  ('GV_03_01', 'Xin đổi lịch dạy, xin nghỉ, nhờ dạy thay', 'SUBGROUP', 'GV_03', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_03_02', 'Lịch dạy bị đổi đột xuất hoặc không được báo', 'SUBGROUP', 'GV_03', 'GV', 'PHAN_ANH', 'CAO', null, null, 20, null),
  ('GV_03_03', 'Phân công lớp, lịch không phù hợp', 'SUBGROUP', 'GV_03', 'GV', 'PHAN_ANH', 'THUONG', null, null, 30, null),
  ('GV_04', 'Vận hành', 'GROUP', null, 'GV', null, null, null, null, 40, null),
  ('GV_04_01', 'Thiếu thông tin lớp, học sinh', 'SUBGROUP', 'GV_04', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_04_02', 'Xin sửa điểm danh, điểm, nhận xét đã chốt', 'SUBGROUP', 'GV_04', 'GV', 'HO_TRO', 'THUONG', null, null, 20, null),
  ('GV_04_03', 'Quy trình vận hành chưa phù hợp', 'SUBGROUP', 'GV_04', 'GV', 'PHAN_ANH', 'THUONG', null, null, 30, null),
  ('GV_05', 'Chuyên môn', 'GROUP', null, 'GV', null, null, null, null, 50, null),
  ('GV_05_01', 'Xin tài liệu, hướng dẫn phương pháp, tình huống sư phạm', 'SUBGROUP', 'GV_05', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_05_02', 'Tài liệu, chương trình chưa phù hợp thực tế lớp', 'SUBGROUP', 'GV_05', 'GV', 'PHAN_ANH', 'THUONG', null, null, 20, null),
  ('GV_06', 'Cơ sở vật chất', 'GROUP', null, 'GV', null, null, null, null, 60, null),
  ('GV_06_01', 'Thiết bị hỏng, thiếu dụng cụ, phòng học không dùng được', 'SUBGROUP', 'GV_06', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_07', 'Phối hợp nội bộ', 'GROUP', null, 'GV', null, null, null, null, 70, null),
  ('GV_07_01', 'Bộ phận khác chậm phản hồi, thiếu phối hợp, thông tin sai', 'SUBGROUP', 'GV_07', 'GV', 'PHAN_ANH', 'THUONG', null, null, 10, null),
  ('GV_08', 'Chính sách', 'GROUP', null, 'GV', null, null, null, null, 80, null),
  ('GV_08_01', 'Hỏi chính sách, quy định, lương thưởng', 'SUBGROUP', 'GV_08', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null),
  ('GV_08_02', 'Lương thưởng, quyền lợi chưa đúng', 'SUBGROUP', 'GV_08', 'GV', 'PHAN_ANH', 'THUONG', null, null, 20, null),
  ('GV_09', 'Khác', 'GROUP', null, 'GV', null, null, null, null, 90, null),
  ('GV_09_01', 'Việc khác (CSKH xếp lại nhóm con khi tiếp nhận)', 'SUBGROUP', 'GV_09', 'GV', 'HO_TRO', 'THUONG', null, null, 10, null);
update app.ticket_category set requires_student = true where business_type is not null and ticket_type = 'DN';
update app.ticket_category set requires_student = true, requires_class = true
 where ticket_type = 'GV' and name in ('Học sinh học kém, không theo kịp lớp', 'Học sinh nghỉ nhiều');

alter table app.ticket_category enable row level security;
revoke all on app.ticket_category from public, anon, authenticated;
grant select on app.ticket_category to authenticated;
create policy ticket_category_read on app.ticket_category for select to authenticated using ((select app.has_permission('TICKET', 'XEM')));

-- Hạn xử lý mặc định theo loại × mức độ (AS-07), tính bằng giờ lịch. Số có nguồn v1 (R-CS-08): Đề nghị Thường 24 giờ/48 giờ; Khiếu nại Khẩn 2 giờ/24 giờ,
-- Thường 24 giờ/72 giờ; còn lại là đề xuất đã duyệt. Admin sửa; mỗi lần sửa ghi nhật ký (apply_standard); ticket cũ giữ hạn đã chụp lúc tạo.
create table app.ticket_sla_rule (
  id uuid primary key default gen_random_uuid(),
  ticket_type text not null check (ticket_type in ('DN', 'KN', 'GV')),
  priority_code text not null check (priority_code in ('KHAN', 'CAO', 'THUONG', 'THAP')),
  response_hours integer not null check (response_hours > 0),
  resolve_hours integer not null check (resolve_hours > 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (ticket_type, priority_code)
);
comment on table app.ticket_sla_rule is 'Hạn phản hồi đầu và hạn xử lý xong (giờ lịch) theo loại ticket × mức độ (AS-07). Hạn riêng nhóm con: ticket_category.resolve_hours_override.';
select app.apply_standard('app.ticket_sla_rule');
insert into app.ticket_sla_rule (ticket_type, priority_code, response_hours, resolve_hours) values
  ('DN', 'KHAN', 2, 24), ('DN', 'CAO', 4, 48), ('DN', 'THUONG', 24, 48), ('DN', 'THAP', 24, 72),
  ('KN', 'KHAN', 2, 24), ('KN', 'CAO', 4, 48), ('KN', 'THUONG', 24, 72), ('KN', 'THAP', 24, 120),
  ('GV', 'KHAN', 2, 24), ('GV', 'CAO', 8, 48), ('GV', 'THUONG', 24, 72), ('GV', 'THAP', 48, 120);
alter table app.ticket_sla_rule enable row level security;
revoke all on app.ticket_sla_rule from public, anon, authenticated;
grant select on app.ticket_sla_rule to authenticated;
create policy ticket_sla_rule_read on app.ticket_sla_rule for select to authenticated using ((select app.has_permission('TICKET', 'XEM')));

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('as_sla_warn_percent', 'Ticket: cảnh báo Sắp quá hạn khi còn dưới', 'INT', '% thời gian', 1, 90, '25', false, 'AFTERSALE', 'R-V2-26',
   'Còn dưới mức này của thời gian xử lý thì ticket hiện vàng "Sắp quá hạn" (AS-07).'),
  ('as_close_wait_days', 'Ticket: Đã xử lý quá số ngày này chưa đóng thì vào "Chờ đóng"', 'INT', 'ngày', 1, 30, '3', false, 'AFTERSALE', 'AS-03',
   'Ticket Đã xử lý quá số ngày này chưa đóng hiện trong bộ lọc "Chờ đóng" để CSKH gọi xác nhận.');

select set_config('hmt.migration', '', false);
