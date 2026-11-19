// Logic thuần của màn GV-07K (Chấm kiểm tra): nhập điểm tổng hoặc 3 nhóm, kiểm giới hạn, bản nháp, lô lưu.
// Luật: R-V2-20 (điểm tổng hoặc Ghi nhớ, Hiểu, Vận dụng; tổng tự cộng; ô trống là chưa chấm, khác điểm 0), R-GV-04 (em vắng không nhập điểm, không tự nhận 0).
export const PRESENT = ['CO_MAT', 'DI_MUON'];

export type ExamConfig = {
  scope_text: string | null;
  max_score: number;
  entry_mode: 'TONG' | 'NHOM';
  max_memory: number;
  max_understand: number;
  max_apply: number;
};

export type ExamScore = {
  total: number | null;
  memory: number | null;
  understand: number | null;
  apply: number | null;
  graded: boolean;
};

export type ExamStudent = {
  student_id: string;
  full_name: string;
  attendance_code: string | null;
  attendance_name: string | null;
  score: ExamScore | null;
  comment: string | null;
  improvement: string | null;
};

export type ExamSheet = {
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
  exam: ExamConfig | null;
  students: ExamStudent[];
};

export type GroupKey = 'memory' | 'understand' | 'apply';
export const GROUPS: { key: GroupKey; label: string; maxKey: keyof ExamConfig }[] = [
  { key: 'memory', label: 'Ghi nhớ', maxKey: 'max_memory' },
  { key: 'understand', label: 'Hiểu', maxKey: 'max_understand' },
  { key: 'apply', label: 'Vận dụng', maxKey: 'max_apply' },
];

/** Bản nháp một em: điểm là chuỗi để ô trống ≠ 0. */
export type ExamDraft = {
  total: string;
  memory: string;
  understand: string;
  apply: string;
  comment: string;
  improvement: string;
};
export type ExamDrafts = Record<string, ExamDraft>;

export const isPresent = (s: ExamStudent): boolean =>
  s.attendance_code !== null && PRESENT.includes(s.attendance_code);

const text = (n: number | null | undefined): string =>
  n === null || n === undefined ? '' : String(n);

export function initialDraft(s: ExamStudent): ExamDraft {
  return {
    total: text(s.score?.total),
    memory: text(s.score?.memory),
    understand: text(s.score?.understand),
    apply: text(s.score?.apply),
    comment: s.comment ?? '',
    improvement: s.improvement ?? '',
  };
}

