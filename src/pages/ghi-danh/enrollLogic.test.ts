import { describe, expect, it } from 'vitest';
import {
  dateKey,
  enrollmentNotice,
  deliveryMismatchWarning,
  defaultStart,
  disabledReason,
  keyToDate,
  seatsText,
  startHint,
  upcomingLabel,
  weekdayLabel,
  parseHours,
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

describe('parseHours (GD-05: số giờ điều chỉnh)', () => {
  it('đọc số dương, số âm, dấu phẩy thập phân', () => {
    expect(parseHours('2')).toBe(2);
    expect(parseHours('-1,5')).toBe(-1.5);
    expect(parseHours(' +0.5 ')).toBe(0.5);
  });
  it('không nhận 0, chữ hay ô trống (bị chặn)', () => {
    expect(parseHours('0')).toBeNull();
    expect(parseHours('')).toBeNull();
    expect(parseHours('hai')).toBeNull();
  });
});

describe('deliveryMismatchWarning (xếp lớp lệch hình thức: chỉ cảnh báo, anh Trường chốt 20/11)', () => {
  it('lớp Offline nhận ghi danh Online: cảnh báo, câu ghi rõ không chặn', () => {
    expect(deliveryMismatchWarning('OFF', 'ONL')).toMatch(
      /Lớp học Offline, ghi danh Online.*vẫn xếp được/,
    );
  });
  it('lớp Online nhận ghi danh Offline: cảnh báo', () => {
    expect(deliveryMismatchWarning('ONL', 'OFF')).not.toBeNull();
  });
  it('lớp OMO nhận cả hai: không cảnh báo', () => {
    expect(deliveryMismatchWarning('OMO', 'OFF')).toBeNull();
    expect(deliveryMismatchWarning('OMO', 'ONL')).toBeNull();
  });
  it('cùng hình thức hoặc thiếu dữ liệu: không cảnh báo', () => {
    expect(deliveryMismatchWarning('OFF', 'OFF')).toBeNull();
    expect(deliveryMismatchWarning(undefined, 'OFF')).toBeNull();
    expect(deliveryMismatchWarning('OFF', null)).toBeNull();
  });
});

describe('enrollmentNotice (GD-02: câu giải thích theo tình trạng và quỹ giờ)', () => {
  const h = (remaining: number, granted = 24, gifted = 0) => ({ granted, gifted, remaining });
  it('Chờ xếp lớp: nhắc bấm Xếp lớp', () => {
    expect(enrollmentNotice('CHO_XEP_LOP', h(24))?.text).toMatch(/Bấm Xếp lớp/);
  });
  it('Đang học hết giờ: báo chặn điểm danh trừ giờ (R-GD-18), tông cảnh báo', () => {
    const n = enrollmentNotice('DANG_HOC', h(0));
    expect(n?.title).toBe('Quỹ giờ bằng 0.');
    expect(n?.text).toMatch(/R-GD-18/);
    expect(n?.tone).toBe('warning');
  });
  it('Đang học còn giờ: không có câu', () => {
    expect(enrollmentNotice('DANG_HOC', h(28))).toBeNull();
  });
  it('Quỹ âm (học trước): câu R-GD-12 kèm số giờ âm', () => {
    const n = enrollmentNotice('DANG_HOC', h(-3, 0));
    expect(n?.title).toBe('Đang học trước, chưa đóng tiền.');
    expect(n?.text).toMatch(/hiện −3 giờ/);
  });
  it('Quỹ 0 mà chưa từng cấp giờ: không báo hết giờ', () => {
    expect(enrollmentNotice('DANG_HOC', h(0, 0, 0))).toBeNull();
  });
  it('Bảo lưu và Hoàn phí có câu riêng', () => {
    expect(enrollmentNotice('BAO_LUU', h(15))?.text).toMatch(/R-GD-09/);
    expect(enrollmentNotice('HOAN_PHI', h(0))?.title).toBe('Ghi danh đã hoàn phí.');
  });
});

describe('GD-02, GD-03: số liệu từ hàm đọc (migration 591)', () => {
  const h = { granted: 0, gifted: 0, remaining: -3 };
  it('học trước: nêu hạn mức buổi và giờ khi máy chủ trả, thiếu thì dùng câu theo tham số', () => {
    const n = enrollmentNotice('DANG_HOC', {
      ...h,
      negative_limit_sessions: 2,
      negative_limit_hours: 3,
    });
    expect(n?.text).toContain('tối đa 2 buổi (3 giờ), hiện −3 giờ');
    expect(enrollmentNotice('DANG_HOC', h)?.text).toContain('«Cho học trước tối đa»');
  });
  it('bảo lưu nêu ngày bắt đầu, kết thúc; hoàn phí nêu mã phiếu chi', () => {
    expect(
      enrollmentNotice(
        'BAO_LUU',
        { ...h, remaining: 15 },
        { holdStart: '2026-10-01', holdEnd: '2026-10-31' },
      )?.title,
    ).toBe('Đang bảo lưu 01/10/2026 đến 31/10/2026.');
    expect(enrollmentNotice('HOAN_PHI', h, { refundVoucher: 'PC-1' })?.text).toContain(
      'phiếu chi PC-1',
    );
  });
  it('lớp trùng buổi: nêu ngày, giờ, lớp khi có clash_first', () => {
    const c = {
      ...cls,
      clash_sessions: 1,
      clash_first: {
        date: '2026-11-03',
        start_time: '18:00:00',
        end_time: '19:30:00',
        class_code: 'L1',
      },
    };
    expect(disabledReason(c)).toContain('Trùng buổi 03/11/2026, 18:00–19:30 với lớp L1');
  });
});
