# Đường OTP, magic link, recover của Supabase Auth (S9, ra-soat 23/11)

## Vấn đề
Supabase Auth vẫn mở `/auth/v1/otp`, `/magiclink`, `/recover`. Với địa chỉ nội bộ của học sinh (`@hocsinh.…`), Edge Function `send-email` bỏ thư và trả 200 (luật: không gửi thư cho học sinh), nhưng mã OTP 6 số vẫn được tạo. Ai biết mã học sinh (dạng HS900001, đoán được) có thể thử đoán 6 số trong thời hạn hiệu lực. Chặn hiện có: 30 lần mỗi 5 phút mỗi IP, hạn 3.600 giây.

## Đã làm trong mã (PR này)
Chỉ tài liệu. Không đổi `send-email`: trả lỗi riêng cho học sinh sẽ cho kẻ xấu biết tài khoản có tồn tại (tệ hơn), nên giữ trả 200 giống địa chỉ không tồn tại. Không đổi `supabase/config.toml` (file cấu hình local của từng máy, không commit); giá trị an toàn đặt trên dashboard của môi trường thật như dưới đây.

## Anh làm tay trên dashboard Supabase (staging trước, rồi chạy thật qua quy trình riêng)
Project `hmt-staging` (và `hmt-prod` do anh làm trên trình duyệt):
1. Authentication → Providers → Email: **Email OTP Expiration = 600** (giây).
2. Authentication → Rate Limits: **Rate limit for token verifications = 10** mỗi 5 phút mỗi IP.
3. Authentication → Attack Protection: bật **CAPTCHA (Turnstile)** cho tầng Auth (đang tắt trên staging, xem báo cáo N0 #10); dán Turnstile secret của môi trường.
4. Authentication → Sign In / Providers: giữ **tắt «Allow new users to sign up»** (S-staging cho tự đăng ký).
Sau khi làm: nhờ Tester kiểm lại: gọi `/auth/v1/otp` không có captcha phải bị từ chối.

Việc này KHÔNG cần khoá chạy thật trên máy Mac; không đụng `hmt-prod` từ `hmt-platform`.
