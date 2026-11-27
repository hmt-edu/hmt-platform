// GD-06 Chờ xếp lớp: số ngày đã chờ tính theo ngày lịch Việt Nam (canvas «Đào tạo — menu và điểm danh», khung GhiDanh).
import { vnDayBounds } from '../../lib/vnDay';

const MS_DAY = 86_400_000; // allow-number: số mili giây của một ngày

export function waitingDaysLabel(since: string, now: Date = new Date()): string {
  const days = Math.round(
    (vnDayBounds(now).start.getTime() - vnDayBounds(new Date(since)).start.getTime()) / MS_DAY,
  );
  return days <= 0 ? 'Hôm nay' : `${days} ngày`;
}