/** Đọc số người dùng gõ (chấp nhận dấu phẩy thập phân). null nếu trống hoặc không phải số. */
export function parseScore(value: string): number | null {
  const t = value.trim().replace(',', '.');
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export type Entry = { total: number | null; error: string | null; empty: boolean };

/** Tính điểm tổng và lỗi của một bản nháp theo cấu hình. Nhóm không có đề (tối đa 0) bỏ qua. */
export function entryOf(draft: ExamDraft, exam: ExamConfig): Entry {
  if (exam.entry_mode === 'TONG') {
    if (draft.total.trim() === '') return { total: null, error: null, empty: true };
    const n = parseScore(draft.total);
    if (n === null || n < 0 || n > exam.max_score) {
      return { total: null, error: `Điểm phải từ 0 đến ${exam.max_score}.`, empty: false };
    }
    return { total: n, error: null, empty: false };
  }
  const active = GROUPS.filter((g) => (exam[g.maxKey] as number) > 0);
  if (active.every((g) => draft[g.key].trim() === ''))
    return { total: null, error: null, empty: true };
  let sum = 0;
  for (const g of active) {
    const max = exam[g.maxKey] as number;
    const n = parseScore(draft[g.key]);
    if (n === null)
      return { total: null, error: `Nhập điểm ${g.label} (0 đến ${max}).`, empty: false };
    // Canvas GV-07K (3nhom): «Vượt điểm tối đa của nhóm (4).»
    if (n > max) {
      return { total: null, error: `Vượt điểm tối đa của nhóm (${max}).`, empty: false };
    }
    if (n < 0) {
      return { total: null, error: `Điểm ${g.label} phải từ 0 đến ${max}.`, empty: false };
    }
    sum += n;
  }
  return { total: sum, error: null, empty: false };
}

export function isRowDirty(s: ExamStudent, d: ExamDraft): boolean {
  const base = initialDraft(s);
  return (
    (['total', 'memory', 'understand', 'apply'] as const).some(
      (k) => parseScore(base[k]) !== parseScore(d[k]),
    ) ||
    base.comment.trim() !== d.comment.trim() ||
    base.improvement.trim() !== d.improvement.trim()
  );
}

export type ExamSave = {
  scores: {
    student_id: string;
    total?: number;
    memory?: number;
    understand?: number;
    apply?: number;
  }[];
  notes: { student_id: string; comment: string; improvement: string }[];
};

/** Lô lưu: chỉ em có mặt đã sửa. null nếu có dòng nhập sai. Em đã chấm mà xoá hết điểm thì báo lỗi (không có thao tác bỏ chấm). */
export function buildExamSave(sheet: ExamSheet, drafts: ExamDrafts): ExamSave | null {
  const exam = sheet.exam;
  if (!exam) return { scores: [], notes: [] };
  const save: ExamSave = { scores: [], notes: [] };
  for (const s of sheet.students) {
    const d = drafts[s.student_id];
    if (!d || !isPresent(s) || !isRowDirty(s, d)) continue;
    const base = initialDraft(s);
    const e = entryOf(d, exam);
    if (e.error) return null;
    if (e.empty && s.score?.graded) return null;
    const scoreChanged = (['total', 'memory', 'understand', 'apply'] as const).some(
      (k) => parseScore(base[k]) !== parseScore(d[k]),
    );
    if (scoreChanged && !e.empty) {
      save.scores.push(
        exam.entry_mode === 'TONG'
          ? { student_id: s.student_id, total: e.total as number }
          : {
              student_id: s.student_id,
              memory: parseScore(d.memory) ?? 0,
              understand: parseScore(d.understand) ?? 0,
              apply: parseScore(d.apply) ?? 0,
            },
      );
    }
    if (
      base.comment.trim() !== d.comment.trim() ||
      base.improvement.trim() !== d.improvement.trim()
    ) {
      save.notes.push({ student_id: s.student_id, comment: d.comment, improvement: d.improvement });
    }
  }
  return save;
}

export function anyDirty(sheet: ExamSheet, drafts: ExamDrafts): boolean {
  return sheet.students.some((s) => {
    const d = drafts[s.student_id];
    return d !== undefined && isPresent(s) && isRowDirty(s, d);
  });
}

/** Tiến độ: số em có mặt đã chấm (theo bản đã lưu) / số em có mặt. */
export function gradedProgress(sheet: ExamSheet): { done: number; total: number } {
  const present = sheet.students.filter(isPresent);
  return { done: present.filter((s) => s.score?.graded).length, total: present.length };
}

export function statusOf(s: ExamStudent, draft: ExamDraft, exam: ExamConfig): string {
  if (s.attendance_code === null) return 'Chưa điểm danh';
  if (!isPresent(s)) return 'Vắng';
  const e = entryOf(draft, exam);
  if (!e.empty && !e.error)
    return s.score?.graded && !isRowDirty(s, draft) ? 'Đã chấm' : 'Chưa lưu';
  return e.error ? 'Điểm chưa hợp lệ' : 'Chưa chấm';
}

/** Buổi Kiểm tra Đã chốt, đã đặt cấu hình thì chấm được; Done chỉ xem. */
export function isExamEditable(statusCode: string, exam: ExamConfig | null): boolean {
  return statusCode === 'DA_CHOT' && exam !== null;
}
