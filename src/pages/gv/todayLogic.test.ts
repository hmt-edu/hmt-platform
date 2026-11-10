import { describe, expect, it } from 'vitest';
import {
  addDays,
  endsAt,
  formatDayHeading,
  formatDeadline,
  formatNextSession,
  hoursLeftText,
  sessionTitle,
  urgentSessions,
  type MySession,
} from './todayLogic';

const base: MySession = {
  session_id: 'x',
  class_id: 'c',
  class_code: 'CS5-2627-HINH-K09-CB-A-001',
  subject_name: 'Hình học',
  session_no: 6,
  session_date: '2026-10-24',
  start_time: '14:00:00',
  end_time: '15:30:00',
  type_code: 'CHINH',
  status_code: 'DA_CHOT',
  my_role: 'GIAO_VIEN',
  has_content: false,
  deadline_at: '2026-10-24T16:30:00Z',
  pending_reason: null,
};

describe('GV-02: chữ hiển thị', () => {
  it('tiêu đề ngày có thứ', () => {
    expect(formatDayHeading('2026-10-24')).toBe('Thứ Bảy 24/10');
    expect(formatDayHeading('2026-10-25')).toBe('Chủ Nhật 25/10');
  });
  it('cộng ngày qua tháng', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2026-11-10', 60)).toBe('2027-01-09');
  });
  it('tên buổi: môn, mã lớp, số buổi', () => {
    expect(sessionTitle(base)).toBe('Hình học · CS5-2627-HINH-K09-CB-A-001 · Buổi 6');
    expect(sessionTitle({ ...base, subject_name: null, session_no: null })).toBe(
      'CS5-2627-HINH-K09-CB-A-001',
    );
  });
  it('hạn cùng ngày chỉ ghi giờ, sang ngày khác ghi cả ngày (giờ Việt Nam)', () => {
    // 16:30Z = 23:30 giờ Việt Nam ngày 24/10; 20:30Z = 03:30 ngày 25/10.
    expect(formatDeadline('2026-10-24T16:30:00Z', '2026-10-24')).toBe('hạn 23:30');
    expect(formatDeadline('2026-10-24T20:30:00Z', '2026-10-24')).toBe('hạn 25/10 03:30');
  });
  it('còn bao nhiêu giờ làm tròn lên, tối thiểu 1', () => {
    const now = new Date('2026-10-24T15:30:00Z');
    expect(hoursLeftText('2026-10-24T16:30:00Z', now)).toBe('Còn 1 giờ');
    expect(hoursLeftText('2026-10-24T20:30:00Z', now)).toBe('Còn 5 giờ');
    expect(hoursLeftText('2026-10-24T15:40:00Z', now)).toBe('Còn 1 giờ');
  });
  it('buổi tiếp theo', () => {
    expect(formatNextSession({ session_date: '2026-10-26', start_time: '19:30:00' })).toBe(
      'Thứ Hai 26/10 19:30',
    );
  });
});

describe('GV-02: nhóm sắp trễ hạn (R-V2-37, R-GV-05)', () => {
  // Kết thúc 15:30 giờ Việt Nam = 08:30Z.
  it('ghép ngày và giờ kết thúc thành thời điểm theo giờ Việt Nam', () => {
    expect(endsAt(base).toISOString()).toBe('2026-10-24T08:30:00.000Z');
  });
  const now = new Date('2026-10-24T12:00:00Z'); // 19:00 giờ Việt Nam
  const ended = { ...base, session_id: 'ended' };
  it('đã kết thúc, chưa Done, còn hạn thì vào nhóm', () => {
    expect(urgentSessions([ended], now).map((s) => s.session_id)).toEqual(['ended']);
  });
  it('chưa kết thúc thì không vào nhóm', () => {
    const later = { ...base, session_id: 'later', end_time: '21:30:00' };
    expect(urgentSessions([later], now)).toEqual([]);
  });
  it('đã Done thì không vào nhóm', () => {
    expect(urgentSessions([{ ...ended, status_code: 'DONE' }], now)).toEqual([]);
  });
  it('quá hạn thì không vào nhóm; hạn đúng bằng bây giờ cũng là quá hạn', () => {
    expect(urgentSessions([{ ...ended, deadline_at: '2026-10-24T11:59:59Z' }], now)).toEqual([]);
    expect(urgentSessions([{ ...ended, deadline_at: '2026-10-24T12:00:00Z' }], now)).toEqual([]);
    expect(urgentSessions([{ ...ended, deadline_at: '2026-10-24T12:00:01Z' }], now)).toHaveLength(
      1,
    );
  });
  it('xếp theo hạn gần nhất trước', () => {
    const a = { ...ended, session_id: 'a', deadline_at: '2026-10-24T20:00:00Z' };
    const b = { ...ended, session_id: 'b', deadline_at: '2026-10-24T14:00:00Z' };
    expect(urgentSessions([a, b], now).map((s) => s.session_id)).toEqual(['b', 'a']);
  });
});
