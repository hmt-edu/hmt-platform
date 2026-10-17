# Bổ sung luật 17/10/2026: mô hình hồ sơ phụ huynh, học sinh dùng chung

Anh Trường đã nói "OK ĐƯA VÀO LUẬT" ngày 17/10/2026 (14:39), sau khi duyệt wireframe hồ sơ học sinh, phụ huynh (10 màn). File này **bổ sung sau** `04d`, `04e`. Khi Code đưa vào repo: thêm R-CRM-26 đến R-CRM-32 vào `docs/spec/04-luat-nghiep-vu.md` (ghi "(17/10)"), sửa `docs/design/ban-do-man-hinh.md` (KH-01 đến KH-06), `docs/nghiep-vu/phan-quyen.md`; không giữ file riêng. Repo là bản đúng.

## 1. Luật mới

| Mã | Luật | |
|---|---|---|
| R-CRM-26 | **(17/10)** **Hồ sơ phụ huynh (PH), học sinh (HS) dùng chung toàn hệ thống**, một người một hồ sơ, không tách theo cơ sở. Mã giữ theo spec 02. | [CHỐT] |
| R-CRM-27 | **(17/10)** **Không có thao tác Tạo tay** PH, HS. Hồ sơ **sinh tự động trong hàm nghiệp vụ**: PH sinh khi tạo cơ hội, khớp theo **SĐT đã chuẩn hoá**; HS sinh khi tạo phiếu kiểm tra đầu vào hoặc khi duyệt đơn, khớp theo **PH + tên đã chuẩn hoá + năm sinh**. Khớp thì dùng hồ sơ có sẵn, không khớp thì tạo mới. Người dùng chỉ **Sửa** và **Gộp** (R-CRM-25). Nhập dữ liệu cũ từ Sheet đi qua hàm riêng của đợt đồng bộ, không qua giao diện. | [CHỐT] |
| R-CRM-28 | **(17/10)** **Cơ sở tiếp nhận** của PH, HS: cố định theo cơ sở của cơ hội đầu tiên sinh ra hồ sơ, **chỉ Admin sửa**; doanh thu ban đầu ghi theo cơ sở này. **Đang học tại**: tự tính từ các lớp đang học (có thể nhiều cơ sở), không ai sửa tay. Đổi cơ sở tiếp nhận hoặc chuyển học sang cơ sở khác chỉ qua **ticket đề nghị "Chuyển cơ sở"** đã duyệt (R-CS-02, R-CS-03). | [CHỐT] |
| R-CRM-29 | **(17/10)** **Xuất file** danh sách, hồ sơ PH, HS: **chỉ Admin**. Trưởng cơ sở và các vai trò khác không có Xuất trên hai phân hệ này. | [CHỐT] |
| R-CRM-30 | **(17/10)** **Chăm sóc hàng tháng:** mỗi HS đang học mỗi tháng có **một ticket chăm sóc**, hệ thống tự sinh bằng pg_cron, giao CSKH của **cơ sở có lớp chính** của HS. Tháng đã có ticket thì không sinh thêm. Hạn xử lý là tham số cấu hình. Nhật ký liên hệ xem ở dòng thời gian (lọc "Liên hệ"), không có bảng riêng. | [CHỐT]; hạn xử lý là **tham số cấu hình** (khai báo bằng migration kèm giá trị mặc định tạm; anh cài giá trị thật sau trong màn Cấu hình) |
| R-CRM-31 | **(17/10)** **Mục tiêu học tập** của HS là **một ô chữ tự do** (không có bảng mục tiêu, mốc ngày). Điểm bài kiểm tra tháng do giáo viên nhập trong App Giáo viên. Nhận xét từng buổi nằm ở App Giáo viên; hồ sơ HS chỉ có đường dẫn tới nhận xét đó, không lặp lại. | [CHỐT] |
| R-CRM-32 | **(17/10)** **Tài khoản app học sinh** (giai đoạn sau): hồ sơ có ba thao tác Cấp tài khoản, Đặt lại mật khẩu, Khoá tài khoản (quyền như QT-13). **Mật khẩu không bao giờ hiển thị**, chỉ đặt lại để tạo mật khẩu mới. Giai đoạn 1: nút mờ, chưa làm. | [CHỐT]; làm ở giai đoạn 4 |

