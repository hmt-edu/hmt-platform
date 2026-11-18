import { describe, expect, it } from 'vitest';
import {
  dayChip,
  defaultDay,
  groupByDay,
  mondayOf,
  timeAndRoom,
  typeLabel,
  typeTone,
  weekDays,
  weekLabel,
} from './scheduleLogic';
import type { MySession } from './todayLogic';

const s = (
  id: string,
  date: string,
  start: string,
  end: string,
  extra: Partial<MySession> = {},
): MySession => ({
  session_id: id,
  class_id: 'c',
  class_code: 'L1',
  subject_name: 'Toán',
  session_no: 1,
  session_date: date,
  start_time: start,
  end_time: end,
  type_code: 'CHINH',
  status_code: 'DA_CHOT',
  my_role: 'GIAO_VIEN',
  has_content: false,
  deadline_at: '2026-10-24T16:30:00Z',
  pending_reason: null,
  ...extra,
});

describe('GV-03: khung tuần', () => {
  it('Thứ Hai của tuần: mọi ngày trong tuần về cùng một Thứ Hai (kể cả Chủ Nhật)', () => {
    expect(mondayOf('2026-10-12')).toBe('2026-10-12'); // Thứ Hai
    expect(mondayOf('2026-10-15')).toBe('2026-10-12');
    expect(mondayOf('2026-10-18')).toBe('2026-10-12'); // Chủ Nhật 18/10 vẫn thuộc tuần 12–18/10
    expect(mondayOf('2026-11-01')).toBe('2026-10-26'); // qua tháng
  });
  it('bảy ngày, nhãn tuần, nút ngày', () => {
    expect(weekDays('2026-10-26')).toEqual([
      '2026-10-26',
      '2026-10-27',
      '2026-10-28',
      '2026-10-29',
      '2026-10-30',
      '2026-10-31',
      '2026-11-01',
    ]);
    expect(weekLabel('2026-10-12')).toBe('12/10 – 18/10');
    expect(weekLabel('2026-10-26')).toBe('26/10 – 01/11');
    expect(dayChip('2026-10-18')).toEqual({ weekday: 'CN', day: '18' });
    expect(dayChip('2026-10-12')).toEqual({ weekday: 'T2', day: '12' });
  });
  it('chia buổi theo ngày, xếp theo giờ; ngày trống là mảng rỗng; buổi ngoài tuần bị bỏ', () => {
    const days = weekDays('2026-10-12');
    const g = groupByDay(
      [
        s('b', '2026-10-13', '19:30:00', '21:00:00'),
        s('a', '2026-10-13', '08:00:00', '09:30:00'),
        s('c', '2026-10-18', '09:00:00', '10:30:00'),
        s('x', '2026-10-19', '09:00:00', '10:00:00'),
      ],
      days,
    );
    expect(g['2026-10-13']?.map((x) => x.session_id)).toEqual(['a', 'b']);
    expect(g['2026-10-18']?.map((x) => x.session_id)).toEqual(['c']);
    expect(g['2026-10-12']).toEqual([]);
    expect(Object.keys(g)).toHaveLength(7);
  });
  it('loại buổi: chữ luôn có, màu theo loại, loại lạ trung tính', () => {
    expect(
      typeLabel(
        s('a', '2026-10-12', '08:00:00', '09:00:00', {
          session_type_name: 'Buổi củng cố',
          type_code: 'CUNG_CO',
        }),
      ),
    ).toBe('Buổi củng cố');
    expect(typeLabel(s('a', '2026-10-12', '08:00:00', '09:00:00'))).toBe('CHINH'); // máy chủ chưa trả tên: dùng mã
    expect(typeTone('CHINH')).not.toBe(typeTone('CUNG_CO'));
    expect(typeTone('LA')).toBe('neutral');
  });
  it('giờ và phòng; ngày mặc định', () => {
    expect(timeAndRoom(s('a', '2026-10-12', '08:00:00', '09:30:00', { room_name: 'P.201' }))).toBe(
      '08:00–09:30 · P.201',
    );
    expect(timeAndRoom(s('a', '2026-10-12', '08:00:00', '09:30:00', { room_name: null }))).toBe(
      '08:00–09:30',
    );
    const days = weekDays('2026-10-12');
    expect(defaultDay(days, '2026-10-14')).toBe('2026-10-14');
    expect(defaultDay(days, '2026-11-20')).toBe('2026-10-12');
  });
});
