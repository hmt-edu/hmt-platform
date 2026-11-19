# Đối chiếu menu cổng CRM với canvas (Code F, 19/11/2026; thẻ F20)

Nguồn canvas: các khung sidebar (`hmt-sb-l1`, `hmt-sb-l2`) trong `design/hmt-canvas-9933`, `-abea`, `-dc47`, `-9189`. Mã nguồn: `src/nav/crmMenu.ts`. Luật: canvas thắng gói cũ; vênh luật thì theo luật.

## Đã sửa (chỉ đổi nhãn, không đổi đường dẫn, quyền)
| Mã | Trước | Sau (theo canvas) |
|---|---|---|
| GD-06 | Chờ xếp lớp | Hàng chờ xếp lớp (PR F-MENU) |
| LOP-01 | Lớp | Lớp học (PR F-MENU) |
| BUOI-12 | Buổi chưa Done | Buổi chưa hoàn tất (PR F-MENU) |
| TC-04 | Chờ kế toán duyệt | Hàng chờ kế toán duyệt |
| CS-01 | Ticket | Tất cả ticket |
| QT-08 | Cơ sở và phòng học | Cơ sở và phòng |
| QT-11 | Nhật ký thao tác | Nhật ký |

## Chưa sửa, cần Chat/Design quyết
| Mục | Canvas | Code | Vì sao chưa sửa |
|---|---|---|---|
| TS-16 | Kiểm tra đầu vào | Phiếu kiểm tra | bài e2e `co-hoi.spec.ts` kiểm đường dẫn có chữ «Phiếu kiểm tra» (breadcrumb lấy nhãn menu); đổi cần sửa bài |
| Nhóm Bán hàng | «Bán hàng & thu chi» | «Bán hàng và thu chi» | nhiều bài e2e dùng «và»; giữ |
| Nhóm Chăm sóc | «Chăm sóc KH» | «Chăm sóc khách hàng» | giữ chữ đầy đủ |
| QT-04, QT-05 | một mục «Vai trò & quyền» | hai mục Vai trò, Ma trận quyền | cấu trúc: gộp hay giữ hai màn |
| QT-11, QT-12 | một mục «Nhật ký» | hai mục (thao tác; đăng nhập, xuất file) | cấu trúc: gộp thành một mục có hai tab? |
| QT-13 | Tài khoản học sinh, phụ huynh | Tài khoản học sinh | màn QT-13 chưa dựng (giai đoạn 4, R-CRM-32) |
| Cấu hình | hai mục gộp «Bán hàng: gói, giá, chiết khấu» và «Đào tạo: khung, rubric, ngày nghỉ» | các mục lẻ CH-01, 03, 04, 09, 05, 07, QT-14 | cấu trúc: canvas gộp theo nhóm |
| Báo cáo | «Báo cáo Looker Studio ↗» (liên kết ngoài) | không có | cần địa chỉ Looker từ anh Trường |
| TT-01, TT-04 | nằm nhóm Đào tạo (Tái tục, Đối chiếu tái tục) | nhóm Chăm sóc khách hàng; nhãn TT-01 đã đổi «Phiếu tái tục» thành «Tái tục» theo canvas (F30) | VỊ TRÍ nhóm chờ anh quyết, không tự đổi |
| BUOI-11 | không có | Điểm danh vận hành | giữ nếu luật cần (thẻ F-MENU hỏi Chat) |

**F30 (19/11/2026, sau khi PR menu #233 và #240 gộp):** dò lại toàn bộ nhãn menu với canvas bằng chương trình: ngoài các dòng «Chưa sửa» ở trên, không còn nhãn mục nào lệch. Nhãn còn khác chỉ là nhóm lớn («&» thay «và», «KH»), mục gộp theo cấu trúc canvas, và các mục chỉ có ở code (Chiến dịch marketing, Nhận xét chờ gửi, Nhóm ticket, SLA ticket, Người duyệt ticket, Khung chương trình, Rubric nhận xét, Giáo viên, trợ giảng, Điều khoản thanh toán): canvas sidebar không liệt kê.
