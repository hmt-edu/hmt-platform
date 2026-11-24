---
title: Xác thực hai bước
slug: chung-hai-buoc
group: bat-dau
order: 22
role: Quản trị viên
portals: [crm]
priority: P1
flow: CH2
screens: [P1-04, P1-05]
---

# Xác thực hai bước

**Làm xong bạn có:** tài khoản được bảo vệ thêm bằng mã 6 số từ ứng dụng trên điện thoại, và đăng nhập bằng mã đó.
**Ai làm:** tài khoản **Quản trị viên (Admin)**. Vai khác, kể cả Kế toán, đăng nhập bằng mật khẩu là đủ và không có mục này.

## Trước khi bắt đầu, kiểm
- [ ] Điện thoại của bạn đã cài một ứng dụng xác thực (Google Authenticator, Microsoft Authenticator…).
- [ ] Bạn đã đăng nhập được bằng email và mật khẩu (xem bài «Đăng nhập, đổi mật khẩu, quên mật khẩu»).

## Thiết lập lần đầu
1. Sau khi nhập email và mật khẩu, màn «Bật xác thực hai bước» hiện (dòng «BƯỚC 1/2 · QUÉT MÃ»).
   *Bạn thấy:* một mã vuông (QR) để quét.
   [ẢNH: hai-buoc-thiet-lap]
2. Mở ứng dụng xác thực trên điện thoại, chọn thêm tài khoản, quét mã. Không quét được thì gõ khoá ở dòng «Không quét được? Nhập khoá này vào ứng dụng:».
   *Bạn thấy:* ứng dụng hiện một mã 6 số đổi sau mỗi ít giây.
3. Bấm sang bước tiếp. Màn «Nhập mã từ ứng dụng» (dòng «BƯỚC 2/2 · NHẬP MÃ») hỏi mã 6 số đang hiện; nhập vào ô «Mã xác thực».
   *Bạn thấy:* hệ thống xác nhận và đưa bạn về màn đăng nhập; đăng nhập lại là vào được.

## Các lần đăng nhập sau
1. Nhập email, mật khẩu, bấm «Đăng nhập».
2. Màn «Xác thực hai bước» nhắc mở ứng dụng trên điện thoại; nhập mã 6 số đang hiện vào «Mã xác thực».
   [ẢNH: hai-buoc-nhap-ma]
   *Bạn thấy:* vào trang chủ của cổng.

## Thêm hoặc gỡ thiết bị
1. Bấm tên mình ở góc trên → «Hồ sơ cá nhân» → mục «Xác thực hai bước».
2. Bạn đăng ký được **tối đa 2 thiết bị** (ví dụ điện thoại chính và một máy dự phòng) để mất một máy vẫn đăng nhập được. **Không có mã dự phòng.**
3. Bấm «Thêm thiết bị» để thêm máy thứ hai (đủ 2 máy thì nút bị khoá: gỡ một máy trước).
4. Bấm «Gỡ» cạnh thiết bị cần bỏ → hộp «Gỡ thiết bị xác thực?» → «Gỡ thiết bị».
   [ẢNH: ho-so-thiet-bi-xac-thuc]

## Làm nhầm thì sao
| Nhầm gì | Làm gì |
|---|---|
| Mất điện thoại, chưa kịp đăng ký máy dự phòng | Liên hệ quản trị viên khác để đặt lại xác thực hai bước («Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước») |
| Gỡ nhầm thiết bị | Bấm «Thêm thiết bị» và quét lại |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| «Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.» | Gõ sai hoặc mã đã đổi | Chờ mã mới hiện rồi nhập lại; kiểm đồng hồ điện thoại có đúng giờ không |
| «Không tải được thông tin xác thực. Tải lại trang rồi thử lại.» | Lỗi mạng | Tải lại trang |

## Hỏi đáp
- **Tôi là Kế toán, có phải bật không?** Không. Kế toán đăng nhập bằng mật khẩu.
- **Đổi điện thoại thì sao?** Thêm máy mới (đăng ký tối đa 2 máy), rồi gỡ máy cũ.
