import { describe, expect, it } from 'vitest';
import {
  attendanceText,
  homeworkSessions,
  nextSession,
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
  it('nhãn hạn: chỉ Trễ hạn có chữ; buổi Done/còn hạn không nhãn', () => {
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

describe('nextSession (GV-11 Buổi tiếp theo)', () => {
  const mk = (date: string, status: string) =>
    ({ id: date + status, session_date: date, status_code: status }) as never;
  it('bỏ buổi Huỷ và Hoàn thành, lấy buổi còn dạy sớm nhất', () => {
    const list = [
      mk('2026-12-07', 'HUY_KHONG_PHI'),
      mk('2026-12-09', 'NHAP'),
      mk('2026-11-30', 'DONE'),
    ];
    expect(nextSession(list, '2026-11-30')?.session_date).toBe('2026-12-09');
  });
  it('buổi hôm nay chưa chốt vẫn là buổi tiếp theo; không còn buổi thì không có', () => {
    expect(nextSession([mk('2026-11-30', 'DA_CHOT')], '2026-11-30')?.session_date).toBe(
      '2026-11-30',
    );
    expect(
      nextSession([mk('2026-11-29', 'NHAP'), mk('2026-12-01', 'HUY_CO_PHI')], '2026-11-30'),
    ).toBeUndefined();
  });
});
