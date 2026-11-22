// GV-18 Chấm bài nộp online: kiểu dữ liệu các hàm app.lms_grading_* và logic thuần (nhãn, điểm, em tiếp theo, lỗi nhập).
// Luật: R-GV-11 (thang 1–5, năm trạng thái; chỉ Đã chấm và Làm chưa xong có điểm), R-LMS-02 (nhãn «Nộp muộn»; em chưa nộp), R-LMS-03 (chấm xong khoá,
// mở lại), Q5 (chọn Không làm, Nộp sau, Không áp dụng thì bỏ điểm), Q6, Q8 («Bài tiếp theo» chỉ em chưa chấm), Q13 (thang 1–5, KHÔNG theo GV08b nháp).
import { HOMEWORK_STATUSES, needsScore, type HomeworkStatus } from './homework';

export type GradingListRow = {
  student_id: string;
  student_code: string;
  full_name: string;
  submit_state: 'CHUA_NOP' | 'DA_NOP';
  is_late: boolean;
  attempt_count: number;
  submitted_at: string | null;
  grade_status_code: HomeworkStatus | null;
  score: number | null;
  graded: boolean;
};

export type GradingList = {
  assignment: {
    id: string;
    title: string;
    due_at: string;
    status: 'DANG_GIAO' | 'DA_GO';
    version: number;
    targets: number;
    submitted: number;
    graded: number;
  };
  rows: GradingListRow[];
};

export type GradingSheet = {
  assignment: {
    id: string;
    title: string;
    description: string;
    due_at: string;
    status: 'DANG_GIAO' | 'DA_GO';
  };
  student: { id: string; code: string; full_name: string; absent_at_session: boolean };
  submission: {
    attempt_count: number;
    submitted_at: string | null;
    is_late: boolean;
    graded_at: string | null;
    pages: { page_no: number; storage_key: string; mime_type: string; byte_size: number }[];
  } | null;
  grade: {
    status_code: HomeworkStatus;
    score: number | null;
    note: string | null;
    version: number;
  } | null;
  allowed_statuses: HomeworkStatus[];
  default_status: HomeworkStatus | null;
};

export type GradingFilter = 'TAT_CA' | 'CHUA_CHAM' | 'DA_CHAM';

/** Giải thích từng trạng thái ở bước 3 (chữ theo khung GV18_b3). */
export const STATUS_HELP: Record<HomeworkStatus, string> = {
  DA_CHAM: 'Điểm 1–5.',
  LAM_CHUA_XONG: 'Làm chưa xong vẫn có điểm 1–5 (R-GV-11).',
  KHONG_LAM: 'Không làm không phải điểm 0; tính vào tỉ lệ làm bài (R-GV-12).',
  NOP_SAU: 'Chờ cập nhật ở buổi sau; sửa điểm được mà không mở lại buổi cũ (R-GV-11).',
  KHONG_AP_DUNG: 'Vắng buổi giao bài hoặc giáo viên miễn; không tính vào tỉ lệ (R-GV-12).',
};

export function statusLabel(code: HomeworkStatus): string {
  return HOMEWORK_STATUSES.find((s) => s.code === code)?.label ?? code;
}

/** «Đã chấm · 4», «Không làm»; chưa chấm thì «Chưa chấm». */
export function gradeText(
  row: Pick<GradingListRow, 'grade_status_code' | 'score' | 'graded'>,
): string {
  if (!row.grade_status_code) return 'Chưa chấm';
  const label = statusLabel(row.grade_status_code);
  return row.score === null ? label : `${label} · ${row.score}`;
}

/** «Nộp lại 1 lần» (lần nộp thứ hai trở đi); lần nộp đầu không có nhãn. */
export function resubmitText(attemptCount: number): string | null {
  return attemptCount > 1 ? `Nộp lại ${attemptCount - 1} lần` : null;
}

/** Em chưa chấm kế tiếp sau em hiện tại, theo thứ tự danh sách; hết thì quay vòng em chưa chấm đầu danh sách; không còn em nào thì null (Q8). */
export function nextUngraded(rows: GradingListRow[], currentId: string): GradingListRow | null {
  const ungraded = (r: GradingListRow) => !r.graded && r.student_id !== currentId;
  const idx = rows.findIndex((r) => r.student_id === currentId);
  const after = rows.slice(idx + 1).find(ungraded);
  return after ?? rows.find(ungraded) ?? null;
}

/** Điểm chỉ gửi khi trạng thái có điểm (Q5: trạng thái khác thì bỏ điểm đã chọn). */
export function scoreToSend(status: HomeworkStatus, score: number | null): number | null {
  return needsScore(status) ? score : null;
}

/** Báo sớm lỗi ở bước lưu (máy chủ vẫn kiểm lại). */
export function gradeError(status: HomeworkStatus | null, score: number | null): string | null {
  if (status === null) return 'Chọn một trạng thái BTVN.';
  if (needsScore(status) && score === null) return 'Chọn điểm từ 1 đến 5 cho trạng thái này.';
  return null;
}

/** Điểm đã chọn có bị bỏ không (hiện dòng nhắc ở bước 3, Q5). */
export function scoreWillBeDropped(status: HomeworkStatus | null, score: number | null): boolean {
  return status !== null && score !== null && !needsScore(status);
}
