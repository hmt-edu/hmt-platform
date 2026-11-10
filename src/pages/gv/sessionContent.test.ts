import { describe, expect, it } from 'vitest';
import {
  cleanLines,
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
    expect(saveBlocker([''], 'KIEM_TRA')).toBeNull();
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
