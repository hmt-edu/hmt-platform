// GV-15 Chấm kiểm tra đầu vào (cổng giáo viên): logic thuần. Máy chủ quyết quyền và trạng thái (app.teacher_test_sheet, enter_test_result,
// complete_student_test; R-CRM-10, R-CRM-11); ở đây chỉ kiểm nhập liệu để báo lỗi tại chỗ.
export type TestSheet = {
  test: {
    id: string;
    code: string;
    status_code: string; // TEACHER_REVIEW (chờ chấm) hoặc COMPLETED (xong, chỉ xem)
    status_name: string | null;
    student_name: string | null;
    subject_name: string | null;
    grade_name: string | null;
    mode_name: string | null;
    level_name: string | null;
    exam_name: string | null;
    scheduled_at: string;
    room_name: string | null;
    score: number | null;
    result_note: string | null;
    suggested_level_code: string | null;
    suggested_framework_code: string | null;
  };
  levels: { code: string; name: string }[];
  frameworks: { code: string; name: string }[];
};

export type PendingTest = {
  test_id: string;
  code: string;
  student_name: string | null;
  subject_name: string | null;
  exam_name: string | null;
  scheduled_at: string;
};

export type PendingTestsResult = { total: number; rows: PendingTest[] };

export type TestDraft = { score: string; note: string; level: string; framework: string };

export function initialTestDraft(t: TestSheet['test']): TestDraft {
  return {
    score: t.score === null ? '' : String(t.score),
    note: t.result_note ?? '',
    level: t.suggested_level_code ?? '',
    framework: t.suggested_framework_code ?? '',
  };
}

export function isTestDirty(t: TestSheet['test'], d: TestDraft): boolean {
  const a = initialTestDraft(t);
  return (
    a.score !== d.score || a.note !== d.note || a.level !== d.level || a.framework !== d.framework
  );
}

export const isTestEditable = (t: TestSheet['test']): boolean => t.status_code === 'TEACHER_REVIEW';

const MAX_SCORE = 10; // allow-number: thang điểm 0–10 của R-CRM-10 (máy chủ kiểm lại; ở đây chỉ báo lỗi sớm)

/** Điểm 0–10, tối đa một chữ số thập phân (R-CRM-10); ô trống là chưa nhập. Chấp nhận dấu phẩy. */
export function parseTestScore(raw: string): { value: number | null; error: string | null } {
  const text = raw.trim().replace(',', '.');
  if (text === '') return { value: null, error: null };
  if (!/^\d+(\.\d)?$/.test(text)) {
    return { value: null, error: 'Nhập điểm từ 0 đến 10, một chữ số thập phân.' };
  }
  const value = Number(text);
  if (value > MAX_SCORE)
    return { value: null, error: 'Nhập điểm từ 0 đến 10, một chữ số thập phân.' };
  return { value, error: null };
}

export type TestErrors = { score?: string; level?: string; framework?: string; note?: string };

/** Trả về sale (nộp kết quả) cần đủ điểm, trình độ, phân loại (canvas GV-15); nhận xét cần vì hàm hoàn thành của máy chủ đòi (R-CRM-10). */
export function submitErrors(d: TestDraft): TestErrors {
  const errors: TestErrors = {};
  const s = parseTestScore(d.score);
  if (s.error) errors.score = s.error;
  else if (s.value === null) errors.score = 'Nhập điểm từ 0 đến 10, một chữ số thập phân.';
  if (d.level === '') errors.level = 'Chọn trình độ đề xuất.';
  if (d.framework === '') errors.framework = 'Chọn phân loại đề xuất.';
  if (d.note.trim() === '') errors.note = 'Nhập nhận xét.';
  return errors;
}

/** Lưu nháp chỉ cần điểm (nếu có) hợp lệ. */
export function draftErrors(d: TestDraft): TestErrors {
  const s = parseTestScore(d.score);
  return s.error ? { score: s.error } : {};
}
