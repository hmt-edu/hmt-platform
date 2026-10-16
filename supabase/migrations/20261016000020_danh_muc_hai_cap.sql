-- PR 6c: nạp các danh mục hai cấp còn thiếu của spec 06 (đối chiếu 16/10/2026) và gắn "áp dụng cho" cho #23.
-- #12 Giai đoạn phiếu tái tục (spec 06 mục 1.4), #19 Nhóm đề nghị (R-CS-03), #20 Nhóm khiếu nại (R-CS-04).
-- Khoá: #12, #19 "khoá mục cha" (tầng nhóm do danh mục HE_THONG); nhóm con đề nghị kéo theo nghiệp vụ của R-CS-02
-- (chuyển lớp, bảo lưu, chuyển phí, hoàn tiền) khoá: đổi tên được, không Ngừng được (R-CS-11).
-- #20 là danh mục Mở cả hai tầng.

select set_config('hmt.migration', 'on', false);

insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('UPSALE_STAGE', 'Giai đoạn phiếu tái tục', 'HE_THONG', null, null, 'L5 Không tái tục kết thúc phiếu, bắt buộc chọn lý do (danh mục Lý do không tái tục); L3 có lịch hẹn tư vấn.', 39),
  ('UPSALE_SUBSTAGE', 'Giai đoạn con phiếu tái tục', 'MO', 'UPSALE_STAGE', null, null, 40),
  ('REQUEST_GROUP', 'Nhóm đề nghị', 'HE_THONG', null, null, 'Ticket đề nghị (R-CS-03). Nhóm khoá: không thêm, không Ngừng.', 41),
  ('REQUEST_SUBGROUP', 'Nhóm con đề nghị', 'MO', 'REQUEST_GROUP', null, 'Nhóm con kéo theo nghiệp vụ của R-CS-02 là mục khoá (R-CS-11).', 42),
  ('COMPLAINT_GROUP', 'Nhóm khiếu nại', 'MO', null, null, 'Ticket khiếu nại (R-CS-04).', 43),
  ('COMPLAINT_SUBGROUP', 'Nhóm con khiếu nại', 'MO', 'COMPLAINT_GROUP', null, null, 44);

-- #12 Giai đoạn phiếu tái tục.
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('UPSALE_STAGE', 'L1', 'Chờ tái tục', 1),
  ('UPSALE_STAGE', 'L2', 'Đã liên hệ', 2),
  ('UPSALE_STAGE', 'L3', 'Đang tư vấn', 3),
  ('UPSALE_STAGE', 'L4', 'Đang cân nhắc', 4),
  ('UPSALE_STAGE', 'L5', 'Không tái tục', 5),
  ('UPSALE_STAGE', 'L6', 'Đồng ý tái tục', 6),
  ('UPSALE_STAGE', 'L7', 'Dự thu', 7),
  ('UPSALE_STAGE', 'L8', 'Hoàn thành tái tục', 8);

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'UPSALE_SUBSTAGE', v.code, v.name, v.sort_order, p.id
from (values
  ('L1A', 'Hệ thống sinh tự động', 1, 'L1'),
  ('L1B', 'Tạo thủ công', 2, 'L1'),
  ('L7A', 'Đã gửi báo giá', 3, 'L7'),
  ('L7B', 'Đã có đơn, chờ đóng tiền', 4, 'L7'),
  ('L8A', 'Đã đóng đủ, đã cộng quỹ giờ', 5, 'L8')
) as v(code, name, sort_order, parent_code)
join app.catalog_item p on p.catalog_code = 'UPSALE_STAGE' and p.code = v.parent_code;

-- #19 Nhóm đề nghị (R-CS-03). "Dừng học" là nhóm (12/10); Chuyển cơ sở và Dừng học không có nhóm con.
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('REQUEST_GROUP', 'CHUYEN_LOP', 'Chuyển lớp', 1),
  ('REQUEST_GROUP', 'CHUYEN_CO_SO', 'Chuyển cơ sở', 2),
  ('REQUEST_GROUP', 'BAO_LUU', 'Bảo lưu', 3),
  ('REQUEST_GROUP', 'CHUYEN_PHI', 'Chuyển phí', 4),
  ('REQUEST_GROUP', 'HOAN_TIEN', 'Hoàn tiền', 5),
  ('REQUEST_GROUP', 'DOI_LICH_HOC', 'Đổi lịch học', 6),
  ('REQUEST_GROUP', 'DUNG_HOC', 'Dừng học', 7);

