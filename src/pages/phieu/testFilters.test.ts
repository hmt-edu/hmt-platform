import { describe, expect, it } from 'vitest';
import { EMPTY_TEST_STATE } from './testConfig';
import { buildTestFilters, testGroupFilter } from './testFilters';

const NOW = new Date('2026-10-14T05:00:00Z'); // 12:00 giờ Việt Nam, thứ Tư
const state = (patch: Partial<typeof EMPTY_TEST_STATE>) => ({
  ...EMPTY_TEST_STATE,
  datePreset: '',
  ...patch,
});

describe('buildTestFilters', () => {
  it('không lọc gì thì bộ lọc rỗng', () => {
    expect(buildTestFilters(state({}), NOW)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildTestFilters(state({ search: '  Huy ' }), NOW)).toEqual({ q: 'Huy' });
  });
  it('"Của tôi" nhiều lựa chọn là một danh sách vai trò (HOẶC, R-CRM-07)', () => {
    expect(
      buildTestFilters(state({ quick: { mine: ['owner', 'grader'] } }), NOW).mine_roles,
    ).toEqual(['OWNER', 'GRADER']);
  });
  it('thời gian và trạng thái đổi sang mã cơ sở dữ liệu', () => {
    const f = buildTestFilters(
      state({ quick: { when: ['overdue', 'upcoming'], status: ['draft', 'review'] } }),
      NOW,
    );
    expect(f.when).toEqual(['OVERDUE', 'UPCOMING']);
    expect(f.status).toEqual(['DRAFT', 'TEACHER_REVIEW']);
  });
  it('mốc nhanh Tuần này thành khoảng giờ test', () => {
    const f = buildTestFilters(state({ datePreset: 'week' }), NOW);
    expect(new Date(String(f.from)).getTime()).toBeLessThan(NOW.getTime());
    expect(new Date(String(f.to)).getTime()).toBeGreaterThan(NOW.getTime());
  });
  it('cửa sổ của Lịch thay mốc nhanh; điều kiện ngày thu hẹp thêm', () => {
    const window = { from: new Date('2026-10-12T00:00:00Z'), to: new Date('2026-10-19T00:00:00Z') };
    const f = buildTestFilters(
      state({
        datePreset: 'month',
        conditions: [{ id: '1', field: 'time', op: 'from', value: '2026-10-15' }],
      }),
      NOW,
      window,
    );
    expect(f.to).toBe('2026-10-19T00:00:00.000Z');
    expect(f.from).toBe('2026-10-14T17:00:00.000Z');
  });
  it('lọc nâng cao: môn, hình thức, cơ sở test, người phụ trách, giáo viên chấm', () => {
    const f = buildTestFilters(
      state({
        conditions: [
          { id: '1', field: 'subject', op: 'in', value: ['TOAN', 'VAN'] },
          { id: '2', field: 'mode', op: 'in', value: ['OFFLINE'] },
          { id: '3', field: 'test_branch', op: 'eq', value: 'b1' },
          { id: '4', field: 'owner', op: 'eq', value: 'u1' },
          { id: '5', field: 'grader', op: 'eq', value: 'u2' },
        ],
      }),
      NOW,
    );
    expect(f).toMatchObject({
      subject: ['TOAN', 'VAN'],
      mode: ['OFFLINE'],
      test_branch_id: 'b1',
      owner_id: 'u1',
      grader_id: 'u2',
    });
  });
});

describe('testGroupFilter', () => {
  it('bộ lọc của một nhóm', () => {
    expect(testGroupFilter('status', 'DRAFT')).toEqual({ status: ['DRAFT'] });
    expect(testGroupFilter('grader', 'u1')).toEqual({ grader_id: 'u1' });
    expect(testGroupFilter('subject', '')).toEqual({});
  });
});
