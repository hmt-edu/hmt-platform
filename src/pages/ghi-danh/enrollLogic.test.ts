import { describe, expect, it } from 'vitest';
import {
  dateKey,
  defaultStart,
  disabledReason,
  keyToDate,
  seatsText,
  startHint,
  upcomingLabel,
  weekdayLabel,
} from './enrollLogic';
import type { MatchingClass } from './enrollTypes';

const cls: MatchingClass = {
  id: 'c',
  code: 'CS1-2627-DAI-K08-CB-A-001',
  subject_name: 'Đại số',
  class_type_name: 'cơ bản',
  level_name: 'A',
  grade_code: 'K08',
  group_id: null,
  group_name: null,
  schedule_text: 'Thứ 3 18:00–19:30',
  teacher_name: null,
  seats_left: 4,
  has_sessions: true,
  class_start_date: '2026-10-06',
  weekdays: [2, 4],
  upcoming: [{ date: '2026-11-03', session_no: 8 }],
  clash_sessions: 0,
};

describe('Hộp chọn lớp: chữ và gợi ý', () => {
  it('thứ trong tuần theo kiểu Việt', () => {
    expect(weekdayLabel(1)).toBe('Thứ 2');
    expect(weekdayLabel(6)).toBe('Thứ 7');
    expect(weekdayLabel(7)).toBe('Chủ nhật');
  });
  it('nhãn buổi sắp tới có thứ và số buổi', () => {
    expect(upcomingLabel('2026-11-03', 8)).toBe('03/11 · Thứ 3, buổi 8');
    expect(upcomingLabel('2026-11-08', null)).toBe('08/11 · Chủ nhật');
  });
  it('ngày vào lớp gợi ý là buổi sắp tới đầu tiên, lớp chưa có buổi thì trống', () => {
    expect(defaultStart(cls)).toBe('2026-11-03');
    expect(defaultStart({ ...cls, upcoming: [], has_sessions: false })).toBe('');
  });
  it('lý do mờ khi trùng buổi, không có thì null (lớp luân phiên máy chủ trả 0)', () => {
    expect(disabledReason({ ...cls, clash_sessions: 3 })).toBe('Trùng 3 buổi với lớp em đang học');
    expect(disabledReason(cls)).toBeNull();
  });
  it('chữ sĩ số', () => {
    expect(seatsText(cls)).toBe('Còn 4 chỗ');
    expect(seatsText({ ...cls, seats_left: null })).toBe('Không giới hạn sĩ số');
  });
  it('gợi ý ngày cho lớp chưa có buổi', () => {
    expect(startHint({ ...cls, has_sessions: false })).toBe(
      'Lớp chưa có buổi: chọn ngày đúng Thứ 3, Thứ 5, không trước 06/10/2026.',
    );
  });
  it('đổi qua lại ngày và chuỗi yyyy-mm-dd', () => {
    expect(dateKey(new Date(2026, 10, 3))).toBe('2026-11-03');
    expect(keyToDate('2026-11-03')?.getDate()).toBe(3);
    expect(keyToDate('')).toBeNull();
  });
});
