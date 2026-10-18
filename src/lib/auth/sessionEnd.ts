// Ghi lại vì sao phiên kết thúc để trang đăng nhập hiện hộp thoại "Phiên làm việc đã hết" (CHUNG-09).
// Không nói lý do cụ thể kiểu "tài khoản bị khoá" (đăng nhập không lộ trạng thái khoá, chốt 10/10).
export type SessionEndReason = 'idle' | 'ended';

/** `minutes`: số phút không thao tác đã áp dụng cho vai trò (tham số thời gian phiên, S03-19); chỉ có khi `idle`. */
export type SessionEnd = { reason: SessionEndReason; minutes: number | null };

const KEY = 'hmt:het-phien';

export function markSessionEnded(reason: SessionEndReason, minutes?: number | null): void {
  try {
    sessionStorage.setItem(KEY, reason === 'idle' && minutes ? `idle:${minutes}` : reason);
  } catch {
    // Trình duyệt chặn lưu trữ: bỏ qua, người dùng chỉ thấy trang đăng nhập.
  }
}

/** Đọc rồi xoá (chỉ hiện hộp thoại một lần). */
export function takeSessionEnded(): SessionEnd | null {
  try {
    const value = sessionStorage.getItem(KEY);
    sessionStorage.removeItem(KEY);
    if (value === 'ended') return { reason: 'ended', minutes: null };
    const match = /^idle(?::(\d+))?$/.exec(value ?? '');
    return match ? { reason: 'idle', minutes: match[1] ? Number(match[1]) : null } : null;
  } catch {
    return null;
  }
}
