Dialog được cấu hình sẵn cho hành động không hoàn tác được: `role="alertdialog"`, focus mặc định ở nút Huỷ, nút xác nhận là destructive solid với động từ cụ thể.

- Tiêu đề là câu hỏi nêu đúng đối tượng ("Xoá Lê Chi khỏi lớp 4C3?"); mô tả nói hậu quả.
- Khi đang xử lý: nút loading, không đóng bằng Esc/scrim.
- Không dùng khi có thể Hoàn tác (dùng Toast có Hoàn tác thay vì hỏi trước).

- `reasonLabel` (+ `reasonOptions`): ô lý do bắt buộc cho huỷ, từ chối, điều chỉnh, đảo khoản, đưa về Nháp; thiếu lý do thì báo lỗi tại ô, không đóng hộp thoại.
