// GV-10 Lớp của tôi: kiểu dữ liệu hàm app.list_classes (phạm vi "lớp được phân công", R-GV-08) và hàm hiển thị thuần.
// Máy chủ quyết lớp nào thuộc giáo viên; trang chỉ ghép sĩ số và buổi tiếp theo (từ app.teacher_my_sessions). Không có thông tin phụ huynh, học phí (R-GV-13).
import { formatNextSession, hhmm, type MySession } from './todayLogic';

export type MyClass = {
  id: string;
  code: string;
  subject_name: string | null;
  class_type_name: string | null;
  level_name: string | null;
  operating_status: string | null;
  max_students: number | null;
  enrolled: number;
  schedule: { weekday: number; start_time: string; end_time: string }[];
};

export type MyClassesResult = { total: number; rows: MyClass[] };

/** Lớp còn dạy: chưa kết thúc. Mã tình trạng vận hành «đã kết thúc» do máy chủ định nghĩa (app.class_operating_status). */
const ENDED = 'DA_KET_THUC';
export function isTeaching(c: Pick<MyClass, 'operating_status'>): boolean {
  return c.operating_status !== ENDED;
}

const SHORT_WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/** Buổi tiếp theo của mỗi lớp: buổi sớm nhất chưa Done trong danh sách (đã lọc từ hôm nay). */
export function nextByClass(rows: MySession[]): Map<string, MySession> {
  const out = new Map<string, MySession>();
  const sorted = [...rows]
    .filter((s) => s.status_code !== 'DONE')
    .sort(
      (a, b) =>
        a.session_date.localeCompare(b.session_date) || a.start_time.localeCompare(b.start_time),
    );
  for (const s of sorted) if (!out.has(s.class_id)) out.set(s.class_id, s);
  return out;
}

/** "Sĩ số 18/20", hoặc "Sĩ số 18" khi lớp không giới hạn (max_students = 0 hoặc trống). */
export function capacityText(c: Pick<MyClass, 'enrolled' | 'max_students'>): string {
  return c.max_students ? `Sĩ số ${c.enrolled}/${c.max_students}` : `Sĩ số ${c.enrolled}`;
}

/** "T2 18:00–19:30 · T5 18:00–19:30" */
export function scheduleText(c: Pick<MyClass, 'schedule'>): string {
  return c.schedule
    .map(
      (s) =>
        `${SHORT_WEEKDAYS[s.weekday % SHORT_WEEKDAYS.length] ?? ''} ${hhmm(s.start_time)}–${hhmm(s.end_time)}`,
    )
    .join(' · ');
}

/** Dòng "Buổi tiếp theo: Thứ Hai 26/10 19:30" hoặc "Chưa có buổi sắp tới". */
export function nextText(s: MySession | undefined): string {
  return s ? `Buổi tiếp theo: ${formatNextSession(s)}` : 'Chưa có buổi sắp tới';
}

/** Tên lớp: môn, phân loại, trình độ (bỏ phần trống); mã lớp hiện riêng. */
export function classTitle(
  c: Pick<MyClass, 'subject_name' | 'class_type_name' | 'level_name'>,
): string {
  return [c.subject_name, c.class_type_name, c.level_name].filter(Boolean).join(' · ');
}
