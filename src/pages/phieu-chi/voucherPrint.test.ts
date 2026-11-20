import { describe, expect, it } from 'vitest';
import type { VoucherRecord } from './voucherTypes';
import { voucherPrintRows } from './voucherPrint';

// So luật TC-12 (R-TIEN-28): bản in hiện đủ các dòng của bảng tính hoàn, số lấy từ máy chủ. Số trong bài là số giả.
const base = {
  kind_code: 'TOAN_BO',
  paid_amount: 1_000_000,
  hours_used: 2,
  unit_price_base: 100_000,
  hours_refund: 0,
  unit_price_net: 0,
  base_amount: 800_000,
  fee_percent: 10,
  fee_amount: 80_000,
  refund_amount: 720_000,
} as unknown as VoucherRecord['refund'];

describe('bản in phiếu chi: các dòng tính hoàn (TC-12)', () => {
  it('hoàn toàn bộ: đã đóng, giờ đã học × giá gốc, còn lại, phí, số hoàn', () => {
    const rows = voucherPrintRows(base);
    expect(rows.map((r) => r.key)).toEqual(['paid', 'used', 'base', 'fee', 'refund']);
    expect(rows.map((r) => r.amount)).toEqual([1_000_000, -200_000, 800_000, -80_000, 720_000]);
  });

  it('hoàn một phần: giờ hoàn × giá sau chiết khấu thay hai dòng đầu', () => {
    const rows = voucherPrintRows({
      ...base,
      kind_code: 'MOT_PHAN',
      hours_refund: 4,
      unit_price_net: 200_000,
    });
    expect(rows.map((r) => r.key)).toEqual(['hours', 'base', 'fee', 'refund']);
    expect(rows[0]?.label).toContain('4 giờ');
  });
});
