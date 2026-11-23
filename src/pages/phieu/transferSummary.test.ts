import { describe, expect, it } from 'vitest';
import { classLine, classTeachers } from './transferSummary';

const cls = {
  code: 'LC-TOAN-K09',
  slots: [
    { weekday: 1, start_time: '19:30', end_time: '21:00', teacher_name: 'Lê Hoài Nam' },
    { weekday: 3, start_time: '19:30', end_time: '21:00', teacher_name: 'Lê Hoài Nam' },
  ],
};

describe('tóm tắt lớp ở hộp Duyệt phiếu Chuyển lớp', () => {
  it('dòng lớp: mã và các buổi trong tuần', () => {
    expect(classLine(cls)).toBe('LC-TOAN-K09 · T2 19:30–21:00, T4 19:30–21:00');
  });
  it('lớp chưa có khung chỉ hiện mã; chưa có lớp hiện «—»', () => {
    expect(classLine({ code: 'A', slots: [] })).toBe('A');
    expect(classLine(null)).toBe('—');
  });
  it('giáo viên không lặp', () => {
    expect(classTeachers(cls)).toBe('Lê Hoài Nam');
    expect(classTeachers(null)).toBe('');
  });
});
