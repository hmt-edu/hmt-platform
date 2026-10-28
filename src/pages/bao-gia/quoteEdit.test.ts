import { describe, expect, it } from 'vitest';
import {
  blankRow,
  buildSaveLines,
  modesOfPrices,
  parseQuantity,
  pruneIssues,
  rowsFromRecord,
  rowsSignature,
  validateRows,
  type EditRow,
} from './quoteEdit';
import type { QuotationLine } from './quoteTypes';

const LINE = {
  id: 'l1',
  line_no: 1,
  line_kind: 'ENROL',
  prospect_student_id: 'ps1',
  package_id: 'pk1',
  package_code: 'LC-TOAN-K09',
  package_name: 'Toán 9 · Lớp chung',
  package_type_code: 'LC',
  delivery_mode_code: 'OFF',
  unit_code: 'GIO',
  quantity: 10,
  gifted_quantity: 0,
  unit_price: 220000,
  gross_amount: 2200000,
  discount_percent: 5,
  gift_percent: 0,
  discount_amount: 110000,
  line_total: 2090000,
  over_cap: false,
  needs_acknowledgement: false,
  student_name: 'Em Một',
  student_birth_year: 2012,
  student_code: null,
  student_complete: true,
  gift_policy_id: null,
  gift_policy_name: null,
  order_id: null,
  order_code: null,
  order_status_code: null,
  discounts: [
    {
      id: 'd1',
      policy_id: 'pol1',
      policy_code: 'GIAM_6_THANG',
      policy_name: 'Giảm khi đóng 6 tháng',
      kind: 'PERCENT',
      applied_value: 5,
      requires_approval: false,
    },
  ],
} as QuotationLine;

describe('quoteEdit', () => {
  it('đọc số lượng người gõ: dấu phẩy, hai chữ số thập phân, không âm', () => {
    expect(parseQuantity('10')).toBe(10);
    expect(parseQuantity(' 1,5 ')).toBe(1.5);
    expect(parseQuantity('2.25')).toBe(2.25);
    expect(parseQuantity('')).toBeNull();
    expect(parseQuantity('0')).toBeNull();
    expect(parseQuantity('abc')).toBeNull();
    expect(parseQuantity('1,234')).toBeNull();
    expect(parseQuantity('-3')).toBeNull();
  });

  it('dòng sửa từ bản ghi giữ em, gói, hình thức, số lượng và chính sách đã lưu', () => {
    const [row] = rowsFromRecord({ lines: [LINE] });
    expect(row).toMatchObject({
      studentId: 'ps1',
      packageId: 'pk1',
      mode: 'OFF',
      quantity: '10',
      unitCode: 'GIO',
    });
    expect(row?.discounts).toEqual([{ policyId: 'pol1', name: 'Giảm khi đóng 6 tháng', value: 5 }]);
    expect(row?.calc?.lineTotal).toBe(2090000);
  });

  it('số lượng thập phân hiện bằng dấu phẩy, bỏ số 0 thừa', () => {
    expect(rowsFromRecord({ lines: [{ ...LINE, quantity: 1.5 }] })[0]?.quantity).toBe('1,5');
    expect(rowsFromRecord({ lines: [{ ...LINE, quantity: 20 }] })[0]?.quantity).toBe('20');
  });

  it('dựng dòng lưu: em, gói, hình thức, số lượng số, chính sách giữ nguyên', () => {
    const rows = rowsFromRecord({ lines: [LINE] });
    expect(buildSaveLines(rows)).toEqual([
      {
        kind: 'ENROL',
        prospect_student_id: 'ps1',
        package_id: 'pk1',
        delivery_mode_code: 'OFF',
        quantity: 10,
        discounts: [{ policy_id: 'pol1', value: 5 }],
      },
    ]);
  });

  it('dòng trống gửi null để máy chủ báo đúng dòng', () => {
    expect(buildSaveLines([blankRow()])[0]).toMatchObject({
      prospect_student_id: null,
      package_id: null,
      delivery_mode_code: null,
      quantity: null,
    });
  });

  it('thiếu số lượng ở dòng đã chọn gói: lỗi theo khung, nêu dòng, mã và tên gói', () => {
    const rows: EditRow[] = [
      {
        ...blankRow(),
        packageId: 'pk1',
        packageCode: 'LC-TOAN-K08',
        packageName: 'Toán 8 · Lớp chung',
      },
    ];
    const issues = validateRows(rows);
    expect(issues).toHaveLength(1);
    expect(issues[0]?.message).toBe('Bắt buộc nhập số lượng.');
    expect(issues[0]?.summary).toBe('Dòng 1 (LC-TOAN-K08 · Toán 8 · Lớp chung) thiếu số lượng.');
  });

  it('dòng chưa chọn gói không báo thiếu số lượng (máy chủ báo chọn gói)', () => {
    expect(validateRows([blankRow()])).toEqual([]);
  });

  it('đổi dòng thì chữ ký đổi; đổi số tính sẵn hay khoá nội bộ thì không', () => {
    const rows = rowsFromRecord({ lines: [LINE] });
    const sig = rowsSignature(rows);
    expect(rowsSignature(rowsFromRecord({ lines: [LINE] }))).toBe(sig);
    const changed = rows.map((r) => ({ ...r, quantity: '12' }));
    expect(rowsSignature(changed)).not.toBe(sig);
    expect(rowsSignature(rows.map((r) => ({ ...r, calc: null })))).toBe(sig);
  });

  it('hình thức của gói: OFF trước ONL, chỉ hình thức có giá', () => {
    expect(modesOfPrices({ ONL: 120000, OFF: 220000 })).toEqual(['OFF', 'ONL']);
    expect(modesOfPrices({ ONL: 300000 })).toEqual(['ONL']);
  });

  it('lỗi thiếu số lượng tự mất khi nhập số hợp lệ, dòng khác giữ lỗi', () => {
    const a = { ...blankRow(), packageId: 'p1', packageCode: 'A', packageName: 'Gói A' };
    const b = { ...blankRow(), packageId: 'p2', packageCode: 'B', packageName: 'Gói B' };
    const issues = validateRows([a, b]);
    expect(issues).toHaveLength(2);
    const fixed = pruneIssues(issues, [{ ...a, quantity: '5' }, b]);
    expect(fixed.map((i) => i.rowKey)).toEqual([b.key]);
    expect(
      pruneIssues(fixed, [
        { ...a, quantity: '5' },
        { ...b, quantity: '1,5' },
      ]),
    ).toEqual([]);
    // Xoá lại ô thì không tự báo lỗi mới trước khi bấm Lưu.
    expect(pruneIssues([], [a, b])).toEqual([]);
  });
});
