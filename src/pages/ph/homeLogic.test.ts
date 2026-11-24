import { describe, expect, it } from 'vitest';
import {
  attentionLine,
  attentionTitle,
  hoursText,
  lastSessionText,
  newReviewsText,
  type HomeChild,
} from './homeLogic';

const child = (over: Partial<HomeChild> = {}): HomeChild => ({
  id: 'a',
  full_name: 'Em A',
  classes: ['L1'],
  hours_left: 3,
  is_low: true,
  projected_end: null,
  last_session: null,
  new_reviews: 0,
  ...over,
});

describe('PH-01 trang chủ phụ huynh', () => {
  it('giờ hiện một chữ số thập phân', () => {
    expect(hoursText(3)).toBe('3,0 giờ');
  });
  it('giờ thấp có ngày hết dự kiến thì ghi ngày', () => {
    expect(
      attentionLine({
        kind: 'GIO_THAP',
        student_id: 'a',
        student_name: 'Em A',
        hours_left: 3,
        projected_end: '2026-12-05',
      }),
    ).toBe('Còn 3,0 giờ · dự kiến hết 05/12');
  });
  it('giờ thấp chưa có lịch thì không ghi ngày dự kiến', () => {
    expect(
      attentionLine({
        kind: 'GIO_THAP',
        student_id: 'a',
        student_name: 'Em A',
        hours_left: 1.5,
        projected_end: null,
      }),
    ).toBe('Còn 1,5 giờ');
  });
  it('đề nghị ghi bước trên 4', () => {
    const it4 = {
      kind: 'DE_NGHI',
      ticket_id: 't',
      title: 'Đổi giờ',
      student_id: null,
      step: 2,
      updated_at: '2026-11-21T03:00:00Z',
    } as const;
    expect(attentionLine(it4)).toBe('Bước 2/4 · cập nhật 21/11');
    expect(attentionTitle(it4)).toBe('Đổi giờ');
  });
  it('buổi gần nhất: có và chưa có', () => {
    expect(lastSessionText(child())).toBe('Chưa có');
    expect(
      lastSessionText(
        child({ last_session: { date: '2026-11-19', class_code: 'L1', status_name: 'Có mặt' } }),
      ),
    ).toBe('19/11 · L1 · Có mặt');
    expect(
      lastSessionText(
        child({ last_session: { date: '2026-11-19', class_code: 'L1', status_name: null } }),
      ),
    ).toBe('19/11 · L1');
  });
  it('nhận xét mới', () => {
    expect(newReviewsText(0)).toBe('Chưa có');
    expect(newReviewsText(2)).toBe('2 nhận xét');
  });
});
