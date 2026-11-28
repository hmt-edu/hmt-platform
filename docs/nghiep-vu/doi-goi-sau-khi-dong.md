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

## Đơn cũ sau Chuyển phí (anh Trường OK 29/11 01:32, migration 715)

- Khi phiếu Chuyển phí được thực hiện và **mọi dòng có tiền** của đơn cũ đã đóng ghi danh (Dừng hoặc Hoàn phí), đơn được đánh dấu «đã chuyển phí» (`fee_transferred_at`, `fee_transfer_ref`); tình trạng vẫn là Đã duyệt, đợt thu giữ nguyên.
- Đơn có dấu: các đợt chưa thu không còn ở Công nợ, «Việc của tôi», nợ trên hồ sơ phụ huynh, mức gắn bó, cổng phụ huynh. Chặn lập, gửi, duyệt phiếu thu mới và dùng số dư (`HMT_DON_DA_CHUYEN_PHI`); vẫn huỷ, từ chối phiếu chưa duyệt và hoàn tác khoản tiền.
- Đơn còn dòng khác (ghi danh còn hiệu lực, dịch vụ, tài liệu): **giữ nguyên công nợ cả đơn**, chỉ ghi lịch sử «Chuyển phí một phần».
- Lần chuyển phí đã làm trước migration 715 không bị đụng.
- Chưa làm: danh sách Đơn hàng vẫn tính «Còn phải thu» theo tổng tiền cho đơn có dấu.
