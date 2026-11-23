// Logic thuần của màn GV-07 (Chấm nhận xét từng em, bố cục «Theo em»): ô điểm 4 trạng thái, tiến độ, lô lưu.
// Luật: R-V2-19 (9 tiêu chí, thang 1–5, 4 trạng thái ô), R-GV-02 (ô trống không phải điểm 0), R-GV-03 (trung bình do máy chủ tính), R-GV-04 (em vắng không chấm).

export type CellState = 'DA_DANH_GIA' | 'KHONG_AP_DUNG' | 'CHUA_DU_CAN_CU' | 'CHUA_DANH_GIA';
export type Cell = { state: CellState; score: number | null };

export const GROUP_LABEL: Record<string, string> = {
  THAI_DO: 'Thái độ',
  TIEP_THU: 'Tiếp thu kiến thức',
  VAN_DUNG: 'Năng lực vận dụng',
};
export const GROUP_ORDER = ['THAI_DO', 'TIEP_THU', 'VAN_DUNG'];
export const LEVELS = [1, 2, 3, 4, 5] as const; // allow-number: thang điểm nhận xét 1 đến 5 cố định (R-V2-19)
export const PRESENT_CODES = ['CO_MAT', 'DI_MUON'];

export type ReviewCriterion = {
  criterion_id: string;
  name: string;
  group_code: string;
  enabled: boolean;
  hint: string | null;
  levels: string[] | null;
};

export type ReviewStudent = {
  student_id: string;
  full_name: string;
  attendance_code: string | null;
  attendance_name: string | null;
  scores: Record<string, Cell>;
  comment: string | null;
  improvement: string | null;
  average: number | null;
};

export type ReviewSheet = {
  session: {
    session_id: string;
    status_code: string;
    type_code: string;
    review_form: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    class_code: string;
    subject_name: string | null;
  };
  criteria: ReviewCriterion[];
  students: ReviewStudent[];
};

export type NoteDraft = { comment: string; improvement: string };
export type ReviewDraft = {
  cells: Record<string, Cell>; // khoá `${studentId}|${criterionId}`
  notes: Record<string, NoteDraft>;
  enabled: Record<string, boolean>; // công tắc tiêu chí đã đổi
};
export const EMPTY_DRAFT: ReviewDraft = { cells: {}, notes: {}, enabled: {} };

const key = (studentId: string, criterionId: string) => `${studentId}|${criterionId}`;

export function isPresent(student: ReviewStudent): boolean {
  return student.attendance_code !== null && PRESENT_CODES.includes(student.attendance_code);
}

export function savedCell(student: ReviewStudent, criterionId: string): Cell {
  return student.scores[criterionId] ?? { state: 'CHUA_DANH_GIA', score: null };
}

export function cellOf(draft: ReviewDraft, student: ReviewStudent, criterionId: string): Cell {
  return draft.cells[key(student.student_id, criterionId)] ?? savedCell(student, criterionId);
}

export function noteOf(draft: ReviewDraft, student: ReviewStudent): NoteDraft {
  return (
    draft.notes[student.student_id] ?? {
      comment: student.comment ?? '',
      improvement: student.improvement ?? '',
    }
  );
}

export function isEnabled(draft: ReviewDraft, criterion: ReviewCriterion): boolean {
  return draft.enabled[criterion.criterion_id] ?? criterion.enabled;
}

export function setCell(
  draft: ReviewDraft,
  studentId: string,
  criterionId: string,
  cell: Cell,
): ReviewDraft {
  return { ...draft, cells: { ...draft.cells, [key(studentId, criterionId)]: cell } };
}

/** Bấm lại đúng mức đang chọn thì bỏ chọn về Chưa đánh giá (không phải điểm 0). */
// Bấm lại cùng mức KHÔNG bỏ chọn (chạm nhầm trên điện thoại làm mất điểm); muốn bỏ thì bấm nút «Xoá điểm» (clearCell).
export function pickLevel(_current: Cell, level: number): Cell {
  return { state: 'DA_DANH_GIA', score: level };
}

/** Xoá điểm: về «Chưa đánh giá» (khác điểm 0). */
export function clearCell(): Cell {
  return { state: 'CHUA_DANH_GIA', score: null };
}

export function pickInsufficient(current: Cell): Cell {
  return current.state === 'CHUA_DU_CAN_CU'
    ? { state: 'CHUA_DANH_GIA', score: null }
    : { state: 'CHUA_DU_CAN_CU', score: null };
}

/** Số ô đã xử lý (khác Chưa đánh giá) trên các tiêu chí đang bật, và tổng số ô cần xử lý. */
export function progressOfStudent(
  draft: ReviewDraft,
  student: ReviewStudent,
  criteria: ReviewCriterion[],
): { done: number; total: number } {
  const active = criteria.filter((c) => isEnabled(draft, c));
  const done = active.filter(
    (c) => cellOf(draft, student, c.criterion_id).state !== 'CHUA_DANH_GIA',
  ).length;
  return { done, total: active.length };
}

