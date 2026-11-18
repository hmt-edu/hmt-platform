// Cấu hình màn Số dư khách hàng (TC-14) cho khuôn danh sách K03: cột, lọc nhanh, trường lọc. Lọc, phân trang làm ở máy chủ.
// Chỉ xem. Nút «Cấn vào đơn mới» (TC-16) làm sau cùng Code C, nên chưa có ở đây.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import type { ListConfig, ListState } from '../../list/types';
import type { BalanceRow } from './balanceTypes';

export const BALANCE_SCREEN_CODE = 'TC-14';

export const EMPTY_BALANCE_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export function buildBalanceConfig(access: AccessView): ListConfig<BalanceRow> {
  return {
    screenCode: BALANCE_SCREEN_CODE,
    title: 'Số dư khách hàng',
    searchPlaceholder: 'Tìm tên, mã, số điện thoại phụ huynh…',
    columns: [
      {
        key: 'parent',
        label: 'Phụ huynh',
        locked: true,
        primary: true,
        render: (r) => (
          <Link
            to={`/crm/so-du-khach-hang/${r.parent_id}`}
            className="font-medium text-link hover:underline"
          >
            {r.parent_name}
          </Link>
        ),
      },
      { key: 'code', label: 'Mã phụ huynh', render: (r) => r.parent_code },
      {
        key: 'balance',
        label: 'Số dư (đ)',
        numeric: true,
        render: (r) => formatNumber(r.balance),
      },
      {
        key: 'last',
        label: 'Phát sinh gần nhất',
        render: (r) => (r.last_date ? formatDate(r.last_date) : '—'),
      },
      { key: 'entries', label: 'Số dòng sổ', numeric: true, render: (r) => String(r.entries) },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
    ],
    quickGroups: [
      {
        key: 'balance',
        label: 'Số dư',
        options: [{ value: 'positive', label: 'Còn tiền dư' }],
      },
    ],
    filterFields: access.seesAllBranches
      ? [
          {
            key: 'branch',
            label: 'Cơ sở',
            type: 'select' as const,
            ops: ['eq' as const],
            options: access.teachingBranches.map((b) => ({
              value: b.id,
              label: `${b.code} ${b.name}`,
            })),
          },
        ]
      : [],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
