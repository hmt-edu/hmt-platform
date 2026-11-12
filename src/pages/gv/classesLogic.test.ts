import { describe, expect, it } from 'vitest';
import {
  capacityText,
  classTitle,
  isTeaching,
  nextByClass,
  nextText,
  scheduleText,
} from './classesLogic';
import type { MySession } from './todayLogic';

const s = (cls: string, date: string, start: string, status = 'DA_CHOT'): MySession => ({
  session_id: `${cls}${date}${start}`,
  class_id: cls,
  class_code: cls,
  subject_name: 'Toán',
  session_no: 1,
  session_date: date,
  start_time: start,
  end_time: '21:00:00',
  type_code: 'CHINH',
  status_code: status,
  my_role: 'GIAO_VIEN',
  has_content: false,
  deadline_at: '2026-10-24T16:30:00Z',
  pending_reason: null,
});

describe('GV-10: lớp của tôi', () => {
  it('buổi tiếp theo của mỗi lớp là buổi sớm nhất chưa Done; lớp không có buổi thì không có khoá', () => {
    const m = nextByClass([
      s('A', '2026-10-28', '19:30:00'),
      s('A', '2026-10-26', '19:30:00'),
      s('A', '2026-10-25', '08:00:00', 'DONE'),
      s('B', '2026-10-27', '18:00:00'),
    ]);
    expect(m.get('A')?.session_date).toBe('2026-10-26');
    expect(m.get('B')?.session_date).toBe('2026-10-27');
    expect(m.get('C')).toBeUndefined();
    expect(nextText(m.get('A'))).toBe('Buổi tiếp theo: Thứ Hai 26/10 19:30');
    expect(nextText(undefined)).toBe('Chưa có buổi sắp tới');
  });
  it('sĩ số: có giới hạn hiện x/y, không giới hạn hiện x', () => {
    expect(capacityText({ enrolled: 18, max_students: 20 })).toBe('Sĩ số 18/20');
    expect(capacityText({ enrolled: 5, max_students: 0 })).toBe('Sĩ số 5');
    expect(capacityText({ enrolled: 0, max_students: null })).toBe('Sĩ số 0');
  });
  it('lịch học, tên lớp, lớp còn dạy', () => {
    expect(
      scheduleText({
        schedule: [
          { weekday: 1, start_time: '18:00:00', end_time: '19:30:00' },
          { weekday: 4, start_time: '18:00:00', end_time: '19:30:00' },
        ],
      }),
    ).toBe('T2 18:00–19:30 · T5 18:00–19:30');
    expect(classTitle({ subject_name: 'Toán', class_type_name: 'Cơ bản', level_name: null })).toBe(
      'Toán · Cơ bản',
    );
    expect(isTeaching({ operating_status: 'DANG_HOC' })).toBe(true);
    expect(isTeaching({ operating_status: null })).toBe(true);
    expect(isTeaching({ operating_status: 'DA_KET_THUC' })).toBe(false);
  });
});
