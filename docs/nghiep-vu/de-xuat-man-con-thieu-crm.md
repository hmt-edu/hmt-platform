# Đề xuất 5 màn CRM còn thiếu và có luật, không cần khung canvas (Code F, 19/11/2026; thẻ F70)

Gửi Chat để anh Trường duyệt trước khi làm (CLAUDE.md: thay đổi lớn, anh OK mới code). Mọi màn dựng từ khuôn dùng chung (K03 danh sách, K06 bản ghi, K08 hộp thoại, K10 cấu hình), không có kiểu mới. Cả 5 chưa có bảng hay hàm trong DB (đã tìm trong `supabase/migrations`): mỗi màn cần migration và pgTAP đi kèm.

| Màn | Làm gì | Khuôn | Luật | Ai làm | Cỡ |
|---|---|---|---|---|---|
| **QT-13 Tài khoản học sinh** | Admin cấp tài khoản theo mã HS, in hoặc gửi mật khẩu tạm, đặt lại khi quên, khoá; cấp hàng loạt | K03 + hộp K08 | bản đồ màn hình QT-13 (chốt 12/10; bước 4, CS từ giai đoạn 4); không mang mật khẩu từ hệ thống cũ | Code F (cùng nhóm với QT-02 tạo người dùng, dùng Edge Function tạo tài khoản) | lớn: Edge Function (khoá service không vào giao diện), migration, pgTAP; mở khoá KH-05, KH-06 (khối «Tài khoản app học sinh») |
| **QT-15 Cấu hình người duyệt ticket theo nhóm con** | Ai duyệt từng nhóm con đề nghị, có ngày hiệu lực, xem lịch sử | K10 (như ma trận quyền) | R-CS-07, R-CS-11, R-V2-24 | Code B (giữ nghiệp vụ ticket) hoặc F | vừa: bảng cấu hình có hiệu lực + hàm đọc; cần thống nhất với bản ghi nghiệp vụ (việc duyệt nằm ở phiếu nghiệp vụ theo R-V2-24) nên **hỏi Chat: còn cần màn này không** |
| **QT-16 Giáo viên, trợ giảng (hồ sơ dạy)** | Mã GV/TG, môn dạy, khối, cơ sở thường dạy, tài khoản liên kết; Tạo, Sửa, Ngừng | K03 + K06 | R-LOP-08, R-LOP-10 (chọn giáo viên khi tạo lớp) | Code A (giữ Lớp) hoặc F | vừa: bảng hồ sơ dạy; hiện giáo viên chọn từ tài khoản người dùng có vai Giáo viên, chưa có môn, khối |
| **TS-12 Việc tuyển sinh hôm nay** | Bản đồ màn hình ghi rõ «gộp vào trang chủ theo vai trò K09b (CHUNG-14), không làm riêng» | không làm riêng | R-CRM-07 | không cần | đề xuất: đổi trạng thái thành «Gộp vào CHUNG-14» thay vì «Chưa có» |
| **KH-08 Lên khối đầu năm học** | Tăng khối cho học sinh đang học khi sang năm học mới; xem trước, loại trừ từng em, xác nhận | K08 (hộp xem trước) | không có luật chi tiết trong docs/spec (bản đồ màn hình để «—») | Code B (Khách hàng) | vừa; **thiếu luật**: em lớp 12 lên «tốt nghiệp» hay giữ khối; ghi nhật ký từng em; chạy một lần mỗi năm học. Cần anh chốt luật trước |

## Đề xuất thứ tự
1. TS-12: không làm, chỉ sửa trạng thái trong bảng (xong ở PR này nếu anh đồng ý).
2. QT-13 (mở khoá KH-05/06, cần cho go-live CS5 khi học sinh đăng nhập app).
3. QT-16, rồi QT-15 (sau khi Chat xác nhận còn cần), KH-08 (sau khi có luật).

