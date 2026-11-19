import { describe, expect, it } from 'vitest';
import { ENROLL_GROUP_FIELD_OF, enrollGroupFilter } from './enrollFilters';

describe('Group By Ghi danh (Kho #17)', () => {
  it('ba trường nhóm: hình thức học, lớp, tình trạng', () => {
    expect(Object.keys(ENROLL_GROUP_FIELD_OF)).toEqual(['mode', 'class', 'status']);
  });
  it('mở nhóm lọc đúng theo khoá', () => {
    expect(enrollGroupFilter('mode', 'OFF')).toEqual({ delivery_mode_code: ['OFF'] });
    expect(enrollGroupFilter('class', 'abc')).toEqual({ class_id: 'abc' });
    expect(enrollGroupFilter('status', 'DANG_HOC')).toEqual({ status: ['DANG_HOC'] });
  });
  it('nhóm «Chưa có»: lớp trống nghĩa là chưa có lớp; trường khác không lọc thêm', () => {
    expect(enrollGroupFilter('class', '')).toEqual({ no_class: true });
    expect(enrollGroupFilter('mode', '')).toEqual({});
    expect(enrollGroupFilter('status', '')).toEqual({});
  });
});
