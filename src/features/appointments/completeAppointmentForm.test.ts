import { describe, expect, it } from 'vitest';
import { completeErrors, resultRequired, type CompleteDraft } from './completeAppointmentForm';

const NOW = new Date('2026-11-23T10:00:00Z');
const draft: CompleteDraft = { resultCode: '', nextDate: null, nextTime: '', note: '' };

describe('hộp Hoàn thành lịch hẹn (TS-11)', () => {
  it('kết quả bắt buộc chỉ khi Gọi điện, không tự nhắc, và tham số bật (D-23-31)', () => {
    expect(resultRequired('GOI_DIEN', false, true)).toBe(true);
    expect(resultRequired('ZALO', false, true)).toBe(false);
    expect(resultRequired('GOI_DIEN', true, true)).toBe(false); // lịch tự nhắc bỏ qua
    expect(resultRequired('GOI_DIEN', false, false)).toBe(false); // tham số tắt
    expect(resultRequired('GOI_DIEN', false, null)).toBe(false); // chưa đọc được: DB vẫn chặn
    expect(completeErrors(true, draft, null, NOW).result).toBe('Chọn kết quả.');
    expect(completeErrors(false, draft, null, NOW)).toEqual({});
    expect(completeErrors(true, { ...draft, resultCode: 'SAI_SO' }, null, NOW)).toEqual({});
  });
  it('hẹn lần sau: bỏ trống là không hẹn; thiếu một nửa thì báo; phải sau hiện tại', () => {
    expect(completeErrors(false, draft, null, NOW)).toEqual({});
    expect(
      completeErrors(false, { ...draft, nextDate: new Date('2026-11-24') }, null, NOW).next,
    ).toBe('Chọn đủ ngày và giờ của lần hẹn sau.');
    const past = new Date('2026-11-23T09:00:00Z');
    expect(
      completeErrors(false, { ...draft, nextDate: past, nextTime: '16:00' }, past, NOW).next,
    ).toBe('Hẹn lần sau không được trước thời điểm hiện tại.');
    const future = new Date('2026-11-24T09:00:00Z');
    expect(
      completeErrors(false, { ...draft, nextDate: future, nextTime: '16:00' }, future, NOW),
    ).toEqual({});
  });
});
