# QT-14 Ngày nghỉ lễ (migration 181)

Luật: R-LOP-12 (ngày nghỉ áp cho mọi cơ sở hoặc từng cơ sở; thêm ngày nghỉ sau khi đã sinh buổi thì xem trước các buổi bị ảnh hưởng rồi dời), R-LOP-09 (ngày nghỉ dùng để tính ngày kết thúc lớp, `app.is_holiday`).
Quyền: module `HOLIDAY` có sẵn trong ma trận quyền (Admin toàn hệ thống: Tạo, Sửa, Huỷ, Xem; Trưởng cơ sở trong cơ sở mình: Tạo, Sửa, Huỷ, Xem; CSKH, Sale: Xem). Ngày nghỉ chung (mọi cơ sở) chỉ người có quyền ở phạm vi toàn hệ thống (Admin).

| Hàm | Ai | Việc |
| --- | --- | --- |
| `save_holiday(id, ngày, tên, cơ sở)` | HOLIDAY · Tạo (id rỗng) hoặc Sửa, trong phạm vi cơ sở | Thêm hoặc sửa. Chặn trùng (ngày, cơ sở) đang dùng (HMT_NGAY_NGHI_TRUNG); thêm đúng ngày đã Ngừng thì dùng lại dòng cũ; không đổi cơ sở (HMT_KHONG_DOI_CO_SO). Trả `affected_sessions`. |
| `set_holiday_active(id, bật)` | HOLIDAY · Huỷ (ngừng) hoặc Sửa (dùng lại) | Không xoá cứng. |
| `list_holiday_sessions(id)` | HOLIDAY · Xem; chỉ buổi của cơ sở mình (trừ toàn hệ thống) | Chỉ đọc: các buổi Nháp, Đã chốt trùng ngày nghỉ (tối đa `list_page_size_max`). |
| `count_holiday_sessions(ngày, cơ sở)` | nội bộ | Số buổi chưa diễn ra trùng ngày. |

Giao diện: `/crm/cau-hinh/ngay-nghi` (máy tính): bảng theo năm, Thêm, Sửa, Ngừng/Dùng lại, hộp «Xem buổi bị ảnh hưởng».
**Chưa làm:** việc DỜ buổi (R-LOP-12 «rồi dời») thuộc màn Buổi học, làn Đào tạo; màn này chỉ xem. **Thiếu khuôn:** không có khung canvas riêng cho QT-14 (BAN-DO-VIEC ghi «Thiếu khung canvas»), dựng từ khuôn K10 và thành phần dùng chung, chữ lấy từ bản đồ màn hình.
