Khung nhãn + ô nhập + helper/lỗi dùng chung cho TextInput, Select, Textarea, DateInput — ô nhập tự nhận id, aria-describedby, aria-invalid.

- **Consumer cung cấp:** `label` (luôn hiển thị, không dùng placeholder thay nhãn), `required`/`optional`, `helper`, `error` (câu nói cách sửa).
- Lỗi hiện khi rời ô hoặc khi gửi; sửa xong ẩn ngay. Khi gửi có lỗi: tóm tắt lỗi ở đầu form nhận focus, mỗi dòng dẫn tới ô.
- Viền ô `hmt-border-strong` (≥3:1); focus viền `hmt-focus`; lỗi viền `hmt-danger-border` + icon + chữ `hmt-danger`.
- Teacher Portal/LMS: chữ trong ô 16px để iOS không tự phóng to. Dùng `type`/`inputMode` đúng (tel, numeric, email).
- Select gốc của trình duyệt cho ≤ 15 lựa chọn; danh sách dài cần tìm kiếm (combobox) — chưa có trong bộ này.
