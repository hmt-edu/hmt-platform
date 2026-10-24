import { describe, expect, it } from 'vitest';
import { afterMergeNote, keepAndMerge, matchSentence, moreItems } from './mergeLogic';

describe('keepAndMerge', () => {
  it('chưa chọn bản kia thì chưa có cặp', () => {
    expect(keepAndMerge('current', 'a', null)).toEqual({ keepId: null, mergeId: null });
  });
  it('giữ bản đang mở: bản kia gộp vào', () => {
    expect(keepAndMerge('current', 'a', 'b')).toEqual({ keepId: 'a', mergeId: 'b' });
  });
  it('giữ bản kia: bản đang mở gộp vào', () => {
    expect(keepAndMerge('other', 'a', 'b')).toEqual({ keepId: 'b', mergeId: 'a' });
  });
});

describe('câu chữ', () => {
  it('lead trùng theo SĐT, cơ hội theo phụ huynh', () => {
    expect(matchSentence('LEAD', '0912 000 121')).toContain('Hai lead cùng SĐT 0912 000 121');
    expect(matchSentence('OPPORTUNITY', '0912 000 121')).toContain('Hai cơ hội cùng phụ huynh');
  });
  it('nêu số mục không liệt kê hết', () => {
    expect(moreItems(8, 5)).toBe('và 3 mục nữa');
    expect(moreItems(5, 5)).toBeNull();
    expect(moreItems(0, 0)).toBeNull();
  });
  it('ghi chú cuối nêu mã hai bên', () => {
    const note = afterMergeNote('LD000001', 'LD000002');
    expect(note).toContain('LD000001 được giữ nguyên');
    expect(note).toContain('LD000002 chuyển sang trạng thái “Đã gộp”');
  });
});
