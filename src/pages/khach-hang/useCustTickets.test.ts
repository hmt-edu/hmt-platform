import { describe, expect, it } from 'vitest';
import { openTicketTotal } from './useCustTickets';

describe('nút số «Ticket mở» của hồ sơ khách hàng', () => {
  it('chỉ cộng trạng thái chưa xong', () => {
    expect(
      openTicketTotal([
        { status_code: 'MOI', total: 2 },
        { status_code: 'DANG_XU_LY', total: 1 },
        { status_code: 'DA_XU_LY', total: 5 },
        { status_code: 'DA_DONG', total: 7 },
        { status_code: 'DA_HUY', total: 3 },
      ]),
    ).toBe(3);
  });
});
