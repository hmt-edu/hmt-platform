// Cấu hình màn Tài khoản học sinh (QT-13, khuôn K03 danh sách): cột, lọc nhanh Tình trạng, điều kiện Cơ sở. Tìm, lọc, phân trang ở máy chủ.
import { formatDateTime } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Code, Tag } from '../../ui/Data';
import type { StudentAccountRow, StudentAccountState } from './studentAccountTypes';

export const STUDENT_ACCOUNT_SCREEN_CODE = 'QT-13';

export const EMPTY_STUDENT_ACCOUNT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const STATE_LABEL: Record<StudentAccountState, string> = {
  CHUA_CAP: 'Chưa cấp',
  HOAT_DONG: 'Đang dùng',
  BI_KHOA: 'Đã khoá',
};
const STATE_TONE = { CHUA_CAP: 'neutral', HOAT_DONG: 'success', BI_KHOA: 'danger' } as const;

export function buildStudentAccountConfig(
  branches: { id: string; label: string }[],
  rowActions: (row: StudentAccountRow) => React.ReactNode,
): ListConfig<StudentAccountRow> {
  return {
    screenCode: STUDENT_ACCOUNT_SCREEN_CODE,
    title: 'Tài khoản học sinh',
    searchPlaceholder: 'Tìm tên học sinh, mã HS, tên phụ huynh…',
    columns: [
      {
        key: 'code',
        label: 'Mã HS',
        locked: true,
        render: (r) => <Code>{r.student_code}</Code>,
      },
      {
        key: 'name',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.full_name}</span>,
      },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'state',
        label: 'Tài khoản',
        render: (r) => <Tag tone={STATE_TONE[r.state]}>{STATE_LABEL[r.state]}</Tag>,
      },
      {
        key: 'must_change',
        label: 'Đổi mật khẩu lần đầu',
        render: (r) =>
          r.user_id === null ? (
            <span className="text-fg-muted">—</span>
          ) : r.must_change_password ? (
            'Chưa đổi'
          ) : (
            'Đã đổi'
          ),
      },
      {
        key: 'last_login',
        label: 'Đăng nhập gần nhất',
        render: (r) => (
          <span className="tabular">{r.last_login_at ? formatDateTime(r.last_login_at) : '—'}</span>
        ),
      },
      { key: 'actions', label: '', locked: true, render: (r) => rowActions(r) },
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
