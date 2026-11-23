import { describe, expect, it } from 'vitest';
import { formatScore, homeworkRate, shortDate } from './portalResults';

describe('Kết quả học tập cổng học sinh: định dạng (HT-07)', () => {
  it('điểm dùng dấu phẩy thập phân, chưa có điểm thì «–»', () => {
    expect(formatScore(4.2)).toBe('4,2');
    expect(formatScore(5)).toBe('5,0');
    expect(formatScore(null)).toBe('–');
  });

  it('tỉ lệ làm BTVN làm tròn phần trăm; chưa có buổi nào thì null', () => {
    expect(homeworkRate({ has: true, done: 5, total: 6, avg_score: 4 })).toBe(83);
    expect(homeworkRate({ has: false, done: 0, total: 0, avg_score: null })).toBeNull();
  });

  it('ngày ngắn dd/mm từ yyyy-mm-dd', () => {
    expect(shortDate('2026-11-19')).toBe('19/11');
  });
});
