// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_tickets (AS-07, AS-09). Hàm thuần, có kiểm thử.
// Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07); máy chủ nhận một giá trị mỗi khoá, nhiều giá trị cùng nhóm thì không gửi (xem tất cả).
import type { ListState } from '../../list/types';
import type { TicketFilters } from './ticketTypes';

export const EMPTY_TICKET_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const TICKET_TYPES = ['DN', 'KN', 'GV'];
export const SLA_STATES = ['QUA_HAN', 'SAP_QUA_HAN', 'CHO_DONG'];

function only(values: string[] | undefined, allowed: string[]): string | undefined {
  const ok = (values ?? []).filter((v) => allowed.includes(v));
  return ok.length === 1 ? ok[0] : undefined;
}

/** `statusCodes`: mã trạng thái hợp lệ (từ danh mục); mã lạ bị bỏ để không gửi lên máy chủ. */
export function buildTicketFilters(state: ListState, statusCodes: string[]): TicketFilters {
  const filters: TicketFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const type = only(state.quick.type, TICKET_TYPES);
  if (type) filters.ticket_type = type;
  const sla = only(state.quick.sla, SLA_STATES);
  if (sla) filters.sla_state = sla;
  const status = only(state.quick.status, statusCodes);
  if (status) filters.status_code = status;
  if ((state.quick.mine ?? []).includes('mine')) filters.mine = true;
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value === '') continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = value;
    if (cond.field === 'priority' && cond.op === 'eq') filters.priority_code = value;
  }
  return filters;
}