## Nhầm lẫn đã sửa trong bảng màn hình (cùng PR)
Script không thấy mã ở đầu file nên báo «chưa có» hoặc «chỉ có DB»: CHUNG-07 (đổi mật khẩu bắt buộc: `PasswordPages.tsx`), CHUNG-18 (Xuất: nút «Xuất» ở các danh sách), CHUNG-19 (Favorites: `list/Favorites.tsx`), CHUNG-22 (Ghi chú và hoạt động: `ui/Chatter.tsx`), TS-14 (cảnh báo trùng: `ui/Dialogs.tsx`), GV-06 (`SessionContentPage.tsx`), GV-07 (`ReviewGradingPage.tsx`), LOP-04, LOP-07, LOP-10 (đã gộp vào LOP-03). Số mới: 197 màn, **157 có màn**, 10 chỉ có DB, 30 chưa có (HT 9, PH 5 để sau go-live; CRM 14, Giáo viên 2, trong đó 5 màn có đề xuất ở trên).

## Cập nhật 19/11 23:05 (anh Trường duyệt)

- TS-12: đổi trạng thái thành «Gộp vào CHUNG-14» (không làm riêng).
- QT-13: làm (Code F, PR riêng, rủi ro CAO).
- KH-08: **chưa làm vì thiếu luật.** Sáu câu hỏi gửi anh:
  1. Ai được chạy việc «Lên khối»: chỉ Admin, hay cả Trưởng cơ sở cho cơ sở của mình?
  2. Chạy khi nào: một lần cố định mỗi năm (ngày nào), hay anh bấm khi sang năm học mới (theo danh mục năm học)?
  3. Khối nào lên khối nào: mỗi em tăng một khối (ví dụ 6 lên 7)? Em lớp 12 thì chuyển «Đã tốt nghiệp» hay giữ nguyên?
  4. Em đang bảo lưu, đã dừng học hoặc nghỉ: có lên khối không, hay bỏ qua?
  5. Xem trước: có hiện danh sách từng em (khối cũ, khối mới) để bỏ tick loại trừ trước khi xác nhận không? Em học vượt cấp hoặc học lại thì sửa tay thế nào?
  6. Hoàn tác: sau khi xác nhận có cho hoàn tác cả đợt (trong bao lâu) không, hay chỉ sửa khối từng em? Ghi nhật ký theo từng em hay một dòng cho cả đợt?

## LOP-02 / LOP-03: câu hỏi quyết định DB (Code A, 20/11/2026, để Chat hỏi anh Trường)

Hiện trạng: nhóm lớp đã có (bảng `app.class_group`, cột `app.class.group_id`, luật R-LOP-14 đã CHỐT). LOP-02 đã hiện «Cùng nhóm» và «Lớp còn lại của nhóm» (migration 310). Canvas 9933 (`LOP03_tao`, `LOP03_sua`, `LOP02_*`) còn bốn chỗ chưa có trong code. Chi tiết đề xuất cũ: `docs/spec/de-xuat-hinh-thuc-hoc-to-chuc-lop.md`.

| # | Câu hỏi | Lựa chọn | Khuyến nghị | Hệ quả |
|---|---|---|---|---|
| 1 | Ô «Tổ chức lớp» (Học chung, Học riêng) trùng ý Phân loại «Lớp riêng»? | A. Bỏ ô, hiện chữ tự suy từ Phân loại (Lớp riêng = Học riêng, còn lại = Học chung). B. Giữ thành cột riêng, tự nhập. | **A** | A: không migration, không mâu thuẫn «Cơ bản + Học riêng». B: thêm cột, phải nêu quan hệ với Phân loại. |
| 2 | «Hình thức học» của LỚP (Offline, Online, OMO): thêm không? Ghi danh đã có OFF, ONL (R-TIEN-12). | A. Thêm danh mục lớp OFF, ONL, OMO + cột `delivery_mode_code` (lớp cũ mặc định OFF); xếp lớp chỉ CẢNH BÁO khi lệch. B. Như A nhưng CHẶN xếp lớp khi lệch (OMO nhận cả hai). C. Không thêm. | **A** (chặn sau khi anh thấy dữ liệu thật) | A, B: một migration mức CAO nhẹ + pgTAP, B đụng luật xếp lớp, cần Tester. C: bỏ ô, canvas vênh. |
| 3 | «Tạo lớp còn lại cho nhóm này»: lớp mới có sao chép giáo viên, lịch không? | A. Điền sẵn nhóm, cơ sở, năm, khối, phân loại; để TRỐNG môn, giáo viên, lịch (mỗi lớp độc lập, R-LOP-14). B. Sao chép cả lịch, giáo viên. | **A** | Không migration (dùng `create_class` có `group_id`). Làm được ngay khi anh chốt. |
| 4 | «Xem trước ngày kết thúc dự kiến» ở form Tạo/sửa lớp (số buổi theo khung, bỏ ngày nghỉ lễ, R-LOP-09, R-LOP-12). | A. Hàm đọc mới tính từ khung giờ đang nhập (chưa lưu). B. Chỉ hiện sau khi Lưu nháp (dùng ngày đã sinh). | **A** | A: một hàm đọc `security definer`, không đổi bảng, một migration nhẹ + pgTAP. B: không migration nhưng không «xem trước» đúng nghĩa. |

