-- PR 6c: danh mục hai cấp theo spec 06 (#12 giai đoạn phiếu tái tục, #19 nhóm đề nghị, #20 nhóm khiếu nại)
-- và cột applies_to của #23 Lý do huỷ buổi.
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

create function pg_temp.names(p_catalog text) returns text[] language sql as $$
  select array_agg(name order by sort_order) from app.catalog_item where catalog_code = p_catalog;
$$;
-- Tên các nhóm con của một nhóm, theo thứ tự.
create function pg_temp.children(p_child_catalog text, p_parent_code text) returns text[] language sql as $$
  select array_agg(i.name order by i.sort_order) from app.catalog_item i
  join app.catalog_item p on p.id = i.parent_id where i.catalog_code = p_child_catalog and p.code = p_parent_code;
$$;

-- #12 Giai đoạn phiếu tái tục (spec 06 mục 1.4).
select is(pg_temp.names('UPSALE_STAGE'),
          array['Chờ tái tục', 'Tổng hợp thông tin', 'Chưa liên hệ được', 'Đang tư vấn', 'Không tái tục', 'Tiềm năng tái tục', 'Dự thu', 'Hoàn thành tái tục'],
          'Spec 06 #12: tám giai đoạn phiếu tái tục L1–L8');
select is(pg_temp.children('UPSALE_SUBSTAGE', 'L1'), array['Hệ thống sinh tự động', 'Tạo thủ công', 'Đã tiếp nhận, chờ xếp lịch gọi'], 'Spec 06 #12: L1A đến L1C');
select is(pg_temp.children('UPSALE_SUBSTAGE', 'L7'), array['Đã gửi báo giá', 'Đã chốt gói, hẹn ngày đóng', 'Quá hẹn đóng, cần nhắc lại'], 'Spec 06 #12: L7A đến L7C');
select is(pg_temp.children('UPSALE_SUBSTAGE', 'L8'), array['Chờ lên đơn', 'Đã lên đơn, chờ duyệt', 'Đơn đã duyệt'], 'Spec 06 #12: L8A đến L8C theo tiến độ đơn');
select is(pg_temp.err($$select app.catalog_add_item('UPSALE_STAGE', 'L9', 'Giai đoạn mới')$$), 'HMT_DANH_MUC_HE_THONG',
          'Khoá mục cha: không thêm giai đoạn phiếu tái tục');

-- #19 Nhóm đề nghị (R-CS-03).
select is(pg_temp.names('REQUEST_GROUP'),
          array['Chuyển lớp', 'Chuyển cơ sở', 'Bảo lưu', 'Chuyển phí', 'Hoàn tiền', 'Đổi lịch học', 'Dừng học'],
          'R-CS-03: bảy nhóm đề nghị, gồm Dừng học');
select is(pg_temp.children('REQUEST_SUBGROUP', 'CHUYEN_LOP'),
          array['Cùng môn: đổi giờ học', 'Cùng môn: đổi trình độ', 'Cùng môn: đổi giáo viên', 'Khác môn'], 'R-CS-03: nhóm con Chuyển lớp');
select is(pg_temp.children('REQUEST_SUBGROUP', 'BAO_LUU'), array['Bảo lưu mới', 'Gia hạn bảo lưu', 'Quay lại học sớm'], 'R-CS-03: nhóm con Bảo lưu');
select is(pg_temp.children('REQUEST_SUBGROUP', 'CHUYEN_PHI'), array['Sang môn khác', 'Sang anh/chị/em', 'Sang gói khác'], 'R-CS-03: nhóm con Chuyển phí');
select is(pg_temp.children('REQUEST_SUBGROUP', 'HOAN_TIEN'), array['Toàn bộ', 'Một phần'], 'R-CS-03: nhóm con Hoàn tiền');
select is(pg_temp.children('REQUEST_SUBGROUP', 'DOI_LICH_HOC'), array['Dời một buổi', 'Đổi ca cố định', 'Xin học bù'], 'R-CS-03: nhóm con Đổi lịch học');
select ok(pg_temp.children('REQUEST_SUBGROUP', 'CHUYEN_CO_SO') is null and pg_temp.children('REQUEST_SUBGROUP', 'DUNG_HOC') is null,
          'R-CS-03: Chuyển cơ sở và Dừng học không có nhóm con');
select is(pg_temp.err($$select app.catalog_add_item('REQUEST_GROUP', 'NHOM_MOI', 'Nhóm mới')$$), 'HMT_DANH_MUC_HE_THONG',
          'Khoá mục cha: không thêm nhóm đề nghị');

-- R-CS-11: nhóm con kéo theo nghiệp vụ của R-CS-02 là mục khoá (không Ngừng được); Đổi lịch học thì không.
select is((select count(*)::int from app.catalog_item where catalog_code = 'REQUEST_SUBGROUP' and is_locked), 12,
          'R-CS-11: 12 nhóm con của chuyển lớp, bảo lưu, chuyển phí, hoàn tiền bị khoá');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('REQUEST_SUBGROUP', 'HOAN_TIEN_MOT_PHAN'), false)$$),
          'HMT_MUC_BI_KHOA', 'R-CS-11: nhóm con có nghiệp vụ không Ngừng được');
