// Logic thuần của màn GV-06 (Nội dung buổi và BTVN): làm sạch dòng nội dung, so sánh với bản đã lưu, kiểm điều kiện lưu.
// Luật: R-V2-35 (cần ít nhất một dòng nội dung; BTVN trống = buổi này không giao, không có ô tích "không giao").

export type SessionOverview = {
  session_id: string;
  status_code: string;
  type_code: string;
  /** Form nhận xét của buổi (chụp lúc tạo): TIEU_CHI = 9 tiêu chí, DIEM = form điểm (Kiểm tra các loại, A25). */
  review_form: string;
  type_name: string | null;
  /** Buổi Kiểm tra: cấu hình do vận hành đặt, giáo viên chỉ xem; null nếu chưa đặt. */
  exam: {
    scope_text: string | null;
    max_score: number;
    entry_mode: 'TONG' | 'NHOM';
    max_memory: number;
    max_understand: number;
    max_apply: number;
  } | null;
  class_code: string;
  subject_name: string | null;
  session_no: number | null;
  session_date: string;
  start_time: string;
  end_time: string;
  lines: string[];
  homework_text: string | null;
  /** Số phiên bản nội dung (Q-243): gửi lại khi lưu để máy chủ từ chối nếu đã có người khác sửa; 0 = chưa có nội dung. */
  content_version: number;
  /** Số ô nhận xét đã chấm; lớn hơn 0 thì màn báo "sửa nội dung sau khi đã chấm" (điểm không đổi). */
  review_scored: number;
  has_content: boolean;
  content_lines: number;
  /** GV-04: số em có mặt cần chấm, số em đã chấm đủ, tên tối đa 10 em còn thiếu. */
  grading_present: number;
  grading_done: number;
  grading_missing: string[];
  /** GV-04: bước chấm BTVN buổi trước. DAU_LOP và KHONG_GIAO: bỏ qua; CAN_CHAM: buổi trước có giao BTVN. */
  prev_homework_state: 'DAU_LOP' | 'KHONG_GIAO' | 'CAN_CHAM';
  /** GV-08: số em có mặt cần có trạng thái BTVN, số em đã có (hoặc vắng buổi giao bài), tên tối đa 10 em còn thiếu. */
  homework_present: number;
  homework_done: number;
  homework_missing: string[];
  attendance_total: number;
  attendance_marked: number;
  deadline_at: string;
  pending_reason: string | null;
  /** Dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done (R-GV-05); null khi chưa Done hoặc buổi Done trước khi có dấu. */
  completion?: { late: boolean; late_hours: number; stamped_at: string } | null;
};

/** Mã form điểm của buổi Kiểm tra (app.class_session.review_form). */
export const EXAM_FORM = 'DIEM';
export const NO_LINES_MESSAGE = 'Cần ít nhất một dòng nội dung.';

/** Bỏ dòng trống, cắt khoảng trắng đầu cuối (khớp app.save_session_content). */
export function cleanLines(lines: string[]): string[] {
  return lines.map((line) => line.trim()).filter((line) => line !== '');
}

/** Ô nhập luôn có ít nhất một dòng để giáo viên gõ vào. */
export function initialLines(saved: string[]): string[] {
  return saved.length > 0 ? [...saved] : [''];
}

export function isDirty(
  saved: { lines: string[]; homework: string | null },
  draft: { lines: string[]; homework: string },
): boolean {
  const savedLines = cleanLines(saved.lines);
  const draftLines = cleanLines(draft.lines);
  const sameLines =
    savedLines.length === draftLines.length &&
    savedLines.every((line, i) => line === draftLines[i]);
  return !sameLines || (saved.homework ?? '').trim() !== draft.homework.trim();
}

/** Lỗi chặn nút Lưu; null là lưu được. */
/** Buổi Kiểm tra không đòi dòng nội dung (Q-252). */
export function saveBlocker(lines: string[], reviewForm = 'TIEU_CHI'): string | null {
  if (reviewForm === EXAM_FORM) return null;
  return cleanLines(lines).length === 0 ? NO_LINES_MESSAGE : null;
}

/** Buổi đã Done, huỷ hoặc bị thay thì giáo viên chỉ xem (R-GV-08). */
export function isContentEditable(statusCode: string): boolean {
  return statusCode === 'NHAP' || statusCode === 'DA_CHOT';
}

export const CONFLICT_CODE = 'HMT_XUNG_DOT';

/**
 * Hộp «hai người cùng sửa» (khung GV06_xung_dot): các ô bản của bạn khác bản vừa lấy từ máy chủ.
 * Chỉ so sau khi làm sạch dòng trống. Rỗng nghĩa là hai bên giống nhau (không còn gì để chọn).
 */
export function conflictCells(
  mine: { lines: string[]; homework: string },
  theirs: { lines: string[]; homework: string | null },
): { key: 'lines' | 'homework'; label: string; mine: string; theirs: string }[] {
  const out: { key: 'lines' | 'homework'; label: string; mine: string; theirs: string }[] = [];
  const myLines = cleanLines(mine.lines);
  const theirLines = cleanLines(theirs.lines);
  if (myLines.length !== theirLines.length || myLines.some((l, i) => l !== theirLines[i])) {
    out.push({
      key: 'lines',
      label: 'Nội dung buổi',
      mine: myLines.join('; '),
      theirs: theirLines.join('; '),
    });
  }
  const myHomework = mine.homework.trim();
  const theirHomework = (theirs.homework ?? '').trim();
  if (myHomework !== theirHomework) {
    out.push({
      key: 'homework',
      label: 'Bài tập về nhà',
      mine: myHomework,
      theirs: theirHomework,
    });
  }
  return out;
}
