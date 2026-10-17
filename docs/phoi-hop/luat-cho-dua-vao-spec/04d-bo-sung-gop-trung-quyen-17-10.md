# Bổ sung luật 17/10/2026: ai được gộp trùng; quyền Huỷ, Giao việc, Duyệt

Anh Trường đã nói "OK ĐƯA VÀO LUẬT" ngày 17/10/2026 (10:55). File này **bổ sung sau** `04c-bo-sung-phieu-test-lich-hen-gop-16-10.md` (04c đã vào repo ở PR #34). Khi Code đưa vào repo: sửa dòng R-CRM-22 trong `docs/spec/04-luat-nghiep-vu.md`, thêm R-CRM-25, ghi "(17/10)" ở chỗ sửa, không giữ file riêng. Repo là bản đúng.

## 1. Sửa luật đã có

| Mã | Sửa thành | |
|---|---|---|
| R-CRM-22 | **(17/10)** **Gộp trùng lead, cơ hội:** **Tuyển sinh, CSKH, Trưởng cơ sở** được gộp **trong cơ sở của mình**; **Admin** gộp ở mọi cơ sở. Hai hồ sơ thuộc **hai cơ sở khác nhau** thì chỉ Admin gộp được. Quyền gộp dùng hành động **Duyệt** trên phân hệ Lead và Cơ hội (các phân hệ này chưa có luồng duyệt nào khác, nên Duyệt ở đó nghĩa là gộp trùng; ma trận quyền ghi chú rõ). Các phần còn lại của R-CRM-22 giữ như 04c: chọn bản giữ lại; lịch hẹn, ghi chú, phiếu test chuyển sang bản giữ lại; bản bị gộp thành "Đã gộp" chỉ đọc, ghi "Đã gộp vào <mã>", ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã; không xoá cứng; không hoàn tác, hộp gộp có câu xác nhận; chặn gộp cơ hội nếu bản bị gộp đã có báo giá hoặc đơn hàng (nêu rõ mã); ghi lịch sử ở cả hai bản, kèm người gộp. | [CHỐT] |

## 2. Luật mới

| Mã | Luật | |
|---|---|---|
| R-CRM-25 | **(17/10)** **Gộp phụ huynh, học sinh trùng** (màn KH-07): cùng nguyên tắc R-CRM-22. Tuyển sinh, CSKH, Trưởng cơ sở gộp trong cơ sở mình; hai hồ sơ khác cơ sở chỉ Admin. Quyền gộp dùng hành động **Duyệt** trên phân hệ Phụ huynh và Học sinh. Hồ sơ giữ lại nhận lead, cơ hội, đơn, ghi danh, ghi chú của hồ sơ bị gộp; hồ sơ bị gộp thành "Đã gộp", chỉ đọc, vẫn tìm được bằng mã; không hoàn tác; ghi lịch sử cả hai bản kèm người gộp. Điều kiện chặn chi tiết (ví dụ học sinh cùng đang học hai lớp trùng giờ) **[CHỜ]**: chốt khi làm phân hệ Ghi danh và Lớp học; ở giai đoạn 1 chặn khi hai hồ sơ có báo giá hoặc đơn xung đột (nêu rõ mã). | [CHỐT] phần quyền và nguyên tắc; [CHỜ] điều kiện chặn chi tiết |

## 3. Ma trận quyền phiên bản 3 (nạp bằng `app.save_permission_matrix`, anh duyệt bảng trước khi nạp)

Phạm vi đều là **cơ sở mình** (CO_SO). Các vai trò khác không đổi. Trưởng cơ sở và Admin đã có đủ hành động nên không thêm.

| Vai trò | Phân hệ | Hành động thêm |
|---|---|---|
| Tuyển sinh | Lead (LEAD) | Giao việc, Duyệt |
| Tuyển sinh | Cơ hội (OPPORTUNITY) | Giao việc, Duyệt |
| Tuyển sinh | Phụ huynh (PARENT) | Duyệt |
| Tuyển sinh | Học sinh (STUDENT) | Duyệt |
| Tuyển sinh | Kiểm tra đầu vào (STUDENT_TEST) | Huỷ |
| CSKH | Lead | Giao việc, Duyệt |
| CSKH | Cơ hội | Giao việc, Duyệt |
| CSKH | Phụ huynh | Duyệt |
| CSKH | Học sinh | Duyệt |
| CSKH | Kiểm tra đầu vào | Huỷ, Giao việc |

Tổng 15 ô. Giáo viên, trợ giảng vẫn không có quyền Huỷ phiếu kiểm tra (xem lại khi làm cổng giáo viên). Ghi chú trong ma trận: "Duyệt trên Lead, Cơ hội, Phụ huynh, Học sinh = gộp trùng".

## 4. Việc cho giai đoạn code

- P3b1 (#35): nạp ma trận phiên bản 3 theo bảng trên (sau khi anh duyệt bảng TRƯỚC / SAU của Code); sửa bài kiểm thử đang ghi "Tuyển sinh chưa có quyền Giao việc".
- P3b3: hàm gộp lead, cơ hội kiểm quyền Duyệt theo cơ sở của hai hồ sơ; hai hồ sơ khác cơ sở chỉ Admin; pgTAP đủ trường hợp (cùng cơ sở được, khác cơ sở bị chặn, Giáo viên không có quyền).
- Gộp phụ huynh, học sinh (R-CRM-25): làm cùng phân hệ Khách hàng (P4), dùng cùng quyền Duyệt.
- Sửa `docs/spec/04` (R-CRM-22, thêm R-CRM-25), `docs/design/ban-do-man-hinh.md` (TS-10: vai trò gộp là SA, CS, BM, AD; KH-07: SA, CS, BM, AD), `docs/nghiep-vu/phan-quyen.md`.
