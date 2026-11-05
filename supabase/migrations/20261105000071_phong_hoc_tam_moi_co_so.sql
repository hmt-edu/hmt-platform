-- Dữ liệu Cơ sở 5 (anh chốt 05/11/2026): mỗi cơ sở dạy học (CS1 đến CS5) đặt tạm 5 phòng.
-- Tên theo [Cơ sở]-[Tầng]-[Số phòng]: CSx-T1-01, CSx-T1-02, CSx-T2-01, CSx-T2-02, CSx-T3-01. Tên thật anh sửa sau trên màn Cơ sở và phòng học.
-- Làm gì: thêm 5 phòng cho mỗi cơ sở dạy học đang hoạt động (CS3 là cơ sở dạy học thường từ Đ286; Hội sở văn phòng không có phòng, luật R-HT-02).
-- Mã phòng viết hoa, gạch dưới (CSx_T1_01) vì mã chỉ nhận chữ hoa, số, gạch dưới và không đổi được; tên hiển thị có dấu gạch ngang.
-- Sức chứa để trống (anh chưa cung cấp). Chạy lại không nhân đôi (on conflict do nothing).
-- Chỉ mục: không thêm; đã có unique (branch_id, code).
-- Phòng giả của bản thử nghiệm (P101, P102, ONL1 do seed.sql tạo): chuyển sang Ngừng nếu có, không xoá (có thể đã có lịch tham chiếu). Bản chạy thật không có các phòng này nên lệnh không đổi gì.
select set_config('hmt.migration', 'on', false);

insert into app.room (branch_id, code, name, sort_order)
select b.id,
       b.code || '_' || r.suffix,
       b.code || '-' || replace(r.suffix, '_', '-'),
       r.sort_order
  from app.branch b
 cross join (values ('T1_01', 1), ('T1_02', 2), ('T2_01', 3), ('T2_02', 4), ('T3_01', 5)) as r (suffix, sort_order)
 where not b.is_office and b.is_active
on conflict (branch_id, code) do nothing;

update app.room set is_active = false
 where code in ('P101', 'P102', 'ONL1') and is_active;
