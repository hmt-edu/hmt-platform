import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildStudentAccountFilters, issuable } from './studentAccountFilters';
import type { StudentAccountRow } from './studentAccountTypes';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const row = (id: string, state: StudentAccountRow['state']): StudentAccountRow => ({
  student_id: id,
  student_code: `HS${id}`,
  full_name: `Em ${id}`,
  branch_code: 'CS1',
  parent_name: 'Phụ huynh',
  user_id: state === 'CHUA_CAP' ? null : `u${id}`,
  state,
  must_change_password: false,
  last_login_at: null,
});

describe('Lọc tài khoản học sinh (QT-13)', () => {
  it('chưa lọc gì thì bộ lọc rỗng', () => {
    expect(buildStudentAccountFilters(EMPTY)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildStudentAccountFilters({ ...EMPTY, search: '  HS000012 ' })).toEqual({
      q: 'HS000012',
    });
  });
  it('chọn một tình trạng thì lọc, chọn nhiều thì không lọc', () => {
    expect(buildStudentAccountFilters({ ...EMPTY, quick: { state: ['none'] } })).toEqual({
      state: 'CHUA_CAP',
    });
    expect(buildStudentAccountFilters({ ...EMPTY, quick: { state: ['locked'] } })).toEqual({
      state: 'BI_KHOA',
    });
    expect(buildStudentAccountFilters({ ...EMPTY, quick: { state: ['none', 'active'] } })).toEqual(
      {},
    );
  });
  it('điều kiện cơ sở thành branch_id', () => {
    const state: ListState = {
      ...EMPTY,
      conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
    };
    expect(buildStudentAccountFilters(state)).toEqual({ branch_id: 'b1' });
  });
  it('cấp hàng loạt chỉ lấy em chưa có tài khoản trong số đã chọn', () => {
    const rows = [
      row('1', 'CHUA_CAP'),
      row('2', 'HOAT_DONG'),
      row('3', 'CHUA_CAP'),
      row('4', 'BI_KHOA'),
    ];
    expect(issuable(rows, new Set(['1', '2', '4'])).map((r) => r.student_id)).toEqual(['1']);
  });
});
