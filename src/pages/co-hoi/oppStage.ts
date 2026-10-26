// Luật chuyển giai đoạn cơ hội ở giao diện (TS-09): chọn đúng hộp thoại trước khi gọi change_opportunity_stage.
// Hàm cơ sở dữ liệu kiểm lại mọi luật (R-CRM-02, 03, 12 đến 16); đây chỉ để hiện đúng hộp. Hàm thuần, có kiểm thử.
// Thứ tự kiểm giống hàm DB: R-CRM-03 → R-CRM-12 → R-CRM-14 → R-CRM-16.
import type { OppTest, OppTestState } from './oppTypes';

/** Thứ tự giai đoạn cơ hội (danh mục OPP_STAGE). */
export const OPP_STAGE_ORDER = ['L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8'];
/** Từ giai đoạn này trở lên bắt buộc có tên, năm sinh học sinh (R-CRM-03). */
const STUDENT_REQUIRED_FROM = 'L5';
/** L6 do hệ thống chuyển khi phiếu test Hoàn thành (R-CRM-13). */
export const SYSTEM_STAGE = 'L6';
/** L7, L8: cần phiếu test hợp lệ hoặc lý do bỏ qua test (R-CRM-12, 14). */
const TEST_GATED = ['L7', 'L8'];
/** L8: chọn nhóm con và xác nhận không hoàn tác (R-CRM-16). */
const L8 = 'L8';
/** Nhóm con L5 do hệ thống gắn (R-CRM-15), L6A do hệ thống gắn (R-CRM-34), L8C do hệ thống nâng khi thu đủ (R-CRM-17). */
export const L5 = 'L5';
export const L6A = 'L6A';
export const L8C = 'L8C';

export type StageContext = {
  stage_code: string;
  student_name: string | null;
  student_birth_year: number | null;
  test_state: OppTestState | null;
  tests: OppTest[];
};

export type StagePlan =
  /** R-CRM-03: thiếu tên hoặc năm sinh học sinh; `missing` là nhãn các ô còn trống. */
  | { kind: 'blocked-student'; missing: string[] }
  /** R-CRM-12: còn phiếu dang dở; `tests` là các phiếu đó (nếu danh sách phiếu đọc được). */
  | { kind: 'blocked-tests'; codes: string[]; tests: OppTest[] }
  /** R-CRM-14: không có phiếu Hoàn thành, bắt chọn lý do bỏ qua test; `l8` nếu còn chọn nhóm con L8. */
  | { kind: 'skip-test'; l8: boolean }
  /** R-CRM-16: L8 chọn nhóm con, xác nhận không hoàn tác. */
  | { kind: 'l8' }
  | { kind: 'normal' };

export function stageIndex(code: string): number {
  return OPP_STAGE_ORDER.indexOf(code);
}

export function planStageChange(ctx: StageContext, target: string): StagePlan {
  if (stageIndex(target) >= stageIndex(STUDENT_REQUIRED_FROM)) {
    const missing = [
      ...((ctx.student_name ?? '').trim() === '' ? ['Tên học sinh'] : []),
      ...(ctx.student_birth_year === null ? ['Năm sinh học sinh'] : []),
    ];
    if (missing.length > 0) return { kind: 'blocked-student', missing };
  }
  if (TEST_GATED.includes(target)) {
    const state = ctx.test_state;
    if (state && state.in_progress > 0) {
      const codes = state.in_progress_codes ?? [];
      return {
        kind: 'blocked-tests',
        codes,
        tests: ctx.tests.filter((t) => codes.includes(t.code)),
      };
    }
    // Không có phiếu Hoàn thành (không có phiếu, hoặc mọi phiếu đều Huỷ): bắt lý do bỏ qua test.
    if (!state || state.completed === 0) return { kind: 'skip-test', l8: target === L8 };
  }
  if (target === L8) return { kind: 'l8' };
  return { kind: 'normal' };
}

export type SubstageRule = {
  /** Nhóm con người dùng chọn được (mã). */
  allowed: string[];
  /** Ô khoá: không chọn tay (nêu lý do). */
  lockedReason: string | null;
};

/**
 * Nhóm con người dùng chọn tay trong một giai đoạn (R-CRM-15, 17, 34, 35): L5 do hệ thống gắn theo phiếu; ở L6 không chọn
 * lại L6A; ở L8 đã L8C thì khoá, còn lại đổi qua lại L8A, L8B.
 */
export function substageRule(stage: string, current: string | null, codes: string[]): SubstageRule {
  if (stage === L5) {
    return { allowed: [], lockedReason: 'Nhóm con L5 do hệ thống gắn theo các phiếu kiểm tra.' };
  }
  if (stage === 'L8' && current === L8C) {
    return {
      allowed: [],
      lockedReason: 'Cơ hội đã L8C (thu đủ), không đổi nhóm con (R-CRM-17).',
    };
  }
  if (stage === 'L8') return { allowed: codes.filter((c) => c !== L8C), lockedReason: null };
  if (stage === SYSTEM_STAGE)
    return { allowed: codes.filter((c) => c !== L6A), lockedReason: null };
  return { allowed: codes, lockedReason: null };
}

/**
 * Các nhóm con hiện trong ô chọn Sub-stage: nhóm con chọn tay được cộng với nhóm con HIỆN TẠI nếu hệ thống gắn mà người dùng không
 * chọn lại được (L6A, R-CRM-34), để ô hiện đúng giá trị thay vì trống; thứ tự theo danh mục. Nhóm con hiện tại chọn lại là không đổi gì.
 */
export function substageDisplayCodes(
  allCodes: string[],
  allowed: string[],
  current: string | null,
): string[] {
  return allCodes.filter((c) => allowed.includes(c) || c === current);
}

/** Nhóm con chọn được khi CHUYỂN SANG một giai đoạn (L8 chọn cả L8C, R-CRM-16; L5 do hệ thống gắn nên không chọn). */
export function substageChoicesForMove(target: string, codes: string[]): string[] {
  if (target === L5) return [];
  return codes;
}

/** Lý do không bấm tay vào một giai đoạn (L6 do hệ thống chuyển, R-CRM-13); null nếu bấm được. */
export function lockedStageReason(stage: string): string | null {
  return stage === SYSTEM_STAGE
    ? 'L6 do hệ thống chuyển khi phiếu kiểm tra Hoàn thành, không bấm tay được.'
    : null;
}
