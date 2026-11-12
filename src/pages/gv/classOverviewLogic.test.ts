import { describe, expect, it } from 'vitest';
import {
  attendanceText,
  homeworkSessions,
  scoreText,
  shortDate,
  slotText,
  timelinessLabel,
  type ClassOverview,
} from './classOverviewLogic';

const ses = (id: string, homework: string | null) =>
  ({
    id,
    session_no: 1,
    session_date: '2026-10-24',
    start_time: '18:00:00',
    end_time: '19:30:00',
    status_code: 'DONE',
    type_code: 'CHINH',
    type_name: null,
    deadline_at: 'x',
    timeliness: null,
    homework_text: homework,
  }) as ClassOverview['sessions'][number];

describe('GV-11: chữ hiển thị', () => {
  it('chuyên cần: có mặt/đã điểm danh; chưa điểm danh buổi nào thì báo rõ', () => {
    expect(attendanceText({ attendance_present: 3, attendance_marked: 4 })).toBe('Có mặt 3/4 buổi');
    expect(attendanceText({ attendance_present: 0, attendance_marked: 0 })).toBe('Chưa điểm danh');
  });
  it('điểm TB: một chữ số thập phân, dấu phẩy; null không phải 0 (R-GV-02)', () => {
    expect(scoreText(4)).toBe('TB 4,0');
    expect(scoreText(3.75)).toBe('TB 3,8');
    expect(scoreText(null)).toBe('Chưa có điểm');
  });
  it('nhãn hạn luôn có chữ; không có thì null', () => {
    expect(timelinessLabel('DUNG_HAN')).toBe('Đúng hạn');
    expect(timelinessLabel('TRE_HAN')).toBe('Trễ hạn');
    expect(timelinessLabel(null)).toBeNull();
  });
  it('lịch, ngày, BTVN', () => {
    expect(slotText({ weekday: 1, start_time: '18:00:00', end_time: '19:30:00' })).toBe(
      'Thứ Hai 18:00–19:30',
    );
    expect(slotText({ weekday: 0, start_time: '08:00:00', end_time: '09:30:00' })).toBe(
      'Chủ Nhật 08:00–09:30',
    );
    expect(shortDate('2026-10-24')).toBe('24/10');
    expect(
      homeworkSessions([ses('a', 'Bài 1'), ses('b', null), ses('c', '   ')]).map((x) => x.id),
    ).toEqual(['a']);
  });
});
