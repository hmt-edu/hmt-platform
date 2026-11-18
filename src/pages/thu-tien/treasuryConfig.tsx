// Cấu hình hai màn cụm Thu tiền cho khuôn danh sách K03: TC-08 Khoản tiền vào và TC-13 Công nợ. Chỉ đọc; lọc, sắp xếp, phân trang làm ở máy chủ.
// TC-08: không có nút Tạo (khoản tiền vào tự sinh khi Kế toán duyệt phiếu, R-TIEN-01). Đảo khoản (TC-09) và Xuất chưa có trong đợt này.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import {
  DEBT_STATUS_LABEL,
  type DebtStatus,
  type MoneyInRow,
  type ReceivableRow,
} from './treasuryTypes';

export const MONEY_IN_SCREEN_CODE = 'TC-08';
export const RECEIVABLE_SCREEN_CODE = 'TC-13';

export function emptyTreasuryState(dateField: string): ListState {
  return {
    search: '',
    quick: {},
    conditions: [],
    group: [],
    columns: [],
    dateField,
    datePreset: '',
  };
}

const DEBT_TONE: Record<DebtStatus, TagTone> = {
  QUA_HAN: 'danger',
  SAP_DEN_HAN: 'warning',
  CHUA_DEN_HAN: 'neutral',
};

const branchField = (access: AccessView) =>
  access.seesAllBranches
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
    : [];

export function buildMoneyInConfig(access: AccessView): ListConfig<MoneyInRow> {
  return {
    screenCode: MONEY_IN_SCREEN_CODE,
    title: 'Khoản tiền vào',
    searchPlaceholder: 'Tìm mã khoản, mã phiếu, mã đơn, phụ huynh, SĐT…',
    columns: [
      { key: 'code', label: 'Mã', locked: true, primary: true, render: (r) => r.code },
      {
        key: 'receipt',
        label: 'Phiếu thu',
        render: (r) => (
          <Link to={`/crm/phieu-thu/${r.receipt_id}`} className="text-link hover:underline">
            {r.receipt_code}
          </Link>
        ),
      },
      {
        key: 'order',
        label: 'Đơn hàng',
        render: (r) => (
          <Link to={`/crm/don-hang/${r.order_id}`} className="text-link hover:underline">
            {r.order_code}
          </Link>
        ),
      },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      {
        key: 'amount',
        label: 'Số tiền (đ)',
        numeric: true,
        sortable: true,
        render: (r) => formatNumber(r.amount),
      },
      {
        key: 'date',
        label: 'Ngày',
        sortable: true,
        render: (r) => formatDate(r.created_at),
      },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'note',
        label: 'Ghi chú',
        render: (r) => (r.amount < 0 ? <Tag tone="warning">Khoản đảo</Tag> : ''),
      },
    ],
    quickGroups: [
      {
        key: 'kind',
        label: 'Loại',
        options: [
          { value: 'THU', label: 'Khoản thu' },
          { value: 'DAO', label: 'Khoản đảo (âm)' },
        ],
      },
    ],
    filterFields: [...branchField(access), { key: 'created', label: 'Ngày ghi sổ', type: 'date' }],
    groupFields: [],
    dateFields: [{ key: 'created', label: 'Ngày ghi sổ' }],
    views: ['list'],
  };
}

export function buildReceivableConfig(access: AccessView): ListConfig<ReceivableRow> {
  const statusOptions = (Object.keys(DEBT_STATUS_LABEL) as DebtStatus[]).map((value) => ({
    value,
    label: DEBT_STATUS_LABEL[value],
  }));
  return {
    screenCode: RECEIVABLE_SCREEN_CODE,
    title: 'Công nợ',
    searchPlaceholder: 'Tìm mã đơn, phụ huynh, SĐT…',
    columns: [
      {
        key: 'order',
        label: 'Đơn hàng',
        locked: true,
        primary: true,
        render: (r) => (
          <Link
            to={`/crm/don-hang/${r.order_id}`}
            className="font-medium text-link hover:underline"
          >
            {r.order_code}
          </Link>
        ),
      },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'sale', label: 'Sale', render: (r) => r.sale_name ?? '' },
      { key: 'seq', label: 'Đợt', render: (r) => `Đợt ${r.seq}/${r.seq_count}` },
      { key: 'due', label: 'Hạn đóng', sortable: true, render: (r) => formatDate(r.due_date) },
      {
        key: 'due_amount',
        label: 'Phải đóng (đ)',
        numeric: true,
        render: (r) => formatNumber(r.due_amount),
      },
      {
        key: 'paid',
        label: 'Đã đóng (đ)',
        numeric: true,
        render: (r) => formatNumber(r.paid_amount),
      },
      {
        key: 'owed',
        label: 'Còn nợ (đ)',
        numeric: true,
        sortable: true,
        render: (r) => formatNumber(r.owed),
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={DEBT_TONE[r.status]} dot>
            {r.status === 'QUA_HAN' && r.overdue_days !== null
              ? `Quá hạn ${r.overdue_days} ngày`
              : DEBT_STATUS_LABEL[r.status]}
          </Tag>
        ),
      },
    ],
    quickGroups: [{ key: 'status', label: 'Tình trạng', options: statusOptions }],
    filterFields: [
      { key: 'status', label: 'Tình trạng', type: 'multi', options: statusOptions },
      ...branchField(access),
      { key: 'due', label: 'Hạn đóng', type: 'date' },
    ],
    groupFields: [],
    dateFields: [{ key: 'due', label: 'Hạn đóng' }],
    views: ['list'],
  };
}
