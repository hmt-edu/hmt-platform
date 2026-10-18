import type { SessionEnd } from './sessionEnd';

const MINUTES_PER_HOUR = 60; // allow-number: đổi đơn vị thời gian để hiển thị, không phải ngưỡng nghiệp vụ
const MINUTES_PER_DAY = 1440; // allow-number: đổi đơn vị thời gian để hiển thị, không phải ngưỡng nghiệp vụ

/**
 * Số phút không thao tác (tham số `*_idle_logout_minutes`, luật R-HT-03) viết cho dễ đọc: chia hết cho ngày thì
 * hiện ngày, chia hết cho giờ thì hiện giờ, còn lại hiện phút. Ví dụ 10080 → "7 ngày", 120 → "2 giờ", 60 → "60 phút".
 */
export function formatIdleDuration(minutes: number): string {
  if (minutes >= MINUTES_PER_DAY && minutes % MINUTES_PER_DAY === 0)
    return `${minutes / MINUTES_PER_DAY} ngày`;
  if (minutes > MINUTES_PER_HOUR && minutes % MINUTES_PER_HOUR === 0)
    return `${minutes / MINUTES_PER_HOUR} giờ`;
  return `${minutes} phút`;
}

/** Câu của hộp thoại hết phiên (DN09). Số phút lấy từ tham số thời gian phiên của vai trò, không viết cứng. */
export function sessionEndText(end: SessionEnd): string {
  if (end.reason === 'idle')
    return end.minutes
      ? `Bạn không thao tác quá ${formatIdleDuration(end.minutes)} nên hệ thống đã đăng xuất để bảo vệ dữ liệu. Phần đang nhập dở chưa được lưu.`
      : 'Bạn không thao tác quá thời gian cho phép nên hệ thống đã đăng xuất để bảo vệ dữ liệu. Phần đang nhập dở chưa được lưu.';
  return 'Phiên đăng nhập của bạn đã kết thúc nên hệ thống đã đăng xuất để bảo vệ dữ liệu. Phần đang nhập dở chưa được lưu.';
}
