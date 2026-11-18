// Cấu hình hai tab của QT-12 (khuôn K03 danh sách, chỉ đọc): Đăng nhập và Xuất file. Lọc, phân trang ở máy chủ.
import { formatDateTime } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import { RESULT_LABEL, summarizeExportFilters } from './loginLogLogic';
import type { ExportRow, LoginRow } from './loginLogTypes';

export const EMPTY_LOG_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const RESULT_TONE: Record<string, 'success' | 'danger' | 'warning' | 'neutral'> = {
  THANH_CONG: 'success',
  SAI_MAT_KHAU: 'warning',
  TAI_KHOAN_KHOA: 'danger',
  KHOA_TAM: 'danger',
  KHONG_CO_TAI_KHOAN: 'warning',
  LOI: 'danger',
};

export function buildLoginConfig(
  rowAction: (r: LoginRow) => React.ReactNode,
): ListConfig<LoginRow> {
  return {
    screenCode: 'QT-12',
    title: 'Nhật ký đăng nhập',
    searchPlaceholder: 'Tìm theo tên đăng nhập…',
    columns: [
      {
        key: 'at',
        label: 'Lúc',
        locked: true,
        primary: true,
        render: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
      },
      { key: 'login', label: 'Tên đăng nhập', render: (r) => r.login_name },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code ?? '—' },
      {
        key: 'result',
        label: 'Kết quả',
        render: (r) => (
          <Tag tone={RESULT_TONE[r.result] ?? 'neutral'}>{RESULT_LABEL[r.result] ?? r.result}</Tag>
        ),
      },
      {
        key: 'ip',
        label: 'Địa chỉ IP',
        render: (r) => <span className="tabular">{r.ip ?? '—'}</span>,
      },
      {
        key: 'ua',
        label: 'Thiết bị',
        defaultVisible: false,
        render: (r) => <span title={r.user_agent ?? ''}>{r.user_agent ?? '—'}</span>,
      },
      { key: 'actions', label: '', locked: true, render: rowAction },
    ],
    quickGroups: [
      {
        key: 'result',
        label: 'Kết quả',
        options: Object.entries(RESULT_LABEL).map(([value, label]) => ({ value, label })),
      },
    ],
    filterFields: [{ key: 'at', label: 'Ngày', type: 'date' }],
    groupFields: [],
    dateFields: [{ key: 'at', label: 'Ngày đăng nhập' }],
    views: ['list'],
  };
}

export function buildExportConfig(
  modules: { code: string; name: string }[],
): ListConfig<ExportRow> {
  return {
    screenCode: 'QT-12-XUAT',
    title: 'Nhật ký xuất file',
    searchPlaceholder: 'Lọc bằng nút Filters (phân hệ, ngày)',
    columns: [
      {
        key: 'at',
        label: 'Lúc',
        locked: true,
        primary: true,
        render: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
      },
      { key: 'user', label: 'Ai xuất', render: (r) => r.user_name ?? r.user_id },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code ?? '—' },
      {
        key: 'module',
        label: 'Phân hệ',
        render: (r) => modules.find((m) => m.code === r.module_code)?.name ?? r.module_code,
      },
      { key: 'rows', label: 'Số dòng', numeric: true, render: (r) => r.row_count },
      {
        key: 'filters',
        label: 'Bộ lọc',
        defaultVisible: false,
        render: (r) => summarizeExportFilters(r.filters),
      },
    ],
    quickGroups: [],
    filterFields: [
      {
        key: 'module',
        label: 'Phân hệ',
        type: 'select',
        ops: ['eq'],
        options: modules.map((m) => ({ value: m.code, label: m.name })),
      },
      { key: 'at', label: 'Ngày', type: 'date' },
    ],
    groupFields: [],
    dateFields: [{ key: 'at', label: 'Ngày xuất' }],
    views: ['list'],
  };
}