## 2. Ma trận quyền phiên bản 4 (anh duyệt bảng TRƯỚC / SAU của Code rồi mới nạp)

Áp cho hai phân hệ **Phụ huynh (PARENT)** và **Học sinh (STUDENT)**:

| Thay đổi | Vai trò | Ghi chú |
|---|---|---|
| **Bỏ Tạo** | Tuyển sinh, CSKH, Trưởng cơ sở, Admin | Hồ sơ sinh qua hàm hệ thống (R-CRM-27). Hàm tạo là `security definer` nên không cần quyền Tạo của người gọi. |
| **Bỏ Xuất** | Trưởng cơ sở | Chỉ Admin còn Xuất (R-CRM-29). |
| **Xem: phạm vi toàn hệ thống** | Tuyển sinh, CSKH, Trưởng cơ sở | Để khớp, tìm hồ sơ đã có ở cơ sở khác (R-CRM-26). Sửa và Duyệt vẫn **cơ sở mình** (đã có ở 04d). Hồ sơ "thuộc cơ sở mình" khi Cơ sở tiếp nhận là cơ sở mình hoặc Đang học tại có cơ sở mình. **[CHỐT 17/10, 14:44]** anh đã xác nhận cách hiểu này. |
| **Thêm Xem PARENT** | Kế toán (toàn hệ thống) | Kế toán đã có Xem STUDENT; cần Xem PH để đối chiếu thu chi (PH-03). |
| Giữ nguyên | Giáo viên, trợ giảng | Xem STUDENT trong phạm vi được phân công; không thêm quyền PH. |

Cột "Hành động" trên thanh nút hồ sơ chỉ gồm: Gộp (quyền Duyệt), Tạo ticket (quyền Tạo của phân hệ Ticket). Ba nút tài khoản HS theo QT-13.

## 3. Việc cho Code (lời nhắn P3b2, P3b3, P4)

- **P3b2:** `student_id` ở cơ hội, phiếu kiểm tra cho phép rỗng đến khi có HS; hàm tạo cơ hội gọi hàm "tìm hoặc tạo PH" (khớp SĐT chuẩn hoá); hàm tạo phiếu kiểm tra, duyệt đơn gọi hàm "tìm hoặc tạo HS" (khớp PH + tên + năm sinh chuẩn hoá). Chỉ mục cho SĐT chuẩn hoá và (PH, tên chuẩn hoá, năm sinh). pgTAP: trùng thì dùng hồ sơ cũ, khác cơ sở vẫn khớp, không khớp thì tạo mới; chặn ghi trực tiếp vào bảng PH, HS ngoài hàm.
- **Khối và Tình trạng của HS:** thêm cột cho danh sách KH-04 (tình trạng theo spec 02: Tiềm năng, Đang học, Bảo lưu, Dừng học; hệ thống tự đổi).
- **Ma trận v4:** nạp bằng `app.save_permission_matrix` sau khi anh duyệt TRƯỚC / SAU; sửa bài kiểm thử nào đang ghi "Tuyển sinh có Tạo PH, HS".
- **Màn hình:** bỏ phần Tạo ở KH-01, KH-03, KH-04, KH-06 (chỉ còn Sửa); cập nhật bản đồ màn hình.
- **Chăm sóc tháng (R-CRM-30):** hàm sinh ticket + lịch pg_cron làm cùng phân hệ Ticket; ghi vào việc chờ nếu phân hệ Ticket chưa có.
- **Sau này:** bài kiểm tra tháng nhập từ App Giáo viên (giai đoạn 3); tài khoản app học sinh (giai đoạn 4).
