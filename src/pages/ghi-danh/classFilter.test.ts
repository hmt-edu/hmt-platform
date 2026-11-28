// Bộ lọc lớp trong hộp xếp lớp (A-27-22).
import { describe, expect, it } from 'vitest';

import { filterClasses, initialClassFilter } from './enrollLogic';
import type { MatchingClass } from './enrollTypes';

const cls = (id: string, over: Partial<MatchingClass>) =>
  ({ id, subject_name: 'Đại số', grade_code: 'K09', level_name: 'A', ...over }) as MatchingClass;
const list = [
  cls('off', { delivery_mode_code: 'OFF' }),
  cls('onl', { delivery_mode_code: 'ONL', level_name: 'B' }),
  cls('omo', { delivery_mode_code: 'OMO', subject_name: 'Hình học' }),
];
const ALL = { subject: '', grade: '', level: '', mode: '' };
const ids = (c: MatchingClass[]) => c.map((x) => x.id);

describe('lọc lớp khi xếp', () => {
  it('để «Tất cả» thì giữ đủ; lọc nhiều ô cùng lúc thì phải khớp hết', () => {
    expect(ids(filterClasses(list, ALL))).toEqual(['off', 'onl', 'omo']);
    expect(ids(filterClasses(list, { ...ALL, level: 'A', subject: 'Đại số' }))).toEqual(['off']);
    expect(filterClasses(list, { ...ALL, grade: 'K10' })).toEqual([]);
  });
  it('lọc hình thức vẫn giữ lớp OMO', () => {
    expect(ids(filterClasses(list, { ...ALL, mode: 'OFF' }))).toEqual(['off', 'omo']);
  });
  it('điền sẵn hình thức của ghi danh, trừ khi không lớp nào hợp', () => {
    expect(initialClassFilter(list, 'OFF').mode).toBe('OFF');
    expect(initialClassFilter([cls('onl', { delivery_mode_code: 'ONL' })], 'OFF').mode).toBe('');
    expect(initialClassFilter(list, null).mode).toBe('');
  });
});
