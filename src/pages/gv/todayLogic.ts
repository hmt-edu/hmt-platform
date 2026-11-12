// GV-02 Hôm nay: kiểu dữ liệu hàm app.teacher_my_sessions và các hàm hiển thị thuần (giờ Việt Nam). Máy chủ quyết buổi nào thuộc
// giáo viên và hạn hoàn tất (R-GV-05, R-GV-08); giao diện chỉ gom nhóm "sắp trễ hạn" từ giờ kết thúc, trạng thái và hạn (R-V2-37).

export type MySession = {
  session_id: string;
  class_id: string;
  class_code: string;
  subject_name: string | null;
  session_no: number | null;
  session_date: string;
  start_time: string;
  end_time: string;
  type_code: string;
  status_code: string;
  my_role: 'GIAO_VIEN' | 'TRO_GIANG';
  has_content: boolean;
  deadline_at: string;
  pending_reason: string | null;
  /** Hàm máy chủ (migration 109) trả thêm; có thể vắng ở bản cũ. */
  room_name?: string | null;
  session_type_name?: string | null;
};

export type MySessionsResult = { total: number; rows: MySession[] };

const WEEKDAYS = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
const MS_PER_HOUR = 3_600_000; // allow-number: mili giây trong một giờ (đổi đơn vị, không phải số nghiệp vụ)
// Việt Nam không dùng giờ mùa hè: múi giờ cố định UTC+7, đủ để ghép ngày và giờ của buổi thành một thời điểm.
const VN_OFFSET = '+07:00';
export const NEXT_LOOKAHEAD_DAYS = 60; // allow-number: số ngày tìm buổi tiếp theo khi hôm nay trống (chỉ để hiển thị gợi ý)

/** "2026-10-24" → "Thứ Bảy 24/10". */
export function formatDayHeading(dateKey: string): string {
  const [y, m, d] = dateKey.split('-').map(Number);
  if (!y || !m || !d) return dateKey;
  const weekday = WEEKDAYS[new Date(Date.UTC(y, m - 1, d, 12)).getUTCDay()] ?? '';
  return `${weekday} ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}`;
}

/** "14:00:00" → "14:00". */
export function hhmm(time: string): string {
  return time.slice(0, 5);
}

/** Cộng số ngày vào một ngày dạng yyyy-mm-dd (không đụng múi giờ). */
export function addDays(dateKey: string, days: number): string {
  const at = new Date(`${dateKey}T12:00:00Z`);
  at.setUTCDate(at.getUTCDate() + days);
  return at.toISOString().slice(0, 10);
}

/** Tên buổi: môn, mã lớp, số buổi. (Trình độ, loại lớp, tên loại buổi sẽ thêm khi hàm máy chủ trả; migration 109 của Code 2.) */
export function sessionTitle(s: MySession): string {
  return [s.subject_name, s.class_code, s.session_no ? `Buổi ${s.session_no}` : null]
    .filter(Boolean)
    .join(' · ');
}

/** Thời điểm kết thúc của buổi (giờ Việt Nam). */
export function endsAt(s: MySession): Date {
  return new Date(`${s.session_date}T${s.end_time}${VN_OFFSET}`);
}

/**
 * Sắp trễ hạn (R-V2-37, R-GV-05): buổi đã kết thúc, chưa Done, hạn hoàn tất còn phía trước. Quá hạn rồi thì không hiện ở GV-02
 * (nằm ở GV-12). Hạn đúng bằng bây giờ coi là đã quá hạn. Xếp theo hạn gần nhất trước.
 */
export function urgentSessions(rows: MySession[], now: Date): MySession[] {
  return rows
    .filter(
      (s) =>
        s.status_code !== 'DONE' &&
        endsAt(s).getTime() <= now.getTime() &&
        new Date(s.deadline_at).getTime() > now.getTime(),
    )
    .sort((a, b) => new Date(a.deadline_at).getTime() - new Date(b.deadline_at).getTime());
}

const VN_TIME = new Intl.DateTimeFormat('vi-VN', {
  timeZone: 'Asia/Ho_Chi_Minh',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
});
const VN_DAY = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Ho_Chi_Minh',
  day: '2-digit',
  month: '2-digit',
});
const VN_KEY = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });

/** "hạn 23:30" (cùng ngày hôm nay) hoặc "hạn 25/10 03:30" (sang ngày khác). */
export function formatDeadline(deadlineIso: string, todayKey: string): string {
  const at = new Date(deadlineIso);
  const time = VN_TIME.format(at);
  return VN_KEY.format(at) === todayKey ? `hạn ${time}` : `hạn ${VN_DAY.format(at)} ${time}`;
}

/** "Còn 5 giờ" (làm tròn lên); dưới một giờ vẫn ghi "Còn 1 giờ". */
export function hoursLeftText(deadlineIso: string, now: Date): string {
  const hours = Math.max(
    1,
    Math.ceil((new Date(deadlineIso).getTime() - now.getTime()) / MS_PER_HOUR),
  );
  return `Còn ${hours} giờ`;
}

/** "Thứ Hai 26/10 19:30" cho dòng báo buổi tiếp theo khi hôm nay trống. */
export function formatNextSession(s: Pick<MySession, 'session_date' | 'start_time'>): string {
  return `${formatDayHeading(s.session_date)} ${hhmm(s.start_time)}`;
}
