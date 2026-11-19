import { describe, expect, it } from 'vitest';
import {
  buildSchedulePayload,
  EMPTY_SCHEDULE_DRAFT,
  sessionLabel,
  validateScheduleDraft,
} from './scheduleTaskForm';

const full = {
  ...EMPTY_SCHEDULE_DRAFT,
  sessionId: 's1',
  date: '2026-11-25',
  start: '18:00',
  end: '19:30',
  reason: 'Trùng lịch thi',
};

describe('scheduleTaskForm (phiếu Đổi lịch học, CS-11)', () => {
  it('Dời một buổi đủ dữ liệu thì không lỗi', () => {
    expect(validateScheduleDraft(full, true)).toEqual({});
  });
  it('thiếu từng ô thì báo tại ô', () => {
    const e = validateScheduleDraft(EMPTY_SCHEDULE_DRAFT, true);
    expect(Object.keys(e).sort()).toEqual(['date', 'end', 'reason', 'sessionId', 'start']);
  });
  it('giờ kết thúc không sau giờ bắt đầu thì báo', () => {
    expect(validateScheduleDraft({ ...full, end: '17:00' }, true).end).toBe(
      'Giờ kết thúc phải sau giờ bắt đầu.',
    );
  });
  it('ticket chưa gắn học sinh thì chặn', () => {
    expect(validateScheduleDraft(full, false).sessionId).toMatch(/chưa gắn học sinh/);
  });
  it('Đổi ca cố định chỉ cần lý do', () => {
    const draft = {
      ...EMPTY_SCHEDULE_DRAFT,
      action: 'DOI_CA' as const,
      reason: 'Đổi sang thứ Bảy',
    };
    expect(validateScheduleDraft(draft, true)).toEqual({});
    expect(buildSchedulePayload(draft)).toEqual({ action: 'DOI_CA', note: 'Đổi sang thứ Bảy' });
  });
  it('payload dời buổi và nhãn buổi', () => {
    expect(buildSchedulePayload(full)).toEqual({
      action: 'DOI_BUOI',
      session_id: 's1',
      date: '2026-11-25',
      start: '18:00',
      end: '19:30',
      note: 'Trùng lịch thi',
    });
    expect(
      sessionLabel(
        {
          id: 's1',
          class_code: 'L1',
          session_no: 4,
          date: '2026-11-24',
          start: '18:00:00',
          end: '19:30:00',
        },
        (iso) => iso,
      ),
    ).toBe('L1 · Buổi 4 · 2026-11-24 18:00–19:30');
  });
});
