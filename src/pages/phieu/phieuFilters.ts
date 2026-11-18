// Đổi trạng thái màn danh sách phiếu (ListState) thành bộ lọc gửi app.list_ticket_tasks. Hàm thuần, có kiểm thử.
import type { ListState } from '../../list/types';
import type { TaskFilters } from './phieuTypes';

export const EMPTY_TASK_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const only = (values: string[] | undefined, allowed: string[]) => {
  const ok = (values ?? []).filter((v) => allowed.includes(v));
  return ok.length === 1 ? ok[0] : undefined;
};

/** `typeCodes`, `statusCodes`: mã hợp lệ; mã lạ bị bỏ để không gửi lên máy chủ. Nhóm «Hàng chờ» chỉ nhận một giá trị mỗi lần. */
export function buildTaskFilters(
  state: ListState,
  typeCodes: string[],
  statusCodes: string[],
): TaskFilters {
  const filters: TaskFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const type = only(state.quick.type, typeCodes);
  if (type) filters.task_type = type;
  const status = only(state.quick.status, statusCodes);
  if (status) filters.status_code = status;
  const queue = only(state.quick.queue, ['cho_toi', 'cho_ke_toan', 'cho_thuc_hien']);
  // «Đã duyệt, chờ thực hiện» (canvas CSN-05) là bộ lọc trạng thái Đã duyệt; hai hàng chờ kia do máy chủ tính.
  if (queue === 'cho_thuc_hien') filters.status_code = 'DA_DUYET';
  else if (queue) filters[queue] = true;
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value !== '' && cond.field === 'branch' && cond.op === 'eq') filters.branch_id = value;
  }
  return filters;
}
