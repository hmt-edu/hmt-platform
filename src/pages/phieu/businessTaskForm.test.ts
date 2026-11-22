import { describe, expect, it } from 'vitest';
import {
  buildBusinessPayload,
  holdEnrollmentChoices,
  runningHold,
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

describe('Gia hạn bảo lưu (CSN-06b, R-GD-09)', () => {
  const enr = (id: string, status: string) => ({
    id,
    code: id,
    status_code: status,
    subject_code: null,
    class_id: null,
    class_code: null,
    remaining_hours: 5,
  });
  const options = {
    enrollments: [enr('a', 'DANG_HOC'), enr('b', 'BAO_LUU')],
    holds: [{ id: 'h1', enrollment_id: 'b', start_date: '2026-11-01', end_date: '2027-01-01' }],
    hold_reasons: [],
    transfer_reasons: [],
    classes: [],
  };
  const full = {
    ...EMPTY_BUSINESS_DRAFT,
    enrollmentId: 'b',
    reasonCode: 'THI',
    reason: 'Chưa thi xong',
    months: '1',
    holdMode: 'GIA_HAN' as const,
  };
  it('Gia hạn chỉ cho ghi danh có bảo lưu đang chạy, Bảo lưu mới loại ghi danh đang bảo lưu', () => {
    expect(holdEnrollmentChoices(options, 'GIA_HAN').map((x) => x.id)).toEqual(['b']);
    expect(holdEnrollmentChoices(options, 'MOI').map((x) => x.id)).toEqual(['a']);
  });
  it('Gia hạn gửi extends_hold_id của bản đang chạy; bảo lưu mới thì không', () => {
    expect(runningHold(options, 'b')?.id).toBe('h1');
    expect(buildBusinessPayload('BAO_LUU', full, 'h1')).toMatchObject({
      extends_hold_id: 'h1',
      months: 1,
    });
    expect(buildBusinessPayload('BAO_LUU', { ...full, holdMode: 'MOI' }, 'h1')).not.toHaveProperty(
      'extends_hold_id',
    );
  });
  it('Gia hạn báo thiếu số tháng gia hạn', () => {
    expect(validateBusinessDraft('BAO_LUU', { ...full, months: '' }, true).months).toBe(
      'Nhập số tháng gia hạn (từ 1).',
    );
  });
  it('Tiếp tục học: gửi resume, không đòi số tháng, chỉ ghi danh có bảo lưu đang chạy', () => {
    const draft = { ...full, holdMode: 'TIEP_TUC' as const, months: '' };
    expect(validateBusinessDraft('BAO_LUU', draft, true).months).toBeUndefined();
    expect(buildBusinessPayload('BAO_LUU', draft, 'h1')).toEqual({
      enrollment_id: 'b',
      reason_code: 'THI',
      note: 'Chưa thi xong',
      resume: true,
    });
    expect(holdEnrollmentChoices(options, 'TIEP_TUC').map((x) => x.id)).toEqual(['b']);
  });
});

describe('Phiếu Dừng học (CS-14, R-GD-16)', () => {
  const draft = {
    ...EMPTY_BUSINESS_DRAFT,
    enrollmentId: 'e1',
    reasonCode: 'CHUYEN',
    reason: 'Chuyển nhà',
  };
  it('chỉ cần ghi danh, lý do danh mục và lý do chữ; không đòi số tháng hay lớp', () => {
    expect(validateBusinessDraft('DUNG_HOC', draft, true)).toEqual({});
    expect(
      validateBusinessDraft('DUNG_HOC', { ...draft, enrollmentId: '' }, true).enrollmentId,
    ).toBe('Chọn ghi danh.');
    expect(validateBusinessDraft('DUNG_HOC', { ...draft, reasonCode: '' }, true).reasonCode).toBe(
      'Chọn lý do.',
    );
  });
  it('payload gửi ghi danh, lý do và ghi chú', () => {
    expect(buildBusinessPayload('DUNG_HOC', draft)).toEqual({
      enrollment_id: 'e1',
      reason_code: 'CHUYEN',
      note: 'Chuyển nhà',
    });
  });
});

describe('Phiếu Chuyển phí (CS-10, R-GD-10 mục 9)', () => {
  const draft = {
    ...EMPTY_BUSINESS_DRAFT,
    enrollmentId: 'e1',
    reasonCode: 'DOI_LICH_BAN',
    reason: 'Chuyển sang môn khác',
  };
  it('chỉ cần ghi danh, lý do danh mục và lý do chữ (như Dừng học), không đòi lớp', () => {
    expect(validateBusinessDraft('CHUYEN_PHI', draft, true)).toEqual({});
    expect(
      validateBusinessDraft('CHUYEN_PHI', { ...draft, enrollmentId: '' }, true).enrollmentId,
    ).toBe('Chọn ghi danh.');
    expect(validateBusinessDraft('CHUYEN_PHI', draft, false).enrollmentId).toBe(
      'Ticket chưa gắn học sinh nên chưa tạo phiếu này được.',
    );
  });
  it('payload gửi ghi danh, lý do và ghi chú', () => {
    expect(buildBusinessPayload('CHUYEN_PHI', draft)).toEqual({
      enrollment_id: 'e1',
      reason_code: 'DOI_LICH_BAN',
      note: 'Chuyển sang môn khác',
    });
  });
});

describe('phiếu Chuyển cơ sở (R-GD-10, R-CS-07; migration 568)', () => {
  const cs = { ...full, kindCode: 'CHUYEN_CO_SO' };
  it('chưa chọn cơ sở mới thì chặn; không đòi lớp mới và buổi bắt đầu', () => {
    const e = validateBusinessDraft('CHUYEN_LOP', cs, true);
    expect(e.destBranchId).toBeDefined();
    expect(e.toClassId).toBeUndefined();
    expect(e.startDate).toBeUndefined();
  });
  it('đã chọn cơ sở mới thì qua', () => {
    expect(validateBusinessDraft('CHUYEN_LOP', { ...cs, destBranchId: 'b2' }, true)).toEqual({});
  });
  it('payload gửi cơ sở đích, không gửi lớp mới', () => {
    const p = buildBusinessPayload('CHUYEN_LOP', { ...cs, destBranchId: 'b2', toClassId: 'x' });
    expect(p).toEqual({
      enrollment_id: 'e1',
      kind_code: 'CHUYEN_CO_SO',
      dest_branch_id: 'b2',
      reason_code: 'BAN_THI',
      note: 'Em tham gia đội tuyển.',
    });
  });
});
