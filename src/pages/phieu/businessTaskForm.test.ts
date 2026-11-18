import { describe, expect, it } from 'vitest';
import {
  buildBusinessPayload,
  classChoices,
  EMPTY_BUSINESS_DRAFT,
  validateBusinessDraft,
  type TaskOptions,
} from './businessTaskForm';

const full = {
  ...EMPTY_BUSINESS_DRAFT,
  enrollmentId: 'e1',
  reasonCode: 'BAN_THI',
  reason: 'Em tham gia đội tuyển.',
};

describe('phiếu Bảo lưu', () => {
  it('thiếu số tháng thì báo lỗi, đủ thì qua', () => {
    expect(validateBusinessDraft('BAO_LUU', full, true).months).toBeDefined();
    expect(validateBusinessDraft('BAO_LUU', { ...full, months: '0' }, true).months).toBeDefined();
    expect(validateBusinessDraft('BAO_LUU', { ...full, months: '2' }, true)).toEqual({});
  });
  it('ticket chưa gắn học sinh thì chặn', () => {
    expect(
      validateBusinessDraft('BAO_LUU', { ...full, months: '2' }, false).enrollmentId,
    ).toBeDefined();
  });
  it('payload đúng khoá của migration 262', () => {
    expect(buildBusinessPayload('BAO_LUU', { ...full, months: '2' })).toEqual({
      enrollment_id: 'e1',
      months: 2,
      reason_code: 'BAN_THI',
      note: 'Em tham gia đội tuyển.',
    });
  });
});

describe('phiếu Chuyển lớp', () => {
  it('thiếu lớp mới, buổi, loại chuyển thì báo lỗi', () => {
    const e = validateBusinessDraft('CHUYEN_LOP', full, true);
    expect(e.toClassId && e.startDate && e.kindCode).toBeTruthy();
  });
  it('payload dùng kind_code, start_date', () => {
    const p = buildBusinessPayload('CHUYEN_LOP', {
      ...full,
      toClassId: 'c2',
      startDate: '2026-11-17',
      kindCode: 'DOI_GIO',
    });
    expect(p).toMatchObject({ to_class_id: 'c2', start_date: '2026-11-17', kind_code: 'DOI_GIO' });
  });
  it('lớp gợi ý cùng môn, bỏ lớp hiện tại', () => {
    const o: TaskOptions = {
      enrollments: [
        {
          id: 'e1',
          code: 'GD1',
          status_code: 'DANG_HOC',
          subject_code: 'TOAN',
          class_id: 'c1',
          class_code: 'A',
          remaining_hours: 10,
        },
      ],
      hold_reasons: [],
      transfer_reasons: [],
      classes: [
        { id: 'c1', code: 'A', subject_code: 'TOAN', seats_left: 3, upcoming: [] },
        { id: 'c2', code: 'B', subject_code: 'TOAN', seats_left: 3, upcoming: [] },
        { id: 'c3', code: 'C', subject_code: 'ANH', seats_left: 3, upcoming: [] },
      ],
    };
    expect(classChoices(o, 'e1').map((c) => c.id)).toEqual(['c2']);
  });
});
