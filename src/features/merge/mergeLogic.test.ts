import { describe, expect, it } from 'vitest';
import {
  afterMergeNote,
  dialogTitle,
  keepAndMerge,
  matchSentence,
  moreItems,
  moveLines,
} from './mergeLogic';

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

describe('KH-07 gộp phụ huynh, học sinh', () => {
  it('tiêu đề và câu mô tả theo loại hồ sơ', () => {
    expect(dialogTitle('PARENT')).toBe('Gộp phụ huynh trùng');
    expect(dialogTitle('STUDENT')).toBe('Gộp học sinh trùng');
    expect(matchSentence('PARENT', '0912 000 121')).toContain(
      'Hai phụ huynh cùng SĐT 0912 000 121',
    );
    expect(matchSentence('STUDENT', '0912 000 121')).toContain('Hai học sinh cùng phụ huynh');
  });
  it('chỉ liệt kê nhóm dữ liệu có dòng, theo thứ tự cố định', () => {
    expect(moveLines({ notes: 2, orders: 1, students: 0, balance_entries: 3 })).toEqual([
      { label: 'Đơn hàng', count: 1 },
      { label: 'Dòng số dư khách hàng', count: 3 },
      { label: 'Ghi chú', count: 2 },
    ]);
    expect(moveLines({})).toEqual([]);
  });
});
