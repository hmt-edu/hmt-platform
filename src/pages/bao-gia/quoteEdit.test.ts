import { describe, expect, it } from 'vitest';
import {
  addFamilyRows,
  blankRow,
  buildSaveLines,
  flexibleLimitIssues,
  giftRow,
  insertPackageRow,
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
      policy_name: 'Giảm khi đóng lộ trình',
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
    expect(row?.discounts).toEqual([
      { policyId: 'pol1', name: 'Giảm khi đóng lộ trình', value: '5' },
    ]);
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

  it('mức chiết khấu hoặc giờ tặng gõ sai thì báo ở dòng, mức hợp lệ hoặc để trống thì không', () => {
    const base = {
      ...blankRow(),
      packageId: 'p1',
      quantity: '10',
      packageCode: 'A',
      packageName: 'Gói A',
    };
    const disc = (value: string) => [{ policyId: 'pol', name: 'Giảm', value }];
    expect(validateRows([{ ...base, discounts: disc('abc') }])[0]?.message).toBe(
      'Mức ưu đãi hoặc giờ tặng không hợp lệ.',
    );
    expect(validateRows([{ ...base, discounts: disc('') }])).toEqual([]);
    expect(validateRows([{ ...base, discounts: disc('7,5') }])).toEqual([]);
  });

  it('dựng dòng lưu: mức để trống gửi null (máy chủ lấy mức tối đa), mức gõ gửi số', () => {
    const row = {
      ...blankRow(),
      packageId: 'p1',
      mode: 'OFF',
      quantity: '10',
      studentId: 's1',
      discounts: [
        { policyId: 'a', name: 'A', value: '' },
        { policyId: 'b', name: 'B', value: '7,5' },
      ],
    };
    expect(buildSaveLines([row])[0]?.discounts).toEqual([
      { policy_id: 'a', value: null },
      { policy_id: 'b', value: 7.5 },
    ]);
  });

  const POLICY = {
    id: 'g1',
    name: 'Tặng sổ tay công thức',
    gift_package: {
      id: 'tl1',
      code: 'TL-SOTAY-K09',
      name: 'Sổ tay công thức Toán 9',
      package_type_code: 'TL',
      unit_code: 'BO' as const,
    },
  };

  it('dòng quà tặng mới: gắn chính sách, gói quà, chưa chọn em, số lượng để trống', () => {
    const row = giftRow(POLICY);
    expect(row).toMatchObject({
      kind: 'GIFT',
      giftPolicyId: 'g1',
      packageCode: 'TL-SOTAY-K09',
      unitCode: 'BO',
      studentId: '',
      quantity: '',
    });
  });

  it('dựng dòng lưu của quà: kind GIFT, em, chính sách quà, số lượng; không có gói, hình thức, chiết khấu', () => {
    const row = { ...giftRow(POLICY), studentId: 's1', quantity: '1' };
    expect(buildSaveLines([row])[0]).toEqual({
      kind: 'GIFT',
      prospect_student_id: 's1',
      gift_policy_id: 'g1',
      quantity: 1,
    });
  });

  it('quà thiếu số lượng báo lỗi theo khung, nêu mã và tên gói quà', () => {
    const issues = validateRows([giftRow(POLICY)]);
    expect(issues[0]?.message).toBe('Bắt buộc nhập số lượng.');
    expect(issues[0]?.summary).toContain('TL-SOTAY-K09');
  });

  it('dòng gói mới đặt trước các dòng quà (quà đánh số tiếp theo dòng gói)', () => {
    const a = blankRow();
    const g = giftRow(POLICY);
    const fresh = blankRow();
    expect(insertPackageRow([a, g], fresh).map((r) => r.key)).toEqual([a.key, fresh.key, g.key]);
    expect(insertPackageRow([a], fresh).map((r) => r.key)).toEqual([a.key, fresh.key]);
  });
});

describe('flexibleLimitIssues (Ưu đãi linh hoạt vượt hạn mức, Q-151)', () => {
  const policies = [
    { id: 'flex', is_flexible: true, max_value: 5 },
    { id: 'fix', max_value: 10 },
  ];
  const rowWith = (discounts: { policyId: string; value: string }[]): EditRow => ({
    ...blankRow(),
    discounts: discounts.map((d) => ({ ...d, name: 'x' })),
  });
  it('trong hạn mức hoặc đúng hạn mức: hợp lệ', () => {
    expect(flexibleLimitIssues([rowWith([{ policyId: 'flex', value: '3' }])], policies)).toEqual(
      [],
    );
    expect(flexibleLimitIssues([rowWith([{ policyId: 'flex', value: '5' }])], policies)).toEqual(
      [],
    );
  });
  it('vượt hạn mức: câu lỗi nêu hạn mức thật, đúng dòng', () => {
    const rows = [rowWith([]), rowWith([{ policyId: 'flex', value: '5,5' }])];
    const found = flexibleLimitIssues(rows, policies);
    expect(found).toHaveLength(1);
    expect(found[0]?.rowKey).toBe(rows[1]?.key);
    expect(found[0]?.message).toBe('Ưu đãi linh hoạt tối đa 5%');
  });
  it('chính sách thường vượt max_value không bị chặn ở đây; ô trống hoặc chữ sai bỏ qua', () => {
    expect(flexibleLimitIssues([rowWith([{ policyId: 'fix', value: '50' }])], policies)).toEqual(
      [],
    );
    expect(flexibleLimitIssues([rowWith([{ policyId: 'flex', value: '' }])], policies)).toEqual([]);
    expect(flexibleLimitIssues([rowWith([{ policyId: 'flex', value: 'abc' }])], policies)).toEqual(
      [],
    );
  });
  it('gõ dấu phẩy: 5,5 vượt hạn mức 5; 1,5 hợp lệ và gửi máy chủ đúng 1.5', () => {
    expect(
      flexibleLimitIssues([rowWith([{ policyId: 'flex', value: '5,5' }])], policies),
    ).toHaveLength(1);
    const ok = rowWith([{ policyId: 'flex', value: '1,5' }]);
    expect(flexibleLimitIssues([ok], policies)).toEqual([]);
    expect(buildSaveLines([ok])[0]?.discounts).toEqual([{ policy_id: 'flex', value: 1.5 }]);
  });
});

describe('addFamilyRows (Thêm cả nhà, BH02_chon)', () => {
  it('thêm dòng trống cho mỗi em chưa có dòng, bỏ qua em đã có dòng gói', () => {
    const existing = { ...blankRow(), studentId: 'a' };
    const out = addFamilyRows([existing], ['a', 'b', 'c']);
    expect(out.map((r) => r.studentId)).toEqual(['a', 'b', 'c']);
    expect(out.slice(1).every((r) => r.packageId === '' && r.kind === 'ENROL')).toBe(true);
  });
  it('đã đủ mọi em thì không thêm; dòng quà tặng nằm cuối', () => {
    const gift = { ...blankRow(), kind: 'GIFT' as const };
    const out = addFamilyRows([{ ...blankRow(), studentId: 'a' }, gift], ['a', 'b']);
    expect(out.map((r) => `${r.kind}:${r.studentId}`)).toEqual(['ENROL:a', 'ENROL:b', 'GIFT:']);
    expect(addFamilyRows(out, ['a', 'b'])).toEqual(out);
  });
});