Ghi chú: «kiểm môn theo khối khi tạo lớp» (R-LOP-14, [CHỜ anh quyết]) vẫn chưa quyết, không gộp vào bốn câu trên.

## Kho #14: các mục «CẦN CHAT» còn lại của Thu chi và Bán hàng (Code C, 20/11/2026, để Chat hỏi anh Trường)

Đã làm xong: TC-04 cột «Sao kê» và nhóm lọc «Sao kê» (Đã khớp, Chưa khớp) lấy từ cờ TC-15 `bank_matched_at` (migration 576, PR C82). Cột «Mã giao dịch» đã có (migration 431). Phần dưới chưa làm vì thiếu luật hoặc thiếu dữ liệu; mỗi câu có khuyến nghị.

| # | Màn, chỗ thiếu | Câu hỏi | Lựa chọn | Khuyến nghị |
|---|---|---|---|---|
| 1 | TC-04 cột «Xử lý» (nút Duyệt, Từ chối ngay trên dòng) | Có cho duyệt, từ chối ngay trên dòng danh sách không, hay chỉ ở bản ghi? Từ chối cần lý do (hộp K08) | A. Giữ duyệt ở bản ghi TC-02, danh sách chỉ có nút mở. B. Thêm hai nút trên dòng, bấm Từ chối mở hộp K08 nhập lý do, Duyệt mở hộp xác nhận. | **A** (tiền, tránh bấm nhầm; R-HT-01, R-V2-44 không đổi). Nếu chọn B: cần Design vẽ khuôn nút trên dòng, không có trong K03 |
| 2 | TC-10, TC-11 «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến» | Phiếu chi có ba trường này không? Hiện bảng phiếu chi chưa có cột tương ứng | A. Thêm cột `payment_method_code`, `payout_account`, `planned_on` (tuỳ chọn). B. Không thêm, bỏ khỏi canvas. | **A** nếu kế toán cần theo dõi chi; «Tài khoản nhận» tái dùng danh mục RECEIVING_ACCOUNT hay danh mục riêng cho tài khoản người nhận? (Chat hỏi anh) |
| 3 | TT-02 «Lịch sử liên hệ» và «Đã mua gần nhất» | Lịch sử liên hệ dùng ghi chú (note_target) loại UPSALE hay bảng riêng? «Đã mua gần nhất» lấy đơn đã thanh toán gần nhất của phụ huynh? | A. Dùng ghi chú loại UPSALE và đơn Đã duyệt gần nhất theo ngày. B. Bảng liên hệ riêng. | **A** (không bảng mới, một migration nhỏ thêm loại ghi chú) |
| 4 | TC-03, TC-17 «Lịch đóng tiền từng đợt», «Ưu đãi đóng sớm», «Dồn trước» | Lịch đóng từng đợt lấy từ đơn nào? Ưu đãi đóng sớm tính ở đâu? | Thuộc lane B (Bán hàng): chờ Chat giao thẻ và luật chiết khấu đóng sớm trong docs/spec/04 | Chat giao lane B |

Ngoài phạm vi Thu chi: GV-11 «Tiến độ khung chương trình» cần luật tính bài đã dạy (Chat giao lane E).
## KH-07 Gộp phụ huynh / học sinh trên bản ghi: câu hỏi luật cho anh Trường (Code F, 20/11/2026, rủi ro CAO: tiền, điểm danh)

