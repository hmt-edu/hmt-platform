import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildClassFilters, classSortParam } from './classFilters';

const empty: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('Bộ lọc danh sách lớp (LOP-01)', () => {
  it('không lọc gì thì rỗng', () => {
    expect(buildClassFilters(empty)).toEqual({});
  });

  it('tìm theo mã lớp hoặc mã cũ, cắt khoảng trắng (R-LOP-15)', () => {
    expect(buildClassFilters({ ...empty, search: '  4M1 ' })).toEqual({ search: '4M1' });
  });

  it('lọc nhanh tình trạng duyệt và vận hành', () => {
    const f = buildClassFilters({
      ...empty,
      quick: { status: ['DA_DUYET', 'NHAP'], operating: ['DANG_HOC'] },
    });
    expect(f).toEqual({ status: ['DA_DUYET', 'NHAP'], operating: ['DANG_HOC'] });
  });

  it('điều kiện: cơ sở, môn, khối, phân loại; bỏ qua phép khác máy chủ chưa hiểu', () => {
    const f = buildClassFilters({
      ...empty,
      conditions: [
        { id: '1', field: 'branch', op: 'eq', value: 'b1' },
        { id: '2', field: 'subject', op: 'eq', value: 'TOAN' },
        { id: '3', field: 'grade', op: 'ne', value: 'K08' },
        { id: '4', field: 'type', op: 'eq', value: 'CB' },
      ],
    });
    expect(f).toEqual({ branch_id: 'b1', subject_code: 'TOAN', class_type_code: 'CB' });
  });

  it('sắp xếp: mặc định theo mã tăng dần', () => {
    expect(classSortParam(null, null)).toBe('code_asc');
    expect(classSortParam('code', 'desc')).toBe('code_desc');
    expect(classSortParam('start', 'desc')).toBe('start_desc');
  });
});
