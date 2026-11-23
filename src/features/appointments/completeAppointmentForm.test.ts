import { describe, expect, it } from 'vitest';
import { completeErrors, resultRequired, type CompleteDraft } from './completeAppointmentForm';

const NOW = new Date('2026-11-23T10:00:00Z');
const draft: CompleteDraft = { resultCode: '', nextDate: null, nextTime: '', note: '' };

describe('hộp Hoàn thành lịch hẹn (TS-11)', () => {
  it('kết quả bắt buộc chỉ khi Gọi điện', () => {
    expect(resultRequired('GOI_DIEN')).toBe(true);
    expect(resultRequired('ZALO')).toBe(false);
    expect(completeErrors('GOI_DIEN', draft, null, NOW).result).toBe('Chọn kết quả.');
    expect(completeErrors('ZALO', draft, null, NOW)).toEqual({});
    expect(completeErrors('GOI_DIEN', { ...draft, resultCode: 'SAI_SO' }, null, NOW)).toEqual({});
  });
  it('hẹn lần sau: bỏ trống là không hẹn; thiếu một nửa thì báo; phải sau hiện tại', () => {
    expect(completeErrors('ZALO', draft, null, NOW)).toEqual({});
    expect(
      completeErrors('ZALO', { ...draft, nextDate: new Date('2026-11-24') }, null, NOW).next,
    ).toBe('Chọn đủ ngày và giờ của lần hẹn sau.');
    const past = new Date('2026-11-23T09:00:00Z');
    expect(
      completeErrors('ZALO', { ...draft, nextDate: past, nextTime: '16:00' }, past, NOW).next,
    ).toBe('Hẹn lần sau không được trước thời điểm hiện tại.');
    const future = new Date('2026-11-24T09:00:00Z');
    expect(
      completeErrors('ZALO', { ...draft, nextDate: future, nextTime: '16:00' }, future, NOW),
    ).toEqual({});
  });
});
