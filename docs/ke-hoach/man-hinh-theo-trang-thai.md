# Màn hình theo trạng thái (sinh tự động)

Sinh bằng `node scripts/man-hinh-theo-trang-thai.ts` từ `docs/design/ban-do-man-hinh.md`, `src/nav/crmMenu.ts`, `src/app/routes.tsx`, đầu file màn trong `src/`, `supabase/migrations/`, `e2e/`, `design/` và các bảng rà tay. **197 mã màn: 163 có màn, 15 chỉ có DB (chưa thấy màn), 19 chưa có.**

## Số theo cổng

| Cổng | Tổng | Có màn | Chỉ có DB | Chưa có |
|---|---|---|---|---|
| CRM (còn lại) | 155 | 144 | 4 | 7 |
| Giáo viên (GV) | 18 | 16 | 2 | 0 |
| Học sinh (HT) | 9 | 0 | 2 | 7 |
| Phụ huynh (PH) | 5 | 0 | 0 | 5 |
| Báo cáo (BC) | 10 | 3 | 7 | 0 |

Cách đọc: **Có màn** = mục menu có tuyến thật, hoặc mã màn nằm ở đầu file màn/hộp thoại, hoặc file ghi tay đã kiểm. **Chỉ có DB** = migration nhắc mã (hàm đã có) nhưng chưa thấy màn: có thể là hộp thoại nằm trong màn khác, người giữ xác nhận. **Chưa có** = không thấy gì. Mã nhắc ở file không phải màn (hàm tiện ích, hộp thoại của màn khác) KHÔNG được tính, để không báo thừa. «Đúng canvas» lấy từ các bảng rà tay (`ra-ui-*.md`, `doi-chieu-ui-*.md`, `doi-chieu-cot-gop.md`); chưa có bảng nào thì «chưa kiểm». «Ai giữ» theo tiền tố mã (gần đúng).

