import { describe, expect, it } from 'vitest';
import { moveLesson, nextLessonCode, type Lesson } from './lessonLogic';

const mk = (n: number): Lesson => ({
  id: `id${n}`,
  position: n,
  code: `K-B0${n}`,
  title: `Bài ${n}`,
  hint: null,
});

describe('đổi thứ tự bài (CH-06)', () => {
  const ls = [mk(1), mk(2), mk(3)];
  it('xuống một bậc', () => expect(moveLesson(ls, 0, 1)).toEqual(['id2', 'id1', 'id3']));
  it('lên một bậc', () => expect(moveLesson(ls, 2, -1)).toEqual(['id1', 'id3', 'id2']));
  it('ra ngoài biên thì giữ nguyên', () => {
    expect(moveLesson(ls, 0, -1)).toEqual(['id1', 'id2', 'id3']);
    expect(moveLesson(ls, 2, 1)).toEqual(['id1', 'id2', 'id3']);
  });
});

describe('mã bài sắp cấp', () => {
  it('số lớn nhất cộng một, không phụ thuộc thứ tự hiện tại', () => {
    expect(nextLessonCode('K', [{ code: 'K-B03' }, { code: 'K-B01' }, { code: 'K-B02' }])).toBe(
      'K-B04',
    );
  });
  it('khung chưa có bài thì -B01', () => expect(nextLessonCode('K', [])).toBe('K-B01'));
});
