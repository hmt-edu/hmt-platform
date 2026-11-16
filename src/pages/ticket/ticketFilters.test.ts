import { describe, expect, it } from 'vitest';
import { EMPTY_TICKET_STATE, buildTicketFilters } from './ticketFilters';

const STATUS = ['MOI', 'DA_GIAO', 'DANG_XU_LY'];

describe('Bộ lọc danh sách ticket (CS-01)', () => {
  it('trạng thái rỗng thì không gửi bộ lọc nào', () => {
    expect(buildTicketFilters(EMPTY_TICKET_STATE, STATUS)).toEqual({});
  });

  it('ô tìm kiếm cắt khoảng trắng; loại, hạn, trạng thái, của tôi thành khoá máy chủ', () => {
    const state = {
      ...EMPTY_TICKET_STATE,
      search: '  KN-CS5  ',
      quick: { type: ['KN'], sla: ['QUA_HAN'], status: ['MOI'], mine: ['mine'] },
    };
    expect(buildTicketFilters(state, STATUS)).toEqual({
      q: 'KN-CS5',
      ticket_type: 'KN',
      sla_state: 'QUA_HAN',
      status_code: 'MOI',
      mine: true,
    });
  });

  it('chọn nhiều giá trị cùng nhóm hoặc mã lạ thì không gửi (xem tất cả)', () => {
    const state = {
      ...EMPTY_TICKET_STATE,
      quick: { type: ['DN', 'KN'], status: ['KHONG_CO'], sla: ['LA'] },
    };
    expect(buildTicketFilters(state, STATUS)).toEqual({});
  });

  it('điều kiện nâng cao: cơ sở và mức độ', () => {
    const state = {
      ...EMPTY_TICKET_STATE,
      conditions: [
        { id: '1', field: 'branch', op: 'eq' as const, value: 'b-1' },
        { id: '2', field: 'priority', op: 'eq' as const, value: 'KHAN' },
        { id: '3', field: 'priority', op: 'eq' as const, value: '' },
      ],
    };
    expect(buildTicketFilters(state, STATUS)).toEqual({ branch_id: 'b-1', priority_code: 'KHAN' });
  });
});
