// Ghi lại vì sao phiên kết thúc để trang đăng nhập hiện hộp thoại "Hết phiên làm việc" (CHUNG-09).
// Không nói lý do cụ thể kiểu "tài khoản bị khoá" (đăng nhập không lộ trạng thái khoá, chốt 10/10).
export type SessionEndReason = 'idle' | 'ended';

const KEY = 'hmt:het-phien';

export function markSessionEnded(reason: SessionEndReason): void {
  try {
    sessionStorage.setItem(KEY, reason);
  } catch {
    // Trình duyệt chặn lưu trữ: bỏ qua, người dùng chỉ thấy trang đăng nhập.
  }
}

/** Đọc rồi xoá (chỉ hiện hộp thoại một lần). */
export function takeSessionEnded(): SessionEndReason | null {
  try {
    const value = sessionStorage.getItem(KEY);
    sessionStorage.removeItem(KEY);
    return value === 'idle' || value === 'ended' ? value : null;
  } catch {
    return null;
  }
}
