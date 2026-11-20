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
