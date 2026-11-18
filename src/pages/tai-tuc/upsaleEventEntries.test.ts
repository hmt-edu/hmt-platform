import { describe, expect, it } from 'vitest';
import { upsaleEventEntries, upsaleEventTitle } from './upsaleEventEntries';
import type { UpsaleEvent } from './upsaleTypes';

const ev = (over: Partial<UpsaleEvent>): UpsaleEvent => ({
  id: '1',
  event_type: 'TAO',
  from_stage: null,
  to_stage: 'L1',
  note: null,
  created_at: '2026-11-18T01:00:00Z',
  created_by_name: null,
  ...over,
});

describe('Phiếu tái tục: dòng thời gian', () => {
  it('tên sự kiện theo loại', () => {
    expect(upsaleEventTitle(ev({}))).toBe('Tạo phiếu tái tục');
    expect(upsaleEventTitle(ev({ event_type: 'GIAO' }))).toBe('Giao người phụ trách');
    expect(
      upsaleEventTitle(ev({ event_type: 'DOI_GIAI_DOAN', from_stage: 'L1', to_stage: 'L2' })),
    ).toBe('Chuyển giai đoạn L1 → L2');
    expect(upsaleEventTitle(ev({ event_type: 'DOI_GIAI_DOAN' }))).toBe('Cập nhật phiếu');
  });
  it('người thao tác trống thì là Hệ thống, ghi chú thành dòng', () => {
    const [entry] = upsaleEventEntries([ev({ note: 'Hệ thống sinh' })]);
    expect(entry).toMatchObject({ author: 'Hệ thống', lines: ['Hệ thống sinh'] });
  });
});
