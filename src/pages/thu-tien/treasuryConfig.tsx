// Cấu hình hai màn cụm Thu tiền cho khuôn danh sách K03: TC-08 Khoản tiền vào và TC-13 Công nợ. Chỉ đọc; lọc, sắp xếp, phân trang làm ở máy chủ.
// TC-08: không có nút Tạo (khoản tiền vào tự sinh khi Kế toán duyệt phiếu, R-TIEN-01). TC-09 Hoàn tác khoản tiền: nút ở từng dòng (chỉ Kế toán, R-HT-01). Xuất chưa có trong đợt này.
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Button } from '../../ui/Button';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import {
  DEBT_STATUS_LABEL,
  type DebtStatus,
  type MoneyInRow,
  type ReceivableRow,
} from './treasuryTypes';
import { FromLink } from '../../layout/FromLink';

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

export function buildMoneyInConfig(
  access: AccessView,
  onReverse?: (row: MoneyInRow) => void,
  reversalEnabled = false,
): ListConfig<MoneyInRow> {
  // R-HT-01: chỉ người có Kế toán · Duyệt thấy nút (Admin không có quyền này); máy chủ vẫn kiểm lại.
  // Tham số money_reversal_enabled tắt thì ẩn nút (CLAUDE.md: công tắc kiểm cả giao diện lẫn hàm DB), không để bấm tới hộp lý do mới báo lỗi.
  const canReverse =
    access.can('ACCOUNTING', 'DUYET') && onReverse !== undefined && reversalEnabled;
  return {
    screenCode: MONEY_IN_SCREEN_CODE,
    title: 'Khoản tiền vào',
    searchPlaceholder: 'Tìm mã khoản, mã phiếu, mã đơn, phụ huynh, SĐT…',
    columns: [
      { key: 'code', label: 'Mã', locked: true, primary: true, render: (r) => r.code },
      {
        key: 'receipt',
        label: 'Phiếu thu',
        // Khoản đảo không có phiếu thu (receipt_id rỗng): để trống.
        render: (r) =>
          r.receipt_id ? (
            <FromLink to={`/crm/phieu-thu/${r.receipt_id}`} className="text-link hover:underline">
              {r.receipt_code}
            </FromLink>
          ) : (
            ''
          ),
      },
      {
        key: 'order',
        label: 'Đơn hàng',
        // Khoản thu nợ đầu kỳ (TC-02) không có đơn: ghi nhãn thay cho link.
        render: (r) =>
          r.order_id ? (
            <FromLink to={`/crm/don-hang/${r.order_id}`} className="text-link hover:underline">
              {r.order_code}
            </FromLink>
          ) : (
            <Tag tone="neutral">Nợ đầu kỳ</Tag>
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
        render: (r) =>
          r.amount < 0 ? (
            <Tag tone="warning">{`Hoàn tác của ${r.reversal_of_code ?? ''}`.trim()}</Tag>
          ) : r.is_reversed ? (
            <Tag tone="neutral">
              {r.reversed_by_code ? `Đã hoàn tác bằng ${r.reversed_by_code}` : 'Đã hoàn tác'}
            </Tag>
          ) : (
            ''
          ),
      },
      {
        key: 'reverse',
        label: 'Hoàn tác',
        render: (r) =>
          canReverse && r.amount > 0 && !r.is_reversed ? (
            <Button variant="text" onClick={() => onReverse(r)}>
              Hoàn tác khoản tiền
            </Button>
          ) : (
            ''
          ),
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
    // Group By ở máy chủ (K1_nhom): cơ sở (khi xem nhiều cơ sở), ngày ghi sổ.
    groupFields: [
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: MoneyInRow) => r.branch_code }]
        : []),
      { key: 'day', label: 'Ngày ghi sổ', value: (r: MoneyInRow) => r.created_at.slice(0, 10) },
    ],
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
          <FromLink
            to={`/crm/don-hang/${r.order_id}`}
            className="font-medium text-link hover:underline"
          >
            {r.order_code}
          </FromLink>
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
    // Group By ở máy chủ (K1_nhom): cơ sở (khi xem nhiều cơ sở), người lập đơn, tình trạng nợ.
    groupFields: [
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: ReceivableRow) => r.branch_code }]
        : []),
      { key: 'sale', label: 'Người lập đơn', value: (r: ReceivableRow) => r.sale_name ?? '' },
      { key: 'status', label: 'Tình trạng', value: (r: ReceivableRow) => r.status },
    ],
    dateFields: [{ key: 'due', label: 'Hạn đóng' }],
    views: ['list'],
  };
}
