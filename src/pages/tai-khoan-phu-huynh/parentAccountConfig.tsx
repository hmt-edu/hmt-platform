// Cấu hình màn Tài khoản phụ huynh (QT-17, khuôn K03 danh sách): cột, chip lọc Tình trạng, điều kiện Cơ sở. Tìm, lọc, phân trang ở máy chủ.
import { formatDateTime } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Code, Tag } from '../../ui/Data';
import type { ParentAccountRow, ParentAccountState } from './parentAccountTypes';

export const PARENT_ACCOUNT_SCREEN_CODE = 'QT-17';

export const EMPTY_PARENT_ACCOUNT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const PARENT_STATE_LABEL: Record<ParentAccountState, string> = {
  CHUA_CAP: 'Chưa cấp',
  HOAT_DONG: 'Đang dùng',
  BI_KHOA: 'Đã khoá',
};
const STATE_TONE = { CHUA_CAP: 'neutral', HOAT_DONG: 'success', BI_KHOA: 'danger' } as const;

export function buildParentAccountConfig(
  branches: { id: string; label: string }[],
  rowActions: (row: ParentAccountRow) => React.ReactNode,
): ListConfig<ParentAccountRow> {
  return {
    screenCode: PARENT_ACCOUNT_SCREEN_CODE,
    title: 'Tài khoản phụ huynh',
    searchPlaceholder: 'Tìm tên phụ huynh, mã PH, số điện thoại…',
    columns: [
      { key: 'code', label: 'Mã PH', locked: true, render: (r) => <Code>{r.parent_code}</Code> },
      {
        key: 'name',
        label: 'Phụ huynh',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.full_name}</span>,
      },
      {
        key: 'children',
        label: 'Số con',
        render: (r) => <span className="tabular">{r.children_count}</span>,
      },
      {
        key: 'state',
        label: 'Tài khoản',
        render: (r) => <Tag tone={STATE_TONE[r.state]}>{PARENT_STATE_LABEL[r.state]}</Tag>,
      },
      {
        key: 'last_login',
        label: 'Đăng nhập gần nhất',
        render: (r) => (
          <span className="tabular">{r.last_login_at ? formatDateTime(r.last_login_at) : '—'}</span>
        ),
      },
      { key: 'actions', label: 'Thao tác', locked: true, render: (r) => rowActions(r) },
    ],
    quickGroups: [
      {
        key: 'state',
        label: 'Tài khoản',
        options: [
          { value: 'none', label: 'Chưa cấp' },
          { value: 'active', label: 'Đang dùng' },
          { value: 'locked', label: 'Đã khoá' },
        ],
      },
    ],
    filterFields: [
      {
        key: 'branch',
        label: 'Cơ sở',
        type: 'select',
        ops: ['eq'],
        options: branches.map((b) => ({ value: b.id, label: b.label })),
      },
    ],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
