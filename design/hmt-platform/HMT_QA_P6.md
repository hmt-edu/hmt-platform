# HMT Platform · Kiểm tra P6 (QA)

Ngày 12/10/2026 · chuẩn: `HMT_BAN_DO_MAN_HINH.md` (12/10), `HMT_LUAT_CHO_THIET_KE.md` mục 4 và mục 9, `04-luat-nghiep-vu.md` (các dòng 12/10), `HMT_DANH_MUC_VA_THAM_SO.md`. Bản kiểm đầu, sau đó sửa theo ý anh ngày 12/10 (cột Kết quả).

## Tỉ lệ màn đạt

**Sau khi sửa (12/10, kiểm lại):**
- Màn phải vẽ (A + B): **147**, đã vẽ 147.
- Đạt, không còn lỗi Cao/Trung bình: **147/147 = 100%**.
- Đạt hoàn toàn, trừ hai dòng anh cho bỏ (tên rút gọn; màu mã QR): **147/147 = 100%**.

**Lần kiểm đầu (trước khi sửa):** 121/147 = 82% không có lỗi Cao/Trung bình; 48/147 = 33% đạt hoàn toàn.

**Kiểm lại sau sửa:** chạy lại kiểm trạng thái mức A, luồng, vùng bấm (đo phần tử bấm được trong mọi khung điện thoại, kể cả bản điện thoại của màn CRM), tương phản AA, mã và dữ liệu mẫu trên các màn đã sửa — không còn lỗi mới. Các màn mức A còn thiếu "trống" hoặc "không quyền" theo bộ đếm tự động (CHUNG-01, CHUNG-06, BUOI-04, CS-05, GV-05) đã xét là không áp dụng (xem mục "Đã kiểm, đạt").

## Bảng lỗi

