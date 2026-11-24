---
id: qt12
ten: Tài khoản học sinh và phụ huynh (cấp, khoá, đặt lại)
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-13, QT-17]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Tài khoản học sinh và phụ huynh (cấp, khoá, đặt lại)

**Làm xong bạn có:** học sinh hoặc phụ huynh có tài khoản đăng nhập cổng học tập, và bạn giao được mật khẩu tạm cho họ.
**Ai làm:** Admin (cấp, đặt lại, khoá). **Màn:** menu **Quản trị** → **Tài khoản học sinh** hoặc **Tài khoản phụ huynh**.

> Video: [VIDEO: qt12]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai không có quyền Admin không thấy hai mục menu này; vào được màn mà không có quyền Sửa thì không thấy nút thao tác.
- [ ] Hồ sơ học sinh hoặc phụ huynh **đã có** (hồ sơ học sinh tự sinh khi có phiếu kiểm tra đầu vào hoặc đơn được duyệt). Màn này không tạo hồ sơ.
- [ ] Bạn có cách chuyển mật khẩu tạm cho người nhận (hệ thống **không gửi email**).

## Luật cần nhớ (lời thường)
- Tên đăng nhập là **mã HS** (học sinh) hoặc **mã PH** (phụ huynh).
- Hệ thống sinh **mật khẩu tạm, chỉ hiện một lần**, không lưu ở đâu. Chưa chép thì không xem lại được; khi đó Đặt lại mật khẩu.
- Học sinh phải đổi mật khẩu ở lần đăng nhập đầu.
- Đặt lại mật khẩu: mật khẩu cũ hết hiệu lực, người đó bị đăng xuất khỏi mọi thiết bị.
- Khoá: người đó không đăng nhập được nữa và bị đăng xuất khỏi mọi thiết bị.
- Học sinh: khoá rồi có nút **Mở khoá** (đăng nhập lại bằng mật khẩu hiện có). Phụ huynh: khoá rồi **không có Mở khoá**. ⚠ **«Đặt lại mật khẩu» KHÔNG mở lại tài khoản phụ huynh đã khoá** (chỉ đổi mật khẩu, người đó vẫn không đăng nhập được). Hiện màn này chưa có cách mở lại: báo Chat. Cách tạm (chưa thử trên staging): màn **Người dùng** → hồ sơ người đó → «Mở khoá».
- Không xoá tài khoản.

## Các bước: học sinh (QT-13)
1. Vào **Quản trị** → **Tài khoản học sinh**.
   *Bạn thấy:* bảng Mã HS, Học sinh, Phụ huynh, Cơ sở, Tài khoản (Chưa cấp / Đang dùng / Đã khoá), Đổi mật khẩu lần đầu, Đăng nhập gần nhất. Lọc theo Tài khoản và Cơ sở.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt12-b1]
2. Học sinh «Chưa cấp»: bấm **Cấp tài khoản** ở dòng, rồi **Cấp tài khoản** trong hộp xác nhận.
   *Bạn thấy:* hộp «Mật khẩu tạm» ghi tên em, mật khẩu to ở giữa, nút **Chép mật khẩu** (đổi thành «Đã chép») và **Xong**. Thông báo «Đã cấp tài khoản cho <tên>.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt12-b2]
3. Bấm **Chép mật khẩu**, gửi cho em hoặc phụ huynh theo cách riêng, rồi bấm **Xong**.
   ⚠ Bấm «Xong» khi chưa chép, hệ thống nhắc một lần; bấm lần nữa là đóng và mật khẩu mất.
4. Cấp cho nhiều em: tích chọn các dòng «Chưa cấp», bấm **Cấp tài khoản (N)** trên thanh thao tác, rồi **Cấp và tải file**.
   *Bạn thấy:* một file tải về gồm Mã HS (tên đăng nhập), Học sinh, Mật khẩu tạm, Lỗi. Thông báo «Đã cấp N tài khoản. File vừa tải chứa mật khẩu tạm, chỉ có một lần này.» Nếu có em lỗi: «Đã cấp X/Y em; Z em lỗi (xem cột Lỗi trong file vừa tải).»
   ⚠ File là nơi duy nhất có mật khẩu; giữ kín và xoá sau khi giao.
