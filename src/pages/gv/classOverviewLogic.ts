// GV-11 Chi tiết lớp (giáo viên): kiểu dữ liệu hàm app.teacher_class_overview và hàm hiển thị thuần. Máy chủ tính chuyên cần, điểm trung bình, hạn, nhãn
// đúng hạn/trễ hạn (R-GV-02, R-GV-03, R-GV-04, R-GV-05); giao diện chỉ đặt chữ. Không có thông tin phụ huynh, học phí (R-GV-13).
import { hhmm } from './todayLogic';

export type ClassOverview = {
  class: {
    id: string;
    code: string;
    total_sessions: number | null;
    subject_name: string | null;
    class_type_name: string | null;
    level_name: string | null;
  };
  slots: {
    weekday: number;
    start_time: string;
    end_time: string;
    room_name: string | null;
    teacher_name: string | null;
    assistant_name: string | null;
  }[];
  students: {
    student_id: string;
    student_code: string;
    full_name: string;
    attendance_marked: number;
    attendance_present: number;
    avg_score: number | null;
  }[];
  sessions: {
    id: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    status_code: string;
    type_code: string;
    type_name: string | null;
    deadline_at: string;
    timeliness: 'DUNG_HAN' | 'TRE_HAN' | null;
    homework_text: string | null;
  }[];
};

type Student = ClassOverview['students'][number];
type Session = ClassOverview['sessions'][number];

const WEEKDAYS = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
const ONE_DECIMAL = 1; // allow-number: số chữ số thập phân khi hiển thị điểm (máy chủ không làm tròn, R-GV-03)

/** "Có mặt 3/4 buổi"; chưa điểm danh buổi nào thì "Chưa điểm danh". */
export function attendanceText(
  s: Pick<Student, 'attendance_marked' | 'attendance_present'>,
): string {
  return s.attendance_marked === 0
    ? 'Chưa điểm danh'
    : `Có mặt ${s.attendance_present}/${s.attendance_marked} buổi`;
}

/** "4,0" (một chữ số thập phân, dấu phẩy); chưa có điểm thì "Chưa có điểm" (ô trống không phải 0, R-GV-02). */
export function scoreText(avg: number | null): string {
  return avg === null
    ? 'Chưa có điểm'
    : `TB ${new Intl.NumberFormat('vi-VN', { minimumFractionDigits: ONE_DECIMAL, maximumFractionDigits: ONE_DECIMAL }).format(avg)}`;
}

/** Nhãn hạn của buổi: Đúng hạn / Trễ hạn, không nhãn thì null. Luôn kèm chữ, không chỉ màu. */
export function timelinessLabel(t: Session['timeliness']): string | null {
  return t === 'DUNG_HAN' ? 'Đúng hạn' : t === 'TRE_HAN' ? 'Trễ hạn' : null;
}

/** "Thứ Hai 18:00–19:30" */
export function slotText(
  s: Pick<ClassOverview['slots'][number], 'weekday' | 'start_time' | 'end_time'>,
): string {
  return `${WEEKDAYS[s.weekday % WEEKDAYS.length] ?? ''} ${hhmm(s.start_time)}–${hhmm(s.end_time)}`;
}

/** Buổi có giao BTVN (chữ không trống), mới nhất trước như máy chủ trả. */
export function homeworkSessions(sessions: Session[]): Session[] {
  return sessions.filter((x) => (x.homework_text ?? '').trim() !== '');
}

/** "24/10" từ yyyy-mm-dd */
export function shortDate(dateKey: string): string {
  return `${dateKey.slice(8, 10)}/${dateKey.slice(5, 7)}`; // allow-number: cắt chuỗi yyyy-mm-dd
}
