import { describe, expect, it } from 'vitest';
import { EMPTY_UPSALE_STATE, buildUpsaleFilters } from './upsaleFilters';

describe('Phiếu tái tục: bộ lọc danh sách (TT-01)', () => {
  it('trạng thái trống không gửi bộ lọc nào', () => {
    expect(buildUpsaleFilters(EMPTY_UPSALE_STATE)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildUpsaleFilters({ ...EMPTY_UPSALE_STATE, search: '  My ' })).toEqual({ q: 'My' });
  });
  it('một giai đoạn thì gửi, nhiều giai đoạn cùng nhóm thì không gửi', () => {
    expect(buildUpsaleFilters({ ...EMPTY_UPSALE_STATE, quick: { stage: ['L2'] } })).toEqual({
      stage_code: 'L2',
    });
    expect(buildUpsaleFilters({ ...EMPTY_UPSALE_STATE, quick: { stage: ['L2', 'L3'] } })).toEqual(
      {},
    );
  });
  it('mã lạ bị bỏ', () => {
    expect(
      buildUpsaleFilters({ ...EMPTY_UPSALE_STATE, quick: { stage: ['X9'], owner: ['ai-do'] } }),
    ).toEqual({});
  });
  it('người phụ trách và cờ rủi ro', () => {
    expect(
      buildUpsaleFilters({
        ...EMPTY_UPSALE_STATE,
        quick: { owner: ['unassigned'], risk: ['risk'] },
      }),
    ).toEqual({
      owner: 'unassigned',
      risk: true,
    });
  });
  it('điều kiện cơ sở và tháng (chỉ nhận YYYY-MM)', () => {
    const state = {
      ...EMPTY_UPSALE_STATE,
      conditions: [
        { id: 'a', field: 'branch', op: 'eq' as const, value: 'cs-uuid' },
        { id: 'b', field: 'month', op: 'eq' as const, value: '2026-10' },
      ],
    };
    expect(buildUpsaleFilters(state)).toEqual({ branch_id: 'cs-uuid', campaign_month: '2026-10' });
    expect(
      buildUpsaleFilters({
        ...state,
        conditions: [{ id: 'b', field: 'month', op: 'eq' as const, value: '10/2026' }],
      }),
    ).toEqual({});
  });
});
