import { describe, expect, it } from 'vitest';
import type { WeekSession } from './classTypes';
import { addDays, buildRows, clashCount, groupColor, weekDays, weekStart } from './weekLogic';

const s = (over: Partial<WeekSession>): WeekSession => ({
  session_id: 'x',
  class_id: 'c',
  class_code: 'L1',
  group_id: null,
  session_date: '2026-11-17',
  start_time: '18:00:00',
  end_time: '19:30:00',
  status_code: 'DA_CHOT',
  type_code: 'CHINH',
  teacher_name: 'Cô Mai',
  assistant_name: null,
  room_id: 'r1',
  room_name: 'P201',
  room_clash: false,
  teacher_clash: false,
  ...over,
});

describe('Lịch tuần cơ sở (LOP-08)', () => {
  it('tuần bắt đầu từ thứ Hai, kể cả khi ngày rơi vào Chủ nhật', () => {
    expect(weekStart('2026-11-17')).toBe('2026-11-16'); // thứ Ba
    expect(weekStart('2026-11-16')).toBe('2026-11-16'); // thứ Hai
    expect(weekStart('2026-11-22')).toBe('2026-11-16'); // Chủ nhật
    expect(weekDays('2026-11-16')).toHaveLength(7);
    expect(addDays('2026-11-30', 1)).toBe('2026-12-01');
  });

  it('nhóm theo phòng: mỗi phòng một dòng, buổi trong ngày xếp theo giờ', () => {
    const days = weekDays('2026-11-16');
    const rows = buildRows(
      [
        s({ session_id: 'a', start_time: '19:00:00' }),
        s({ session_id: 'b', start_time: '08:00:00' }),
        s({ session_id: 'c', room_name: null }),
      ],
      days,
      'ROOM',
    );
    expect(rows.map((r) => r.label)).toEqual(['Chưa có phòng', 'P201']);
    expect(rows[1]?.cells[1]?.map((x) => x.session_id)).toEqual(['b', 'a']);
  });

  it('nhóm theo giáo viên', () => {
    const rows = buildRows([s({}), s({ teacher_name: null })], weekDays('2026-11-16'), 'TEACHER');
    expect(rows.map((r) => r.label)).toEqual(['Chưa có giáo viên', 'Cô Mai']);
  });

  it('hai lớp cùng nhóm cùng màu viền', () => {
    expect(groupColor('g1')).toBe(groupColor('g1'));
    expect(groupColor(null)).toBe('#9CA3AF');
  });

  it('đếm buổi bị cảnh báo trùng', () => {
    expect(clashCount([s({}), s({ room_clash: true }), s({ teacher_clash: true })])).toBe(2);
  });

  it('tuần qua ranh giới năm: Chủ nhật 03/01/2027 thuộc tuần bắt đầu 28/12/2026', () => {
    expect(weekStart('2027-01-03')).toBe('2026-12-28');
    expect(weekDays('2026-12-28')[6]).toBe('2027-01-03');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('màu viền theo nhóm cố định giữa các lần gọi; lớp không nhóm dùng màu trung tính', () => {
    expect(groupColor('g-123')).toBe(groupColor('g-123'));
    expect(groupColor(null)).toBe('#9CA3AF');
    expect(groupColor('g-123')).not.toBe('#9CA3AF');
  });

  it('không có buổi nào trùng thì đếm 0; trùng phòng và trùng giáo viên cùng buổi chỉ đếm một lần', () => {
    expect(clashCount([])).toBe(0);
    expect(clashCount([s({ session_id: 'a' }), s({ session_id: 'b' })])).toBe(0);
    expect(clashCount([s({ room_clash: true, teacher_clash: true })])).toBe(1);
  });
});