| Mã màn | Loại lỗi | Mô tả | Mức nghiêm trọng | Cách sửa | Kết quả (12/10) |
|---|---|---|---|---|---|
| TC-05 | Thiếu trạng thái (mức A) | Thiếu Đang tải, Lỗi và Không có quyền (Trưởng cơ sở mở link duyệt phiếu thu phải thấy "Không có quyền", R-TIEN · BM không duyệt tiền) | Cao | Thêm 3 trạng thái; Không quyền dùng vai trò BM | Đã sửa: thêm Đang tải, Lỗi, Không có quyền (Trưởng cơ sở, chỉ dẫn sang TC-02 để xem) và trạng thái "Admin duyệt thay". Kiểm lại: đủ 4 trạng thái mức A. |
| TC-13 | Luồng L2 đứt | Công nợ không có "Mở đơn" (hành động trong bản đồ) nên không sang được BH-05 → Tạo phiếu thu (TC-03) | Cao | Dòng công nợ bấm được mở BH-05; thêm nút "Tạo phiếu thu" theo đợt | Đã sửa: mã đơn là link, cột "Mở đơn" sang BH-05; vai trò Tuyển sinh có thêm "Tạo phiếu thu" cho đúng đợt (TC-03). Kiểm lại luồng L2: liền. |
| BH-08 | Thiếu trạng thái (mức A) | Thiếu Không có quyền | Trung bình | Thêm trạng thái Không có quyền (KT mở link) | Đã sửa: thêm trạng thái Không có quyền (Kế toán mở link). |
| GD-03 | Thiếu trạng thái (mức A) | Thiếu Không có quyền | Trung bình | Thêm trạng thái Không có quyền (SA mở link) | Đã sửa: thêm trạng thái Không có quyền (Tuyển sinh, Kế toán). |
| TC-09 | Quyền · Admin duyệt thay | Đảo khoản không có dòng lịch sử "Admin duyệt thay" khi Admin làm (R-HT-01) | Trung bình | Thêm vai trò Admin + dòng lịch sử như TC-05 | Đã sửa: hai trạng thái Kế toán / Admin làm thay; lịch sử ghi "Admin duyệt thay". |
| TC-03 | Luồng L1, L2 đứt | Sau "Tạo phiếu nháp" không dẫn sang phiếu thu (TC-04) để trình Kế toán duyệt (TC-05) | Trung bình | Tạo xong mở TC-04, toast có link | Đã sửa: tạo xong hiện phiếu PT-CS1-2610-0051 ở Nháp kèm nút "Mở phiếu thu để trình (TC-02)" (bản ghi phiếu thu là TC-02, không phải TC-04 như ghi ban đầu). |
| TS-11 | Luồng L1 đứt | Lịch hẹn không có link mở lead/cơ hội gốc, nên không đi tiếp được sang Tạo cơ hội (TS-06) | Trung bình | Mỗi lịch hẹn có link mã LD/CO mở TS-02/TS-08 | Đã sửa: mã LD / CO / PKT dưới mỗi lịch hẹn là link mở TS-02 / TS-08 / TS-17. |
| GV-10, GV-12, HT-02, HT-06, HT-07, PH-02, PH-03, PH-05 | Vùng bấm < 44px | Chip lọc trong cổng Giáo viên, Học tập cao 40px | Trung bình | CSS: chip teacher/lms cao 44px | Đã sửa ở thành phần gốc: Chip trong cổng Giáo viên, Học tập và khung điện thoại cao 44px (laptop giáo viên 36px). Kiểm lại: 0 chip dưới 44px. |
| GV-08, GV-14, GV-15, GV-16, GV-17 | Vùng bấm < 44px | Ô chọn (select gốc) chỉ nhận chạm trên 24px giữa khung 48px | Trung bình | CSS: select phủ hết chiều cao khung | Đã sửa ở thành phần gốc: ô nhập, ô chọn phủ hết chiều cao khung (44–48px). Kiểm lại: đạt. |
| GV-02, GV-05, GV-09 | Vùng bấm < 44px | Nút size="sm" (Tiếp tục, Mở buổi, Còn lại: Có mặt, Đi tới) cao 32px trên điện thoại | Trung bình | CSS: [data-product=teacher] nút sm tối thiểu 44px trên điện thoại | Đã sửa ở thành phần gốc: Button size="sm" cao 44px trong cổng Giáo viên, Học tập và mọi khung điện thoại; laptop giữ 32px. Kiểm lại: đạt. |
| GV-07, K12 | Vùng bấm < 44px | Nút "Bỏ chấm" của RatingScale 32×32px | Trung bình | Tăng lên 44×44px (giữ biểu tượng 20px) | Đã sửa (cùng quy tắc nút sm): "Bỏ chấm" 44×44px. |
| CHUNG-06, CHUNG-07, GV-17 | Vùng bấm < 44px | Nút chỉ có biểu tượng (Hiện mật khẩu, Gỡ tệp, Chọn ngày từ lịch) 32–40px | Trung bình | Nút biểu tượng 44×44px trên điện thoại | Đã sửa: nút biểu tượng tối thiểu 44px; "Hiện mật khẩu" phủ hết chiều cao ô (42px bên trong khung 44px có viền). |
| 82 màn | Tên màn | Tên trên thẻ là tên rút gọn, khác tên trong bản đồ (ví dụ CHUNG-02 "Xác thực hai bước" ↔ "Xác thực hai bước (nhập mã TOTP)"). Danh sách đủ ở phụ lục A | Thấp | Đổi tên ScreenFrame theo đúng cột "Tên màn" của bản đồ | Bỏ: theo anh, giữ tên hiện tại vì mã màn đúng và tiêu đề trên giao diện rõ nghĩa. |
| BH-07, LOP-05, CS-08, TC-11 | Quyền · Admin duyệt thay | Admin duyệt được (menu đủ quyền) nhưng màn không thể hiện ghi "Admin duyệt thay" trong lịch sử | Thấp | Thêm một dòng lịch sử mẫu khi xem với vai trò Admin | Đã sửa: BH-07 thêm trạng thái "Admin duyệt thay"; LOP-05, CS-08, TC-11 ghi rõ Admin duyệt thay, lịch sử ghi "Admin duyệt thay". |
| BH-03 | Luồng L1 | Bản in báo giá không có đường quay về báo giá / Chuyển thành đơn | Thấp | Thêm nút quay lại BH-02 | Đã sửa: nút "Về báo giá BG-CS1-2610-0003 (BH-02)". |
| BH-07 | Luồng L1 | Duyệt đơn xong không gợi ý bước tiếp "Tạo phiếu thu" | Thấp | Toast sau duyệt có link Tạo phiếu thu (BH-05 đã có nút) | Đã sửa: trạng thái Đã duyệt có "Tạo phiếu thu (TC-03)" và "Mở đơn (BH-05)". |
| LOP-03, LOP-04 | Luồng L3 | Lưu nháp lớp / lưu thời khoá biểu không dẫn sang bước kế tiếp (thời khoá biểu, Trình) | Thấp | Sau lưu mở LOP-02 ở tab Thời khoá biểu; LOP-04 có nút Trình khi đủ | Đã sửa: LOP-03 ghi bước kế tiếp (LOP-02 tab Thời khoá biểu → LOP-04 → LOP-05); LOP-04 thêm "Lưu và trình duyệt (LOP-05)". |
| TT-01 | Luồng L6 | Thẻ phiếu tái tục chưa thể hiện bấm mở TT-02 | Thấp | Thẻ kanban/dòng có link mã TT | Đã sửa: mã trên thẻ kanban và trong bảng là link mở TT-02 (KanbanCard thêm `onOpen`). |
| QT-02 | Luồng L13 | Người dùng không có link sang vai trò (QT-04) / ma trận quyền (QT-05) | Thấp | Vai trò trên bản ghi là link | Đã sửa: vai trò trên QT-02 là link, thêm "Xem quyền của các vai trò này (QT-05)". |
| BH-09 | Luồng L15 | Bật "Cho học trước" xong không cho thấy ghi danh sinh sớm (GD-02) | Thấp | Toast có link mã GD | Đã sửa: sau khi bật có link "Mở ghi danh GD000129 (GD-02)". |
| CHUNG-06 | Vùng bấm < 44px | Link "Em quên mật khẩu" cao 24px | Thấp | Thêm đệm dọc cho link thành 44px | Đã sửa: link cao 44px. |
| CHUNG-03 | Token | Mã QR mẫu dùng màu viết cứng #fff/#111 | Thấp | Giữ (QR cần đen trắng) hoặc đổi sang token --hmt-surface/--hmt-fg; ghi chú ngoại lệ | Bỏ: ngoại lệ đã chốt — mã QR giữ đen trên nền trắng để quét được. |
| HomeworkStatus (thẻ), HT-01 | Dữ liệu mẫu không khớp | Trịnh Khánh Linh có hai mã: HS000427 (thẻ HomeworkStatus, lớp 8) và HS000298 (HT-01, lớp 11) | Thấp | Đổi tên học sinh trong thẻ HomeworkStatus | Đã sửa: học sinh lớp 11 ở HT-01 đổi thành Võ Thuỳ Dương (HS000298); dòng công nợ CS4 ở TC-13 đổi thành Tô Bảo Châu; Trịnh Khánh Linh giữ một mã HS000427. |
| TS-17 | Mã | Tên tệp "Phieu-danh-gia-PKT-0005.pdf" theo mã cũ | Thấp | Đổi thành PKT000105 | Đã sửa: Phieu-danh-gia-PKT000105.pdf. |
| CHUNG-10, CHUNG-11, CH-05, CH-06 (README) | Vai trò | README ghi vai trò khác bản đồ mới (thiếu AD hoặc ngược lại) | Thấp | Sinh lại dòng vai trò từ bản đồ 12/10 | Đã sửa: dòng vai trò sinh lại từ bản đồ 12/10. |
| BH-07, BUOI-03, CHUNG-01, CHUNG-15, K03, K06 (CRM trên điện thoại) | Vùng bấm < 44px (phát hiện khi kiểm lại) | Màn duyệt, điểm danh vận hành bản điện thoại: nút 36px, ô nhập 34px, tab 42px, link mã 20px, nút đổi kiểu xem 34px | Trung bình | Áp cùng quy tắc 44px cho khung điện thoại CRM | Đã sửa ở thành phần gốc (`.hmt-phone` và màn hình ≤ 640px). Kiểm lại: đạt (ô nhập 42px trong khung 44px có viền). |

