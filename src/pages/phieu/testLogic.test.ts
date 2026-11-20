import { describe, expect, it } from 'vitest';
import {
  ACTIONS_BY_STATUS,
  STEP_BACK_TARGET,
  createTestText,
  defaultReminder,
  formatScore,
  parseScore,
  stepBackNeedsReason,
} from './testLogic';

const SETTINGS = { timeMinutes: 1020, shortWindowHours: 24, shortLeadHours: 2 };
// 0 giờ giờ Việt Nam của 15/10/2026 = 14/10/2026 17:00 UTC.
const DAY15 = new Date('2026-10-14T17:00:00Z');

describe('nút theo trạng thái', () => {
  it('Nháp: bắt đầu, đổi lịch, huỷ, sửa', () => {
    expect(ACTIONS_BY_STATUS.DRAFT).toEqual(['start', 'reschedule', 'cancel', 'edit']);
  });
  it('chỉ Nháp mới đổi lịch được (R-CRM-05, DB chặn)', () => {
    for (const s of ['TESTING', 'TEACHER_REVIEW', 'COMPLETED', 'CANCELLED'] as const) {
      expect(ACTIONS_BY_STATUS[s]).not.toContain('reschedule');
    }
  });
  it('phiếu Huỷ chỉ mở lại được', () => {
    expect(ACTIONS_BY_STATUS.CANCELLED).toEqual(['reopen']);
  });
  it('phiếu Hoàn thành vẫn nhập lại kết quả, sửa; muốn huỷ phải về Nháp trước (anh chốt 18/10)', () => {
    expect(ACTIONS_BY_STATUS.COMPLETED).toEqual(['enter-result', 'step-back', 'edit']);
  });
});

describe('lùi bước (R-CRM-21)', () => {
  it('đích của từng bước lùi', () => {
    expect(STEP_BACK_TARGET.TESTING).toBe('DRAFT');
    expect(STEP_BACK_TARGET.TEACHER_REVIEW).toBe('TESTING');
    expect(STEP_BACK_TARGET.COMPLETED).toBe('DRAFT');
    expect(STEP_BACK_TARGET.DRAFT).toBeUndefined();
  });
  it('chỉ Hoàn thành về Nháp bắt lý do', () => {
    expect(stepBackNeedsReason('COMPLETED')).toBe(true);
    expect(stepBackNeedsReason('TESTING')).toBe(false);
    expect(stepBackNeedsReason('TEACHER_REVIEW')).toBe(false);
  });
});

describe('giờ nhắc mặc định (cùng công thức app.test_reminder_time)', () => {
  it('test xa: 17:00 ngày hôm trước ngày test', () => {
    const now = new Date('2026-10-12T03:00:00Z');
    const testAt = new Date('2026-10-15T11:00:00Z'); // 18:00 ngày 15
    expect(defaultReminder(testAt, now, DAY15, SETTINGS).toISOString()).toBe(
      '2026-10-14T10:00:00.000Z',
    ); // 17:00 ngày 14
  });
  it('test trong 24 giờ tới: nhắc trước 2 giờ', () => {
    const now = new Date('2026-10-15T01:00:00Z');
    const testAt = new Date('2026-10-15T11:00:00Z');
    expect(defaultReminder(testAt, now, DAY15, SETTINGS).toISOString()).toBe(
      '2026-10-15T09:00:00.000Z',
    );
  });
  it('giờ nhắc tính ra đã qua thì nhắc ngay (không sớm hơn lúc tạo)', () => {
    const now = new Date('2026-10-14T11:00:00Z'); // 18:00 ngày 14, sau 17:00
    const testAt = new Date('2026-10-15T11:00:00Z'); // đúng 24 giờ sau: vào khung ngắn → 9:00 ngày 15, hợp lệ
    expect(defaultReminder(testAt, now, DAY15, SETTINGS).getTime()).toBeGreaterThanOrEqual(
      now.getTime(),
    );
  });
  it('luôn trước giờ test ít nhất một phút', () => {
    const now = new Date('2026-10-15T10:59:30Z');
    const testAt = new Date('2026-10-15T11:00:00Z');
    expect(
      testAt.getTime() - defaultReminder(testAt, now, DAY15, SETTINGS).getTime(),
    ).toBeGreaterThanOrEqual(60_000);
  });
});

describe('điểm (R-CRM-10: 0–10, một chữ số thập phân)', () => {
  it('nhận "7,5", "7.5", "10", "0"', () => {
    expect(parseScore('7,5')).toBe(7.5);
    expect(parseScore('7.5')).toBe(7.5);
    expect(parseScore('10')).toBe(10);
    expect(parseScore('0')).toBe(0);
  });
  it('từ chối ngoài thang, quá một chữ số thập phân, không phải số', () => {
    expect(parseScore('10,5')).toBeNull();
    expect(parseScore('11')).toBeNull();
    expect(parseScore('7,55')).toBeNull();
    expect(parseScore('abc')).toBeNull();
    expect(parseScore('')).toBeNull();
    expect(parseScore('-1')).toBeNull();
  });
  it('hiện điểm kiểu Việt Nam', () => {
    expect(formatScore(7.5)).toBe('7,5/10');
    expect(formatScore(null)).toBe('');
  });
});

describe('chữ hộp Tạo phiếu kiểm tra (So canvas TS-15)', () => {
  it('dòng gợi ý Người phụ trách và dòng nhắc bật nút Tạo phiếu đúng khung TS15_hop', () => {
    expect(createTestText.ownerHelp).toBe(
      'Mặc định là người tạo phiếu; nhận lịch hẹn nhắc và theo dõi lịch test.',
    );
    expect(createTestText.submitHint).toBe('Chọn Ngày test và Giờ test để bật nút Tạo phiếu.');
    expect(createTestText.emHelp).toBe(
      'Chưa thấy em? Đóng hộp này và bấm + Thêm em ở cột Thông tin học sinh.',
    );
  });
});
