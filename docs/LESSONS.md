# Bài học từ các lần PR bị trả lại (lập 23/11/2026, thẻ E-23-01)

Nguồn: thư Tester và Soát từ 16/11 đến 23/11 (`hmt-ca/HOP-THU/LUU/tester-*.md`, `soat-*.md`, `tester.md`, `ra-soat.md`) và các dòng «CHƯA ĐẠT». Mỗi dòng là một lỗi và luật rút ra. Lỗi gặp từ hai lần trở lên thành **luật đánh số BH-nn**: người viết PR đọc trước khi đẩy; Tester và Soát dẫn số khi trả lại. Thêm dòng mới ở cuối từng bảng, không sửa dòng cũ. Số PR là ví dụ để tra, không phải danh sách đầy đủ.

## Luật đã thành quy tắc (lỗi lặp từ hai lần)

| Luật | Lỗi hay gặp | Luật rút ra | Ví dụ |
|---|---|---|---|
| **BH-01** | Đổi nhãn nút, luồng hoặc cách chọn trong màn mà không tìm bài e2e cũ; CI bỏ Playwright nên lỗi lọt, tới lượt Tester mới đỏ | Đổi chữ, nhãn, thứ tự thao tác hay `aria-label` thì `grep` chữ cũ trong `e2e/` và sửa spec trong cùng PR; PR đụng giao diện dùng chung thì xin nhãn `full-ci` | #526 (nhãn «Xác nhận khách huỷ» làm ticket.spec:119 đỏ), #505, #188 |
| **BH-02** | Chỉ có bài pgTAP cho trường hợp đúng; thiếu trường hợp bị chặn (từ chối, lý do bắt buộc, huỷ, cơ sở khác) | Mỗi luật có đủ cặp bài «đúng» và «bị chặn»; tên bài ghi luật bằng tiếng Việt (CLAUDE.md mục SQL 4). Hàm tiền thêm bài ràng buộc chặn đường cũ | #67 (thiếu ngày thu tương lai, ràng buộc kind_check), #56, #54 (thiếu reject, cancel, RLS cơ sở khác) |
| **BH-03** | Trùng số migration giữa hai PR; hoặc nhánh cũ chưa gộp main làm CI đỏ vì nền lỗi thời | Xin số migration từ Chat trước khi tạo; trước khi đẩy gộp main vào nhánh và kiểm không trùng số; nhánh đỏ vì nền cũ thì cập nhật từ main trước khi nghi lỗi | #54 (216) và #56 (217) trùng #45/#44; #79, #80, #81 và 7 PR khác đỏ do nền trước #87 |
| **BH-04** | Lỗi từ máy chủ bị nuốt: gọi lưu xong `setError` nhưng hộp thoại không hiện; hoặc công tắc phân hệ tắt mà giao diện vẫn cho thao tác tới bước cuối | Mỗi thao tác ghi có đường hiện lỗi ngay chỗ người bấm (mã lỗi + câu tiếng Việt); công tắc/tham số kiểm cả ở giao diện lẫn trong hàm DB | Thực hiện phiếu nghiệp vụ lỗi im lặng, CHUYEN_LOP tắt vẫn tạo phiếu (Soát 23/11) |
| **BH-05** | Chữ lộ mã luật «(R-xx-nn)», chữ tiếng Anh («Done») hoặc ghi chú dev («Làm sau: bản 17/11…») trên màn người dùng | Màn người dùng không in mã luật hay ghi chú nội bộ; trạng thái dùng nhãn tiếng Việt. Mã luật ở chú thích code và mô tả PR | GV-03, GV-05, GV-14, GV-16, GV-17 (Soát 23/11, mục H) |
| **BH-06** | Tính «hôm nay» theo UTC: PR xanh ban ngày, đỏ từ 00:00 tới 07:00 giờ Việt Nam | Ngày nghiệp vụ lấy theo `Asia/Ho_Chi_Minh` (`vnDayBounds`), cả trong code và trong bài kiểm; không dùng `toISOString().slice(0,10)` | #369, #370, #371, #379 đỏ cùng bài diem-danh-trong-ngay.spec:77 |

## Lỗi đã gặp một lần (ghi nhận, chưa thành luật)

| Lỗi | Luật rút ra | Ví dụ |
|---|---|---|
| Bài pgTAP chỉ kiểm cấu hình (`proconfig`) nên xanh trong khi hành vi sai | Bài kiểm phải chứng minh hành vi (gọi thật dưới đúng vai trò và thời hạn), không chỉ kiểm khai báo | #45: `statement_timeout` đặt trong hàm không nới được thời hạn của câu lệnh gọi |
| `aria-label` không chứa chữ đang hiện làm axe đỏ cho cả main | `aria-label` phải chứa nguyên chữ nhìn thấy; đổi bố cục chữ thì kiểm lại tên truy cập | #549 (menu tài khoản), sửa ở #565 |
| Lẫn commit không liên quan (workflow staging) vào PR RLS | Mỗi PR một việc; xem `git diff --stat main...` trước khi đẩy | #109 |
| Vùng chạm dưới 44px, nút Lưu xa ngón cái, bấm lại cùng mức làm mất điểm trên điện thoại | Màn giáo viên: nút ≥44px, hành động chính ở thanh đáy, thao tác phá huỷ có nút riêng | Tester 2 T12, sửa ở #562 |
| Soát chỉ đọc tên màn trong bản đồ, không mở màn thật: ghi «có màn» mà không tạo được phiếu | Bản đồ trạng thái chỉ ghi «Đã làm» khi đã mở màn trên staging đi hết luồng | Hoàn phí (CS-05), Chuyển phí (CS-10) không có nút tạo phiếu |
