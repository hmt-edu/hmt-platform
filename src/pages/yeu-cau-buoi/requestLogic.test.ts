import { describe, expect, it } from 'vitest';
import {
  kindName,
  statusName,
  statusTone,
  targetText,
  validateDraft,
  validateMakeup,
  validateSupport,
  whenText,
} from './requestLogic';

describe('yêu cầu buổi (BUOI-08, BUOI-10)', () => {
  it('statusName, statusTone', () => {
    expect(statusName('CHO_DUYET')).toBe('Chờ duyệt');
    expect(statusTone('CHO_DUYET')).toBe('warning');
    expect(statusTone('DA_DUYET')).toBe('success');
    expect(statusTone('TU_CHOI')).toBe('danger');
    expect(statusTone('NHAP')).toBe('neutral');
  });
  it('targetText: cả lớp kèm số em', () => {
    expect(
      targetText({
        kind: 'CUNG_CO',
        subject_name: 'Đại số 9',
        class_code: 'C1',
        student_count: 4,
        student_names: [],
      }),
    ).toBe('Cả lớp Đại số 9 (4 em)');
    expect(
      targetText({
        kind: 'CUNG_CO',
        subject_name: null,
        class_code: 'C1',
        student_count: 0,
        student_names: [],
      }),
    ).toBe('Cả lớp C1 (0 em)');
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
  it('kindName và targetText của bổ trợ: tên các em được chọn', () => {
    expect(kindName('CUNG_CO')).toBe('Củng cố');
    expect(kindName('BO_TRO')).toBe('Bổ trợ');
    expect(
      targetText({
        kind: 'BO_TRO',
        subject_name: 'Đại số 9',
        class_code: 'C1',
        student_count: 2,
        student_names: ['An', 'Bình'],
      }),
    ).toBe('An, Bình');
  });
  it('validateSupport: thiếu em, ngày, giờ, giáo viên; giờ kết thúc không sau giờ bắt đầu', () => {
    expect(
      validateSupport({ studentIds: [], date: '', start: '', end: '', teacherId: '' }),
    ).toEqual({
      students: 'Chọn ít nhất một em cần bổ trợ.',
      date: 'Chọn ngày buổi bổ trợ.',
      start: 'Nhập giờ bắt đầu.',
      end: 'Nhập giờ kết thúc.',
      teacher: 'Chọn giáo viên.',
    });
    expect(
      validateSupport({
        studentIds: ['a'],
        date: '2026-11-17',
        start: '19:00',
        end: '18:00',
        teacherId: 't',
      }).end,
    ).toBe('Giờ kết thúc phải sau giờ bắt đầu.');
    expect(
      validateSupport({
        studentIds: ['a'],
        date: '2026-11-17',
        start: '18:00',
        end: '19:30',
        teacherId: 't',
      }),
    ).toEqual({});
  });
  it('validateMakeup: lý do bắt buộc, giáo viên không bắt buộc', () => {
    expect(validateMakeup({ studentIds: [], date: '', start: '', end: '', reason: ' ' })).toEqual({
      students: 'Chọn ít nhất một em học bù.',
      date: 'Chọn ngày buổi học bù.',
      start: 'Nhập giờ bắt đầu.',
      end: 'Nhập giờ kết thúc.',
      reason: 'Nhập lý do học bù.',
    });
    expect(
      validateMakeup({
        studentIds: ['a'],
        date: '2026-11-17',
        start: '18:00',
        end: '19:00',
        reason: 'Ốm',
      }),
    ).toEqual({});
    expect(kindName('HOC_BU')).toBe('Học bù');
  });
});
