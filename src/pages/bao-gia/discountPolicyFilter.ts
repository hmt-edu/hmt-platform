// Ưu đãi linh hoạt (Q-141, R-V2-45): chính sách hệ thống có cờ is_flexible, nhân viên nhập % tay, hạn mức đọc từ Cài đặt. Phần máy chủ đã xong
// (migration 085). Giao diện chip nhập % và lỗi vượt hạn mức chờ khung của Design (canvas Bán hàng & Thu chi): CHƯA có khung nên em không tự
// bịa chữ, tạm ẩn chính sách này khỏi ô chọn chiết khấu để người dùng không chọn rồi gặp lỗi "nhập % ưu đãi". Bỏ hàm này khi làm màn chip.
export function withoutFlexible<T extends { is_flexible?: boolean | undefined }>(
  policies: T[],
): T[] {
  return policies.filter((p) => p.is_flexible !== true);
}
