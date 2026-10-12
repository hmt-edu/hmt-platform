Xác nhận ngắn sau thao tác, góc dưới phải (desktop) hoặc trên BottomNav (mobile); có thể kèm Hoàn tác.

- `ToastProvider` + `useToast().push({ tone, message, action })`. Tối đa 3; 5s (8s nếu có thao tác); dừng khi rê/focus.
- Lỗi: `aria-live="assertive"`, không tự ẩn. Thành công/thông tin: `polite`.
- Không dùng toast cho lỗi cần sửa trong form (dùng Field error) hay thông tin phải đọc kỹ (dùng Alert).
