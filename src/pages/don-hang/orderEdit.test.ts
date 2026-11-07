import { describe, expect, it } from 'vitest';
import { allRemoved, buildEdits, draftOf, hasChanges, lineError } from './orderEdit';
import type { OrderLine } from './orderTypes';

const line = (over: Partial<OrderLine>): OrderLine =>
  ({
    id: 'l1',
    line_no: 1,
    line_kind: 'ENROL',
    delivery_mode_code: 'OFF',
    quantity: 10,
    discounts: [{ policy_id: 'p5', applied_value: 5, kind: 'PERCENT' }],
    ...over,
  }) as OrderLine;
const fixed = new Set(['p5']);

describe('orderEdit', () => {
  const lines = [line({}), line({ id: 'l2', line_no: 2, discounts: [] })];
  it('nháp ban đầu giống bản ghi: không có thay đổi', () => {
    const draft = draftOf({ lines }, 't1', fixed);
    expect(buildEdits(lines, draft, fixed)).toEqual([]);
    expect(hasChanges(lines, draft, 't1', fixed)).toBe(false);
  });
  it('chỉ gửi phần đổi: số giờ, hình thức, chính sách, bỏ dòng', () => {
    const draft = draftOf({ lines }, 't1', fixed);
    draft.lines[1] = { ...draft.lines[1]!, quantity: 20 };
    draft.lines[2] = { ...draft.lines[2]!, removed: true };
    expect(buildEdits(lines, draft, fixed)).toEqual([
      { line_no: 1, quantity: 20 },
      { line_no: 2, remove: true },
    ]);
    const d2 = draftOf({ lines }, 't1', fixed);
    d2.lines[1] = { ...d2.lines[1]!, mode: 'ONL', discounts: [] };
    expect(buildEdits(lines, d2, fixed)).toEqual([
      { line_no: 1, delivery_mode_code: 'ONL', discounts: [] },
    ]);
  });
  it('chính sách cố định không cần giá trị; chính sách nhập tay đổi giá trị thì tính là đổi', () => {
    const varLine = line({
      discounts: [{ policy_id: 'p10', applied_value: 10, kind: 'PERCENT' }] as never,
    });
    const draft = draftOf({ lines: [varLine] }, 't1', fixed);
    expect(buildEdits([varLine], draft, fixed)).toEqual([]);
    draft.lines[1] = { ...draft.lines[1]!, discounts: [{ policy_id: 'p10', value: 8 }] };
    expect(buildEdits([varLine], draft, fixed)).toHaveLength(1);
  });
  it('đổi điều khoản là có thay đổi', () => {
    const draft = draftOf({ lines }, 't1', fixed);
    expect(hasChanges(lines, { ...draft, termId: 't2' }, 't1', fixed)).toBe(true);
  });
  it('lỗi tại chỗ: số giờ 0 hoặc trống; không bỏ hết dòng', () => {
    expect(lineError({ quantity: 0, mode: 'OFF', discounts: [], removed: false })).not.toBeNull();
    expect(
      lineError({ quantity: null, mode: 'OFF', discounts: [], removed: false }),
    ).not.toBeNull();
    expect(lineError({ quantity: 5, mode: 'OFF', discounts: [], removed: false })).toBeNull();
    const draft = draftOf({ lines }, 't1', fixed);
    expect(allRemoved(draft)).toBe(false);
    for (const k of [1, 2]) draft.lines[k] = { ...draft.lines[k]!, removed: true };
    expect(allRemoved(draft)).toBe(true);
  });
});
