# CHUNG-12 Trung tâm thông báo (không migration)

Chuông ở thanh trên CRM (`src/layout/NotificationBell.tsx`). Đọc bảng `app.notification` bằng quyền người gọi: mỗi người chỉ thấy thông báo của mình (chính sách `notification_read_own`). Số chưa đọc đếm bằng `head count` theo chỉ mục `notification_unread_idx`, làm mới mỗi phút; danh sách mới nhất trước, giới hạn theo `list_page_size_default`.

- Bấm một thông báo: gọi `app.mark_notifications_read(p_id)` rồi mở bản ghi nếu loại bản ghi có màn (`notificationPath`).
- «Đánh dấu tất cả đã đọc»: `app.mark_notifications_read(p_all => true)`.
- Chuông chỉ HIỂN THỊ. Các phân hệ muốn báo (SLA, quá hạn, chờ duyệt…) tạo thông báo qua hàm nghiệp vụ của mình và khai loại trong danh mục `NOTIFICATION_KIND`.
