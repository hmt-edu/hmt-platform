import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { afterExclusion, buildPromotionFilters, newGradeText } from './gradePromotionLogic';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('Lên khối đầu năm (KH-08)', () => {
  it('bộ lọc: tìm và cơ sở', () => {
    expect(buildPromotionFilters(EMPTY)).toEqual({});
    expect(buildPromotionFilters({ ...EMPTY, search: ' An ' })).toEqual({ q: 'An' });
    expect(
      buildPromotionFilters({
        ...EMPTY,
        conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
      }),
    ).toEqual({ branch_id: 'b1' });
  });
  it('chữ khối mới: khối hoặc Tốt nghiệp', () => {
    expect(newGradeText({ new_grade: 9 })).toBe('Khối 9');
    expect(newGradeText({ new_grade: null })).toBe('Tốt nghiệp');
  });
  it('số em sau khi loại trừ', () => {
    expect(afterExclusion({ eligible: 100, graduating: 10 }, { count: 5, graduating: 2 })).toEqual({
      total: 95,
      graduating: 8,
      promoting: 87,
    });
    expect(afterExclusion({ eligible: 3, graduating: 0 }, { count: 9, graduating: 0 }).total).toBe(
      0,
    );
  });
});