**Hiện trạng (đã đọc code):** DB có `merge_parents`, `merge_students` nhưng chỉ chuyển lead, cơ hội, học sinh, phiếu kiểm tra, ghi chú. R-CRM-25 nói bản giữ lại phải nhận cả đơn và ghi danh. Các bảng về sau đã có cột `parent_id` hoặc `student_id` mà hàm gộp chưa chuyển: báo giá, đơn, phiếu thu, ghi danh, số dư khách hàng, hoàn phí, bảo lưu, chuyển lớp, điểm danh và điểm, BTVN, ticket, buổi học thử. Nếu gộp ngay hôm nay thì đơn, ghi danh của hồ sơ bị gộp vẫn trỏ về hồ sơ «Đã gộp» (chỉ đọc). Hộp so sánh (`merge_candidates`, `merge_side`, `merge_items`) mới hỗ trợ lead, cơ hội; canvas có 24 khung KH07_* (trùng, chặn, khác cơ sở, tải).

**Câu 1. Gộp có chuyển cả dữ liệu tiền và ghi danh không?**
- A (khuyến nghị): chuyển TOÀN BỘ bảng có khoá phụ huynh/học sinh, kể cả tiền; trong cùng giao dịch kiểm tổng số dư và công nợ trước = sau, lệch thì huỷ gộp. Hệ quả: đúng R-CRM-25, không còn hồ sơ mồ côi; PR DB rủi ro cao, cần Tester ĐẠT và pgTAP kiểm tổng tiền.
- B: chỉ chuyển như hiện nay, chặn gộp nếu hồ sơ bị gộp đã có đơn hoặc ghi danh. Hệ quả: an toàn, nhưng trùng hồ sơ đã mua hàng thì không bao giờ gộp được.

**Câu 2. Điều kiện chặn (R-CRM-25 còn [CHỜ]).**
- A (khuyến nghị): chặn khi (i) hai học sinh cùng có ghi danh còn hiệu lực ở cùng một lớp, hoặc (ii) hai học sinh đang học hai lớp trùng giờ; còn lại cho gộp. Hệ quả: gộp được hầu hết trùng nhập nhầm; hai ca chặn xử lý tay qua ticket.
- B: chặn thêm khi hai hồ sơ khác cơ sở tiếp nhận (phải đi qua ticket Chuyển cơ sở trước). Hệ quả: chặt hơn, đúng R-CRM-28, thêm một bước cho Sale.

**Câu 3. Ai làm?** Khuyến nghị giao Code F làm cả DB lẫn giao diện (đã quen hộp MergeDialog) nhưng Code A và Code C soát phần ghi danh và tiền trước khi gộp; hoặc giao Code C làm phần tiền. Ai được bấm Gộp: khuyến nghị theo quyền Gộp đã có ở lead (không thêm quyền mới).

Làm xong khi anh chốt: PR DB (migration dải 550–599, pgTAP đúng và bị chặn) rồi PR giao diện (nút Gộp ở KH-02, KH-05). Chưa code gì cho tới khi có câu trả lời.

## Đề xuất DB còn lại của Thu chi (Code C, 20/11/2026, theo thư Chat 19:58; CHƯA code, chờ anh Trường duyệt rồi mới cấp số migration 577 trở đi)

Cả năm mục đều đụng bảng hoặc hàm tiền nên rủi ro **CAO**, mỗi mục một migration, một PR, pgTAP đúng và bị chặn. Không mục nào có số tiền, tỉ lệ viết cứng.