## Đã kiểm, đạt

- **Đủ màn:** 36/36 màn mức A, 111/111 mức B có thẻ; 43 màn mức C chỉ liệt kê; 7 màn Looker không vẽ. Không có mã vẽ thừa.
- **Mức A:** các màn đăng nhập (CHUNG-01, CHUNG-06) không có trạng thái "trống" và "không quyền" theo nghĩa thông thường — coi là không áp dụng; BUOI-04, CS-05 dùng "Đang xử lý" thay "Đang tải"; GV-05 dùng "Chưa lưu được" làm trạng thái lỗi. Mọi màn mức A "Cả hai"/"Điện thoại" có bản điện thoại.
- **Không có nút Tạo trái luật:** BH-01, BH-04, TC-01, TC-02, TT-01, GD-01, BH-06 không có nút Tạo (R-TIEN-02); phiếu tái tục chỉ có "Tạo phiếu tái tục thủ công" trên ghi danh (GD-02).
- **Không lùi trái luật:** cơ hội (TS-08) chỉ đi tới; lead (TS-02) đổi tự do hai chiều, C4D hệ thống gắn (R-CRM-09); đơn, phiếu thu bị từ chối về Nháp (R-TIEN-06).
- **Vai trò:** Trưởng cơ sở không có nút duyệt phiếu thu, đảo khoản, phiếu chi; chỉ Trưởng cơ sở (và Admin duyệt thay) duyệt yêu cầu buổi (BUOI-10); giáo viên không có nút đổi tình trạng buổi, huỷ buổi, chốt danh sách ở mọi màn GV.
- **Mục 9 file luật:** mã mới LD (24 chỗ), CO (40), PKT (16), GD (72), TT (13), KTV-CS1-2610-xxxx (8); không còn gói chứa hình thức; "LEAD-2609-…" chỉ còn ở dạng mã cũ hiện nhỏ (TS-01, đúng quy ước). Ghi danh có "Đã xếp lớp" (GD-01, GD-02, GD-03). Phiếu tái tục L1–L8, L5 Không tái tục bắt buộc lý do (TT-01, TT-02). Giờ tặng tính vào trần 20% (BH-02 "Tặng 4 giờ = 8,3%", BH-05 trạng thái Vượt trần, CH-04). Admin duyệt thay ở TC-05, BUOI-10. Điểm BTVN 1–5, kiểm tra đầu vào 0–10. Cổng phụ huynh 5 tab + menu ảnh đại diện.
- **Cổng giáo viên laptop:** GV-01…GV-09 đều có hai bố cục điện thoại + laptop (K14 ở GV-05, GV-07, GV-08; hai cột ở GV-04). GV-10…GV-16 mức B một bố cục (P-87).
- **Admin trong CRM:** `menuFor("AD")` mở mọi phân hệ (A-22); ô chọn cơ sở có "Tất cả cơ sở".
- **Tương phản AA:** đo màu chữ/nền thật trên trạng thái mặc định của 147 thẻ màn: 0 cặp dưới 4,5:1 (chữ thường) hoặc 3:1 (chữ lớn).
- **Định dạng:** không có "VND", số tiền dấu phẩy, ngày ISO, giờ AM/PM trong chữ hiển thị; tiền dạng 9.504.000 đ; ngày dd/mm/yyyy; giờ 24 giờ.
- **Tiếng Việt có dấu:** quét chuỗi hiển thị, không thấy câu tiếng Việt không dấu.
- **CS3:** không xuất hiện trong lớp, phòng, học sinh; chỉ trong màn người dùng và ghi chú "CS3 không có lớp".
- **Dữ liệu xuyên suốt:** 9A2 Đại · Buổi 4 (12 em) khớp GV-02…GV-09, GV-18, CS-16, HT-*, PH-*; Khúc Bảo Nam HS000420, Khúc Bảo Ngọc HS000515, Lê Gia Huy HS000435/GD000131, thầy Lê Văn Khánh GV2007 (09/2026: 26 buổi, 39,0 giờ) khớp GV-16, BC-08, BC-09.
- **Biểu tượng:** Lucide `lucide@0.460.0`, nét 1,5px; môi trường kiểm chặn CDN nên ảnh chụp hiện bộ vẽ dự phòng (cùng tên).

