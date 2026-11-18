import { describe, expect, it } from 'vitest';
import { draftErrors, parseTestScore, submitErrors } from './testGrading';

const full = { score: '7.5', note: 'Khá', level: 'A', framework: 'CB' };

describe('GV-15 điểm test (R-CRM-10)', () => {
  it('chấp nhận 0, 10, một chữ số thập phân, dấu phẩy', () => {
    expect(parseTestScore('0').value).toBe(0);
    expect(parseTestScore('10').value).toBe(10);
    expect(parseTestScore('7,5').value).toBe(7.5);
  });
  it('chặn quá 10, hai chữ số thập phân, chữ', () => {
    expect(parseTestScore('10.1').error).not.toBeNull();
    expect(parseTestScore('7.25').error).not.toBeNull();
    expect(parseTestScore('abc').error).not.toBeNull();
    expect(parseTestScore('-1').error).not.toBeNull();
  });
  it('ô trống là chưa nhập, không phải 0', () => {
    expect(parseTestScore('  ')).toEqual({ value: null, error: null });
  });
});

describe('GV-15 Lưu nháp và Trả về sale', () => {
  it('Lưu nháp cho phép thiếu trình độ, phân loại', () => {
    expect(draftErrors({ ...full, level: '', framework: '', note: '' })).toEqual({});
  });
  it('Trả về sale cần đủ điểm, trình độ, phân loại, nhận xét', () => {
    expect(submitErrors(full)).toEqual({});
    expect(
      Object.keys(submitErrors({ score: '', note: '', level: '', framework: '' })).sort(),
    ).toEqual(['framework', 'level', 'note', 'score']);
  });
});
