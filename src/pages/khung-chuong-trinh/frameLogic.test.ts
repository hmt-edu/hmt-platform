import { describe, expect, it } from 'vitest';
import { frameCodePreview, nextVersion, yearLabel, yearOptions } from './frameLogic';

describe('mã khung dự kiến (spec 02)', () => {
  it('bản đầu không hậu tố, bản kế thêm -v2, -v3', () => {
    expect(frameCodePreview('TOAN', 'K03', 'CB', '2627', 1)).toBe('TOAN-K03-CB-2627');
    expect(frameCodePreview('TOAN', 'K03', 'CB', '2627', 2)).toBe('TOAN-K03-CB-2627-v2');
    expect(frameCodePreview('DAI', 'K08', 'NC', '2627', 3)).toBe('DAI-K08-NC-2627-v3');
  });
  it('số bản kế tiếp: chưa có thì bản 1, đã có thì lớn nhất cộng một', () => {
    expect(nextVersion([])).toBe(1);
    expect(nextVersion([{ version: 1 }, { version: 3 }, { version: 2 }])).toBe(4);
  });
});

describe('năm học', () => {
  it('đổi mã sang nhãn', () => {
    expect(yearLabel('2627')).toBe('2026–2027');
    expect(yearLabel('xx')).toBe('xx');
  });
  it('danh sách năm quanh năm hiện tại, mã đúng hai năm liền nhau', () => {
    const o = yearOptions(2026);
    expect(o.map((x) => x.value)).toEqual(['2526', '2627', '2728', '2829']);
    expect(o[1]?.label).toBe('2026–2027');
  });
});
