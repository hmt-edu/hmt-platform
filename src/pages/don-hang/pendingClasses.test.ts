import { describe, expect, it } from 'vitest';
import { mergeLineClasses } from './pendingClasses';

const saved = [{ line_no: 1, class_id: 'c1', class_code: 'L1', enrol_start_date: '2026-11-20' }];

describe('mergeLineClasses (BH-08: lớp chọn lúc Sửa đơn chỉ lưu khi bấm Lưu)', () => {
  it('chưa chọn gì: giữ lớp đã lưu', () => {
    expect(mergeLineClasses(saved, {})).toEqual({ 1: saved[0] });
  });
  it('chọn lớp khác cho dòng đã có: hiện lớp mới', () => {
    const m = mergeLineClasses(saved, {
      1: { classId: 'c2', date: '2026-12-01', classCode: 'L2' },
    });
    expect(m[1]).toMatchObject({
      class_id: 'c2',
      class_code: 'L2',
      enrol_start_date: '2026-12-01',
    });
  });
  it('chọn lớp cho dòng chưa có lớp', () => {
    const m = mergeLineClasses([], { 2: { classId: 'c3', date: '2026-12-02', classCode: 'L3' } });
    expect(m[2]?.class_code).toBe('L3');
  });
  it('bỏ chọn lớp (Chưa chọn lớp): dòng không còn lớp', () => {
    const m = mergeLineClasses(saved, { 1: { classId: null, date: null, classCode: null } });
    expect(m[1]).toBeUndefined();
  });
});
