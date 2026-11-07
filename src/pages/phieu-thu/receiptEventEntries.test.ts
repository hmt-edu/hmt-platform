import { describe, expect, it } from 'vitest';
import { receiptEventEntries } from './receiptEventEntries';

describe('mục dòng thời gian của phiếu thu (Q-52)', () => {
  it('mỗi sự kiện một mục: tiêu đề theo mã, ghi chú thành một dòng, người làm', () => {
    const entries = receiptEventEntries([
      {
        event_code: 'TAO',
        from_status: null,
        to_status: 'NHAP',
        note: null,
        at: '2026-11-07T01:00:00Z',
        by_name: 'Giả sales1',
      },
      {
        event_code: 'TU_CHOI',
        from_status: 'CHO_KE_TOAN',
        to_status: 'NHAP',
        note: 'Sai số tiền: nhập thừa số 0',
        at: '2026-11-07T02:00:00Z',
        by_name: null,
      },
    ]);
    expect(entries).toHaveLength(2);
    expect(entries[0]).toMatchObject({
      kind: 'event',
      title: 'Tạo phiếu thu',
      author: 'Giả sales1',
      lines: [],
    });
    expect(entries[1]).toMatchObject({
      title: 'Từ chối',
      author: 'Hệ thống',
      lines: ['Sai số tiền: nhập thừa số 0'],
    });
  });

  it('Gửi lại chưa sửa từ lần bị từ chối: dòng cảnh báo vàng (Q-58)', () => {
    const entries = receiptEventEntries([
      {
        event_code: 'GUI',
        from_status: 'NHAP',
        to_status: 'DA_GUI',
        note: 'Gửi lại, chưa sửa từ lần bị từ chối',
        at: '2026-11-07T03:00:00Z',
        by_name: 'Giả sales1',
      },
    ]);
    expect(entries[0]).toMatchObject({
      title: 'Trình quản lý duyệt',
      warning: 'Gửi lại, chưa sửa từ lần bị từ chối',
      lines: [],
    });
  });
});
