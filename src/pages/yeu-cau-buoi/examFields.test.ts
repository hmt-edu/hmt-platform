import { describe, expect, it } from 'vitest';
import { EMPTY_EXAM, examChargeNote, examRpcArgs, validateExam } from './examFields';

describe('kiểm nhập ô Buổi kiểm tra (A25)', () => {
  it('để trống điểm tối đa, nhập điểm tổng: hợp lệ (máy chủ lấy mặc định)', () => {
    expect(validateExam(EMPTY_EXAM)).toEqual({});
  });
  it('điểm tối đa phải lớn hơn 0', () => {
    expect(validateExam({ ...EMPTY_EXAM, maxScore: '0' }).maxScore).toBeDefined();
    expect(validateExam({ ...EMPTY_EXAM, maxScore: 'abc' }).maxScore).toBeDefined();
    expect(validateExam({ ...EMPTY_EXAM, maxScore: '10' })).toEqual({});
  });
  it('ba nhóm: cần điểm tối đa; tổng ba nhóm phải bằng điểm tối đa (R-V2-20), chấp nhận dấu phẩy', () => {
    const nhom = { ...EMPTY_EXAM, mode: 'NHOM' as const };
    expect(validateExam(nhom).maxScore).toBeDefined();
    expect(
      validateExam({ ...nhom, maxScore: '10', memory: '3', understand: '3', apply: '3' }).groups,
    ).toBeDefined();
    expect(
      validateExam({ ...nhom, maxScore: '10', memory: '3', understand: '3', apply: '4' }),
    ).toEqual({});
    expect(
      validateExam({ ...nhom, maxScore: '10', memory: '2,5', understand: '3,5', apply: '4' }),
    ).toEqual({});
  });
  it('tham số gửi máy chủ: ba nhóm chỉ khi chọn Theo 3 nhóm; trống thì null', () => {
    expect(examRpcArgs({ ...EMPTY_EXAM, scope: ' Hàm số ', maxScore: '10', memory: '3' })).toEqual({
      p_scope: 'Hàm số',
      p_max_score: 10,
      p_mode: 'TONG',
      p_max_memory: 0,
      p_max_understand: 0,
      p_max_apply: 0,
    });
    expect(
      examRpcArgs({
        ...EMPTY_EXAM,
        mode: 'NHOM',
        maxScore: '10',
        memory: '3',
        understand: '3',
        apply: '4',
      }),
    ).toMatchObject({ p_max_memory: 3, p_max_apply: 4 });
    expect(examRpcArgs(EMPTY_EXAM).p_max_score).toBeNull();
  });
  it('câu giải thích tính giờ theo loại yêu cầu', () => {
    expect(examChargeNote('CUNG_CO')).toContain('trừ giờ như buổi Chính');
    expect(examChargeNote('HOC_BU')).toContain('không trừ giờ');
  });
});
