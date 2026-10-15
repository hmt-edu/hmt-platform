import { describe, expect, it } from 'vitest';
import {
  foldText,
  formatDate,
  formatDateTime,
  formatMoney,
  formatWhen,
  parseMoney,
} from './format';

describe('định dạng', () => {
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
