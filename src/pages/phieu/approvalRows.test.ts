import { describe, expect, it } from 'vitest';
import { approvalRows } from './approvalRows';
import type { TaskEvent } from './phieuTypes';

const ev = (event_type: TaskEvent['event_type'], by: string | null, at: string): TaskEvent => ({
  id: `${event_type}${at}`,
  event_type,
  from_status: null,
  to_status: null,
  note: null,
  created_at: at,
  created_by_name: by,
});
const role = (l: string) => (l === 'KE_TOAN' ? 'Kế toán' : 'Quản lý cơ sở');
const levels = ['QUAN_LY_CO_SO', 'KE_TOAN'];

describe('approvalRows (bảng Duyệt CSN-06)', () => {
  it('cấp 1 đã duyệt, cấp 2 đang chờ', () => {
    const rows = approvalRows(
      levels,
      'CHO_DUYET',
      [ev('TRINH', 'Lan', '1'), ev('DUYET', 'Phúc', '2')],
      role,
    );
    expect(rows.map((r) => r.result)).toEqual(['Đã duyệt', 'Đang chờ']);
    expect(rows[0]).toMatchObject({ approver: 'Phúc', at: '2', role: 'Quản lý cơ sở' });
  });
  it('chưa trình thì mọi cấp là Chưa tới', () => {
    expect(
      approvalRows(levels, 'NHAP', [ev('TAO', 'Lan', '0')], role).map((r) => r.result),
    ).toEqual(['Chưa tới', 'Chưa tới']);
  });
  it('từ chối ở cấp 2: cấp 1 Đã duyệt, cấp 2 Từ chối kèm người từ chối', () => {
    const rows = approvalRows(
      levels,
      'TU_CHOI',
      [ev('TRINH', 'Lan', '1'), ev('DUYET', 'Phúc', '2'), ev('TU_CHOI', 'Thuỷ', '3')],
      role,
    );
    expect(rows.map((r) => r.result)).toEqual(['Đã duyệt', 'Từ chối']);
    expect(rows[1]).toMatchObject({ approver: 'Thuỷ', at: '3' });
  });
  it('trình lại sau từ chối: đếm lại từ cấp 1, không lấy duyệt của lần trước', () => {
    const rows = approvalRows(
      levels,
      'CHO_DUYET',
      [
        ev('TRINH', 'Lan', '1'),
        ev('DUYET', 'Phúc', '2'),
        ev('TU_CHOI', 'Thuỷ', '3'),
        ev('TRINH', 'Lan', '4'),
      ],
      role,
    );
    expect(rows.map((r) => r.result)).toEqual(['Đang chờ', 'Chưa tới']);
  });
  it('phiếu huỷ: cấp chưa duyệt là Không áp dụng', () => {
    const rows = approvalRows(levels, 'HUY', [ev('TRINH', 'Lan', '1')], role);
    expect(rows.map((r) => r.result)).toEqual(['Không áp dụng', 'Không áp dụng']);
  });
});