/** Đếm ô theo 4 trạng thái của một em; tiêu chí tắt cả buổi tính vào «Không áp dụng». */
export function countCellStates(
  draft: ReviewDraft,
  student: ReviewStudent,
  criteria: ReviewCriterion[],
): Record<CellState, number> {
  const counts: Record<CellState, number> = {
    DA_DANH_GIA: 0,
    CHUA_DANH_GIA: 0,
    CHUA_DU_CAN_CU: 0,
    KHONG_AP_DUNG: 0,
  };
  for (const c of criteria) {
    if (!isEnabled(draft, c)) counts.KHONG_AP_DUNG += 1;
    else counts[cellOf(draft, student, c.criterion_id).state] += 1;
  }
  return counts;
}

/** Em có mặt chấm đủ mọi tiêu chí đang bật. */
export function isStudentComplete(
  draft: ReviewDraft,
  student: ReviewStudent,
  criteria: ReviewCriterion[],
): boolean {
  const p = progressOfStudent(draft, student, criteria);
  return p.total > 0 && p.done === p.total;
}

/** Tiến độ cả lớp: số em có mặt chấm đủ / số em có mặt. */
export function classProgress(
  draft: ReviewDraft,
  students: ReviewStudent[],
  criteria: ReviewCriterion[],
): { done: number; total: number } {
  const present = students.filter(isPresent);
  return {
    done: present.filter((s) => isStudentComplete(draft, s, criteria)).length,
    total: present.length,
  };
}

/** Điểm trung bình tạm tính trên ô Đã đánh giá để xem trước (máy chủ tính chính thức khi lưu, R-GV-03). */
export function previewAverage(
  draft: ReviewDraft,
  student: ReviewStudent,
  criteria: ReviewCriterion[],
): number | null {
  const scores = criteria
    .filter((c) => isEnabled(draft, c))
    .map((c) => cellOf(draft, student, c.criterion_id))
    .filter((cell) => cell.state === 'DA_DANH_GIA' && cell.score !== null)
    .map((cell) => cell.score as number);
  return scores.length === 0 ? null : scores.reduce((a, b) => a + b, 0) / scores.length;
}

export type SaveReview = {
  criteria: { criterion_id: string; enabled: boolean }[];
  scores: { student_id: string; criterion_id: string; state: CellState; score: number | null }[];
  notes: { student_id: string; comment: string; improvement: string }[];
};

/** Chỉ gửi phần đã đổi so với bản đã lưu. Ô của em vắng không gửi (R-GV-04). */
export function buildSave(sheet: ReviewSheet, draft: ReviewDraft): SaveReview {
  const criteria = sheet.criteria
    .filter(
      (c) =>
        draft.enabled[c.criterion_id] !== undefined && draft.enabled[c.criterion_id] !== c.enabled,
    )
    .map((c) => ({
      criterion_id: c.criterion_id,
      enabled: draft.enabled[c.criterion_id] as boolean,
    }));
  const scores: SaveReview['scores'] = [];
  const notes: SaveReview['notes'] = [];
  for (const student of sheet.students) {
    if (!isPresent(student)) continue;
    for (const c of sheet.criteria) {
      const mine = draft.cells[key(student.student_id, c.criterion_id)];
      if (!mine || !isEnabled(draft, c)) continue;
      const saved = savedCell(student, c.criterion_id);
      if (mine.state !== saved.state || mine.score !== saved.score) {
        scores.push({
          student_id: student.student_id,
          criterion_id: c.criterion_id,
          state: mine.state,
          score: mine.state === 'DA_DANH_GIA' ? mine.score : null,
        });
      }
    }
    const note = draft.notes[student.student_id];
    if (
      note &&
      (note.comment.trim() !== (student.comment ?? '').trim() ||
        note.improvement.trim() !== (student.improvement ?? '').trim())
    ) {
      notes.push({
        student_id: student.student_id,
        comment: note.comment,
        improvement: note.improvement,
      });
    }
  }
  return { criteria, scores, notes };
}

export function isReviewDirty(sheet: ReviewSheet, draft: ReviewDraft): boolean {
  const s = buildSave(sheet, draft);
  return s.criteria.length + s.scores.length + s.notes.length > 0;
}

/** Buổi chỉ chấm được khi Đã chốt; buổi Kiểm tra chấm bằng điểm (chưa có màn trong đợt này). */
export function isReviewEditable(statusCode: string, reviewForm: string): boolean {
  return statusCode === 'DA_CHOT' && reviewForm !== 'DIEM';
}
