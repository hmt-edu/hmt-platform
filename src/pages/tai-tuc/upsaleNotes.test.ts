import { describe, expect, it } from 'vitest';
import { orderStages, upsaleStageNote } from './upsaleNotes';

const T = { hours: 10, days: 30 };
const base = { stage_code: 'L1', substage_code: null, origin_code: 'HE_THONG' as const };

describe('upsaleStageNote (TT-02)', () => {
  it('L1 tự sinh: nêu ngưỡng lấy từ tham số và nhắc bấm Giao', () => {
    const n = upsaleStageNote(base, null, T, 0, true);
    expect(n?.text).toContain('≤ 10 giờ');
    expect(n?.text).toContain('≤ 30 ngày');
    expect(n?.text).toContain('Bấm Giao');
  });
  it('L1 tạo tay: không có câu «hệ thống tự sinh»', () => {
    expect(upsaleStageNote({ ...base, origin_code: 'TAY' }, null, T, 0, true)).toBeNull();
  });
  it('L1 không có nút Giao (điện thoại, thiếu quyền): câu nhắc không mời bấm Giao', () => {
    expect(upsaleStageNote(base, null, T, 0, false)?.text).not.toContain('Giao');
  });
  it('L1 chưa đọc được ngưỡng: câu không có số', () => {
    expect(upsaleStageNote(base, null, { hours: null, days: 30 }, 0, true)?.text).not.toContain(
      '≤',
    );
  });
  it('L5 nêu lý do không tái tục', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L5' }, 'Học phí', T, 0, true)?.text).toBe(
      'Không tái tục. Lý do: Học phí.',
    );
  });
  it('L6A chờ gửi báo giá; L7 chờ đóng tiền', () => {
    expect(
      upsaleStageNote({ ...base, stage_code: 'L6', substage_code: 'L6A' }, null, T, 0, true)?.text,
    ).toMatch(/Chờ gửi báo giá/);
    expect(upsaleStageNote({ ...base, stage_code: 'L7' }, null, T, 1, true)?.text).toMatch(
      /L8 Hoàn thành/,
    );
  });
  it('giai đoạn khác: không có câu', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L3' }, null, T, 0, true)).toBeNull();
  });
});

describe('bố cục TT-02 (A-27-19)', () => {
  it('L7 không có báo giá, đơn nào đếm được thì không nói «đã gửi báo giá»', () => {
    expect(upsaleStageNote({ ...base, stage_code: 'L7' }, null, T, 0, true)).toBeNull();
  });
  it('thanh giai đoạn: «Không tái tục» đứng cuối, các bước khác giữ thứ tự', () => {
    const stages = ['L4', 'L5', 'L6', 'L8'].map((value) => ({ value }));
    expect(orderStages(stages).map((s) => s.value)).toEqual(['L4', 'L6', 'L8', 'L5']);
  });
});
