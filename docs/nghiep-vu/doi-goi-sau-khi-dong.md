# Đổi gói sau khi phụ huynh đã đặt cọc hoặc chia để trả (C-27-24, 29/11/2026)

Ví dụ: đã lên đơn 2 năm, phụ huynh đóng một phần, nay đổi sang đơn 1 năm. Không có tính năng mới; tài liệu ghi cách làm bằng các thao tác sẵn có và những gì mã hiện tại cho phép (đọc mã, chưa chạy thử trên staging). Luật: R-TIEN-26, R-TIEN-32, R-TIEN-33, R-TIEN-38, R-CS-02.

## Đường chuẩn: Chuyển phí

1. Tạo đơn 1 năm mới trên phiếu tái tục (một phiếu ở L8 có được nhiều đơn), trình và duyệt như đơn thường.
2. Tạo ticket đề nghị nhóm Chuyển phí, loại «sang gói khác», cho ghi danh của đơn cũ; duyệt đủ cấp rồi thực hiện (`app.apply_fee_transfer`).
   - Ghi danh cũ chuyển sang Dừng, giờ còn lại trừ hết.
   - Giá trị = giờ mua còn lại × giá sau chiết khấu, không trừ phí; giờ tặng còn lại bị huỷ. Tiền vào **số dư khách hàng** của phụ huynh.
3. Dùng số dư vào đơn mới («Dùng số dư»). Thiếu thì thu thêm; dư thì để lại số dư hoặc hoàn.

## Đường rút gọn (huỷ đơn cũ): chỉ khi chưa có phiếu thu đã duyệt

Kết quả đọc mã `app.cancel_order`, `app.order_has_receipt`, `app.cancel_receipt`, `app.reverse_money_in`:

| Tình trạng đơn cũ | Huỷ đơn được không |
| --- | --- |
| Chưa có phiếu thu nào | Được (kèm điều kiện ghi danh dưới đây) |
| Chỉ có phiếu thu chưa duyệt | Huỷ từng phiếu thu trước (`cancel_receipt`) rồi huỷ đơn |
| Có phiếu thu đã duyệt | **Không** (`HMT_DON_DA_CO_PHIEU_THU`). Phiếu đã duyệt không huỷ được (`HMT_PHIEU_DA_DUYET`); hoàn tác khoản tiền chỉ thêm khoản âm, phiếu thu giữ nguyên tình trạng nên đơn vẫn bị chặn |
| Chỉ có khoản cấn từ số dư | Hoàn tác khoản đó (tiền về lại số dư) thì không còn bị chặn vì khoản này |
| Còn ghi danh hiệu lực (cho học trước) | **Không** (`HMT_DON_CO_GHI_DANH`): dừng học hoặc hoàn phí ghi danh trước |

Vì vậy trường hợp đã đặt cọc hoặc đã đóng một đợt (phiếu thu đã duyệt) **chỉ đi đường Chuyển phí**.

## Chỗ mã chưa lo, cần anh chốt

- Chuyển phí **không đóng đơn cũ**: đơn cũ vẫn Đã duyệt, các đợt chưa thu vẫn hiện ở Công nợ và «Việc của tôi» (`app.list_receivables` lấy mọi đơn Đã duyệt còn đợt thiếu).
- Nếu sau đó vẫn duyệt thêm phiếu thu vào đơn cũ, tiền được ghi nhưng ghi danh đã Dừng không được cấp thêm giờ (`app.sync_enrollment_hours` bỏ qua).
