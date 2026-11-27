import { describe, expect, it } from 'vitest';
import { datePresetLabel } from '../list/state';
import {
  customRangePreset,
  datePresetDateKeys,
  datePresetInstants,
  datePresetRange,
} from './dateRange';

describe('L1 «Tuần trước» và khoảng ngày tự chọn (giờ Việt Nam)', () => {
  it('Tuần trước: thứ Hai đến Chủ nhật liền trước, kể cả khi vắt qua tháng', () => {
    // 04/11/2026 là thứ Tư: tuần trước là 26/10 đến 01/11.
    expect(datePresetDateKeys('last-week', new Date('2026-11-04T03:00:00Z'))).toEqual({
      from: '2026-10-26',
      to: '2026-11-01',
    });
  });

  it('khoảng tự chọn tính hết ngày cuối (23:59:59.999 giờ VN)', () => {
    const preset = customRangePreset(new Date(2026, 9, 30), new Date(2026, 10, 2));
    expect(preset).toBe('range:2026-10-30:2026-11-02');
    const range = datePresetInstants(preset, new Date());
    expect(range?.from.toISOString()).toBe('2026-10-29T17:00:00.000Z');
    expect(range?.to.toISOString()).toBe('2026-11-02T16:59:59.999Z');
    expect(datePresetLabel(preset)).toBe('30/10/2026 – 02/11/2026');
  });

  it('chuỗi lạ không thành khoảng; mốc cũ đã lưu vẫn dùng được', () => {
    expect(datePresetRange('range:abc', new Date())).toBeNull();
    expect(datePresetLabel('last-month')).toBe('Tháng trước');
  });
});