select is(pg_temp.err($$select app.catalog_rename_item(app.catalog_item_id('REQUEST_SUBGROUP', 'HOAN_TIEN_MOT_PHAN'), 'Hoàn một phần')$$),
          null, 'R-CS-11: nhóm con có nghiệp vụ vẫn đổi được tên');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('REQUEST_SUBGROUP', 'DOI_LICH_XIN_HOC_BU'), false)$$),
          null, 'Nhóm con Đổi lịch học Ngừng được');

-- #20 Nhóm khiếu nại (R-CS-04), danh mục Mở.
select is(pg_temp.names('COMPLAINT_GROUP'),
          array['Chương trình học', 'Giáo viên', 'Phương pháp giảng dạy', 'Tư vấn tuyển sinh', 'Vận hành', 'Chăm sóc', 'Khác'],
          'R-CS-04: bảy nhóm khiếu nại');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'CHUONG_TRINH_HOC'),
          array['Nội dung khó/dễ', 'Tiến độ', 'Không bám chương trình trên trường', 'Tài liệu'], 'R-CS-04: nhóm con Chương trình học');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'GIAO_VIEN'),
          array['Thái độ', 'Chuyên môn', 'Đi muộn, nghỉ dạy', 'Thay giáo viên nhiều', 'Nhận xét, chấm bài'], 'R-CS-04: nhóm con Giáo viên');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'PHUONG_PHAP_GIANG_DAY'),
          array['Cách giảng khó hiểu', 'BTVN nhiều/ít', 'Kiểm tra đánh giá', 'Quản lý lớp'], 'R-CS-04: nhóm con Phương pháp giảng dạy');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'TU_VAN_TUYEN_SINH'),
          array['Không đúng cam kết', 'Thái độ', 'Chậm phản hồi', 'Xếp lớp sai trình độ'], 'R-CS-04: nhóm con Tư vấn tuyển sinh');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'VAN_HANH'),
          array['Đổi lịch đột xuất', 'Phòng học, cơ sở vật chất', 'Sĩ số', 'Đưa đón, an toàn', 'Thông báo chậm'], 'R-CS-04: nhóm con Vận hành');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'CHAM_SOC'),
          array['Không phản hồi', 'Thái độ', 'Không gửi nhận xét, báo cáo'], 'R-CS-04: nhóm con Chăm sóc');
select is(pg_temp.children('COMPLAINT_SUBGROUP', 'KHAC'), null, 'R-CS-04: nhóm Khác không có nhóm con');
select is(pg_temp.err($$select app.catalog_add_item('COMPLAINT_GROUP', 'NHOM_MOI', 'Nhóm khiếu nại mới')$$), null,
          'Spec 06 #20: danh mục Mở, thêm nhóm khiếu nại được');

-- #23: "áp dụng cho" ở cột, không đọc tiền tố mã.
select is((select array_agg(code order by sort_order) from app.catalog_item
           where catalog_code = 'SESSION_CANCEL_REASON' and applies_to = array['TRUNG_TAM']),
          array['TT_NGHI_LE_DOT_XUAT', 'TT_GIAO_VIEN_NGHI', 'TT_SU_CO_CO_SO_VAT_CHAT', 'TT_THOI_TIET'], '#23: bốn lý do của trung tâm có applies_to TRUNG_TAM');
select is((select array_agg(code order by sort_order) from app.catalog_item
           where catalog_code = 'SESSION_CANCEL_REASON' and applies_to = array['HOC_SINH']),
          array['HS_OM', 'HS_VIEC_GIA_DINH', 'HS_THI_O_TRUONG', 'HS_KHAC'], '#23: bốn lý do của học sinh có applies_to HOC_SINH');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SESSION_CANCEL_REASON' and applies_to = '{}'), 0,
          '#23: không mục nào để trống applies_to');

select * from finish();
rollback;
