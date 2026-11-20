# So canvas nhóm Bán hàng, Thu chi (lượt C, 19/11/2026)

Cách rà: đối chiếu chữ nhãn của khung canvas (abea, 9933, 1aab) với chữ trong mã; chưa chụp màn hình từng điểm ảnh (Tester kiểm trên staging). Kết quả ghi theo luật 21:32.

| Màn | Kết quả | Ghi chú |
| --- | --- | --- |
| TC-17 Phiếu thu (bản ghi) | **Lệch, đã sửa một phần** (#363) | Thêm cột Học sinh, Thành tiền ở bảng chia tiền. CẦN CHAT: cột Lớp, Giờ cấp (cần hàm DB trả theo dòng); bản xem trước chia tiền ở bước Đã trình; «Tài khoản nhận» chưa lưu |
| TC-03, BH-09 Đơn hàng (bản ghi đã duyệt) | **Gần đúng, đã sửa chữ** (#364) | Tiêu đề «Lịch đóng tiền từng đợt (tự tính, chỉ đọc)», chữ khối Phiếu thu trống. Còn: nhãn «Đã duyệt · khoá», chú về xếp lớp, chuyển lớp |
| TC-09 Hoàn tác khoản tiền | **Đúng về cột, Gần đúng về chữ** | Danh sách TC-08 đã có cột Ghi chú, nút «Hoàn tác khoản tiền» (hộp lý do K08), khoản đảo «Hoàn tác của …». Lệch nhỏ: canvas ghi «Đã hoàn tác bằng …0006» (mã khoản đảo), mã ghi «Đã hoàn tác»: cần `list_money_in` trả mã khoản đảo. Đã có từ trước, không phải màn mới |
| TC-10, TC-11 Phiếu chi | Lệch (đã nêu ở #347, #356) | CẦN CHAT: hình thức chi, tài khoản nhận, ngày chi dự kiến |
| TC-07 Biên nhận (in) | Gần đúng | Nhãn khung in khớp; «Khổ giấy», «Màn nguồn» là chú thích thiết kế, không phải giao diện |
| BH-03 Báo giá (in) | Gần đúng | Như TC-07 |
| BH-02 Báo giá, đơn (tạo/sửa, 27 khung) | **Chưa kiểm được bằng nhãn** | Nhiều nhãn nút «+ Thêm em», «+ Thêm cả nhà», «+ Thêm quà tặng» ghép biểu tượng nên so chữ không đủ: cần Tester so ảnh trên staging |
| CH-05, CH-06, CH-07 | Không có khung cùng mã trong canvas abea, 9933; thuộc 1aab (Code A đã làm) | Giao Tester/Code A |

## So canvas TC-01, TC-04 (Code C, 20/11/2026, thẻ 18:20; canvas 9933, TC01*, TC04*)

Cấu hình đọc từ `CFG` của `TC01.dc.html`, `TC04.dc.html` (trường tìm, nhóm, lọc, yêu thích) và so với `receiptConfig.tsx`, `receiptFilters.ts`. So canvas TC-01, TC-04.

| Mục | Canvas | Code | Kết quả |
|---|---|---|---|
| TC-01, TC-04 Lọc «Hình thức» | nhóm lọc Chuyển khoản, Tiền mặt, Quẹt thẻ | trước đây chỉ có Tình trạng và trường nâng cao | **Đã sửa** (PR C83): nhóm lọc nhanh «Hình thức» lấy từ danh mục PAYMENT_METHOD, máy chủ lọc theo mảng `payment_method` |
| TC-04 Lọc, cột «Sao kê» | Đã khớp, Chưa khớp | thiếu | **Đã sửa** ở PR C82 (#404, migration 576) |
| TC-04 Cột «Mã giao dịch» | có | có | Đúng (migration 431) |
| TC-01, TC-04 Trường tìm | TC-01: Mã, Đơn hàng, Phụ huynh; TC-04: Mã, Phụ huynh, Mã giao dịch | ô tìm một ô, `search_text` đã gồm mã, đơn, phụ huynh, mã giao dịch | Đúng |
| TC-01 Group By | Tình trạng, Hình thức, Cơ sở | Tình trạng, Hình thức, Cơ sở | Đúng |
| TC-04 Group By «Sao kê» | thêm nhóm Sao kê | chưa có | **Chưa sửa**: cần migration (`receipt_group_counts` thêm trường `bank`, số > 576); xin Chat cấp số và duyệt |
| TC-01, TC-04 Lọc nhanh «Cơ sở» (CS1, CS2, CS4, CS5) | chip nhiều cơ sở | chỉ lọc nâng cao một cơ sở (khi xem nhiều cơ sở) | **Chưa sửa**: máy chủ nhận một `branch_id`; muốn chip nhiều cơ sở cần đổi hàm thành mảng (migration). Xin Chat quyết |
| Yêu thích mẫu («Chờ kế toán duyệt», «Chưa khớp sao kê», «Chuyển khoản CS2») | ví dụ minh hoạ | Yêu thích là bộ lọc người dùng tự lưu (`saved_filter`), không có mẫu dựng sẵn | Không làm (đúng khuôn K1_fav; số liệu minh hoạ) |

## So canvas TC-06, BH-04, BH-10, BH-11 (Code C, 20/11/2026, thẻ 18:20)

Bốn màn là hộp thoại K08 (mức C). Canvas 9933 không có khung hộp thoại riêng cho từng màn: chỉ có khung bản ghi sau thao tác (`TC02_huy`, `BH02_tu_choi`, `BH05_huy`, `BH02_bh11`). Đã đối chiếu từng hộp thoại có trong code và dòng nhật ký sau thao tác.

| Màn | Trong code | Canvas (khung bản ghi) | Kết quả |
|---|---|---|---|
| TC-06 Huỷ phiếu thu | `ReceiptRecordPage.tsx` hộp «Huỷ phiếu thu», lý do bắt buộc, chỉ phiếu chưa duyệt | `TC02_huy`: dòng «Huỷ phiếu thu. Lý do: …», trạng thái Đã trình → Huỷ | Đúng |
| BH-04 Từ chối báo giá | `QuotationRecordPage.tsx` hộp «Từ chối báo giá», lý do từ danh mục, «Khác» bắt ghi chú | `BH02_tu_choi`: «Từ chối báo giá. Lý do: …», Đã gửi → Từ chối | Đúng |
| BH-10 Huỷ đơn hàng | `OrderRecordPage.tsx` hộp «Huỷ đơn hàng»; dòng «Huỷ đơn» kèm lý do; đơn đã có phiếu thu bị chặn kèm mời tạo ticket hoàn tiền | `BH05_huy`: «Huỷ đơn. Lý do: … Chưa thu tiền.» | Gần đúng: canvas thêm câu «Chưa thu tiền.» cuối dòng; câu này là chú thích minh hoạ của khung, giữ như hiện tại (không đổi luật R-TIEN-03) |
| BH-11 Cảnh báo cơ hội đã có đơn nháp | `OrderCreatePage.tsx`, `OpportunityRecordPage.tsx`, hàm migration 88 (R-TIEN-39) | `BH02_bh11` | Đúng về luật: có cảnh báo kèm mã đơn nháp, nút Mở đơn cũ, Vẫn tạo |

## So luật TC-12, TC-14, TC-16 (không có khung canvas; Code C, 20/11/2026, thẻ 20:22)

Bản đồ màn hình xếp ba màn mức C; đối chiếu với luật R-TIEN-08, R-TIEN-28, R-TIEN-33, R-CS-03 và mã hiện có.

| Màn | Luật | Trong code | Kết quả |
|---|---|---|---|
| TC-12 Bản in phiếu chi | R-TIEN-08 (có bản in phiếu chi), R-TIEN-28 (tiền hoàn = đã đóng − giờ học × giá gốc − phí xử lý) | `VoucherPrintPage.tsx` dùng khuôn K13; bản in chỉ có 3 dòng: trước phí, phí, số hoàn | **Đã sửa** (PR C86): bản in thêm các dòng «Phụ huynh đã đóng», «Giờ đã học × giá gốc», «Còn lại sau khi trừ giờ đã học» (hoàn toàn bộ) hoặc «Giờ hoàn × giá sau chiết khấu» (một phần), cùng nhãn và số với bản ghi TC-11; hàm `voucherPrintRows` có Vitest |
| TC-14 Số dư khách hàng | R-TIEN-33 (sổ chỉ thêm dòng, không hết hạn), R-CS-03 | `BalanceListPage`, `BalanceHistoryPage`; sổ chỉ thêm dòng ở DB (`tg_customer_balance_append_only`); cột Phụ huynh, Mã, Số dư, Phát sinh gần nhất, Số dòng sổ, Cơ sở; lọc «Còn tiền dư» | Đúng về luật. **Thiếu nút «Cấn vào đơn mới» trên danh sách** (bản đồ màn hình liệt kê hành động này); xem câu hỏi bên dưới |
| TC-16 Dùng số dư cho đơn mới | R-TIEN-33 (ghi như một khoản tiền vào của đơn mới, không có phiếu thu) | `UseBalanceDialog.tsx` hộp K08 mở từ bản ghi đơn: số tiền mặc định bằng mức tối đa, chặn vượt số dư hoặc phần đơn còn thiếu, câu giải thích «không có phiếu thu» | Đúng |

**Câu hỏi cho Chat (TC-14):** nút «Cấn vào đơn mới» ở danh sách số dư nên làm gì? A. Mở danh sách Đơn hàng lọc theo phụ huynh đó, người dùng vào đơn rồi «Dùng số dư» (TC-16); không code mới nhiều. B. Hộp chọn đơn của phụ huynh rồi mở TC-16 ngay: cần Design vẽ khung chọn đơn. Khuyến nghị **A**.
## So canvas BH-01, BH-02, BH-05, BH-06, BH-07, TC-02, TC-05 (Code C, 20/11/2026, thẻ 19:58)

Cách rà: lấy chữ của mọi khung `BH01*`, `BH05*`, `BH06*`, `BH07*`, `TC02*`, `TC05*` (canvas 9933, abea), bỏ tên người, số liệu minh hoạ, rồi tìm từng nhãn trong `src/` và `supabase/migrations/`. Nhãn không thấy thì đọc khung và quyết định.

| Màn | Lệch | Kết quả |
|---|---|---|
| BH-05 Đơn hàng (bản ghi) | Tiêu đề khối «Người xử lý và cơ sở» (35 khung) và khối «Thanh toán» tách riêng; code gộp Người lập, Người duyệt, Cơ sở vận hành, Điều khoản thanh toán vào «Thông tin chung» | **Đã sửa** (PR C85): ba khối «Thông tin chung», «Người xử lý và cơ sở», «Thanh toán»; e2e kiểm tiêu đề |
| TC-02, TC-05 Phiếu thu (bản ghi) | Nhãn «Duyệt bởi» (tên Kế toán · ngày) khi Đã duyệt | **Đã sửa** (PR C85): lấy từ sự kiện DUYET_KT gần nhất; e2e kiểm nhãn |
| TC-02, TC-05 «Dồn trước», cột «Giờ cấp» | cần dữ liệu cấn dòng và giờ cấp theo dòng | Chưa sửa: đề xuất DB mục 1 ở `de-xuat-man-con-thieu-crm.md` |
| TC-02 Gợi ý «khoá khi rời Nháp», «Chỉ hiện tài khoản của cơ sở thu đã chọn» | chú dưới ô Cấn vào dòng, Tài khoản nhận | Chưa sửa: «Tài khoản nhận» chưa do nhân viên chọn (đề xuất DB mục 5); chú «khoá khi rời Nháp» sẽ thêm cùng lúc |
| BH-07 Duyệt đơn: ô «Đồng ý chiết khấu vượt trần» (D12) | canvas vẽ ô tích bắt buộc trước khi Duyệt | **Không làm, theo luật**: R-V2-11 (chốt) bỏ ô tích đồng ý (thay Đ102); trần 20% chỉ cảnh báo. Canvas vênh luật thì theo luật |
| BH-01, BH-06 | «Lọc thông minh» (2 khung) | Chưa rõ: nút của khung canvas mẫu, không có trong bản đồ màn hình; Tester so ảnh trên staging |
| BH-02 Báo giá, đơn (tạo/sửa) | nhãn «+ Thêm dòng», «+ Thêm quà tặng», «+ Thêm cả nhà», «Tặng tối đa 4 giờ»… là dữ liệu mẫu và nút ghép biểu tượng | Không so được bằng chữ (đã ghi ở bảng trên): cần Tester so ảnh |