| # | Mục | Lệch gì (canvas 9933) | Luật spec | Migration đề xuất | Rủi ro, ghi chú |
|---|---|---|---|---|---|
| 1 | **TC-17 cột «Lớp», «Giờ cấp» và xem trước chia tiền** (khung `TC17_duyet`, `TC17_admin`) | Bảng «Chia tiền vào dòng đơn» có cột Dòng, Học sinh, Lớp, Thành tiền, Tiền chia về dòng, Giờ cấp (ví dụ «6,1 / 24 giờ»), nhãn «Dồn trước». Code đã có Học sinh, Thành tiền, Tiền chia; thiếu Lớp, Giờ cấp, và bảng chỉ hiện sau khi duyệt chứ không hiện ở bước Đã trình | R-TIEN-23 (dồn dòng chọn trước, phần thừa chia tỉ lệ), R-TIEN-21 (giờ cấp = giờ dòng × tiền chia ÷ thành tiền dòng), R-TIEN-24 (giờ tặng chỉ cấp khi thu đủ) | Một hàm đọc `app.preview_receipt_allocation(p_receipt_id)` (security definer, chỉ đọc, kiểm quyền xem phiếu thu và phạm vi cơ sở): dùng đúng thuật toán của `allocate_money_in` nhưng không ghi; trả theo dòng {dòng, học sinh, tên gói/lớp, thành tiền, tiền chia, giờ cấp, cờ dồn trước}. Không đổi bảng | CAO (tiền, giờ). Rủi ro chính: hai bản thuật toán lệch nhau; cách tránh: tách phần tính ra hàm chung dùng cho cả preview và `allocate_money_in`, pgTAP so hai kết quả khớp nhau trên cùng dữ liệu. Giờ cấp làm tròn theo `numeric(6,2)` |
| 2 | **TC-10, TC-11 Phiếu chi: «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến»** | Canvas có ba trường mà `app.payment_voucher` chưa có | R-TIEN-34 (Kế toán lập, ghi theo cơ sở học sinh) | Thêm ba cột tuỳ chọn vào `payment_voucher`: `payment_method_code` (danh mục PAYMENT_METHOD), `payout_account_code`, `planned_on date`; hàm lập, đổi phiếu chi nhận thêm ba tham số. «Tài khoản nhận» của phiếu chi là tài khoản **người nhận** (phụ huynh) nên **không** dùng danh mục RECEIVING_ACCOUNT (tài khoản của trung tâm, migration 478); đề xuất ghi chữ tự do `payout_account_note` | CAO (tiền). **Cần anh chốt:** Tài khoản nhận là chữ tự do hay danh mục? Ngày chi dự kiến có chặn «Chi» trước ngày đó không (đề xuất: không chặn, chỉ cảnh báo) |
| 3 | **TC-04 Group By «Sao kê»** | Canvas có nhóm Sao kê (Đã khớp, Chưa khớp) | R-TIEN-40 không liên quan; dùng cờ `bank_matched_at` (migration 478, 576) | Sửa `receipt_group_label`, `receipt_group_counts` thêm trường `bank` (hai nhóm); không đổi bảng | Thấp về dữ liệu (chỉ đọc) nhưng sửa hàm tiền: CAO theo quy ước; một PR nhỏ |
| 4 | **TC-01, TC-04 chip nhiều «Cơ sở»** (CS1, CS2, CS4, CS5) | Canvas chip chọn nhiều cơ sở; code chỉ chọn một | R-HT phạm vi cơ sở: người chỉ thấy cơ sở của mình không thấy chip | `list_receipts` và `receipt_group_counts` đổi bộ lọc `branch_id` thành mảng `branch_ids` (giữ `branch_id` cũ để tương thích); giao diện hiện chip khi xem nhiều cơ sở | CAO (hàm danh sách tiền, RLS). Phạm vi cơ sở vẫn cắt bên trong hàm, mảng chỉ thu hẹp thêm; pgTAP người cơ sở khác không thấy phiếu ngoài phạm vi |
| 5 | **TC-17 «Tài khoản nhận» chưa lưu ở bước Đã trình** | Canvas hiện tài khoản nhận trong khối «Nơi nhận tiền» | Migration 478 đã thêm `receiving_account_code` (Kế toán ghi khi đối soát) | Không cần migration mới nếu chỉ **hiện** cột đã có; nếu muốn nhân viên chọn khi lập phiếu thì mở quyền ghi cột này ở hàm lập phiếu | Hỏi anh: ai chọn tài khoản nhận, nhân viên lúc lập phiếu hay Kế toán lúc đối soát (hiện chỉ Kế toán) |

### Đề xuất thứ tự
1. Mục 1 (giá trị cao nhất cho Quản lý duyệt, không đổi bảng); 2. Mục 3 và 4 (nhỏ, cùng hàm danh sách); 3. Mục 2 và 5 sau khi anh trả lời hai câu hỏi.