## Luồng: các bước không phải lỗi

Bước chuyển giữa hai cổng (GV-17 → HT-02, HT-04 → GV-18, HT-05 → PH-02, GV-07 → CS-16) và bước do hệ thống tự làm (GV-09 → buổi Done, trừ giờ GD-04; GD-03 → danh sách buổi BUOI-02) không cần nút. Các bước đi qua bản ghi trung tâm (lead TS-02, cơ hội TS-08, đơn BH-05, buổi BUOI-02, ticket CS-02) đã có nút sang màn kế tiếp.

## Phụ lục A · Tên màn rút gọn

| Mã | Tên trên thẻ | Tên trong bản đồ |
|---|---|---|
| CHUNG-02 | Xác thực hai bước | Xác thực hai bước (nhập mã TOTP) |
| CHUNG-03 | Thiết lập hai bước lần đầu | Thiết lập xác thực hai bước lần đầu |
| CHUNG-04 | Quên mật khẩu | Quên mật khẩu (gửi email đặt lại) |
| CHUNG-06 | Đăng nhập học sinh | Đăng nhập học sinh (mã HS) |
| CHUNG-10 | Khung ứng dụng CRM | Khung ứng dụng CRM (menu trái, thanh trên, chọn cơ sở; điện thoại: menu thu gọn) |
| CHUNG-14 | Trang chủ CRM theo vai trò | Trang chủ CRM theo vai trò (việc của tôi hôm nay) |
| CHUNG-22 | Ghi chú trao đổi + lịch sử thay đổi | Ghi chú trao đổi + lịch sử thay đổi (cột phải mọi bản ghi) |
| CHUNG-26 | Xác nhận chung, rời trang chưa lưu | Hộp thoại xác nhận chung + cảnh báo rời trang chưa lưu |
| QT-01 | Người dùng | Người dùng (danh sách) |
| QT-04 | Vai trò | Vai trò (danh sách + mô tả) |
| QT-05 | Ma trận quyền | Ma trận quyền (vai trò × phân hệ × hành động × phạm vi) |
| QT-06 | Danh mục | Danh mục (danh sách các danh mục) |
| QT-07 | Danh mục · sửa các mục | Danh mục (sửa các mục) |
| QT-13 | Tài khoản học sinh | Tài khoản học sinh (cấp, khoá, đặt lại mật khẩu) |
| CHUNG-15 | Hàng việc chờ tôi duyệt | Hàng việc chờ tôi duyệt (gộp mọi loại) |
| CH-01 | Gói bán | Gói bán / sản phẩm (danh sách) |
| TS-01 | Lead (danh sách / kanban) | Lead (danh sách / kanban theo giai đoạn) |
| TS-03 | Tạo lead nhanh | Tạo lead nhanh (kèm kiểm trùng SĐT) |
| TS-06 | Tạo cơ hội từ lead | Tạo cơ hội từ lead (cảnh báo đã có cơ hội) |
| TS-07 | Cơ hội (kanban L1–L8) | Cơ hội (danh sách / kanban L1–L8) |
| TS-11 | Lịch hẹn | Lịch hẹn (danh sách + lịch tuần) |
| TS-18 | Xếp lịch kiểm tra | Xếp lịch kiểm tra (ngày giờ xác nhận, phòng, GV chấm) |
| TS-19 | Huỷ / từ chối phiếu kiểm tra | Huỷ / từ chối phiếu kiểm tra (bắt buộc lý do) |
| BH-02 | Báo giá (bản ghi) | Báo giá (bản ghi, dòng gói) |
| BH-03 | Bản in / gửi báo giá | Bản in / gửi báo giá cho phụ huynh |
| BH-08 | Chọn lớp và ngày vào lớp | Chọn lớp và ngày vào lớp cho dòng đơn |
| BH-09 | Cho học trước, đóng tiền sau | Bật "Cho học trước, đóng tiền sau" |
| TC-07 | Bản in biên nhận | Bản in phiếu thu / biên nhận |
| TC-09 | Đảo khoản tiền | Đảo khoản tiền (lý do) |
| TC-13 | Công nợ | Công nợ (đơn chưa thu đủ) |
| QT-15 | Người duyệt ticket | Cấu hình người duyệt ticket theo nhóm con |
| QT-16 | Giáo viên, trợ giảng | Giáo viên, trợ giảng (hồ sơ dạy) |
| CH-05 | Khung chương trình | Khung chương trình (danh sách phiên bản) |
| CH-06 | Khung chương trình (bài học) | Khung chương trình (danh sách bài học) |
| GD-03 | Xếp lớp cho ghi danh | Xếp lớp cho ghi danh (gợi ý Đại + Hình) |
| GD-05 | Điều chỉnh giờ | Điều chỉnh giờ (dòng ngược dấu, bắt buộc lý do) |
| TT-01 | Phiếu tái tục | Phiếu tái tục (danh sách / kanban L1–L8) |
| LOP-01 | Lớp (danh sách / kanban) | Lớp (danh sách / kanban theo bước duyệt) |
| LOP-03 | Tạo / sửa lớp | Tạo / sửa lớp (chỉ ở Nháp, Từ chối) |
| LOP-06 | Đóng / huỷ lớp | Đóng / huỷ lớp (bị chặn thì liệt kê lý do) |
| LOP-07 | Đổi giáo viên lớp | Đổi giáo viên và sinh lại buổi chưa diễn ra |
| LOP-08 | Lịch tuần cơ sở | Lịch tuần cơ sở (theo phòng, giáo viên) |
| LOP-10 | Đổi lịch cố định của lớp | Đổi lịch cố định của lớp đã duyệt |
| BUOI-01 | Buổi học (danh sách) | Buổi học (danh sách, mặc định hôm nay) |
| BUOI-03 | Điểm danh vận hành | Điểm danh phía vận hành + lý do liên hệ |
| BUOI-04 | Huỷ buổi | Huỷ buổi (trung tâm huỷ / học sinh huỷ lớp riêng) |
| BUOI-05 | Dời một buổi | Dời một buổi (đổi ngày, giờ, phòng) |
| BUOI-06 | Thêm học thử | Thêm học sinh học thử vào buổi |
| BUOI-07 | Yêu cầu học bù | Yêu cầu học bù (tạo) |
| BUOI-08 | Yêu cầu buổi củng cố | Yêu cầu buổi củng cố (tạo) |
| BUOI-09 | Yêu cầu học bổ trợ | Yêu cầu học bổ trợ (tạo từ lớp) |
| BUOI-10 | Yêu cầu buổi | Yêu cầu buổi (danh sách + duyệt) |
| BUOI-11 | Điểm danh vận hành trong ngày | Điểm danh vận hành trong ngày (gọi nhắc) |
| BUOI-12 | Buổi chưa Done | Theo dõi buổi chưa Done, GV chưa hoàn tất |
| BUOI-13 | Dạy thay một buổi | Đổi giáo viên / trợ giảng cho một buổi (dạy thay) |
| CS-01 | Ticket (danh sách / kanban) | Ticket (danh sách / kanban theo bước) |
| CS-04 | Tạo ticket | Tạo ticket (chọn loại, nhóm, nhóm con) |
| CS-05 | Thực hiện hoàn tiền | Thực hiện hoàn tiền (bảng tính hoàn) |
| CS-06 | Thực hiện chuyển lớp | Thực hiện chuyển lớp (cùng môn) |
| CS-08 | Duyệt / từ chối ticket | Duyệt / từ chối ticket (từng cấp) |
| CS-09 | Thực hiện bảo lưu | Thực hiện bảo lưu (mới, gia hạn, quay lại sớm) |
| CS-10 | Thực hiện chuyển phí | Thực hiện chuyển phí (sang môn khác, anh chị em, gói khác) |
| CS-11 | Thực hiện đổi lịch học | Thực hiện đổi lịch học (dời buổi, đổi ca, xin học bù) |
| CH-07 | Rubric nhận xét | Rubric nhận xét (tiêu chí, mô tả mức 1–5, theo môn) |
| GV-01 | Khung cổng giáo viên | Khung cổng giáo viên (điện thoại: thanh dưới · laptop: menu trái thu gọn) |
| GV-02 | Hôm nay | Hôm nay (buổi dạy, việc sắp trễ hạn) |
| GV-03 | Lịch dạy | Lịch dạy (tuần, tháng) |
| GV-04 | Buổi dạy | Buổi dạy (tổng quan các bước cần làm) |
| GV-05 | Điểm danh | Điểm danh (4 trạng thái) |
| GV-06 | Nội dung buổi và giao BTVN | Nội dung buổi + giao BTVN |
| GV-08 | Chấm BTVN của buổi trước | Chấm BTVN của buổi trước (5 trạng thái) |
| GV-09 | Hoàn tất buổi | Hoàn tất buổi (kiểm còn thiếu gì) |
| GV-10 | Lớp của tôi | Lớp của tôi (danh sách) |
| GV-12 | Việc cần làm | Việc cần làm / quá hạn |
| GV-14 | Tạo ticket · ticket lớp tôi | Tạo ticket từ cổng giáo viên + ticket lớp tôi |
| GV-16 | Giờ dạy của tôi | Giờ dạy của tôi (căn cứ lương) |
| GV-17 | Giao bài trên LMS | Giao bài trên LMS (đề, tệp, hạn nộp) |
| HT-02 | Bài tập | Bài tập (cần làm, đã nộp, đã chấm) |
| HT-04 | Nộp bài | Nộp bài (chụp ảnh, tải tệp) |
| HT-07 | Kết quả học tập | Kết quả học tập (tiêu chí theo thời gian) |
| HT-09 | Khung cổng Học tập | Khung cổng học tập (điện thoại: thanh dưới · laptop: menu trái, nội dung một cột giữa trang) |
| PH-01 | Trang chủ phụ huynh | Trang chủ phụ huynh (các con) |
