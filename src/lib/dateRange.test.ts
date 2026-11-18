import { describe, expect, it } from 'vitest';
import { datePresetDateKeys, datePresetInstants } from './dateRange';

// R-HT-07 (Q-171): ranh giới 00:00 theo giờ Việt Nam, không phụ thuộc múi giờ máy. Chạy bộ này với TZ=UTC, TZ=America/Los_Angeles, TZ=Asia/Tokyo: kết quả phải giống nhau.
// 17/11/2026 18:00 UTC = 18/11/2026 01:00 giờ Việt Nam (lúc ngày UTC còn hôm trước).
const AFTER_MIDNIGHT_VN = new Date('2026-11-17T18:00:00Z');
// 17/11/2026 16:59:59 UTC = 17/11/2026 23:59:59 giờ Việt Nam (chót ngày 17).
const BEFORE_MIDNIGHT_VN = new Date('2026-11-17T16:59:59Z');

describe('datePresetInstants (mốc nhanh theo thời điểm, 00:00 giờ Việt Nam)', () => {
  it('Hôm nay lúc 01:00 giờ VN ngày 18: từ 00:00 VN ngày 18 đến 23:59:59.999 VN ngày 18', () => {
    const r = datePresetInstants('today', AFTER_MIDNIGHT_VN);
    expect(r?.from.toISOString()).toBe('2026-11-17T17:00:00.000Z');
    expect(r?.to.toISOString()).toBe('2026-11-18T16:59:59.999Z');
  });
  it('Hôm nay lúc 23:59:59 giờ VN ngày 17: vẫn là ngày 17', () => {
    const r = datePresetInstants('today', BEFORE_MIDNIGHT_VN);
    expect(r?.from.toISOString()).toBe('2026-11-16T17:00:00.000Z');
    expect(r?.to.toISOString()).toBe('2026-11-17T16:59:59.999Z');
  });
  it('mili giây ngay sau nửa đêm giờ VN sang ngày mới, mili giây ngay trước thì chưa', () => {
    const justBefore = datePresetInstants('today', new Date('2026-11-17T16:59:59.999Z'));
    const justAfter = datePresetInstants('today', new Date('2026-11-17T17:00:00.000Z'));
    expect(justBefore?.from.toISOString()).toBe('2026-11-16T17:00:00.000Z');
    expect(justAfter?.from.toISOString()).toBe('2026-11-17T17:00:00.000Z');
  });
  it('Tuần này bắt đầu 00:00 VN thứ Hai (16/11/2026) và hết chủ nhật 22/11', () => {
    const r = datePresetInstants('week', AFTER_MIDNIGHT_VN);
    expect(r?.from.toISOString()).toBe('2026-11-15T17:00:00.000Z');
    expect(r?.to.toISOString()).toBe('2026-11-22T16:59:59.999Z');
  });
  it('Tháng này, Tháng trước theo ngày VN', () => {
    expect(datePresetInstants('month', AFTER_MIDNIGHT_VN)?.from.toISOString()).toBe(
      '2026-10-31T17:00:00.000Z',
    );
    expect(datePresetInstants('last-month', AFTER_MIDNIGHT_VN)?.to.toISOString()).toBe(
      '2026-10-31T16:59:59.999Z',
    );
  });
  it('mốc lạ thì không có khoảng', () => {
    expect(datePresetInstants('khong-co', AFTER_MIDNIGHT_VN)).toBeNull();
  });
});

describe('datePresetDateKeys (mốc nhanh theo ngày lịch)', () => {
  it('Hôm nay lúc 01:00 giờ VN ngày 18 là 2026-11-18', () => {
    expect(datePresetDateKeys('today', AFTER_MIDNIGHT_VN)).toEqual({
      from: '2026-11-18',
      to: '2026-11-18',
    });
  });
  it('Tuần này', () => {
    expect(datePresetDateKeys('week', AFTER_MIDNIGHT_VN)).toEqual({
      from: '2026-11-16',
      to: '2026-11-22',
    });
  });
});
