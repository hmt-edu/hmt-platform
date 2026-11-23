# Đề xuất: nhãn riêng cho buổi học bù, bổ trợ (G18) và cảnh báo trùng giờ giáo viên khi duyệt (G21)

Thẻ A-23-17, Code A, 23/11/2026. Anh OK 16:37 (G18: nhãn «Học bù», «Bổ trợ», không chiếm số buổi chính; G21: cảnh báo, không chặn). **Chưa code**, chờ Chat duyệt đề xuất này rồi làm migration 630.

## Hiện trạng (đã đọc code)

- `app.renumber_class_sessions` (migration 102) đánh «Buổi N» theo thứ tự ngày cho MỌI buổi còn sống (Nháp, Đã chốt, Done, Huỷ có phí), **kể cả học bù và bổ trợ**: một buổi học bù chen giữa làm các buổi chính phía sau dịch số (lớp 10 buổi chính có thể thành «Buổi 11»). Các hàm duyệt cùng gọi nó: củng cố (139), bổ trợ (140), học bù (141, 430, 305), kiểm tra (303), huỷ và dời (102, 123).
- `class_session.session_no` cho phép null (giao diện `sessionNoLabel(null)` ra «—»).
- `app.session_move_check` (migration 123) đã có kiểu cảnh báo trùng phòng, trùng giáo viên (chỉ đọc, R-LOP-08 chỉ cảnh báo); hộp duyệt yêu cầu buổi chưa dùng hàm kiểm trùng.

## G18 đề xuất

1. **Đánh số:** `renumber_class_sessions` chỉ đếm buổi loại CHINH, CUNG_CO, KIEM_TRA (buổi chương trình). Buổi HOC_BU, BO_TRO có `session_no = null`. Củng cố giữ như hiện nay (luật R-BUOI-04 cho củng cố vẫn chiếm số, không đổi).
2. **Nhãn:** khi `session_no` null, giao diện hiện chữ theo loại: «Học bù», «Bổ trợ» (lấy tên từ danh mục SESSION_TYPE, không viết cứng) ở danh sách Buổi, bản ghi Buổi, lịch tuần, cổng giáo viên, báo cáo giờ dạy. Thêm hàm TS `sessionLabel(session)` thay `sessionNoLabel` ở các chỗ có loại buổi.
3. **Buổi cũ:** migration chạy `renumber` một lần cho mọi lớp (số buổi chính đóng khít lại; buổi bù, bổ trợ cũ thành null). Chữ «Buổi N» đã in ở phiếu, tin nhắn cũ không đổi; nhật ký ghi đổi số theo audit chuẩn. Lớp đã có buổi bù chen giữa sẽ thấy số buổi chính tụt lại (đúng ý anh).
4. **Phụ thuộc kiểm trước khi code:** mọi chỗ dùng `session_no` làm khoá (nhãn bài, chốt tháng, huỷ thêm cuối lịch «Buổi N+1», sổ giờ). Huỷ trung tâm thêm một buổi cuối lịch phải dùng số lớn nhất trên buổi chính, không đếm buổi bù. Rà bằng grep `session_no` (khoảng 40 chỗ SQL, 8 chỗ TS).
5. **pgTAP:** (a) lớp 3 buổi chính + 1 bù chen giữa → chính vẫn 1, 2, 3, bù null; (b) duyệt bổ trợ không đẩy số; (c) huỷ trung tâm thêm buổi cuối = Buổi 4 dù có buổi bù; (d) migration chạy lại không đổi; (e) đổi loại buổi giữa chính và củng cố giữ số.

## G21 đề xuất

1. Hàm đọc `app.session_request_clash_check(p_request_id)` (chỉ đọc, security definer, quyền Buổi học · Sửa như hàm duyệt): với yêu cầu học bù hoặc bổ trợ có ngày, giờ, giáo viên dự kiến, trả `{teacher_clash: [chữ], room_clash: [chữ]}` cùng mẫu và điều kiện với `session_move_check` (buổi còn sống Nháp, Đã chốt, Done giao giờ; bỏ buổi đang xét).
2. Hộp duyệt (BUOI-10) gọi hàm này khi mở, hiện khối **cảnh báo** (không khoá nút Duyệt, không đổi `approve_session_request`): «Giáo viên X đã có buổi LỚP · Buổi N ngày … giờ …». Dùng Alert cảnh báo chuẩn có sẵn (như BUOI-05).
3. pgTAP: trùng giáo viên cùng giờ → có cảnh báo; không trùng → rỗng; duyệt vẫn thành công khi có cảnh báo; vai không có quyền bị chặn; buổi huỷ không tính là trùng.

## Việc cần Chat chốt

- (a) Củng cố giữ chiếm số (đề xuất) hay cũng nhãn riêng?
- (b) `session_no` null cho bù, bổ trợ (đề xuất, không thêm cột) hay cột mới `makeup_no` để đánh «Bù 1, Bù 2»?
- (c) Làm một PR (migration 630 và giao diện) vì hai việc cùng chạm hộp duyệt yêu cầu buổi và nhãn buổi?

Rủi ro: CAO (đổi số buổi hàng loạt, liên quan trừ giờ theo buổi và báo cáo). Cần pgTAP đầy đủ và Tester ĐẠT.
