// CH-09: mã từ tên, kiểm các đợt trước khi gửi (cùng luật create_payment_term), mô tả cách chia.
import { describe, expect, it } from 'vitest';
import {
  codeFromName,
  dateToIso,
  describeInstallments,
  installmentsError,
  shareLabel,
  termLabel,
  toPayload,
  type Draft,
} from './termLogic';

const pct = (value: string, dueDays = '0'): Draft => ({ mode: 'PERCENT', value, dueDays });
const fixed = (value: string, dueDays = '0'): Draft => ({ mode: 'FIXED', value, dueDays });

describe('CH-09 mã và ngày', () => {
  it('mã từ tên: hoa, không dấu, gạch dưới', () => {
    expect(codeFromName('Chia 3 đợt, đợt 1 là 30%')).toBe('CHIA_3_DOT_DOT_1_LA_30');
    expect(codeFromName('  Đóng một lần ')).toBe('DONG_MOT_LAN');
    expect(codeFromName('!!!')).toBe('');
  });
  it('ngày giờ địa phương về yyyy-mm-dd', () => {
    expect(dateToIso(new Date(2026, 0, 5))).toBe('2026-01-05');
  });
});

describe('CH-09 kiểm các đợt', () => {
  it('toàn % tổng đúng 100 thì hợp lệ', () => {
    expect(installmentsError([pct('30'), pct('30', '30'), pct('40', '60')])).toBeNull();
    expect(installmentsError([pct('100')])).toBeNull();
  });
  it('tổng % khác 100 thì báo đang bao nhiêu (khung CH09_loi)', () => {
    expect(installmentsError([pct('30'), pct('30', '30'), pct('30', '60')])).toBe(
      'Tổng phần trăm các đợt chia theo % phải đúng 100 (đang 90).',
    );
  });
  it('đợt 1 cọc cố định cộng các đợt % tổng 100 thì hợp lệ; thiếu đợt sau thì chặn', () => {
    expect(installmentsError([fixed('5000000'), pct('60', '30'), pct('40', '60')])).toBeNull();
    expect(installmentsError([fixed('5000000')])).not.toBeNull();
  });
  it('chỉ đợt 1 được cố định; giá trị rỗng, âm, ngày đến hạn lẻ thì chặn', () => {
    expect(installmentsError([pct('50'), fixed('1000')])).toBe(
      'Chỉ đợt 1 được là số tiền cố định.',
    );
    expect(installmentsError([pct(''), pct('100')])).toBe('Đợt 1: nhập giá trị lớn hơn 0.');
    expect(installmentsError([pct('100', '-1')])).toBe(
      'Đợt 1: số ngày đến hạn là số nguyên không âm.',
    );
    expect(installmentsError([pct('100', '1.5')])).not.toBeNull();
    expect(installmentsError([])).toBe('Cần ít nhất một đợt.');
  });
});

describe('CH-09 gửi và hiển thị', () => {
  it('payload đánh số từ 1, đợt 1 cố định có fixed_amount', () => {
    expect(toPayload([fixed('5000000'), pct('100', '30')])).toEqual([
      { seq: 1, share_percent: null, fixed_amount: 5000000, due_days: 0 },
      { seq: 2, share_percent: 100, fixed_amount: null, due_days: 30 },
    ]);
  });
  it('mô tả cách chia', () => {
    const i = (seq: number, share: number | null, amt: number | null) => ({
      seq,
      share_percent: share,
      fixed_amount: amt,
      due_days: 0,
    });
    expect(describeInstallments([i(1, 100, null)])).toBe('Đóng một lần');
    expect(describeInstallments([i(1, 30, null), i(2, 70, null)])).toBe('Chia 2 đợt');
    expect(describeInstallments([i(1, null, 5000000), i(2, 100, null)])).toBe(
      'Cọc 5.000.000 đ rồi 1 đợt',
    );
  });
  it('nhãn cách chia: sau cọc cố định là phần còn lại, toàn % là của tổng đơn', () => {
    expect(shareLabel({ seq: 2, share_percent: 60, fixed_amount: null, due_days: 0 }, true)).toBe(
      '% của phần còn lại sau đợt 1',
    );
    expect(shareLabel({ seq: 2, share_percent: 60, fixed_amount: null, due_days: 0 }, false)).toBe(
      '% của tổng đơn',
    );
    expect(shareLabel({ seq: 1, share_percent: null, fixed_amount: 1, due_days: 0 }, true)).toBe(
      'Số tiền cố định',
    );
  });
});

describe('Ô chọn điều khoản: tên ghép lịch đợt', () => {
  const inst = (seq: number, share: number | null, fixedAmount: number | null, days: number) => ({
    seq,
    share_percent: share,
    fixed_amount: fixedAmount,
    due_days: days,
  });
  it('chia phần trăm, số kiểu Việt', () => {
    expect(
      termLabel({
        name: 'Đặt cọc',
        installments: [inst(2, 66.67, null, 14), inst(1, 33.33, null, 0)],
      }),
    ).toBe('Đặt cọc · 33,33% + 66,67% sau 14 ngày');
  });
  it('đợt 1 số tiền cố định thì các đợt sau là phần còn lại', () => {
    expect(
      termLabel({ name: 'Cọc', installments: [inst(1, null, 1000000, 0), inst(2, 100, null, 30)] }),
    ).toBe('Cọc · 1.000.000 đ + 100% phần còn lại sau 30 ngày');
  });
  it('đóng ngay một lần hoặc chưa có lịch đợt thì chỉ hiện tên', () => {
    expect(termLabel({ name: 'Đóng một lần', installments: [inst(1, 100, null, 0)] })).toBe(
      'Đóng một lần',
    );
    expect(termLabel({ name: 'Đóng một lần' })).toBe('Đóng một lần');
  });
});