-- is_locked: nhóm con có nghiệp vụ trong code (R-CS-02: chuyển lớp, bảo lưu, chuyển phí, hoàn tiền).
insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, is_locked)
select 'REQUEST_SUBGROUP', v.code, v.name, v.sort_order, p.id, v.locked
from (values
  ('CHUYEN_LOP_CUNG_MON_DOI_GIO', 'Cùng môn: đổi giờ học', 1, 'CHUYEN_LOP', true),
  ('CHUYEN_LOP_CUNG_MON_DOI_TRINH_DO', 'Cùng môn: đổi trình độ', 2, 'CHUYEN_LOP', true),
  ('CHUYEN_LOP_CUNG_MON_DOI_GIAO_VIEN', 'Cùng môn: đổi giáo viên', 3, 'CHUYEN_LOP', true),
  ('CHUYEN_LOP_KHAC_MON', 'Khác môn', 4, 'CHUYEN_LOP', true),
  ('BAO_LUU_MOI', 'Bảo lưu mới', 5, 'BAO_LUU', true),
  ('BAO_LUU_GIA_HAN', 'Gia hạn bảo lưu', 6, 'BAO_LUU', true),
  ('BAO_LUU_QUAY_LAI_SOM', 'Quay lại học sớm', 7, 'BAO_LUU', true),
  ('CHUYEN_PHI_SANG_MON_KHAC', 'Sang môn khác', 8, 'CHUYEN_PHI', true),
  ('CHUYEN_PHI_SANG_ANH_CHI_EM', 'Sang anh/chị/em', 9, 'CHUYEN_PHI', true),
  ('CHUYEN_PHI_SANG_GOI_KHAC', 'Sang gói khác', 10, 'CHUYEN_PHI', true),
  ('HOAN_TIEN_TOAN_BO', 'Toàn bộ', 11, 'HOAN_TIEN', true),
  ('HOAN_TIEN_MOT_PHAN', 'Một phần', 12, 'HOAN_TIEN', true),
  ('DOI_LICH_DOI_MOT_BUOI', 'Dời một buổi', 13, 'DOI_LICH_HOC', false),
  ('DOI_LICH_DOI_CA_CO_DINH', 'Đổi ca cố định', 14, 'DOI_LICH_HOC', false),
  ('DOI_LICH_XIN_HOC_BU', 'Xin học bù', 15, 'DOI_LICH_HOC', false)
) as v(code, name, sort_order, parent_code, locked)
join app.catalog_item p on p.catalog_code = 'REQUEST_GROUP' and p.code = v.parent_code;

