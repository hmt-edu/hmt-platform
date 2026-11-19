import { describe, expect, it } from 'vitest';
import { SESSION_GROUP_FIELD_OF, sessionGroupFilter } from './sessionLogic';

describe('Group By Buổi học (Kho #17)', () => {
  it('sáu trường nhóm', () => {
    expect(Object.keys(SESSION_GROUP_FIELD_OF)).toEqual([
      'date',
      'class',
      'branch',
      'teacher',
      'type',
      'status',
    ]);
  });
  it('mở nhóm lọc đúng theo khoá', () => {
    expect(sessionGroupFilter('date', '2026-11-20')).toEqual({
      date_from: '2026-11-20',
      date_to: '2026-11-20',
    });
    expect(sessionGroupFilter('class', 'c1')).toEqual({ class_id: 'c1' });
    expect(sessionGroupFilter('branch', 'b1')).toEqual({ branch_id: 'b1' });
    expect(sessionGroupFilter('teacher', 't1')).toEqual({ teacher_id: 't1' });
    expect(sessionGroupFilter('type', 'CHINH')).toEqual({ type_code: ['CHINH'] });
    expect(sessionGroupFilter('status', 'DONE')).toEqual({ status: ['DONE'] });
  });
  it('nhóm «Chưa có»: giáo viên trống = chưa có giáo viên; trường khác không lọc thêm', () => {
    expect(sessionGroupFilter('teacher', '')).toEqual({ no_teacher: true });
    expect(sessionGroupFilter('type', '')).toEqual({});
  });
});
