import { describe, expect, it } from 'vitest';
import {
  lockedStageReason,
  planStageChange,
  stageIndex,
  substageChoicesForMove,
  substageDisplayCodes,
  substageRule,
  type StageContext,
} from './oppStage';

const base: StageContext = {
  stage_code: 'L4',
  student_name: 'Em Ba',
  student_birth_year: 2011,
  test_state: { in_progress: 0, completed: 1, cancelled: 0, in_progress_codes: null },
  tests: [],
};
const ctx = (patch: Partial<StageContext>): StageContext => ({ ...base, ...patch });

describe('planStageChange', () => {
  it('chuyển bình thường khi đủ điều kiện', () => {
    expect(planStageChange(base, 'L5')).toEqual({ kind: 'normal' });
    expect(planStageChange(base, 'L2')).toEqual({ kind: 'normal' });
  });
  it('R-CRM-03: từ L5 thiếu tên hoặc năm sinh thì chặn, nêu đúng ô thiếu', () => {
    expect(planStageChange(ctx({ student_name: '  ' }), 'L5')).toEqual({
      kind: 'blocked-student',
      missing: ['Tên học sinh'],
    });
    expect(planStageChange(ctx({ student_birth_year: null }), 'L7')).toEqual({
      kind: 'blocked-student',
      missing: ['Năm sinh học sinh'],
    });
    expect(planStageChange(ctx({ student_name: null, student_birth_year: null }), 'L8')).toEqual({
      kind: 'blocked-student',
      missing: ['Tên học sinh', 'Năm sinh học sinh'],
    });
  });
  it('R-CRM-03: dưới L5 không đòi thông tin học sinh', () => {
    expect(planStageChange(ctx({ student_name: null, student_birth_year: null }), 'L3')).toEqual({
      kind: 'normal',
    });
  });
  it('R-CRM-12: còn phiếu dang dở thì chặn L7, L8 và nêu mã phiếu', () => {
    const state = { in_progress: 1, completed: 0, cancelled: 0, in_progress_codes: ['PKT000112'] };
    const plan = planStageChange(ctx({ test_state: state }), 'L7');
    expect(plan.kind).toBe('blocked-tests');
    expect(plan).toMatchObject({ codes: ['PKT000112'] });
    expect(planStageChange(ctx({ test_state: state }), 'L8').kind).toBe('blocked-tests');
  });
  it('R-CRM-12: phiếu dang dở không chặn L5 (chỉ L7, L8)', () => {
    const state = { in_progress: 2, completed: 0, cancelled: 0, in_progress_codes: ['A', 'B'] };
    expect(planStageChange(ctx({ test_state: state }), 'L5')).toEqual({ kind: 'normal' });
  });
  it('R-CRM-14: không có phiếu Hoàn thành thì bắt lý do bỏ qua test (L7), kèm chọn L8 nếu sang L8', () => {
    const none = { in_progress: 0, completed: 0, cancelled: 2, in_progress_codes: null };
    expect(planStageChange(ctx({ test_state: none }), 'L7')).toEqual({
      kind: 'skip-test',
      l8: false,
    });
    expect(planStageChange(ctx({ test_state: none }), 'L8')).toEqual({
      kind: 'skip-test',
      l8: true,
    });
    expect(planStageChange(ctx({ test_state: null }), 'L7')).toEqual({
      kind: 'skip-test',
      l8: false,
    });
  });
  it('R-CRM-14: đã có phiếu Hoàn thành thì không cần lý do bỏ qua', () => {
    expect(planStageChange(base, 'L7')).toEqual({ kind: 'normal' });
  });
  it('R-CRM-16: sang L8 chọn nhóm con và xác nhận', () => {
    expect(planStageChange(base, 'L8')).toEqual({ kind: 'l8' });
  });
  it('R-CRM-03 được kiểm trước R-CRM-12', () => {
    const state = { in_progress: 1, completed: 0, cancelled: 0, in_progress_codes: ['A'] };
    expect(planStageChange(ctx({ test_state: state, student_name: null }), 'L7').kind).toBe(
      'blocked-student',
    );
  });
});

describe('nhóm con', () => {
  const l5 = ['L5A', 'L5B', 'L5P'];
  const l6 = ['L6A', 'L6B', 'L6C'];
  const l8 = ['L8A', 'L8B', 'L8C'];
  it('R-CRM-15: nhóm con L5 do hệ thống gắn, người dùng không chọn', () => {
    expect(substageRule('L5', 'L5A', l5).allowed).toEqual([]);
    expect(substageRule('L5', 'L5A', l5).lockedReason).not.toBeNull();
    expect(substageChoicesForMove('L5', l5)).toEqual([]);
  });
  it('R-CRM-34: ô Sub-stage ở L6 vẫn hiện L6A (hệ thống gắn) dù không chọn lại được', () => {
    const allowed = substageRule('L6', 'L6A', l6).allowed;
    expect(substageDisplayCodes(l6, allowed, 'L6A')).toEqual(['L6A', 'L6B', 'L6C']);
    // Đã chọn L6B tay: L6A không còn trong ô.
    expect(substageDisplayCodes(l6, substageRule('L6', 'L6B', l6).allowed, 'L6B')).toEqual([
      'L6B',
      'L6C',
    ]);
    // Chưa có nhóm con: chỉ các nhóm chọn được.
    expect(substageDisplayCodes(l6, allowed, null)).toEqual(['L6B', 'L6C']);
  });
  it('R-CRM-34: ở L6 không chọn lại L6A', () => {
    expect(substageRule('L6', 'L6A', l6).allowed).toEqual(['L6B', 'L6C']);
  });
  it('R-CRM-35: ở L8 đổi qua lại L8A, L8B; L8C khoá (R-CRM-17)', () => {
    expect(substageRule('L8', 'L8A', l8).allowed).toEqual(['L8A', 'L8B']);
    expect(substageRule('L8', 'L8C', l8).lockedReason).not.toBeNull();
  });
  it('R-CRM-16: khi chuyển sang L8 chọn được cả L8C', () => {
    expect(substageChoicesForMove('L8', l8)).toEqual(l8);
  });
  it('các giai đoạn khác chọn mọi nhóm con', () => {
    expect(substageRule('L7', null, ['L7A', 'L7B']).allowed).toEqual(['L7A', 'L7B']);
  });
});

describe('giai đoạn', () => {
  it('L6 do hệ thống chuyển, bấm tay có lý do', () => {
    expect(lockedStageReason('L6')).toContain('hệ thống');
    expect(lockedStageReason('L7')).toBeNull();
  });
  it('thứ tự L1 đến L8', () => {
    expect(stageIndex('L1')).toBe(0);
    expect(stageIndex('L8')).toBe(7);
  });
});