5. Đã có tài khoản: **Đặt lại mật khẩu** (hộp «Đặt lại mật khẩu» → xác nhận → hộp «Mật khẩu tạm»), **Khoá** (chọn lý do, bấm «Khoá»), hoặc **Mở khoá** nếu đang khoá.
   *Bạn thấy:* «Đã đặt lại mật khẩu cho <tên>.», «Đã khoá tài khoản của <tên>.» hoặc «Đã mở khoá tài khoản của <tên>.»

## Các bước: phụ huynh (QT-17)
1. Vào **Quản trị** → **Tài khoản phụ huynh**.
   *Bạn thấy:* bảng Mã PH, Phụ huynh, Số con, Tài khoản, Đăng nhập gần nhất, Thao tác. Lọc theo Tài khoản và Cơ sở.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt12-b6]
2. «Chưa cấp»: **Cấp tài khoản** → xác nhận → hộp «Mật khẩu tạm» → **Chép mật khẩu** → **Xong**. Chuyển mật khẩu cho phụ huynh (không có email tự động).
   *Bạn thấy:* «Đã cấp tài khoản cho <tên>.»
3. Đã có tài khoản: **Đặt lại mật khẩu** hoặc **Khoá** (nút Khoá chỉ hiện khi tài khoản đang hoạt động). Khoá phụ huynh **không bắt chọn lý do**.
   *Bạn thấy:* «Đã đặt lại mật khẩu cho <tên>.» hoặc «Đã khoá tài khoản của <tên>.» Tài khoản khoá chỉ còn nút **Đặt lại mật khẩu**, nhưng nút này không mở lại được tài khoản đã khoá.

## Sau bước này
- **Ai làm tiếp:** học sinh, phụ huynh đăng nhập cổng học tập bằng mã và mật khẩu tạm; học sinh đổi mật khẩu ở lần đầu.
- **Bạn xem ở đâu:** bảng này, cột «Tài khoản» và «Đăng nhập gần nhất». Mọi lần đổi có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Lỡ đóng hộp khi chưa chép mật khẩu | Bấm «Đặt lại mật khẩu» để sinh mật khẩu mới |
| Khoá nhầm học sinh | Bấm «Mở khoá» |
| Khoá nhầm phụ huynh | **Đặt lại mật khẩu không mở lại được.** Báo Chat; cách tạm chưa thử: màn Người dùng → hồ sơ → «Mở khoá». Nên xác nhận kỹ trước khi bấm «Khoá» |
| Cấp nhầm người | Không xoá được. Bấm «Khoá» |
| Giao nhầm mật khẩu cho người khác | Bấm «Đặt lại mật khẩu» ngay |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Chưa có học sinh» / «Chưa có phụ huynh» | bộ lọc không có dòng nào | Bỏ bớt bộ lọc. Chưa có hồ sơ học sinh thì chờ phiếu kiểm tra đầu vào hoặc đơn được duyệt |
| Em lỗi trong file cấp hàng loạt (cột «Lỗi») | cấp riêng em đó không được | Đọc cột «Lỗi»; cấp lại riêng em đó |
| Lỗi đỏ trong hộp xác nhận | máy chủ từ chối | Đọc câu trong hộp; không rõ thì báo Admin hệ thống |
| Chép mật khẩu không được | trình duyệt chặn bộ nhớ tạm | Bôi đen mật khẩu rồi sao chép tay |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**; một học sinh và một phụ huynh giả chưa có tài khoản.
- **Dùng:** cấp tài khoản cho một em, đặt lại mật khẩu, khoá rồi mở khoá; với phụ huynh: cấp, khoá, đặt lại. Không chép mật khẩu của người thật vào chat hay ghi chú.
- Vai Vận hành tập tạm bằng quyền CSKH (anh Trường chốt 24/11): menu này đòi quyền Admin nên CSKH **không vào được**; tập bằng `bgd.tap`.
- Chưa có trong bộ mẫu: học sinh, phụ huynh giả dành riêng cho việc tập.

## Tự kiểm: bạn làm được khi
- [ ] Bạn cấp được một tài khoản và chép được mật khẩu tạm trước khi bấm «Xong».
- [ ] Bạn nói được khác biệt: học sinh có Mở khoá; phụ huynh khoá rồi thì Đặt lại mật khẩu không mở lại được.
- [ ] Bạn cấp hàng loạt và biết file tải về là nơi duy nhất có mật khẩu.
