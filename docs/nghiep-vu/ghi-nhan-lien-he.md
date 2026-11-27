# Ghi nhận liên hệ trên hồ sơ phụ huynh, học sinh (migration 694; R-CRM-30, R-CRM-42, R-CRM-43)

| Thành phần | Nội dung |
| --- | --- |
| Danh mục `CONTACT_CHANNEL`, `CONTACT_RESULT` | Kiểu mở, quản trị ở QT-07 |
| Cột `app.note` | `contact_channel_code`, `contact_result_code` (cùng có hoặc cùng trống). Ghi chú có hai cột này là một lần liên hệ |
| Cột `app.appointment` | `parent_id`, `student_id`; mỗi lịch gắn đúng một hồ sơ |
| Hàm `app.log_contact(loại, id, kênh, kết quả, nội dung, hẹn lần sau)` | Quyền như thêm ghi chú; hẹn lần sau cần thêm quyền Lịch hẹn · Tạo. Một giao dịch. Lỗi: `HMT_LOAI_BAN_GHI_SAI`, `HMT_THIEU_THONG_TIN`, `HMT_BAN_GHI_DA_GOP`, `HMT_HEN_LAN_SAU_QUA_KHU`, `HMT_KHONG_CO_QUYEN` |
| Hàm `app.record_notes` | Trả thêm `contact_channel`, `contact_result` (tên) |
| Hàm `app.create_appointment` | Thêm `p_parent_id`, `p_student_id` |
| Các hàm lịch hẹn | Danh sách, Group By, xuất, dời, giao, hoàn thành, «Việc của tôi» hiểu lịch gắn PH/HS; lọc thêm `parent_id`, `student_id`, loại `PARENT`, `STUDENT` |
