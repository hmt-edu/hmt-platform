import { describe, expect, it } from 'vitest';
import {
  EMPTY_ABSENT_STATE,
  EMPTY_SESSION_STATE,
  buildAbsentFilters,
  buildSessionFilters,
  classLabel,
  sessionNoLabel,
  sessionSortParam,
  ymd,
} from './sessionLogic';

const NOW = new Date('2026-10-20T03:00:00Z'); // 10:00 ngày 20/10/2026 giờ Việt Nam
const STATUSES = ['NHAP', 'DA_CHOT', 'DONE'];

describe('buildSessionFilters (BUOI-01)', () => {
  it('mặc định lọc đúng ngày hôm nay theo giờ Việt Nam', () => {
    const f = buildSessionFilters(EMPTY_SESSION_STATE, STATUSES, NOW);
    expect(f).toEqual({ date_from: '2026-10-20', date_to: '2026-10-20' });
  });
  it('bỏ mốc thời gian thì không có khoảng ngày', () => {
    const f = buildSessionFilters({ ...EMPTY_SESSION_STATE, datePreset: '' }, STATUSES, NOW);
    expect(f).toEqual({});
  });
  it('lọc nhanh tình trạng và bỏ mã lạ', () => {
    const f = buildSessionFilters(
      { ...EMPTY_SESSION_STATE, datePreset: '', quick: { status: ['DONE', 'LA'] } },
      STATUSES,
      NOW,
    );
    expect(f.status).toEqual(['DONE']);
  });
  it('điều kiện nâng cao: cơ sở, từ ngày, đến ngày, tìm kiếm', () => {
    const f = buildSessionFilters(
      {
        ...EMPTY_SESSION_STATE,
        search: ' Toán ',
        conditions: [
          { id: '1', field: 'branch', op: 'eq', value: 'b1' },
          { id: '2', field: 'session_date', op: 'from', value: '2026-10-01' },
          { id: '3', field: 'session_date', op: 'to', value: '2026-10-31' },
        ],
      },
      STATUSES,
      NOW,
    );
    expect(f).toMatchObject({
      q: 'Toán',
      branch_id: 'b1',
      date_from: '2026-10-01',
      date_to: '2026-10-31',
    });
  });
});

describe('buildAbsentFilters (BUOI-11)', () => {
  it('chọn một loại thì lọc, chọn cả hai thì không lọc', () => {
    expect(buildAbsentFilters({ ...EMPTY_ABSENT_STATE, quick: { kind: ['VANG'] } })).toEqual({
      kind: 'VANG',
    });
    expect(
      buildAbsentFilters({ ...EMPTY_ABSENT_STATE, quick: { kind: ['VANG', 'CHUA_DEN'] } }),
    ).toEqual({});
  });
});

describe('nhãn', () => {
  it('sắp xếp, nhãn lớp, số buổi, ngày', () => {
    expect(sessionSortParam(null)).toBe('time_asc');
    expect(sessionSortParam({ key: 'time', direction: 'desc' })).toBe('time_desc');
    expect(classLabel('Toán', 'CS1-X')).toBe('Toán · CS1-X');
    expect(classLabel(null, 'CS1-X')).toBe('CS1-X');
    expect(sessionNoLabel(5)).toBe('Buổi 5');
    expect(sessionNoLabel(null)).toBe('—');
    expect(ymd(new Date(2026, 0, 5))).toBe('2026-01-05');
  });
});
