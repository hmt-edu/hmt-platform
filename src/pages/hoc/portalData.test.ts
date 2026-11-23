import { describe, expect, it } from 'vitest';
import { groupSessionsByDay, timeRange, type PortalSession } from './portalData';

const base: PortalSession = {
  session_id: 'a',
  session_date: '2026-11-24',
  start_time: '18:00:00',
  end_time: '19:30:00',
  class_code: 'L1',
  subject_name: null,
  room_name: null,
  teacher_name: null,
  type_code: 'CHINH',
  type_name: null,
  status_code: 'NHAP',
  is_makeup: false,
};

describe('Lịch học cổng HT-06/PH-05', () => {
  it('gom buổi theo ngày, ngày không có buổi là mảng rỗng, bỏ buổi ngoài khoảng', () => {
    const g = groupSessionsByDay(
      [base, { ...base, session_id: 'b', session_date: '2026-12-31' }],
      ['2026-11-24', '2026-11-25'],
    );
    expect(g['2026-11-24']).toHaveLength(1);
    expect(g['2026-11-25']).toEqual([]);
    expect(g['2026-12-31']).toBeUndefined();
  });
  it('khoảng giờ bỏ giây', () => {
    expect(timeRange(base)).toBe('18:00 – 19:30');
  });
});

describe('Bài tập cổng HT-02', () => {
  it('nhãn hạn nộp theo công tắc nhận bài muộn (R-LMS-02)', async () => {
    const { dueNote } = await import('./portalData');
    expect(dueNote({ is_overdue: false, allow_late: false })).toBe('Hạn nộp');
    expect(dueNote({ is_overdue: true, allow_late: true })).toContain('vẫn nhận');
    expect(dueNote({ is_overdue: true, allow_late: false })).toContain('không nhận');
  });
});
