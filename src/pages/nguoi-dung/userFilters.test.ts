import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildUserFilters, userSortParam } from './userFilters';

const base: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('buildUserFilters', () => {
  it('không lọc gì thì rỗng', () => {
    expect(buildUserFilters(base)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildUserFilters({ ...base, search: '  hà ' })).toEqual({ q: 'hà' });
  });
  it('trạng thái: chọn một thì lọc, chọn cả hai thì không lọc', () => {
    expect(buildUserFilters({ ...base, quick: { status: ['locked'] } })).toEqual({
      status: 'LOCKED',
    });
    expect(buildUserFilters({ ...base, quick: { status: ['active'] } })).toEqual({
      status: 'ACTIVE',
    });
    expect(buildUserFilters({ ...base, quick: { status: ['active', 'locked'] } })).toEqual({});
  });
  it('điều kiện vai trò, cơ sở, loại', () => {
    const state: ListState = {
      ...base,
      conditions: [
        { id: '1', field: 'role', op: 'in', value: ['SALES', 'CSKH'] },
        { id: '2', field: 'branch', op: 'eq', value: 'b1' },
        { id: '3', field: 'kind', op: 'eq', value: 'GV' },
      ],
    };
    expect(buildUserFilters(state)).toEqual({
      role: ['SALES', 'CSKH'],
      branch_id: 'b1',
      kind: 'GV',
    });
  });
  it('điều kiện "khác" và giá trị trống bị bỏ qua', () => {
    const state: ListState = {
      ...base,
      conditions: [
        { id: '1', field: 'branch', op: 'ne', value: 'b1' },
        { id: '2', field: 'role', op: 'in', value: [] },
      ],
    };
    expect(buildUserFilters(state)).toEqual({});
  });
});

describe('userSortParam', () => {
  it('chỉ các kiểu máy chủ hỗ trợ; còn lại là tên A-Z', () => {
    expect(userSortParam('last_login', 'desc')).toBe('last_login_desc');
    expect(userSortParam('created', 'desc')).toBe('created_desc');
    expect(userSortParam('last_login', 'asc')).toBe('name_asc');
    expect(userSortParam(null, null)).toBe('name_asc');
  });
});
