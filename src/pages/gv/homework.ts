// Logic thuần của màn GV-08 (Chấm BTVN buổi trước): 5 trạng thái, điểm 1–5, bản nháp từng em, lô lưu, bài Nộp sau.
// Luật: R-GV-10 (BTVN buổi N chấm ở buổi N+1), R-GV-11 (5 trạng thái; điểm chỉ cho Đã chấm và Làm chưa xong; vắng buổi giao bài = Không áp dụng đặt sẵn),
// R-GV-12 (Không làm không phải điểm 0), R-V2-35 (buổi trước không giao BTVN thì bỏ qua).

export type HomeworkStatus =
  'DA_CHAM' | 'LAM_CHUA_XONG' | 'KHONG_LAM' | 'NOP_SAU' | 'KHONG_AP_DUNG';

/** Thứ tự và phím tắt 1–5 theo khung GV-08. Tên hiển thị lấy theo bảng này vì danh mục chỉ đổi tên được, không thêm bớt (R-GV-11). */
export const HOMEWORK_STATUSES: { code: HomeworkStatus; label: string }[] = [
  { code: 'DA_CHAM', label: 'Đã chấm' },
  { code: 'LAM_CHUA_XONG', label: 'Làm chưa xong' },
  { code: 'KHONG_LAM', label: 'Không làm' },
  { code: 'NOP_SAU', label: 'Nộp sau' },
  { code: 'KHONG_AP_DUNG', label: 'Không áp dụng' },
];

/** Bài Nộp sau chỉ cập nhật sang ba trạng thái này (khung GV-08, mục Bài Nộp sau chờ cập nhật). */
export const LATE_STATUSES = HOMEWORK_STATUSES.filter((s) =>
  ['DA_CHAM', 'LAM_CHUA_XONG', 'KHONG_LAM'].includes(s.code),
);

export const SCORES = [1, 2, 3, 4, 5] as const; // allow-number: thang điểm BTVN 1 đến 5 cố định (R-GV-11)

export const CONFLICT_CODE = 'HMT_XUNG_DOT';

export type HomeworkResult = {
  status_code: HomeworkStatus;
  score: number | null;
  note: string | null;
  version: number;
};

export type GradingRow = {
  student_id: string;
  full_name: string;
  attendance_code: string;
  /** Em vắng buổi giao bài: đặt sẵn Không áp dụng (R-GV-11). */
  absent_at_assignment: boolean;
  result: HomeworkResult | null;
};

export type LateItem = {
  assigned_session_id: string;
  session_no: number | null;
  session_date: string;
  homework_text: string | null;
  student_id: string;
  full_name: string;
  version: number;
  /** true: suy từ điểm danh (em có mặt buổi giao bài, vắng buổi kế tiếp, chưa có dòng nào). */
  inferred: boolean;
};

export type GradingSheet = {
  state: 'DAU_LOP' | 'KHONG_GIAO' | 'CAN_CHAM';
  session: {
    session_id: string;
    status_code: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    class_code: string;
    subject_name: string | null;
  };
  prev: {
    session_id: string;
    session_no: number | null;
    session_date: string;
    homework_text: string | null;
  } | null;
  students: GradingRow[];
  absent_now: {
    student_id: string;
    full_name: string;
    attendance_code: string;
    attendance_name: string | null;
  }[];
  late: LateItem[];
  present: number;
  done: number;
};

export type Draft = { status: HomeworkStatus | null; score: number | null; note: string };

export function needsScore(status: HomeworkStatus | null): boolean {
  return status === 'DA_CHAM' || status === 'LAM_CHUA_XONG';
}

/** Bản nháp ban đầu của một em: kết quả đã lưu, hoặc Không áp dụng đặt sẵn nếu vắng buổi giao bài, hoặc chưa chọn. */
export function initialDraft(row: GradingRow): Draft {
  if (row.result) {
    return { status: row.result.status_code, score: row.result.score, note: row.result.note ?? '' };
  }
  return { status: row.absent_at_assignment ? 'KHONG_AP_DUNG' : null, score: null, note: '' };
}

/** Đổi trạng thái: bỏ điểm nếu trạng thái mới không có điểm (Không làm không phải điểm 0, R-GV-12). */
export function withStatus(draft: Draft, status: HomeworkStatus): Draft {
  return { ...draft, status, score: needsScore(status) ? draft.score : null };
}

export function isRowDirty(row: GradingRow, draft: Draft): boolean {
  const base = initialDraft(row);
  return (
    base.status !== draft.status ||
    base.score !== draft.score ||
    base.note.trim() !== draft.note.trim()
  );
}

/** Lỗi của một dòng đã sửa; null là hợp lệ. */
export function draftError(draft: Draft): string | null {
  if (draft.status === null) return 'Chọn một trạng thái.';
  if (needsScore(draft.status) && draft.score === null) return 'Chọn điểm 1–5.';
  return null;
}

/** Số em đã có trạng thái (kể cả Không áp dụng đặt sẵn) theo bản nháp hiện tại. */
export function countWithStatus(rows: GradingRow[], drafts: Record<string, Draft>): number {
  return rows.filter((row) => (drafts[row.student_id] ?? initialDraft(row)).status !== null).length;
}

export type SaveItem = {
  student_id: string;
  status_code: HomeworkStatus;
  score: number | null;
  note: string;
  expected_version: number;
};

/** Lô lưu: chỉ các em đã sửa. null nếu có dòng sửa dở (chưa chọn trạng thái hoặc điểm). */
export function buildSaveItems(
  rows: GradingRow[],
  drafts: Record<string, Draft>,
): SaveItem[] | null {
  const items: SaveItem[] = [];
  for (const row of rows) {
    const draft = drafts[row.student_id];
    if (!draft || !isRowDirty(row, draft)) continue;
    if (draftError(draft) !== null || draft.status === null) return null;
    items.push({
      student_id: row.student_id,
      status_code: draft.status,
      score: needsScore(draft.status) ? draft.score : null,
      note: draft.note.trim(),
      expected_version: row.result?.version ?? 0,
    });
  }
  return items;
}

export function anyDirty(rows: GradingRow[], drafts: Record<string, Draft>): boolean {
  return rows.some((row) => {
    const draft = drafts[row.student_id];
    return draft !== undefined && isRowDirty(row, draft);
  });
}

/** Buổi đã Done hoặc đã đóng thì chỉ xem; bài Nộp sau vẫn cập nhật được (R-GV-11). */
export function isGradingEditable(statusCode: string): boolean {
  return statusCode === 'DA_CHOT';
}