-- #20 Nhóm khiếu nại (R-CS-04). Danh mục Mở; "Khác" là nhóm không có nhóm con.
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('COMPLAINT_GROUP', 'CHUONG_TRINH_HOC', 'Chương trình học', 1),
  ('COMPLAINT_GROUP', 'GIAO_VIEN', 'Giáo viên', 2),
  ('COMPLAINT_GROUP', 'PHUONG_PHAP_GIANG_DAY', 'Phương pháp giảng dạy', 3),
  ('COMPLAINT_GROUP', 'TU_VAN_TUYEN_SINH', 'Tư vấn tuyển sinh', 4),
  ('COMPLAINT_GROUP', 'VAN_HANH', 'Vận hành', 5),
  ('COMPLAINT_GROUP', 'CHAM_SOC', 'Chăm sóc', 6),
  ('COMPLAINT_GROUP', 'KHAC', 'Khác', 7);

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'COMPLAINT_SUBGROUP', v.code, v.name, v.sort_order, p.id
from (values
  ('CT_NOI_DUNG_KHO_DE', 'Nội dung khó/dễ', 1, 'CHUONG_TRINH_HOC'),
  ('CT_TIEN_DO', 'Tiến độ', 2, 'CHUONG_TRINH_HOC'),
  ('CT_KHONG_BAM_CHUONG_TRINH_TREN_TRUONG', 'Không bám chương trình trên trường', 3, 'CHUONG_TRINH_HOC'),
  ('CT_TAI_LIEU', 'Tài liệu', 4, 'CHUONG_TRINH_HOC'),
  ('GV_THAI_DO', 'Thái độ', 5, 'GIAO_VIEN'),
  ('GV_CHUYEN_MON', 'Chuyên môn', 6, 'GIAO_VIEN'),
  ('GV_DI_MUON_NGHI_DAY', 'Đi muộn, nghỉ dạy', 7, 'GIAO_VIEN'),
  ('GV_THAY_GIAO_VIEN_NHIEU', 'Thay giáo viên nhiều', 8, 'GIAO_VIEN'),
  ('GV_NHAN_XET_CHAM_BAI', 'Nhận xét, chấm bài', 9, 'GIAO_VIEN'),
  ('PP_CACH_GIANG_KHO_HIEU', 'Cách giảng khó hiểu', 10, 'PHUONG_PHAP_GIANG_DAY'),
  ('PP_BTVN_NHIEU_IT', 'BTVN nhiều/ít', 11, 'PHUONG_PHAP_GIANG_DAY'),
  ('PP_KIEM_TRA_DANH_GIA', 'Kiểm tra đánh giá', 12, 'PHUONG_PHAP_GIANG_DAY'),
  ('PP_QUAN_LY_LOP', 'Quản lý lớp', 13, 'PHUONG_PHAP_GIANG_DAY'),
  ('TV_KHONG_DUNG_CAM_KET', 'Không đúng cam kết', 14, 'TU_VAN_TUYEN_SINH'),
  ('TV_THAI_DO', 'Thái độ', 15, 'TU_VAN_TUYEN_SINH'),
  ('TV_CHAM_PHAN_HOI', 'Chậm phản hồi', 16, 'TU_VAN_TUYEN_SINH'),
  ('TV_XEP_LOP_SAI_TRINH_DO', 'Xếp lớp sai trình độ', 17, 'TU_VAN_TUYEN_SINH'),
  ('VH_DOI_LICH_DOT_XUAT', 'Đổi lịch đột xuất', 18, 'VAN_HANH'),
  ('VH_PHONG_HOC_CO_SO_VAT_CHAT', 'Phòng học, cơ sở vật chất', 19, 'VAN_HANH'),
  ('VH_SI_SO', 'Sĩ số', 20, 'VAN_HANH'),
  ('VH_DUA_DON_AN_TOAN', 'Đưa đón, an toàn', 21, 'VAN_HANH'),
  ('VH_THONG_BAO_CHAM', 'Thông báo chậm', 22, 'VAN_HANH'),
  ('CS_KHONG_PHAN_HOI', 'Không phản hồi', 23, 'CHAM_SOC'),
  ('CS_THAI_DO', 'Thái độ', 24, 'CHAM_SOC'),
  ('CS_KHONG_GUI_NHAN_XET_BAO_CAO', 'Không gửi nhận xét, báo cáo', 25, 'CHAM_SOC')
) as v(code, name, sort_order, parent_code)
join app.catalog_item p on p.catalog_code = 'COMPLAINT_GROUP' and p.code = v.parent_code;

-- #23 Lý do huỷ buổi: lý do của trung tâm hay của học sinh nằm ở cột applies_to, để hàm nghiệp vụ lọc theo cột,
-- không đọc tiền tố mã (anh Trường chốt 16/10).
update app.catalog_item set applies_to = array['TRUNG_TAM']
where catalog_code = 'SESSION_CANCEL_REASON' and code like 'TT\_%';
update app.catalog_item set applies_to = array['HOC_SINH']
where catalog_code = 'SESSION_CANCEL_REASON' and code like 'HS\_%';
update app.catalog set description = 'Cột applies_to: TRUNG_TAM là lý do của trung tâm, HOC_SINH là lý do của học sinh.'
where code = 'SESSION_CANCEL_REASON';

select set_config('hmt.migration', '', false);
