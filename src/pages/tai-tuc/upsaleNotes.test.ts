import { describe, expect, it } from 'vitest';
import { orderStages, upsaleStageNote } from './upsaleNotes';

const T = { hours: 10, days: 30 };
const NONE = { sentQuotes: 0, orders: 0 };
const base = { stage_code: 'L1', substage_code: null, origin_code: 'HE_THONG' as const };

describe('upsaleStageNote (TT-02)', () => {
  it('L1 tự sinh: nêu ngưỡng lấy từ tham số và nhắc bấm Giao', () => {
    const n = upsaleStageNote(base, null, T, NONE);
    expect(n?.text).toContain('≤ 10 giờ');
    expect(n?.text).toContain('≤ 30 ngày');
    expect(n?.text).toContain('Bấm Giao');
  });
  it('L1 tạo tay: không có câu «hệ thống tự sinh»', () => {
    expect(upsaleStageNote({ ...base, origin_code: 'TAY' }, null, T, NONE)).toBeNull();
  });
  it('L1 chưa đọc được ngưỡng: câu không có số', () => {
    expect(upsaleStageNote(base, null, { hours: null, days: 30 }, NONE)?.text).not.toContain('≤');
  });
  it('L5 nêu lý do không tái tục', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L5' }, 'Học phí', T, NONE)?.text).toBe(
      'Không tái tục. Lý do: Học phí.',
    );
  });
  it('L6A chưa gửi báo giá thì chờ gửi; gửi rồi thì không còn câu đó', () => {
    const s = { ...base, stage_code: 'L6', substage_code: 'L6A' };
    expect(upsaleStageNote(s, null, T, NONE)?.text).toMatch(/Chờ gửi báo giá/);
    expect(upsaleStageNote(s, null, T, { sentQuotes: 1, orders: 0 })?.text).not.toMatch(/Chờ gửi/);
  });
  it('L7: câu khớp số đếm, không nói tự sang L8', () => {
    const s = { ...base, stage_code: 'L7' };
    expect(upsaleStageNote(s, null, T, { sentQuotes: 1, orders: 0 })?.text).toMatch(/Đã gửi/);
    expect(upsaleStageNote(s, null, T, { sentQuotes: 1, orders: 1 })?.text).toMatch(/Đã có đơn/);
    expect(upsaleStageNote(s, null, T, { sentQuotes: 1, orders: 0 })?.text).not.toMatch(/L8/);
  });
  it('giai đoạn khác: không có câu', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L3' }, null, T, NONE)).toBeNull();
  });
});

describe('bố cục TT-02 (A-27-19)', () => {
  it('L7 không có báo giá, đơn nào đếm được thì không nói «đã gửi báo giá»', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L7' }, null, T, NONE)).toBeNull();
  });
  it('thanh giai đoạn: «Không tái tục» đứng cuối, các bước khác giữ thứ tự', () => {
    const stages = ['L4', 'L5', 'L6', 'L8'].map((value) => ({ value }));
    expect(orderStages(stages).map((s) => s.value)).toEqual(['L4', 'L6', 'L8', 'L5']);
  });
});
