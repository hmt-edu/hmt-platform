import { describe, expect, it } from 'vitest';
import { amountInWords } from './amountInWords';

describe('amountInWords (số tiền bằng chữ, bản in K13)', () => {
  it.each([
    [13608000, 'Mười ba triệu sáu trăm lẻ tám nghìn đồng'],
    [0, 'Không đồng'],
    [1000, 'Một nghìn đồng'],
    [15000, 'Mười lăm nghìn đồng'],
    [21000, 'Hai mươi mốt nghìn đồng'],
    [24000, 'Hai mươi tư nghìn đồng'],
    [105000, 'Một trăm lẻ năm nghìn đồng'],
    [1000050, 'Một triệu không trăm năm mươi đồng'],
    [4752000, 'Bốn triệu bảy trăm năm mươi hai nghìn đồng'],
    [2000000000, 'Hai tỷ đồng'],
    [1000000001, 'Một tỷ không trăm lẻ một đồng'],
  ])('%i → %s', (value, expected) => {
    expect(amountInWords(value)).toBe(expected);
  });

  it('số âm hoặc không nguyên thì để trống', () => {
    expect(amountInWords(-1)).toBe('');
    expect(amountInWords(1.5)).toBe('');
  });
});
