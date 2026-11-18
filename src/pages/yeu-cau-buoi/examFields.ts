// A25: ô «Buổi kiểm tra» ở form yêu cầu buổi (BUOI-07, 08, 09). Luật R-V2-20 (điểm tối đa, điểm tổng hoặc ba nhóm; tổng ba nhóm = điểm tối đa), R-V2-18 (kiểm tra trừ giờ như buổi Chính),
// R-BUOI-03 (kiểm tra bù từ học bù, bổ trợ KHÔNG trừ giờ). Máy chủ kiểm lại (app.set_request_exam); đây là kiểm nhập cơ bản để báo lỗi tại ô.
export type ExamInput = {
  scope: string;
  maxScore: string;
  mode: 'TONG' | 'NHOM';
  memory: string;
  understand: string;
  apply: string;
};
export const EMPTY_EXAM: ExamInput = {
  scope: '',
  maxScore: '',
  mode: 'TONG',
  memory: '',
  understand: '',
  apply: '',
};
export type ExamError = Partial<Record<'maxScore' | 'groups', string>>;

const num = (t: string): number => Number(t.trim().replace(',', '.'));

/** Điểm tối đa trống là hợp lệ (máy chủ lấy tham số mặc định); nhập thì phải lớn hơn 0; theo ba nhóm thì tổng ba nhóm bằng điểm tối đa (cần nhập điểm tối đa). */
export function validateExam(e: ExamInput): ExamError {
  const out: ExamError = {};
  const hasMax = e.maxScore.trim() !== '';
  if (hasMax && !(num(e.maxScore) > 0)) out.maxScore = 'Điểm tối đa phải lớn hơn 0.';
  if (e.mode === 'NHOM') {
    if (!hasMax) out.maxScore = 'Nhập điểm tối đa để chia ba nhóm.';
    else if (!out.maxScore) {
      const sum = [e.memory, e.understand, e.apply].reduce(
        (s, t) => s + (t.trim() === '' ? 0 : num(t)),
        0,
      );
      if (
        [e.memory, e.understand, e.apply].some((t) => t.trim() !== '' && Number.isNaN(num(t))) ||
        Math.abs(sum - num(e.maxScore)) > 1e-9
      ) {
        out.groups = 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.';
      }
    }
  }
  return out;
}

/** Tham số gửi app.set_request_exam; điểm tối đa trống gửi null (máy chủ lấy mặc định). */
export function examRpcArgs(e: ExamInput): {
  p_scope: string | null;
  p_max_score: number | null;
  p_mode: string;
  p_max_memory: number;
  p_max_understand: number;
  p_max_apply: number;
} {
  const n = (t: string) => (t.trim() === '' ? 0 : num(t));
  return {
    p_scope: e.scope.trim() === '' ? null : e.scope.trim(),
    p_max_score: e.maxScore.trim() === '' ? null : num(e.maxScore),
    p_mode: e.mode,
    p_max_memory: e.mode === 'NHOM' ? n(e.memory) : 0,
    p_max_understand: e.mode === 'NHOM' ? n(e.understand) : 0,
    p_max_apply: e.mode === 'NHOM' ? n(e.apply) : 0,
  };
}

/** Câu giải thích cách tính giờ theo loại yêu cầu (R-V2-18, R-BUOI-03). */
export function examChargeNote(kind: 'CUNG_CO' | 'BO_TRO' | 'HOC_BU'): string {
  return kind === 'CUNG_CO'
    ? 'Buổi kiểm tra từ yêu cầu củng cố trừ giờ như buổi Chính (R-V2-18).'
    : 'Kiểm tra bù (thi bù) không trừ giờ của học sinh, đi theo luật học bù, bổ trợ (R-BUOI-03, R-V2-20).';
}
