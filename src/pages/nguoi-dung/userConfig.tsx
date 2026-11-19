// Cấu hình màn Người dùng (QT-01, khuôn K03 danh sách): cột, lọc nhanh, điều kiện. Tìm, lọc, sắp xếp, phân trang ở máy chủ.
import { Link } from 'react-router';
import { formatDateTime } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import { roleNames, staffKind } from './userLogic';
import type { UserRow } from './userTypes';

export const USER_SCREEN_CODE = 'QT-01';

export const EMPTY_USER_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const userPath = (id: string) => `/crm/quan-tri/nguoi-dung/${id}`;

export function buildUserConfig(
  roles: { code: string; name: string }[],
  branches: { id: string; label: string }[],
  rowActions: (row: UserRow) => React.ReactNode,
): ListConfig<UserRow> {
  return {
    screenCode: USER_SCREEN_CODE,
    title: 'Người dùng',
    searchPlaceholder: 'Tìm tên, email, mã NV/GV/TG…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        render: (r) => <span className="tabular">{r.staff_code ?? '—'}</span>,
      },
      {
        key: 'username',
        label: 'Tên đăng nhập',
        locked: true,
        render: (r) => <span className="tabular">{r.username ?? '—'}</span>,
      },
      {
        key: 'name',
        label: 'Tên hiển thị',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={userPath(r.id)} className="font-medium text-link hover:underline">
            {r.display_name}
          </Link>
        ),
      },
      {
        key: 'email',
        label: 'Email đăng nhập',
        defaultVisible: false,
        render: (r) => r.login_name,
      },
      {
        key: 'roles',
        label: 'Vai trò',
        render: (r) => <span title={roleNames(r.roles)}>{roleNames(r.roles)}</span>,
      },
      { key: 'kind', label: 'Loại', defaultVisible: false, render: (r) => staffKind(r.staff_code) },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'status',
        label: 'Trạng thái',
        render: (r) =>
          r.is_locked ? <Tag tone="danger">Đã khoá</Tag> : <Tag tone="success">Đang hoạt động</Tag>,
      },
      {
        key: 'last_login',
        label: 'Đăng nhập gần nhất',
        sortable: true,
        render: (r) => (
          <span className="tabular">{r.last_login_at ? formatDateTime(r.last_login_at) : '—'}</span>
        ),
      },
      {
        key: 'manager',
        label: 'Quản lý trực tiếp',
        defaultVisible: false,
        render: (r) => r.manager_name ?? '',
      },
      { key: 'actions', label: '', locked: true, render: (r) => rowActions(r) },
    ],
    quickGroups: [
      {
        key: 'status',
        label: 'Trạng thái',
        options: [
          { value: 'active', label: 'Đang hoạt động' },
          { value: 'locked', label: 'Đã khoá' },
        ],
      },
    ],
    filterFields: [
      {
        key: 'role',
        label: 'Vai trò',
        type: 'multi',
        options: roles.map((r) => ({ value: r.code, label: r.name })),
      },
      {
        key: 'branch',
        label: 'Cơ sở',
        type: 'select',
        ops: ['eq'],
        options: branches.map((b) => ({ value: b.id, label: b.label })),
      },
      {
        key: 'kind',
        label: 'Loại tài khoản',
        type: 'select',
        ops: ['eq'],
        options: [
          { value: 'NV', label: 'Nhân viên' },
          { value: 'GV', label: 'Giáo viên' },
          { value: 'TG', label: 'Trợ giảng' },
        ],
      },
    ],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
