import { describe, expect, it } from 'vitest';
import { EMPTY_AUDIT_STATE } from './auditConfig';
import { buildAuditFilters, summarizeChanges } from './auditLogic';

describe('QT-11 nhật ký thao tác', () => {
  it('tóm tắt sửa: cột cũ → mới, gộp phần dư', () => {
    const text = summarizeChanges({
      action: 'U',
      changes: { a: [1, 2], b: [null, 'x'], c: ['p', 'q'], d: [1, 2] },
    });
    expect(text).toBe('a: 1 → 2; b: (trống) → x; c: p → q; và 1 trường khác');
  });
  it('tóm tắt tạo và xoá', () => {
    expect(summarizeChanges({ action: 'I', changes: null })).toBe('Tạo mới');
    expect(summarizeChanges({ action: 'D', changes: { id: 'x' } })).toBe('Đã xoá bản ghi');
  });
  it('bộ lọc: bảng, loại thao tác, mã bản ghi, ngày', () => {
    const id = '123e4567-e89b-12d3-a456-426614174000';
    const f = buildAuditFilters({
      ...EMPTY_AUDIT_STATE,
      search: id,
      quick: { action: ['U'] },
      conditions: [
        { id: '1', field: 'table', op: 'eq', value: 'lead' },
        { id: '2', field: 'at', op: 'from', value: '2026-11-10' },
        { id: '3', field: 'at', op: 'to', value: '2026-11-10' },
      ],
    });
    expect(f).toMatchObject({ record_id: id, action: 'U', table: 'lead' });
    expect(new Date(String(f.to)).getTime() - new Date(String(f.from)).getTime()).toBe(86_400_000);
  });
  it('chọn cả ba loại thì không lọc loại', () => {
    expect(buildAuditFilters({ ...EMPTY_AUDIT_STATE, quick: { action: ['I', 'U', 'D'] } })).toEqual(
      {},
    );
  });
});
