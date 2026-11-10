import { describe, expect, it } from 'vitest';
import {
  addedError,
  flexibleLimitError,
  withFlexibleMax,
  allRemoved,
  buildEdits,
  draftOf,
  hasChanges,
  lineError,
  type AddedLine,
} from './orderEdit';
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

  describe('thêm dòng khi sửa (Q-67)', () => {
    const added = (over: Partial<AddedLine> = {}): AddedLine => ({
      key: 'new-1',
      studentId: 's1',
      packageId: 'pk1',
      packageCode: 'LC-TOAN-K09',
      packageName: 'Toán 9',
      packageTypeCode: 'LC',
      discounts: [],
      mode: 'OFF',
      modes: ['OFF', 'ONL'],
      quantity: 4,
      ...over,
    });
    it('dòng mới hợp lệ gửi thành phần tử add sau các dòng cũ; chưa có em hoặc số lượng thì chưa gửi', () => {
      const draft = draftOf({ lines }, 't1', fixed);
      expect(draft.added).toEqual([]);
      expect(buildEdits(lines, draft, fixed)).toEqual([]);
      draft.added = [
        added(),
        added({ key: 'new-2', studentId: '' }),
        added({ key: 'new-3', quantity: null }),
      ];
      expect(buildEdits(lines, draft, fixed)).toEqual([
        {
          add: {
            kind: 'ENROL',
            prospect_student_id: 's1',
            package_id: 'pk1',
            delivery_mode_code: 'OFF',
            quantity: 4,
            discounts: [],
          },
        },
      ]);
      expect(hasChanges(lines, draft, 't1', fixed)).toBe(true);
    });
    it('Q-69: chiết khấu chọn lúc thêm dòng được gửi cùng phần tử add (máy chủ tính khi Lưu)', () => {
      const draft = draftOf({ lines }, 't1', fixed);
      draft.added = [
        added({
          discounts: [
            { policy_id: 'p6', value: null },
            { policy_id: 'p10', value: 8 },
          ],
        }),
      ];
      const [edit] = buildEdits(lines, draft, fixed);
      expect(edit).toMatchObject({
        add: {
          discounts: [
            { policy_id: 'p6', value: null },
            { policy_id: 'p10', value: 8 },
          ],
        },
      });
    });
    it('lỗi nhập: phải chọn em và số lượng lớn hơn 0', () => {
      expect(addedError(added())).toBeNull();
      expect(addedError(added({ studentId: '' }))).toBe('Chọn học sinh.');
      expect(addedError(added({ quantity: 0 }))).toBe('Nhập số lượng lớn hơn 0.');
      expect(addedError(added({ quantity: null }))).toBe('Nhập số lượng lớn hơn 0.');
    });
    it('bỏ hết dòng cũ nhưng còn dòng mới thêm thì đơn vẫn còn dòng', () => {
      const draft = draftOf({ lines }, 't1', fixed);
      for (const k of [1, 2]) draft.lines[k] = { ...draft.lines[k]!, removed: true };
      expect(allRemoved(draft)).toBe(true);
      draft.added = [added()];
      expect(allRemoved(draft)).toBe(false);
    });
  });
});

describe('flexibleLimitError (Ưu đãi linh hoạt vượt hạn mức, Q-151)', () => {
  const policies = [
    { id: 'flex', is_flexible: true, max_value: 5 },
    { id: 'fix', max_value: 10 },
  ];
  it('trong hạn mức, ô trống, chính sách thường: không lỗi', () => {
    expect(flexibleLimitError([{ policy_id: 'flex', value: 5 }], policies)).toBeNull();
    expect(flexibleLimitError([{ policy_id: 'flex', value: null }], policies)).toBeNull();
    expect(flexibleLimitError([{ policy_id: 'fix', value: 50 }], policies)).toBeNull();
  });
  it('vượt hạn mức: câu lỗi nêu hạn mức thật', () => {
    expect(flexibleLimitError([{ policy_id: 'flex', value: 5.5 }], policies)).toBe(
      'Ưu đãi linh hoạt tối đa 5%',
    );
  });
});

describe('withFlexibleMax (đọc hạn mức từ Cài đặt)', () => {
  const list = [
    { id: 'flex', is_flexible: true, max_value: 20 },
    { id: 'fix', max_value: 10 },
  ];
  it('đọc được: chỉ chính sách linh hoạt đổi max_value, kể cả số thập phân', () => {
    expect(withFlexibleMax(list, 2.5)).toEqual([
      { id: 'flex', is_flexible: true, max_value: 2.5 },
      { id: 'fix', max_value: 10 },
    ]);
  });
  it('Cài đặt lỗi (null): giữ nguyên max_value của chính sách', () => {
    expect(withFlexibleMax(list, null)).toEqual(list);
  });
  it('hạn mức thập phân 2,5: gõ 2,5 qua, gõ 2,6 bị chặn', () => {
    const p = withFlexibleMax(list, 2.5);
    expect(flexibleLimitError([{ policy_id: 'flex', value: 2.5 }], p)).toBeNull();
    expect(flexibleLimitError([{ policy_id: 'flex', value: 2.6 }], p)).toBe(
      'Ưu đãi linh hoạt tối đa 2,5%',
    );
  });
});
