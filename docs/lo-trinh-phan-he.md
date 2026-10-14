# Lộ trình làm việc theo phân hệ

Cập nhật 14/10/2026. Một khái niệm duy nhất: **phân hệ**. Mỗi phân hệ là một vùng trên canvas Claude Design, đánh số P0, P1, P2…; thiết kế cả phân hệ một lượt. Bỏ các tên "đợt A/B/Tuyển sinh", "Đợt 5.x" khi trao đổi.

## Quy trình mỗi phân hệ (6 bước)
1. **Vẽ** (Claude Design): cả phân hệ, artboard 1440 × 1000 (điện thoại 390 × 844), chỉ dùng nút có trong danh sách, chỗ thiếu ghi "Câu hỏi mở".
2. **Anh duyệt**: comment, sửa trực tiếp trên canvas.
3. **Đặc tả màn hình** (Claude Chat viết): mỗi phân hệ một file. Mức A khoảng 1 trang (trường, nút, mọi trạng thái, lỗi, hộp thoại chặn); mức B nửa trang; mức C 2 dòng. Chỉ dẫn mã luật R-*, S03-*, không chép lại luật. Anh duyệt rồi đưa vào repo bằng PR tài liệu.
4. **Code** (Claude Code): dùng thành phần chung, không chép kiểu dáng riêng vào từng màn; thấy chỗ khác khuôn thì báo.
5. **Staging**: anh thử, comment "OK" trên PR.
6. **Chạy thật**: `hmt-deploy`.

Quy tắc kèm theo: chỉnh nhỏ ở một hộp thoại thì nói rõ chỉnh riêng (sửa trong màn) hay chỉnh chung (sửa khuôn).

## Danh sách phân hệ
| Mã | Phân hệ | Giai đoạn | Trạng thái |
|---|---|---|---|
| P0 | Khuôn chung (K1 List, K2 Kanban, K3 Chi tiết, K4 Hộp thoại, K5 Calendar + bổ sung B1–B7) | 0 | Anh đang sửa; đã gửi prompt bổ sung |
| P1 | Đăng nhập & Khung cổng | 0 | 10 màn đăng nhập đã lên canvas; khung các cổng chưa vẽ |
| P2 | Quản trị & Chung (Cấu hình, Ma trận quyền; sẽ bổ sung Người dùng, Vai trò, Danh mục, Cơ sở & phòng, Công tắc tính năng, Nhật ký, Tài khoản học sinh, Hồ sơ cá nhân) | 0 | Anh đang sửa |
| P3 | Tuyển sinh (Lead, Cơ hội, Lịch hẹn, Kiểm tra đầu vào) | 1 | Anh đang sửa |
| P4 | Khách hàng (Phụ huynh, Học sinh) | 1 | Chưa |
| P5 | Bán hàng (Báo giá, Đơn hàng, cấu hình gói/giá/chiết khấu) | 1 | Chưa |
| P6 | Thu chi (Phiếu thu, kế toán duyệt, công nợ) | 1 | Chưa |
| P7 | Ghi danh & Tái tục | 2 | Chưa |
| P8 | Lớp học | 2 | Chưa |
| P9 | Buổi học | 2 | Chưa |
| P10 | Chăm sóc khách hàng (Ticket) & Phiếu chi | 2 | Chưa |
| P11 | Cổng giáo viên | 3 | Chưa |
| P12 | Học tập (học sinh) & Phụ huynh | 4 | Chưa |
| P13 | Báo cáo (TC-15 Đối soát thu tiền, BC-01 Tổng quan Ban giám đốc; BC-02…10 làm trên Looker) | 5 | Làm sau cùng |
| P14 | Tìm kiếm & Thông báo (CHUNG-11, CHUNG-12) | 5 | Làm sau cùng |

## Thứ tự Claude Code
1. P0 xong: dựng hệ thiết kế (`hmt-theme.css`, PR 4d) và các khuôn dùng chung.
2. P1: viết phần khác biệt giữa bản cũ đã code và bản thiết kế mới.
3. P2, P3 xong: đặc tả màn hình, rồi code.
4. Ô tìm kiếm và chuông thông báo trên thanh trên nằm trong khung P0, dựng được ngay; bảng kết quả và danh sách thông báo chờ P14.

## Bốn việc đang treo
- Tách PR #16: PR dữ liệu (migration 016 + pgTAP) và giữ phần giao diện ở nháp.
- Đặt lại mật khẩu qua email: chốt SMTP, Google Workspace, tên miền.
- Đánh dấu `claude-code-buoc4.md` hết hạn hay không.
- Chốt công thức chuyển đổi luỹ kế và định nghĩa ASP bán mới.
