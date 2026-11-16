import { describe, expect, it } from 'vitest';
import { statusName, statusTone, targetText, validateDraft, whenText } from './requestLogic';

describe('yêu cầu buổi (BUOI-08, BUOI-10)', () => {
  it('statusName, statusTone', () => {
    expect(statusName('CHO_DUYET')).toBe('Chờ duyệt');
    expect(statusTone('CHO_DUYET')).toBe('warning');
    expect(statusTone('DA_DUYET')).toBe('success');
    expect(statusTone('TU_CHOI')).toBe('danger');
    expect(statusTone('NHAP')).toBe('neutral');
  });
  it('targetText: cả lớp kèm số em', () => {
    expect(targetText({ subject_name: 'Đại số 9', class_code: 'C1', student_count: 4 })).toBe(
      'Cả lớp Đại số 9 (4 em)',
    );
    expect(targetText({ subject_name: null, class_code: 'C1', student_count: 0 })).toBe(
      'Cả lớp C1 (0 em)',
    );
  });
  it('whenText: ngày dd/mm/yyyy và giờ hh:mm', () => {
    expect(
      whenText({ session_date: '2026-11-17', start_time: '18:00:00', end_time: '19:30:00' }),
    ).toBe('17/11/2026 · 18:00–19:30');
  });
  it('validateDraft: thiếu ô, giờ kết thúc không sau giờ bắt đầu', () => {
    expect(validateDraft({ classId: '', date: '', start: '', end: '' })).toEqual({
      class: 'Chọn lớp.',
      date: 'Chọn ngày buổi củng cố.',
      start: 'Nhập giờ bắt đầu.',
      end: 'Nhập giờ kết thúc.',
    });
    expect(
      validateDraft({ classId: 'x', date: '2026-11-17', start: '19:30', end: '18:00' }).end,
    ).toBe('Giờ kết thúc phải sau giờ bắt đầu.');
    expect(
      validateDraft({ classId: 'x', date: '2026-11-17', start: '18:00', end: '19:30' }),
    ).toEqual({});
  });
});
