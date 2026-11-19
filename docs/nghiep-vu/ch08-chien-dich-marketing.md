# CH-08 Chiến dịch marketing (migration 560, Code F)

Luật R-CRM-11 (anh Trường chốt 19/11/2026): mọi vai trò vào được cổng CRM đều xem và tạo được chiến dịch; không xoá, chỉ Ngừng. Bảng `app.campaign` (migration 24): tên (không trùng, không phân biệt hoa thường), ngày bắt đầu, ngày kết thúc (tuỳ chọn, kết thúc không trước bắt đầu), đang dùng hay ngừng. Chiến dịch gắn vào lead; chiến dịch Ngừng không chọn được cho lead mới.

| Hàm | Ai gọi | Làm gì |
|---|---|---|
| `app.list_campaigns(bộ lọc, số dòng, bỏ qua)` | mọi người dùng cổng CRM | `{total, rows[{id, name, starts_on, ends_on, is_active, lead_count, created_by_name, can_toggle}]}`; lọc `q` (tên), `status` (DANG_DUNG, NGUNG); phân trang máy chủ |
| `app.create_campaign(tên, bắt đầu, kết thúc)` | mọi người dùng cổng CRM | tạo chiến dịch; lỗi HMT_CHIEN_DICH_TEN, HMT_CHIEN_DICH_TRUNG, HMT_CHIEN_DICH_NGAY_SAI |
| `app.set_campaign_active(id, bật)` | Admin hoặc người tạo | Ngừng, Dùng lại |

«Người dùng cổng CRM» = vai trò đang dùng có cổng `crm` (Admin, Trưởng cơ sở, Tuyển sinh, CSKH, Kế toán); giáo viên, trợ giảng, học sinh, phụ huynh không. Màn: `/crm/cau-hinh/chien-dich` (Cấu hình · K10, không có khung canvas riêng). Chờ Chat xác nhận: ai được Ngừng (đang là Admin hoặc người tạo).
