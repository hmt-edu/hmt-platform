// GV-05 Điểm danh: kiểu dữ liệu hai hàm app.teacher_attendance_sheet, app.save_attendance_teacher và các hàm thuần của bảng nháp.
// Luật nghiệp vụ (ai ghi được, buổi nào, phát hiện hai người cùng sửa) do máy chủ quyết; giao diện chỉ giữ bản nháp tới khi bấm Lưu (không tự lưu).

export type AttendanceStatus = { code: string; name: string };

export type AttendanceStudent = {
  student_id: string;
  student_code: string;
  full_name: string;
  is_trial: boolean;
  teacher_status_code: string | null;
  teacher_marked_at: string | null;
  /** Lý do liên hệ do vận hành ghi (Không nghe máy, Đã nhắc vào lớp…): giáo viên chỉ xem (R-DD-03). */
  contact_reason_name: string | null;
  has_review: boolean;
};

export type AttendanceSheet = {
  session: {
    id: string;
    status_code: string;
    type_code: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    class_code: string;
    subject_name: string | null;
    class_type_name: string | null;
    level_name: string | null;
  };
  statuses: AttendanceStatus[];
  listed: boolean;
  students: AttendanceStudent[];
};

export type AttendanceConflict = {
  student_id: string;
  full_name: string;
  current_status_code: string | null;
  marked_by_name: string | null;
  marked_at: string | null;
};

export type SaveResult = { saved: number; conflicts: AttendanceConflict[] };

/** Bản nháp: chỉ các ô đã đổi so với máy chủ. Giá trị null = xoá về "chưa điểm danh". */
export type Draft = Record<string, string | null>;

export type SaveEntry = { student_id: string; status_code: string; base_marked_at: string | null };

/** Trạng thái đang hiện của một em: bản nháp nếu có, không thì bản đã lưu. */
export function effectiveStatus(student: AttendanceStudent, draft: Draft): string | null {
  return student.student_id in draft
    ? (draft[student.student_id] ?? null)
    : student.teacher_status_code;
}

/** Đặt một ô; đặt lại đúng giá trị đã lưu thì bỏ khỏi bản nháp (không còn "chưa lưu"). */
export function setDraft(draft: Draft, student: AttendanceStudent, code: string | null): Draft {
  const next = { ...draft };
  if (code === student.teacher_status_code) delete next[student.student_id];
  else next[student.student_id] = code;
  return next;
}

/** "Đã điểm danh 3/4": số em có trạng thái (kể cả bản nháp) trên tổng số em. */
export function countMarked(students: AttendanceStudent[], draft: Draft): number {
  return students.filter((s) => effectiveStatus(s, draft) !== null).length;
}

/** Nút "Còn lại: Có mặt": đặt mọi em còn trống thành `code`. Em đã có trạng thái giữ nguyên. */
export function fillRemaining(students: AttendanceStudent[], draft: Draft, code: string): Draft {
  let next = draft;
  for (const s of students) {
    if (effectiveStatus(s, next) === null) next = setDraft(next, s, code);
  }
  return next;
}

/**
 * R-V2-36: đổi em đã có điểm nhận xét từ Có mặt, Đi muộn sang Vắng thì hỏi trước.
 * `absentCodes`: các trạng thái "Vắng" (từ danh mục: mã bắt đầu bằng VANG).
 */
export function needsAbsenceConfirm(
  student: AttendanceStudent,
  draft: Draft,
  newCode: string | null,
): boolean {
  if (!student.has_review || newCode === null || !isAbsent(newCode)) return false;
  const current = effectiveStatus(student, draft);
  return current !== null && !isAbsent(current);
}

export function isAbsent(code: string): boolean {
  return code.startsWith('VANG');
}

/** Danh sách gửi máy chủ: ô đã đổi kèm giờ ghi lúc mở màn (để máy chủ phát hiện người khác vừa sửa). */
export function buildEntries(
  students: AttendanceStudent[],
  draft: Draft,
  baseMarked: Record<string, string | null>,
): SaveEntry[] {
  return students
    .filter((s) => s.student_id in draft)
    .map((s) => ({
      student_id: s.student_id,
      status_code: draft[s.student_id] ?? '',
      base_marked_at: baseMarked[s.student_id] ?? null,
    }));
}

/** Tên người vừa sửa cho nút "Lấy của …": một tên chung thì ghi tên, nhiều người thì ghi chung. */
export function otherEditorLabel(conflicts: AttendanceConflict[]): string {
  const names = Array.from(new Set(conflicts.map((c) => c.marked_by_name).filter(Boolean)));
  return names.length === 1 ? `Lấy của ${names[0]}` : 'Lấy của người kia';
}

/** "Đại số 9 · cơ bản A · Buổi 5": môn, loại lớp kèm trình độ, số buổi. */
export function sheetTitle(session: AttendanceSheet['session']): string {
  const type = session.level_name
    ? `${session.class_type_name ?? ''} ${session.level_name}`.trim()
    : session.class_type_name;
  return [session.subject_name, type, session.session_no ? `Buổi ${session.session_no}` : null]
    .filter(Boolean)
    .join(' · ');
}

/** "24/10 18:00–19:30". */
export function sheetWhen(session: AttendanceSheet['session']): string {
  const [, m, d] = session.session_date.split('-');
  return `${d}/${m} ${session.start_time}–${session.end_time}`;
}
