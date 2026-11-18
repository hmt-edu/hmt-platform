// GV-03 Lịch dạy: hàm thuần cho khung tuần (giờ Việt Nam). Máy chủ quyết buổi nào thuộc giáo viên (R-GV-08, hàm app.teacher_my_sessions);
// trang chỉ chia buổi theo ngày trong tuần và đặt chữ, màu theo loại buổi.
import { addDays, formatDayHeading, hhmm, type MySession } from './todayLogic';
import type { TagTone } from '../../ui/Data';

export const DAYS_IN_WEEK = 7; // allow-number: một tuần có bảy ngày (hiển thị lịch tuần, không phải số nghiệp vụ)
const MONDAY_OFFSET = 6; // allow-number: đổi thứ (Chủ Nhật = 0) sang vị trí trong tuần bắt đầu từ Thứ Hai
const SHORT_WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/** Ngày Thứ Hai của tuần chứa ngày đã cho (yyyy-mm-dd). */
export function mondayOf(dateKey: string): string {
  const dow = new Date(`${dateKey}T12:00:00Z`).getUTCDay();
  return addDays(dateKey, -((dow + MONDAY_OFFSET) % DAYS_IN_WEEK));
}

/** Bảy ngày của tuần bắt đầu từ Thứ Hai. */
export function weekDays(mondayKey: string): string[] {
  return Array.from({ length: DAYS_IN_WEEK }, (_, i) => addDays(mondayKey, i));
}

/** "26/10 – 01/11" */
export function weekLabel(mondayKey: string): string {
  const fmt = (k: string) => k.slice(8, 10) + '/' + k.slice(5, 7); // allow-number: cắt chuỗi yyyy-mm-dd
  return `${fmt(mondayKey)} – ${fmt(addDays(mondayKey, DAYS_IN_WEEK - 1))}`;
}

/** "T2 26" cho nút ngày trên điện thoại. */
export function dayChip(dateKey: string): { weekday: string; day: string } {
  const dow = new Date(`${dateKey}T12:00:00Z`).getUTCDay();
  return { weekday: SHORT_WEEKDAYS[dow] ?? '', day: dateKey.slice(8, 10) }; // allow-number: cắt chuỗi yyyy-mm-dd
}

/** Chia buổi theo ngày (đủ mọi ngày đã cho, ngày không có buổi là mảng rỗng), xếp theo giờ bắt đầu rồi giờ kết thúc. */
export function groupByDay(rows: MySession[], days: string[]): Record<string, MySession[]> {
  const out: Record<string, MySession[]> = Object.fromEntries(days.map((d) => [d, []]));
  for (const s of rows) out[s.session_date]?.push(s);
  for (const list of Object.values(out))
    list.sort(
      (a, b) => a.start_time.localeCompare(b.start_time) || a.end_time.localeCompare(b.end_time),
    );
  return out;
}

const TYPE_TONES: Record<string, TagTone> = {
  CHINH: 'info',
  CUNG_CO: 'warning',
  HOC_BU: 'brand',
  BO_TRO: 'success',
};

/** Màu theo loại buổi; loại lạ dùng màu trung tính. Luôn kèm chữ (typeLabel), không chỉ dùng màu. */
export function typeTone(typeCode: string): TagTone {
  return TYPE_TONES[typeCode] ?? 'neutral';
}

/** Tên loại buổi: ưu tiên tên từ danh mục (máy chủ trả), không có thì mã. */
export function typeLabel(s: Pick<MySession, 'type_code' | 'session_type_name'>): string {
  return s.session_type_name?.trim() || s.type_code;
}

/** Dòng phụ của buổi: giờ, phòng (nếu có). */
export function timeAndRoom(s: MySession): string {
  return [`${hhmm(s.start_time)}–${hhmm(s.end_time)}`, s.room_name?.trim() || null]
    .filter(Boolean)
    .join(' · ');
}

/** Ngày được chọn khi mở tuần: hôm nay nếu nằm trong tuần, không thì Thứ Hai. */
export function defaultDay(days: string[], todayKey: string): string {
  return days.includes(todayKey) ? todayKey : (days[0] ?? todayKey);
}

export { formatDayHeading };
