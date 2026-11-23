import { describe, expect, it } from 'vitest';
import {
  foldText,
  formatDate,
  formatDateTime,
  formatMoney,
  formatMonth,
  formatWhen,
  parseMoney,
} from './format';

describe('định dạng', () => {
  it('tháng: mm/yyyy theo giờ Việt Nam (TT-02 Đã mua gần nhất)', () => {
    expect(formatMonth('2026-05-31T18:00:00Z')).toBe('06/2026');
    expect(formatMonth(null)).toBe('');
  });
  it('tiền: dấu chấm ngăn nghìn, đuôi "đ"', () => {
    expect(formatMoney(9504000)).toBe('9.504.000 đ');
    expect(formatMoney(0)).toBe('0 đ');
    expect(formatMoney(null)).toBe('');
  });

  it('đọc số tiền người dùng gõ', () => {
    expect(parseMoney('9.504.000 đ')).toBe(9504000);
    expect(parseMoney('')).toBeNull();
  });

  it('ngày dd/mm/yyyy, giờ 24h, theo giờ Việt Nam', () => {
    // 17:30 UTC ngày 11/10 là 00:30 ngày 12/10 ở Việt Nam.
    expect(formatDate('2026-10-11T17:30:00Z')).toBe('12/10/2026');
    expect(formatDateTime('2026-10-11T17:30:00Z')).toBe('12/10/2026 00:30');
    expect(formatDateTime('2026-10-11T07:05:00Z')).toBe('11/10/2026 14:05');
    expect(formatDate(null)).toBe('');
  });

  it('trong ngày thì ghi "hôm nay"', () => {
    const now = new Date('2026-10-12T03:00:00Z');
    expect(formatWhen('2026-10-12T02:42:00Z', now)).toBe('09:42 hôm nay');
    expect(formatWhen('2026-10-10T02:42:00Z', now)).toBe('10/10/2026 09:42');
  });

  it('gấp chữ để tìm không dấu (khớp app.fold_text)', () => {
    expect(foldText('Đặng Quốc Huy')).toBe('dang quoc huy');
  });
});

describe('ngày dd/mm/yyyy nhập tay', () => {
  it('chèn dấu / khi gõ số và bỏ ký tự lạ', async () => {
    const { maskDmy } = await import('./dateText');
    expect(maskDmy('0')).toBe('0');
    expect(maskDmy('051')).toBe('05/1');
    expect(maskDmy('05102026')).toBe('05/10/2026');
    expect(maskDmy('05/10/2026999')).toBe('05/10/2026');
    expect(maskDmy('ab05')).toBe('05');
  });

  it('đọc chặt: sai định dạng hoặc ngày không có thật thì null', async () => {
    const { parseDmy, formatDmy, fromIsoDate, toIsoDate } = await import('./dateText');
    expect(formatDmy(parseDmy('05/10/2026'))).toBe('05/10/2026');
    expect(parseDmy('31/02/2026')).toBeNull();
    expect(parseDmy('5/10/2026')).toBeNull();
    expect(parseDmy('2026-10-05')).toBeNull();
    expect(toIsoDate(parseDmy('05/10/2026') as Date)).toBe('2026-10-05');
    expect(formatDmy(fromIsoDate('2026-10-05'))).toBe('05/10/2026');
  });
});
