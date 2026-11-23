import { describe, expect, it } from 'vitest';
import {
  cleanLines,
  conflictCells,
  initialLines,
  isContentEditable,
  isDirty,
  NO_LINES_MESSAGE,
  saveBlocker,
} from './sessionContent';

describe('Nội dung buổi (GV-06, R-V2-35)', () => {
  it('bỏ dòng trống và cắt khoảng trắng', () => {
    expect(cleanLines(['  Bài 1 ', '', '   ', 'Bài 2'])).toEqual(['Bài 1', 'Bài 2']);
  });

  it('luôn có ít nhất một ô nhập', () => {
    expect(initialLines([])).toEqual(['']);
    expect(initialLines(['A'])).toEqual(['A']);
  });

  it('chặn lưu khi không có dòng nội dung, BTVN để trống không chặn', () => {
    expect(saveBlocker(['', '  '])).toBe(NO_LINES_MESSAGE);
    expect(saveBlocker(['Bài 1'])).toBeNull();
  });

  it('buổi Kiểm tra lưu được khi không có dòng nội dung (Q-252)', () => {
    expect(saveBlocker([''], 'DIEM')).toBeNull();
    expect(saveBlocker([''], 'CHINH')).toBe(NO_LINES_MESSAGE);
  });

  it('chưa sửa gì thì không bẩn; dòng trống thêm vào không tính là sửa', () => {
    const saved = { lines: ['A', 'B'], homework: null };
    expect(isDirty(saved, { lines: ['A', 'B'], homework: '' })).toBe(false);
    expect(isDirty(saved, { lines: ['A', 'B', ''], homework: '  ' })).toBe(false);
  });

  it('sửa dòng hoặc BTVN thì bẩn', () => {
    const saved = { lines: ['A'], homework: 'Bài 6' };
    expect(isDirty(saved, { lines: ['A2'], homework: 'Bài 6' })).toBe(true);
    expect(isDirty(saved, { lines: ['A'], homework: '' })).toBe(true);
  });

  it('chỉ sửa được khi buổi Nháp hoặc Đã chốt', () => {
    expect(isContentEditable('NHAP')).toBe(true);
    expect(isContentEditable('DA_CHOT')).toBe(true);
    expect(isContentEditable('DONE')).toBe(false);
    expect(isContentEditable('HUY_CO_PHI')).toBe(false);
  });
});

describe('GV-06: hộp hai người cùng sửa (GV06_xung_dot)', () => {
  it('chỉ liệt kê ô khác nhau, bỏ qua dòng trống và khoảng trắng', () => {
    expect(
      conflictCells(
        { lines: ['Bài 1', ''], homework: ' Bài 6 ' },
        { lines: ['Bài 1'], homework: 'Bài 6' },
      ),
    ).toEqual([]);
    const cells = conflictCells(
      { lines: ['Bài 1', 'Bài 2'], homework: 'A' },
      { lines: ['Bài 1'], homework: null },
    );
    expect(cells.map((c) => c.key)).toEqual(['lines', 'homework']);
    expect(cells[0]).toMatchObject({ mine: 'Bài 1; Bài 2', theirs: 'Bài 1' });
    expect(cells[1]).toMatchObject({ mine: 'A', theirs: '' });
  });
});