| Mã | Tên màn | Mức | Trạng thái (bằng chứng) | Khung canvas | Đúng canvas | e2e nhắc | Ai giữ |
|---|---|---|---|---|---|---|---|
| CHUNG-01 | Đăng nhập nhân viên, giáo viên | A | **Có màn** `src/pages/auth/LoginPages.tsx` | không có khung | chưa kiểm | smoke.spec.ts | Code F |
| CHUNG-02 | Xác thực hai bước (nhập mã TOTP) | B | **Có màn** `src/pages/auth/MfaPages.tsx` | không có khung | chưa kiểm | auth.spec.ts | Code F |
| CHUNG-03 | Thiết lập xác thực hai bước lần đầu | B | **Có màn** `src/pages/auth/TotpEnroll.tsx` | không có khung | chưa kiểm | auth.spec.ts | Code F |
| CHUNG-04 | Quên mật khẩu (liên hệ quản trị viên) **(theo thiết kế P1 v4, 18/10)** | B | **Có màn** `src/pages/auth/PasswordPages.tsx` | không có khung | chưa kiểm | smoke.spec.ts | Code F |
| CHUNG-05 | Đặt mật khẩu mới (từ link email) **(HOÃN, thiết kế P1 v4)** | C | **Chưa có** | không có khung | chưa kiểm | smoke.spec.ts | Code F |
| CHUNG-06 | Đăng nhập học sinh (mã HS) | A | **Có màn** `src/pages/auth/LoginPages.tsx` | không có khung | chưa kiểm | auth.spec.ts, smoke.spec.ts | Code F |
| CHUNG-07 | Đổi mật khẩu bắt buộc lần đầu | B | **Có màn** `src/pages/auth/PasswordPages.tsx` | không có khung | chưa kiểm | auth.spec.ts, so-sanh-dang-nhap.spec.ts | Code F |
| CHUNG-08 | Không thể đăng nhập **(chốt 12/10; chữ theo thiết kế P1 v4)** | C | **Có màn** `/khong-dang-nhap-duoc` (`CannotLoginPage`, PasswordPages.tsx) | có (DN08_pc_lock, DN08_mb_lock, canvas 9933) | đã so 23/11: khớp tiêu đề, một câu chung, nút «Quay lại đăng nhập», dòng «Cần hỗ trợ đăng nhập»; không nói lý do hay thời gian khoá (S03-18); không lệch | smoke.spec.ts (CHUNG-08), dang-nhap-thiet-ke.spec.ts | Code F |
| CHUNG-09 | Hết phiên làm việc | C | **Có màn** `src/pages/auth/SessionEndDialog.tsx` | không có khung | chưa kiểm | auth.spec.ts | Code F |
| CHUNG-10 | Khung ứng dụng CRM (menu trái, thanh trên, chọn cơ sở; điện thoại: menu thu gọn) | A | **Có màn** `src/layout/CrmShell.tsx` | không có khung | chưa kiểm | auth.spec.ts | Code F |
| CHUNG-11 | Tìm kiếm toàn hệ thống | B | **Có màn** `src/layout/GlobalSearch.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-12 | Trung tâm thông báo | B | **Có màn** `src/layout/NotificationBell.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-13 | Hồ sơ cá nhân (đổi mật khẩu, hai bước, phiên đăng nhập) | C | **Có màn** `src/pages/common/ProfilePage.tsx` | không có khung | chưa kiểm | auth.spec.ts | Code F |
| CHUNG-14 | Trang chủ CRM theo vai trò (việc của tôi hôm nay) | A | **Có màn** `src/pages/home/CrmHome.tsx` | không có khung | chưa kiểm | trang-chu.spec.ts | Code F |
| CHUNG-16 | Không có quyền truy cập | C | **Có màn** `src/pages/common/PortalPages.tsx` | không có khung | chưa kiểm | auth.spec.ts, quan-tri-chan-quyen.spec.ts | Code F |
| CHUNG-17 | Không tìm thấy / lỗi hệ thống | C | **Có màn** `src/pages/common/PortalPages.tsx` | không có khung | chưa kiểm | smoke.spec.ts | Code F |
| CHUNG-18 | Xuất file (có nhật ký) | C | **Có màn** `src/pages/lead/LeadListPage.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-19 | Lưu bộ lọc yêu thích | C | **Có màn** `src/list/Favorites.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-20 | Xoá bản ghi nhập nhầm (chỉ Admin) | C | **Có màn** `src/pages/lead/CancelLeadDialog.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-22 | Ghi chú trao đổi + lịch sử thay đổi (cột phải mọi bản ghi) | A | **Có màn** `src/ui/Chatter.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-24 | Phân hệ chưa bật ở cơ sở này | C | **Có màn** `src/pages/common/PortalPages.tsx` | không có khung | chưa kiểm | auth.spec.ts, so-sanh.spec.ts | Code F |
| CHUNG-25 | Chọn cổng (người có nhiều vai trò) | C | **Có màn** `src/pages/common/ChoosePortalPage.tsx` | không có khung | chưa kiểm | — | Code F |
| CHUNG-26 | Hộp thoại xác nhận chung + cảnh báo rời trang chưa lưu | B | **Có màn** `src/ui/Dialogs.tsx` | không có khung | chưa kiểm | — | Code F |
| QT-01 | Người dùng (danh sách) | B | **Có màn** `/crm/quan-tri/nguoi-dung` | không có khung | Lệch → đã sửa | nguoi-dung.spec.ts | Code F |
| QT-02 | Người dùng (bản ghi) | B | **Có màn** `src/pages/nguoi-dung/UserDialogs.tsx` | có (3 khung) | Gần đúng | nguoi-dung.spec.ts | Code F |
| QT-03 | Tạo người dùng | B | **Có màn** `src/pages/nguoi-dung/UserDialogs.tsx` | có (4 khung) | Gần đúng | nguoi-dung.spec.ts | Code F |
| QT-04 | Vai trò (danh sách + mô tả) | B | **Có màn** `/crm/quan-tri/vai-tro` | không có khung | chưa kiểm | ma-tran-quyen.spec.ts, vai-tro.spec.ts | Code F |
| QT-05 | Ma trận quyền (vai trò × phân hệ × hành động × phạm vi) | A | **Có màn** `/crm/quan-tri/ma-tran-quyen` | không có khung | chưa kiểm | ma-tran-quyen.spec.ts | Code F |
| QT-06 | Danh mục (danh sách các danh mục) | B | **Có màn** `/crm/quan-tri/danh-muc` | không có khung | chưa kiểm | danh-muc.spec.ts | Code F |
| QT-07 | Danh mục (sửa các mục) | A | **Có màn** `src/pages/danh-muc/CatalogDialogs.tsx` | có (11 khung) | Đúng | danh-muc.spec.ts | Code F |
| QT-08 | Cơ sở và phòng học | B | **Có màn** `/crm/quan-tri/co-so` | có (7 khung) | Đúng | ticket-sla.spec.ts | Code F |
| QT-09 | Cài đặt tham số nghiệp vụ | A | **Có màn** `/crm/quan-tri/tham-so` | có (9 khung) | Lệch → đã sửa | tham-so.spec.ts | Code F |
| QT-10 | Công tắc tính năng theo cơ sở | B | **Có màn** `/crm/quan-tri/cong-tac` | không có khung | chưa kiểm | cong-tac.spec.ts | Code F |
| QT-11 | Nhật ký thao tác | B | **Có màn** `/crm/quan-tri/nhat-ky` | không có khung | chưa kiểm | danh-muc.spec.ts | Code F |
| QT-12 | Nhật ký đăng nhập và xuất file | C | **Có màn** `/crm/quan-tri/nhat-ky-dang-nhap` | không có khung | chưa kiểm | danh-muc.spec.ts | Code F |
| QT-13 | Tài khoản học sinh (cấp, khoá, đặt lại mật khẩu) | B | **Có màn** `/crm/quan-tri/tai-khoan-hoc-sinh` | không có khung | chưa kiểm | tai-khoan-hoc-sinh.spec.ts | Code F |
| CHUNG-15 | Hàng việc chờ tôi duyệt (gộp mọi loại) | A | **Có màn** `/crm/viec-cho-duyet` | có (28 khung) | Đúng | auth.spec.ts, viec-cho-duyet.spec.ts | Code F |
| CHUNG-21 | Đính kèm tệp (tải lên, xem trước) | C | **Chưa có** | không có khung | chưa kiểm | — | Code F |
| CH-01 | Gói bán / sản phẩm (danh sách) | B | **Có màn** `/crm/cau-hinh/goi-ban` | có (4 khung) | Đúng | goi-ban.spec.ts | Code F |
| CH-02 | Gói bán (bản ghi) | C | **Có màn** `src/pages/goi-ban/PackageRecordPage.tsx` | không có khung | chưa kiểm | goi-ban-ban-ghi.spec.ts | Code F |
| CH-03 | Bảng giá có ngày hiệu lực | B | **Có màn** `/crm/cau-hinh/bang-gia` | có (6 khung) | Gần đúng | bang-gia.spec.ts | Code F |
| CH-04 | Chính sách chiết khấu | B | **Có màn** `/crm/cau-hinh/chiet-khau` | có (4 khung) | Lệch (chưa sửa) | chiet-khau.spec.ts | Code F |
| CH-08 | Chiến dịch marketing | C | **Có màn** `/crm/cau-hinh/chien-dich` | không có khung | chưa kiểm | chien-dich.spec.ts | Code F |
| CH-09 | Điều khoản thanh toán (các đợt, hạn đóng) | C | **Có màn** `/crm/cau-hinh/dieu-khoan-thanh-toan` | có (4 khung) | Đúng | dieu-khoan.spec.ts | Code F |
| TS-01 | Lead (danh sách / kanban theo giai đoạn) | A | **Có màn** `/crm/lead` | có (12 khung) | Lệch → đã sửa | lead.spec.ts, so-sanh.spec.ts | Code ? |
| TS-02 | Lead (bản ghi) | B | **Có màn** `src/pages/lead/LeadRecordPage.tsx` | có (17 khung) | Gần đúng | lead-ban-ghi.spec.ts, so-sanh.spec.ts | Code ? |
| TS-03 | Tạo lead nhanh (kèm kiểm trùng SĐT) | B | **Có màn** `src/pages/lead/LeadRecordPage.tsx` | có (5 khung) | Gần đúng | lead-ban-ghi.spec.ts, so-sanh.spec.ts | Code ? |
| TS-04 | Nhập lead từ file | C | **Có màn** `src/pages/lead/ImportLeadsDialog.tsx` | có (5 khung) | Đúng | nhap-lead.spec.ts | Code ? |
| TS-05 | Giao người phụ trách (lead, cơ hội, phiếu tái tục, ticket) | C | **Có màn** `src/features/assign/AssignDialog.tsx` | không có khung | chưa kiểm | lead.spec.ts, so-sanh.spec.ts | Code ? |
| TS-06 | Tạo cơ hội từ lead (cảnh báo đã có cơ hội) | B | **Có màn** `src/pages/co-hoi/CreateOpportunityDialog.tsx` | có (13 khung) | Gần đúng | co-hoi.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code ? |
| TS-07 | Cơ hội (danh sách / kanban L1–L8) | B | **Có màn** `/crm/co-hoi` | có (14 khung) | Lệch → đã sửa | co-hoi.spec.ts | Code ? |
| TS-08 | Cơ hội (bản ghi) | A | **Có màn** `src/pages/co-hoi/OpportunityRecordPage.tsx` | có (36 khung) | Gần đúng | co-hoi.spec.ts | Code ? |
| TS-09 | Chuyển giai đoạn cơ hội (chọn nhóm con, lý do) | C | **Có màn** `src/pages/co-hoi/OpportunityListPage.tsx` | có (25 khung) | Đúng | co-hoi.spec.ts | Code ? |
| TS-10 | Gộp lead / cơ hội trùng | C | **Có màn** `src/features/merge/MergeDialog.tsx` | có (14 khung) | Đúng | gop-trung.spec.ts | Code ? |
| TS-11 | Lịch hẹn (danh sách + lịch tuần) | A | **Có màn** `/crm/lich-hen` | có (15 khung) | Đúng | lich-hen.spec.ts | Code ? |
| TS-12 | Việc tuyển sinh hôm nay (lọc sẵn) | C | **Có màn** `src/pages/home/CrmHome.tsx` | không có khung | chưa kiểm | trang-chu.spec.ts | Code ? |
| TS-13 | Tạo / dời lịch hẹn | B | **Có màn** `src/features/appointments/AppointmentDialog.tsx` | có (5 khung) | Đúng | lead-ban-ghi.spec.ts, so-sanh.spec.ts | Code ? |
| TS-14 | Cảnh báo trùng khách hàng | C | **Có màn** `src/ui/Dialogs.tsx` | không có khung | chưa kiểm | lead-ban-ghi.spec.ts, so-sanh.spec.ts | Code ? |
| TS-15 | Tạo phiếu kiểm tra từ cơ hội (gồm xếp lịch, đổi lịch) | B | **Có màn** `src/pages/phieu/CreateTestDialog.tsx` | có (9 khung) | Gần đúng | phieu.spec.ts | Code ? |
| TS-16 | Phiếu kiểm tra (danh sách + Kanban + lịch) | B | **Có màn** `/crm/phieu-kiem-tra` | có (15 khung) | Lệch → đã sửa | phieu.spec.ts | Code ? |
| TS-17 | Phiếu kiểm tra (bản ghi) | A | **Có màn** `src/pages/phieu/TestDialogs.tsx` | có (5 khung) | Gần đúng | phieu.spec.ts | Code ? |
| KH-01 | Phụ huynh (danh sách) | B | **Có màn** `/crm/phu-huynh` | có (24 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-02 | Phụ huynh (bản ghi) | B | **Có màn** `src/pages/khach-hang/ParentRecordPage.tsx` | có (34 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-03 | Sửa phụ huynh (không có Tạo tay) | C | **Có màn** `src/pages/khach-hang/ParentRecordPage.tsx` | có (10 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-04 | Học sinh (danh sách) | B | **Có màn** `/crm/hoc-sinh` | có (24 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-05 | Học sinh (hồ sơ 360°) | B | **Có màn** `src/pages/khach-hang/StudentRecordPage.tsx` | có (48 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-06 | Sửa học sinh (không có Tạo tay) | C | **Có màn** `src/pages/khach-hang/StudentRecordPage.tsx` | có (10 khung) | Gần đúng | khach-hang.spec.ts | Code ? |
| KH-07 | Gộp phụ huynh / học sinh trùng | C | **Có màn** `src/pages/khach-hang/ParentRecordPage.tsx` | có (24 khung) | Gần đúng | — | Code ? |
| BH-01 | Báo giá (danh sách) | B | **Có màn** `/crm/bao-gia` | có (16 khung) | Đúng | bao-gia.spec.ts | Code C |
| BH-02 | Báo giá (bản ghi, dòng gói) | A | **Có màn** `src/pages/bao-gia/QuotationCreatePage.tsx` | có (65 khung) | Gần đúng | bao-gia.spec.ts | Code C |
| BH-03 | Bản in / gửi báo giá cho phụ huynh | B | **Có màn** `src/pages/bao-gia/QuotationPrintPage.tsx` | có (4 khung) | Gần đúng | bao-gia.spec.ts | Code C |
| BH-04 | Từ chối báo giá (lý do) | C | **Có màn** `src/pages/bao-gia/QuotationRecordPage.tsx` | không có khung | Đúng (so khung BH02_tu_choi, 23/11) | bao-gia.spec.ts | Code C |
| BH-05 | Đơn hàng (bản ghi) | A | **Có màn** `src/pages/don-hang/OrderCreatePage.tsx` | có (89 khung) | Gần đúng | don-hang-ban-ghi.spec.ts | Code C |
| BH-06 | Đơn hàng (danh sách) | B | **Có màn** `/crm/don-hang` | có (16 khung) | Đúng | don-hang-ban-ghi.spec.ts, don-hang.spec.ts | Code C |
| BH-07 | Duyệt / từ chối đơn hàng | B | **Có màn** `src/pages/don-hang/OrderApproveDialogs.tsx` | có (8 khung) | Đúng | don-hang-duyet.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code C |
| BH-08 | Chọn lớp và ngày vào lớp cho dòng đơn | A | **Có màn** `src/pages/don-hang/OrderCreatePage.tsx` | có (20 khung) | Đúng | chon-lop-don.spec.ts | Code C |
| BH-09 | Bật "Cho học trước, đóng tiền sau" | B | **Có màn** `src/pages/don-hang/PayLaterDialog.tsx` | có (4 khung) | Đúng | don-hang-cho-hoc-truoc.spec.ts | Code C |
| BH-10 | Huỷ đơn hàng (lý do) | C | **Có màn** `src/pages/don-hang/OrderRecordPage.tsx` | không có khung | Gần đúng (khung BH05_huy thêm câu minh hoạ «Chưa thu tiền.», 23/11) | — | Code C |
| BH-11 | Cảnh báo cơ hội đã có đơn nháp | C | **Có màn** `src/pages/don-hang/OrderCreatePage.tsx` | không có khung | Đúng (so khung BH02_bh11, 23/11) | don-hang-tao.spec.ts | Code C |
| TC-01 | Phiếu thu (danh sách) | B | **Có màn** `/crm/phieu-thu` | có (17 khung) | Lệch (chưa sửa) | — | Code C/D |
| TC-02 | Phiếu thu (bản ghi) | A | **Có màn** `src/pages/phieu-thu/CreateReceiptDialog.tsx` | có (69 khung) | Gần đúng | phieu-thu-no-dau-ky.spec.ts, phieu-thu.spec.ts | Code C/D |
| TC-03 | Tạo phiếu thu từ đơn hàng | B | **Có màn** `src/pages/phieu-thu/CreateReceiptDialog.tsx` | có (6 khung) | Gần đúng | phieu-thu.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code C/D |
| TC-04 | Hàng chờ kế toán duyệt | B | **Có màn** `/crm/cho-ke-toan-duyet` | có (20 khung) | Lệch (chưa sửa) | — | Code C/D |
| TC-05 | Kế toán duyệt / từ chối phiếu thu | A | **Có màn** `src/pages/phieu-thu/ReceiptRecordPage.tsx` | có (24 khung) | Gần đúng | phieu-thu.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code C/D |
| TC-06 | Huỷ phiếu thu (lý do) | C | **Có màn** `src/pages/phieu-thu/ReceiptRecordPage.tsx` | không có khung | Đúng (so khung bản ghi TC02_huy, 23/11) | — | Code C/D |
| TC-07 | Bản in phiếu thu / biên nhận | B | **Có màn** `src/pages/phieu-chi/VoucherPrintPage.tsx` | có (4 khung) | Gần đúng | phieu-thu.spec.ts | Code C/D |
| TC-08 | Khoản tiền vào (sổ thu tiền) | B | **Có màn** `/crm/khoan-tien-vao` | có (20 khung) | Đúng | thu-tien.spec.ts | Code C/D |
| TC-09 | Đảo khoản tiền (lý do) | B | **Có màn** `/crm/khoan-tien-vao` (nút Hoàn tác ở từng dòng, hộp lý do K08) | có (8 khung) | Đúng | cskh-khieu-nai-bao-luu.spec.ts, duong-ke-toan.spec.ts | Code C/D |
| TC-13 | Công nợ (đơn chưa thu đủ) | B | **Có màn** `/crm/cong-no` | có (16 khung) | Đúng | thu-tien.spec.ts | Code C/D |
| TC-15 | Đối soát thu tiền | B | **Có màn** `/crm/doi-soat-thu-tien` | có (16 khung) | Đúng nhãn (so TC15, _tai, _trong, _khong_quyen, 23/11; chip lọc mặc định do khuôn K03) | duong-ke-toan.spec.ts | Code C/D |
| GV-15 | Chấm kiểm tra đầu vào | B | **Có màn** `src/pages/gv/TeacherTodoPage.tsx` | có (20 khung) | Đúng | — | Code E |
| QT-14 | Ngày nghỉ lễ | B | **Có màn** `/crm/cau-hinh/ngay-nghi` | không có khung | chưa kiểm | ngay-nghi.spec.ts | Code F |
| QT-15 | Cấu hình người duyệt ticket theo nhóm con | B | **Có màn** `/crm/cau-hinh/nguoi-duyet-ticket` | không có khung | chưa kiểm | — | Code F |
| QT-16 | Giáo viên, trợ giảng (hồ sơ dạy) | B | **Có màn** `/crm/quan-tri/giao-vien` | không có khung | chưa kiểm | ho-so-day.spec.ts | Code F |
| CH-05 | Khung chương trình (danh sách phiên bản) | B | **Có màn** `/crm/cau-hinh/khung-chuong-trinh` | có (14 khung) | đã so 23/11 (7 khung): khớp chữ, nút, hộp Tạo bản mới/Ngừng, trạng thái trống/tải/quyền; không lệch | lop.spec.ts | Code F |
| CH-06 | Khung chương trình (danh sách bài học) | B | **Có màn** `src/pages/khung-chuong-trinh/CurriculumFramePage.tsx` | có (14 khung) | đã so 23/11 (7 khung): khớp; lệch có chủ đích: kéo tay nắm → nút Lên/Xuống; «Nhập từ file» chỉ nút mờ (thiếu khuôn T5) | — | Code F |
| KH-08 | Lên khối đầu năm học (hàng loạt) | C | **Có màn** `/crm/len-khoi-dau-nam` | không có khung | chưa kiểm | len-khoi-dau-nam.spec.ts | Code ? |
| TC-10 | Phiếu chi (danh sách) | B | **Có màn** `/crm/phieu-chi` | có (16 khung) | Đúng | phieu-chi-so-du.spec.ts | Code C/D |
| TC-11 | Phiếu chi (bản ghi) | B | **Có màn** `src/pages/phieu-chi/VoucherRecordPage.tsx` | có (12 khung) | Gần đúng | phieu-chi-so-du.spec.ts | Code C/D |
| TC-12 | Bản in phiếu chi | C | **Có màn** `src/pages/phieu-chi/VoucherPrintPage.tsx` | không có khung | Đúng luật (có In, Tải PDF; không có khung, 23/11) | trang-chu.spec.ts | Code C/D |
| TC-14 | Số dư khách hàng (tiền dư giữ lại) | C | **Có màn** `/crm/so-du-khach-hang` | không có khung | Gần đúng (danh sách và lịch sử đúng luật; nút «Cấn vào đơn mới» nằm ở đơn hàng (TC-16), không ở danh sách; không có khung, 23/11) | phieu-chi-so-du.spec.ts | Code C/D |
| TC-16 | Dùng số dư khách hàng cho đơn mới | C | **Có màn** `src/pages/don-hang/UseBalanceDialog.tsx` | không có khung | Đúng luật (hộp K08, tối đa theo số dư và còn phải thu, «Xác nhận dùng số dư»; không có khung, 23/11) | — | Code C/D |
| TC-17 | Quản lý duyệt phiếu thu | B | **Có màn** `src/features/approver-reassign/ReassignApproverDialog.tsx` | có (9 khung) | Gần đúng | — | Code C/D |
| GD-01 | Ghi danh (danh sách) | B | **Có màn** `/crm/ghi-danh` | có (16 khung) | Đúng | ghi-danh.spec.ts | Code A |
| GD-02 | Ghi danh (bản ghi) | A | **Có màn** `src/pages/ghi-danh/AssignClassDialog.tsx` | có (36 khung) | Gần đúng (so lại 20/11, #412 #446; còn ticket CS-04) | ghi-danh.spec.ts | Code A |
| GD-03 | Xếp lớp cho ghi danh (theo nhóm hoặc theo lớp) | A | **Có màn** `src/pages/ghi-danh/AssignClassDialog.tsx` | có (24 khung) | Đúng | duong-di-hoc-sinh.spec.ts, ghi-danh-nhom.spec.ts | Code A |
| GD-04 | Sổ giờ của ghi danh | B | **Có màn** `src/pages/ghi-danh/EnrollmentLedgerPage.tsx` | có (16 khung) | Lệch → đã sửa | ghi-danh-dieu-chinh-gio.spec.ts, ghi-danh.spec.ts | Code A |
| GD-05 | Điều chỉnh giờ (dòng ngược dấu, bắt buộc lý do) | B | **Có màn** `src/pages/ghi-danh/AdjustHoursDialog.tsx` | có (4 khung) | Gần đúng | ghi-danh-dieu-chinh-gio.spec.ts, ghi-danh.spec.ts | Code A |
| GD-06 | Hàng chờ xếp lớp | B | **Có màn** `/crm/cho-xep-lop` | có (16 khung) | Đúng | ghi-danh.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code A |
| GD-07 | Sắp hết giờ / dự báo hết giờ | B | **Có màn** `/crm/sap-het-gio` | có (16 khung) | Lệch → đã sửa | sap-het-gio.spec.ts | Code A |
| TT-01 | Phiếu tái tục (danh sách / kanban L1–L8) | B | **Có màn** `/crm/tai-tuc` | có (10 khung) | Đúng | — | Code C |
| TT-02 | Phiếu tái tục (bản ghi) | B | **Có màn** `src/pages/bao-gia/QuotationCreatePage.tsx` | có (16 khung) | Gần đúng | — | Code C |
| TT-03 | Tạo phiếu tái tục thủ công | C | **Có màn** `src/pages/ghi-danh/EnrollmentRecordPage.tsx` | có (2 khung) | Gần đúng | ghi-danh.spec.ts | Code C |
| LOP-01 | Lớp (danh sách / kanban theo bước duyệt) | B | **Có màn** `/crm/lop` | có (17 khung) | Lệch → đã sửa | lop.spec.ts | Code A |
| LOP-02 | Lớp (bản ghi) | A | **Có màn** `src/pages/lop/ClassRecordPage.tsx` | có (27 khung) | Gần đúng (so lại 21/11, #407 #420 #471) | lop.spec.ts | Code A |
| LOP-03 | Tạo / sửa lớp (chỉ ở Nháp, Từ chối) | B | **Có màn** `src/pages/lop/ClassFormPage.tsx` | có (26 khung) | Gần đúng (so lại 21/11, #407) | lop.spec.ts | Code A |
| LOP-04 | Thời khoá biểu lớp **(đã gộp vào LOP-03, 26/10, R-LOP-10)** | A | **Có màn** `src/pages/lop/ClassFormPage.tsx` | không có khung | Gần đúng (gộp vào LOP-03, so cùng LOP-03) | — | Code A |
| LOP-05 | Trình / xác nhận / duyệt / từ chối lớp | B | **Có màn** `src/pages/lop/ClassRecordPage.tsx` | có (12 khung) | Gần đúng | lop.spec.ts | Code A |
| LOP-06 | Đóng / huỷ lớp (bị chặn thì liệt kê lý do) | B | **Có màn** `src/pages/lop/ClassRecordPage.tsx` | có (6 khung) | Gần đúng | lop.spec.ts | Code A |
| LOP-07 | Đổi giáo viên và sinh lại buổi chưa diễn ra **(đã gộp vào LOP-03, 26/10, R-LOP-10, R-LOP-11)** | B | **Có màn** `src/pages/lop/ClassFormPage.tsx` | không có khung | Gần đúng (gộp vào LOP-03, so cùng LOP-03) | — | Code A |
| LOP-08 | Lịch tuần cơ sở (theo phòng, giáo viên) | A | **Có màn** `/crm/lich-tuan` | có (18 khung) | Lệch → đã sửa | lop.spec.ts | Code A |
| LOP-09 | Danh sách học sinh của lớp (dòng xếp lớp) | C | **Có màn** `src/pages/lop/ClassStudentsPage.tsx` | có (4 khung) | Gần đúng (#415) | duong-di-hoc-sinh.spec.ts | Code A |
| LOP-10 | Đổi lịch cố định của lớp đã duyệt **(đã gộp vào LOP-03, 26/10, R-LOP-10)** | B | **Có màn** `src/pages/lop/ClassFormPage.tsx` | không có khung | Gần đúng (gộp vào LOP-03, so cùng LOP-03) | — | Code A |
| BUOI-01 | Buổi học (danh sách, mặc định hôm nay) | B | **Có màn** `/crm/buoi-hoc` | có (8 khung) | Đúng | buoi-a.spec.ts, buoi-b.spec.ts | Code A |
| BUOI-02 | Buổi học (bản ghi) | A | **Có màn** `src/pages/buoi/SessionListPage.tsx` | có (16 khung) | Gần đúng | buoi-a.spec.ts, duong-di-hoc-sinh.spec.ts | Code A |
| BUOI-03 | Điểm danh phía vận hành + lý do liên hệ | B | **Có màn** `src/pages/buoi/AbsentTodayPage.tsx` | có (16 khung) | Đúng | buoi-a.spec.ts, duong-di-hoc-sinh.spec.ts | Code A |
| BUOI-04 | Huỷ buổi (trung tâm huỷ / học sinh huỷ lớp riêng) | A | **Có màn** `src/pages/buoi/CancelSessionDialog.tsx` | có (6 khung) | Gần đúng | buoi-b.spec.ts, yeu-cau-buoi.spec.ts | Code A |
| BUOI-05 | Dời một buổi (đổi ngày, giờ, phòng) | B | **Có màn** `src/pages/buoi/MoveSessionDialog.tsx` | có (2 khung) | Đúng | buoi-b.spec.ts | Code A |
| BUOI-06 | Thêm học sinh học thử vào buổi | B | **Có màn** `src/pages/buoi/AddTrialDialog.tsx` | có (2 khung) | Đúng | buoi-hoc-thu.spec.ts | Code A |
| BUOI-07 | Yêu cầu học bù (tạo) | B | **Có màn** `src/pages/yeu-cau-buoi/SessionRequestMakeupPage.tsx` | có (14 khung) | Gần đúng | yeu-cau-buoi.spec.ts | Code A |
| BUOI-08 | Yêu cầu buổi củng cố (tạo) | B | **Có màn** `src/pages/yeu-cau-buoi/SessionRequestCreatePage.tsx` | có (14 khung) | Gần đúng | yeu-cau-buoi.spec.ts | Code A |
| BUOI-09 | Yêu cầu học bổ trợ (tạo từ lớp) | B | **Có màn** `src/pages/yeu-cau-buoi/SessionRequestListPage.tsx` | có (14 khung) | Gần đúng | yeu-cau-buoi.spec.ts | Code A |
| BUOI-10 | Yêu cầu buổi (danh sách + duyệt) | B | **Có màn** `/crm/yeu-cau-buoi` | có (10 khung) | Đúng | yeu-cau-buoi.spec.ts | Code A |
| BUOI-11 | Điểm danh vận hành trong ngày (gọi nhắc) | B | **Có màn** `/crm/diem-danh` | có (8 khung) | Đúng | buoi-a.spec.ts | Code A |
| BUOI-12 | Theo dõi buổi chưa Done, GV chưa hoàn tất | B | **Có màn** `/crm/buoi-chua-done` | có (8 khung) | Đúng | buoi-b.spec.ts | Code A |
| BUOI-13 | Đổi giáo viên / trợ giảng cho một buổi (dạy thay) | B | **Có màn** `src/pages/buoi/ChangeStaffDialog.tsx` | có (2 khung) | Đúng | buoi-doi-giao-vien.spec.ts | Code A |
| BUOI-14 | Sửa điểm danh sau khi buổi Done | C | **Có màn** `src/pages/buoi/CorrectAttendanceDialog.tsx` | có (2 khung) | Đúng | buoi-sua-diem-danh.spec.ts | Code A |
| CS-01 | Ticket (danh sách / kanban theo bước) | B | **Có màn** `/crm/ticket` | có (18 khung) | Lệch (chưa sửa) | ticket-danh-sach.spec.ts | Code B |
| CS-02 | Ticket đề nghị (bản ghi) | A | **Có màn** `src/pages/ticket/TicketRecordPage.tsx` | có (6 khung) | Lệch → đã sửa | phieu-bao-luu-toan-luong.spec.ts | Code B |
| CS-03 | Ticket khiếu nại (bản ghi) | A | **Có màn** `src/pages/ticket/TicketRecordPage.tsx` | có (34 khung) | Lệch → đã sửa | — | Code B |
| CS-04 | Tạo ticket (chọn loại, nhóm, nhóm con) | B | **Có màn** `src/pages/ghi-danh/EnrollmentRecordPage.tsx` | có (12 khung) | Gần đúng (so khung CSN03 ở C50 cụm 2, #264; chưa mở staging) | — | Code B |
| CS-05 | Thực hiện hoàn tiền (bảng tính hoàn) | A | **Có màn** `/crm/phieu-nghiep-vu` | có (10 khung) | chưa kiểm | — | Code B |
| CS-06 | Thực hiện chuyển lớp (cùng môn) | B | **Có màn** `src/pages/phieu/TaskRecordPage.tsx` | có (46 khung) | Lệch → đã sửa | cskh-khieu-nai-bao-luu.spec.ts | Code B |
| CS-07 | Thực hiện chuyển cơ sở | B | **Chỉ có DB** `20261119000479_qt15_nguoi_duyet_ticket_hieu_luc.sql` | có (4 khung) | chưa kiểm | — | Code B |
| CS-08 | Duyệt / từ chối ticket (từng cấp) | B | **Có màn** `src/pages/phieu/TaskRecordPage.tsx` | có (14 khung) | Gần đúng (so khung CSN05, CSN06 ở C50 #268, #295, #390; chưa mở staging) | cskh-khieu-nai-bao-luu.spec.ts | Code B |
| CS-09 | Thực hiện bảo lưu (mới, gia hạn, quay lại sớm) | B | **Có màn** `src/pages/phieu/BusinessTaskDialog.tsx` | có (10 khung) | Gần đúng (so khung CSN06b ở #237, #295; chưa mở staging) | — | Code B |
| CS-10 | Thực hiện chuyển phí (sang môn khác, anh chị em, gói khác) | B | **Chỉ có DB** `20261119000479_qt15_nguoi_duyet_ticket_hieu_luc.sql` | không có khung | chưa kiểm | gv-ticket.spec.ts | Code B |
| CS-11 | Thực hiện đổi lịch học (dời buổi, đổi ca, xin học bù) | B | **Có màn** `src/pages/phieu/ScheduleTaskDialog.tsx` | không có khung | chưa kiểm | — | Code B |
| CS-12 | Từ chối / khách huỷ ticket (lý do) | C | **Chưa có** | không có khung | chưa kiểm | — | Code B |
| CS-13 | Nâng cấp / mở lại khiếu nại | C | **Có màn** `src/pages/ticket/TicketRecordPage.tsx` | không có khung | chưa kiểm | cskh-khieu-nai-bao-luu.spec.ts | Code B |
| CS-14 | Thực hiện dừng học (ticket nhóm Dừng học) | C | **Chỉ có DB** `20261119000427_c60_dung_hoc_qua_phieu.sql` | không có khung | chưa kiểm | — | Code B |
| CH-07 | Rubric nhận xét (tiêu chí, mô tả mức 1–5, theo môn) | B | **Có màn** `/crm/cau-hinh/rubric` | có (14 khung) | đã so 23/11 (7 khung): khớp; lệch luật: tab Câu mẫu theo R-V2-39 (24 câu), canvas vẽ tiêu chí × mức 1–5; chưa có Ngừng/Dùng lại tiêu chí (khung không có nút); mô tả mức là chữ mẫu | — | Code F |
| CS-16 | Nhận xét chờ gửi phụ huynh | B | **Chưa có** | không có khung | chưa kiểm | — | Code B |
| GV-01 | Khung cổng giáo viên (điện thoại: thanh dưới · laptop: menu trái thu gọn) | B | **Có màn** `src/layout/TabShell.tsx` | có (8 khung) | Đúng | auth.spec.ts, so-sanh.spec.ts | Code E |
| GV-02 | Hôm nay (buổi dạy, việc sắp trễ hạn) | A | **Có màn** `src/pages/gv/TeacherTodayPage.tsx` | có (16 khung) | Lệch → đã sửa | gv-hom-nay.spec.ts | Code E |
| GV-03 | Lịch dạy (tuần, tháng) | B | **Có màn** `src/pages/gv/TeacherSchedulePage.tsx` | có (16 khung) | Đúng | gv-lich-day.spec.ts | Code E |
| GV-04 | Buổi dạy (tổng quan các bước cần làm) | A | **Có màn** `src/pages/gv/TeacherSchedulePage.tsx` | có (31 khung) | Lệch → đã sửa | gv-cham-btvn.spec.ts, gv-cham-kiem-tra.spec.ts | Code E |
| GV-05 | Điểm danh (4 trạng thái) | A | **Có màn** `src/pages/gv/TeacherAttendancePage.tsx` | có (23 khung) | Đúng | buoi-a.spec.ts, gv-diem-danh.spec.ts | Code E |
| GV-06 | Nội dung buổi + giao BTVN | B | **Có màn** `src/pages/gv/SessionContentPage.tsx` | có (28 khung) | Đúng | gv-noi-dung.spec.ts, t4-duong-hoc-sinh-moi.spec.ts | Code E |
| GV-07 | Chấm nhận xét từng em | A | **Có màn** `src/pages/gv/ReviewGradingPage.tsx` | có (53 khung) | Lệch → đã sửa | gv-cham-btvn.spec.ts, gv-cham-kiem-tra.spec.ts | Code E |
| GV-08 | Chấm BTVN của buổi trước (5 trạng thái) | A | **Có màn** `src/pages/gv/TeacherTodoPage.tsx` | có (39 khung) | Đúng | gv-cham-btvn.spec.ts, gv-gio-day.spec.ts | Code E |
| GV-09 | Kiểm còn thiếu (QĐ-Đ21) | B | **Có màn** `src/pages/gv/CompleteDialog.tsx` | có (12 khung) | Gần đúng | gv-diem-danh.spec.ts, gv-hoan-tat.spec.ts | Code E |
| GV-10 | Lớp của tôi (danh sách) | B | **Có màn** `src/pages/gv/TeacherClassesPage.tsx` | có (16 khung) | Đúng | gv-chi-tiet-lop.spec.ts, gv-lop-cua-toi.spec.ts | Code E |
| GV-11 | Lớp (chi tiết cho giáo viên) | B | **Có màn** `src/pages/gv/TeacherClassPage.tsx` | có (16 khung) | Gần đúng | gv-cham-btvn.spec.ts, gv-chi-tiet-lop.spec.ts | Code E |
| GV-12 | Việc cần làm / quá hạn | B | **Có màn** `src/pages/gv/TeacherTodayPage.tsx` | có (16 khung) | Đúng | gv-viec-can-lam.spec.ts | Code E |
| GV-13 | Học sinh (hồ sơ rút gọn cho giáo viên) | C | **Có màn** `src/pages/gv/TeacherStudentPage.tsx` | có (16 khung) | Đúng | gv-chi-tiet-lop.spec.ts | Code E |
| GV-14 | Tạo ticket từ cổng giáo viên + ticket lớp tôi | B | **Có màn** `src/pages/gv/TeacherTicketCreatePage.tsx` | có (22 khung) | Đúng | gv-chi-tiet-lop.spec.ts, gv-ticket.spec.ts | Code E |
| GV-16 | Giờ dạy của tôi (căn cứ lương) | B | **Có màn** `src/pages/gv/TeacherHoursPage.tsx` | có (24 khung) | Lệch → đã sửa | gv-gio-day.spec.ts | Code E |
| BC-08 | Giáo viên trễ hạn hằng tháng | B | **Có màn** `/crm/bao-cao/giao-vien-tre-han` | có (10 khung) | đã so 23/11 (5 khung): khớp bảng, thẻ tổng, trống, tải; LỆCH LỚN: chưa có «Xuất CSV» (khung có, chờ Chat xác nhận); chữ trang không quyền chưa theo khung | bc08-tre-han.spec.ts | Code F |
| BC-09 | Giờ dạy giáo viên (căn cứ tính lương) | B | **Có màn** `/crm/bao-cao/gio-day` | có (16 khung) | đã so 23/11 (8 khung): khớp bảng, trống, tải; LỆCH LỚN: chưa có Chốt tháng, trạng thái Chưa chốt/Đã chốt, hộp Chốt, Xuất CSV (cần bảng chốt trong DB, thẻ riêng; luật: chốt cả hệ thống, không Mở lại, Trưởng cơ sở không có nút Chốt) | bc09-gio-day.spec.ts | Code F |
| CHUNG-23 | Đăng nhập phụ huynh | C | **Chưa có** | không có khung | chưa kiểm | — | Code F |
| QT-17 | Tài khoản phụ huynh (cấp, khoá, đặt lại) | C | **Chưa có** | không có khung | chưa kiểm | — | Code F |
| QT-18 | Nhập dữ liệu cũ (chọn loại, tải file CSV, xem trước từng dòng, nạp, tải dòng lỗi) | B | **Có màn** `/crm/quan-tri/nhap-du-lieu` | có (10 khung) | Đúng | nhap-du-lieu.spec.ts | Code F |
| GV-17 | Giao bài trên LMS (đề, tệp, hạn nộp) | B | **Chỉ có DB** `20261121000597_lms_giao_bai.sql` | không có khung | chưa kiểm | — | Code E |
| GV-18 | Chấm bài nộp online | B | **Chỉ có DB** `20261121000598_lms_cham_bai.sql` | không có khung | chưa kiểm | — | Code E |
| HT-01 | Trang chủ học sinh | A | **Chưa có** | không có khung | chưa kiểm | phieu-chi-so-du.spec.ts, phieu-thu-no-dau-ky.spec.ts | giai đoạn sau |
| HT-02 | Bài tập (cần làm, đã nộp, đã chấm) | B | **Chưa có** | không có khung | chưa kiểm | auth.spec.ts | giai đoạn sau |
| HT-03 | Chi tiết bài tập | B | **Chỉ có DB** `20261121000597_lms_giao_bai.sql` | không có khung | chưa kiểm | — | giai đoạn sau |
| HT-04 | Nộp bài (chụp ảnh, tải tệp) | A | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| HT-05 | Kết quả bài và nhận xét | B | **Chỉ có DB** `20261121000597_lms_giao_bai.sql` | không có khung | chưa kiểm | — | giai đoạn sau |
| HT-06 | Lịch học của em | B | **Chưa có** | không có khung | chưa kiểm | phieu-thu.spec.ts | giai đoạn sau |
| HT-07 | Kết quả học tập (tiêu chí theo thời gian) | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| HT-08 | Nhận xét các buổi học | C | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| HT-09 | Khung cổng học tập (điện thoại: thanh dưới · laptop: menu trái, nội dung một cột giữa trang) | B | **Chưa có** | không có khung | chưa kiểm | so-sanh.spec.ts | giai đoạn sau |
| PH-01 | Trang chủ phụ huynh (các con) | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| PH-02 | Kết quả và nhận xét của con | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| PH-03 | Học phí và giờ học của con | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| PH-04 | Gửi đề nghị / khiếu nại và theo dõi | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| PH-05 | Lịch học của con | B | **Chưa có** | không có khung | chưa kiểm | — | giai đoạn sau |
| BC-01 | Tổng quan Ban giám đốc | A | **Có màn** `/crm/bao-cao/tong-quan` | không có khung | chưa kiểm | — | Code F |
| BC-02 | Báo cáo tuyển sinh (phễu lead → đăng ký) | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-03 | Doanh thu ghi nhận theo buổi Done | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-04 | Thu tiền và giờ chưa dạy (quỹ giờ còn) | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-05 | Tái tục | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-06 | Sĩ số, lấp đầy lớp, chuyên cần | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-07 | BTVN (tỉ lệ làm bài, điểm TB) | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
| BC-10 | Báo cáo ticket | Looker (không vẽ) | **Chỉ có DB** `20261116000214_bao_cao_view.sql` | không có khung | chưa kiểm | — | Code F |
