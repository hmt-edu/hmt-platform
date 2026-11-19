// Hàm thuần của CHUNG-15: nhãn loại việc, đường mở bản ghi, thời gian chờ, bộ lọc. Có kiểm thử.
import type { ListState } from '../../list/types';
import type { ApprovalFilters, ApprovalKind, ApprovalRow } from './approvalsTypes';

export const EMPTY_APPROVAL_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const KIND_LABELS: Record<ApprovalKind, string> = {
  DON_HANG: 'Đơn hàng',
  PHIEU_THU: 'Phiếu thu',
  LOP: 'Lớp',
  YEU_CAU_BUOI: 'Yêu cầu buổi',
  HOAN_PHI: 'Hoàn phí',
  DUNG_HOC: 'Dừng học',
  BAO_LUU: 'Bảo lưu',
  CHUYEN_LOP: 'Chuyển lớp',
  PHIEU_NGHIEP_VU: 'Phiếu nghiệp vụ',
};
export const KIND_ORDER = Object.keys(KIND_LABELS) as ApprovalKind[];

/** Đường mở bản ghi (dưới /crm). Dòng chỉ để mở bản ghi; Duyệt, Từ chối nằm trong màn từng loại. */
export function approvalPath(row: Pick<ApprovalRow, 'kind' | 'open_id'>): string {
  switch (row.kind) {
    case 'DON_HANG':
      return `/crm/don-hang/${row.open_id}`;
    case 'PHIEU_THU':
      return `/crm/phieu-thu/${row.open_id}`;
    case 'LOP':
      return `/crm/lop/${row.open_id}`;
    case 'YEU_CAU_BUOI':
      return '/crm/yeu-cau-buoi';
    case 'PHIEU_NGHIEP_VU':
      return `/crm/phieu-nghiep-vu/${row.open_id}`;
    default:
      return `/crm/ghi-danh/${row.open_id}`;
  }
}

const MS_HOUR = 3_600_000; // allow-number: mili-giây một giờ (đổi đơn vị hiển thị)
const HOURS_DAY = 24; // allow-number: giờ một ngày (đổi đơn vị hiển thị)

/** «3 ngày», «1 ngày 4 giờ», «22 giờ», «dưới 1 giờ»: thời gian chờ từ lúc đến lượt cấp hiện tại. */
export function waitingText(since: string | Date, now: Date = new Date()): string {
  const hours = Math.max(0, Math.floor((now.getTime() - new Date(since).getTime()) / MS_HOUR));
  if (hours < 1) return 'dưới 1 giờ';
  const days = Math.floor(hours / HOURS_DAY);
  const rest = hours % HOURS_DAY;
  if (days === 0) return `${hours} giờ`;
  return rest === 0 ? `${days} ngày` : `${days} ngày ${rest} giờ`;
}

export function approvalFilters(state: ListState): ApprovalFilters {
  const filters: ApprovalFilters = {};
  const kinds = (state.quick.kind ?? []).filter((k) => KIND_ORDER.includes(k as ApprovalKind));
  if (kinds.length === 1 && kinds[0]) filters.kind = kinds[0];
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value !== '' && cond.field === 'branch' && cond.op === 'eq') filters.branch_id = value;
  }
  return filters;
}
