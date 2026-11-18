import { describe, expect, it } from 'vitest';
import { EMPTY_TASK_STATE, buildTaskFilters } from './phieuFilters';

const TYPES = ['CAP_NHAT_HO_SO', 'HOAN_PHI'];
const STATUS = ['NHAP', 'CHO_DUYET'];

describe('Phiếu nghiệp vụ: bộ lọc danh sách (CSN-05)', () => {
  it('không lọc gì thì rỗng; tìm kiếm cắt khoảng trắng', () => {
    expect(buildTaskFilters(EMPTY_TASK_STATE, TYPES, STATUS)).toEqual({});
    expect(buildTaskFilters({ ...EMPTY_TASK_STATE, search: '  PNV-1 ' }, TYPES, STATUS)).toEqual({
      q: 'PNV-1',
    });
  });
  it('lọc nhanh một giá trị: loại, trạng thái, hàng chờ', () => {
    const state = {
      ...EMPTY_TASK_STATE,
      quick: { type: ['HOAN_PHI'], status: ['CHO_DUYET'], queue: ['cho_toi'] },
    };
    expect(buildTaskFilters(state, TYPES, STATUS)).toEqual({
      task_type: 'HOAN_PHI',
      status_code: 'CHO_DUYET',
      cho_toi: true,
    });
  });
  it('mã lạ hoặc nhiều giá trị cùng nhóm thì bỏ', () => {
    const state = {
      ...EMPTY_TASK_STATE,
      quick: { type: ['LA'], status: ['NHAP', 'CHO_DUYET'], queue: ['x'] },
    };
    expect(buildTaskFilters(state, TYPES, STATUS)).toEqual({});
  });
  it('điều kiện cơ sở', () => {
    const state = {
      ...EMPTY_TASK_STATE,
      conditions: [{ id: '1', field: 'branch', op: 'eq' as const, value: 'b1' }],
    };
    expect(buildTaskFilters(state, TYPES, STATUS)).toEqual({ branch_id: 'b1' });
  });
  it('«Đã duyệt, chờ thực hiện» lọc theo trạng thái Đã duyệt (CSN-05)', () => {
    const state = { ...EMPTY_TASK_STATE, quick: { queue: ['cho_thuc_hien'] } };
    expect(buildTaskFilters(state, TYPES, STATUS)).toEqual({ status_code: 'DA_DUYET' });
  });
});
