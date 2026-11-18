# Đề xuất lịch tự kết thúc bảo lưu đã tới hạn (CHỜ ANH DUYỆT, CHƯA BẬT)

Code D, 18/11/2026. Chỉ là đề xuất. Không có migration, không đăng ký lịch nào trong PR này.

## Việc cần làm

Hàm `app.end_expired_enrollment_holds()` (migration 215) kết thúc mọi bảo lưu đang `DANG_BAO_LUU` có `end_date` đã tới hoặc qua hôm nay (giờ Việt Nam), lý do `HET_HAN`, trả về số bản đã kết thúc. Hàm là nội bộ, chưa có lịch, nên bảo lưu hết hạn chỉ được kết thúc khi có người bấm tay. Quá hạn mà không ai bấm thì ghi danh vẫn nằm ở trạng thái Bảo lưu, giờ chưa quay lại, em không vào lớp lại được.

## Đề xuất lịch

- **Một lịch, mỗi ngày một lần lúc 00:15 giờ Việt Nam** (17:15 UTC, vì pg_cron chạy theo UTC): biểu thức `15 17 * * *`. Lý do: `end_date` là ngày, bảo lưu hết hạn từ đầu ngày hôm đó; chạy sau nửa đêm để em quay lại học từ sáng. Chạy một lần mỗi ngày là đủ, rất nhẹ (một câu chọn theo chỉ mục `enrollment_hold` trạng thái và `end_date`).
- Tên lịch cố định `hmt-end-expired-holds` để gọi đăng ký lại không nhân đôi, theo đúng cách của `app.sync_session_cron()` (migration 104).
- Lệnh đăng ký (sẽ làm ở migration riêng SAU khi anh duyệt): `select cron.schedule('hmt-end-expired-holds', '15 17 * * *', 'select app.end_expired_enrollment_holds()');`.

## Điều kiện và an toàn

1. **Cờ công tắc BAO_LUU theo cơ sở:** hàm cron chạy không người dùng nên không qua kiểm công tắc của hàm tay. Đề xuất sửa nhỏ: chỉ kết thúc bản của cơ sở đang bật công tắc `BAO_LUU` (cơ sở tắt thì bỏ qua), để không tự đổi dữ liệu cơ sở chưa dùng tính năng.
2. **pg_cron phải bật trước** ở từng môi trường (hướng dẫn `docs/van-hanh/bat-pg-cron.md`), staging trước, chạy thật do anh bật.
3. **Không tự gia hạn, không hoàn tiền:** hàm chỉ đổi trạng thái bảo lưu và trả ghi danh về trạng thái trước bảo lưu theo `finish_enrollment_hold`; không động tới tiền.
4. **Kiểm thử trước khi bật:** pgTAP gọi hàm khi có bản quá hạn (kết thúc), bản chưa tới hạn (giữ nguyên), cờ tắt (bỏ qua); chạy hàm hai lần liên tiếp (lần hai trả 0).
5. **Theo dõi:** ghi kết quả mỗi lần chạy vào nhật ký thao tác (số bản đã kết thúc); lỗi một bản không làm hỏng cả lô (mỗi bản một giao dịch con).

## Việc anh quyết

- Giờ chạy 00:15 (giờ Việt Nam) có ổn không, hay muốn giờ khác.
- Đồng ý thêm kiểm công tắc `BAO_LUU` theo cơ sở khi chạy lịch.
- Cho phép làm migration đăng ký lịch sau khi pg_cron bật ở staging.
