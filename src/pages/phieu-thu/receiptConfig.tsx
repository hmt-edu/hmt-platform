// Cấu hình màn Phiếu thu (TC-01, TC-04) cho khuôn danh sách K03: cột, lọc nhanh, trường lọc nâng cao. Lọc, sắp xếp, phân trang làm ở máy chủ.
// Phiếu thu chỉ tạo từ đơn Đã duyệt (R-TIEN-02) nên không có nút Tạo ở danh sách; nút Tạo phiếu thu nằm ở bản ghi đơn hàng.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { ReceiptRow } from './receiptTypes';

export const RECEIPT_SCREEN_CODE = 'TC-01';

export const EMPTY_RECEIPT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

export const RECEIPT_STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_GUI: 'info',
  CHO_KE_TOAN: 'warning',
  DA_DUYET: 'success',
  HUY: 'neutral',
};

const STATUS_CODES = ['NHAP', 'DA_GUI', 'CHO_KE_TOAN', 'DA_DUYET', 'HUY'];

export function buildReceiptConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
): ListConfig<ReceiptRow> {
  const statusName = (code: string) => catalogs.name('RECEIPT_STATUS', code) ?? code;
  const statusOptions = STATUS_CODES.map((value) => ({ value, label: statusName(value) }));
  return {
    screenCode: RECEIPT_SCREEN_CODE,
    title: 'Phiếu thu',
    searchPlaceholder: 'Tìm mã phiếu, mã đơn, phụ huynh, SĐT…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={`/crm/phieu-thu/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </Link>
        ),
      },
      {
        key: 'order',
        label: 'Đơn hàng',
        render: (r) =>
          r.order_id ? (
            <Link to={`/crm/don-hang/${r.order_id}`} className="text-link hover:underline">
              {r.order_code}
            </Link>
          ) : (
            <span className="text-fg-muted">Thu nợ đầu kỳ</span>
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
        key: 'method',
        label: 'Hình thức',
        render: (r) => r.payment_method ?? r.payment_method_code,
      },
      { key: 'paid_on', label: 'Ngày nhận', render: (r) => formatDate(r.paid_on) },
      // Canvas TC01: «Cơ sở» là cơ sở thu tiền; cơ sở của đơn tách sang cột riêng (không gộp hai thông tin vào một ô).
      { key: 'branch', label: 'Cơ sở', render: (r) => r.collect_branch_code },
      // Canvas TC01 không có «Cơ sở đơn»: giữ nhưng ẩn mặc định (bật ở Cột khi cần).
      {
        key: 'order_branch',
        label: 'Cơ sở đơn',
        defaultVisible: false,
        render: (r) => r.branch_code,
      },
      { key: 'creator', label: 'Người lập', render: (r) => r.created_by_name ?? '' },
      { key: 'receiver', label: 'Người nhận tiền', render: (r) => r.receiver_name ?? '' },
      // Canvas TC01: «Người duyệt» (người duyệt được phân công của phiếu).
      { key: 'approver', label: 'Người duyệt', render: (r) => r.approver_name ?? '—' },
      // Canvas TC04 (hàng chờ kế toán): «Mã giao dịch»; ẩn mặc định ở TC-01.
      {
        key: 'txn_ref',
        label: 'Mã giao dịch',
        defaultVisible: false,
        render: (r) => r.txn_ref ?? '—',
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={RECEIPT_STATUS_TONE[r.status_code] ?? 'neutral'} dot>
            {statusName(r.status_code)}
          </Tag>
        ),
      },
    ],
    quickGroups: [
      {
        key: 'mine',
        label: 'Của tôi',
        options: [
          { value: 'mine', label: 'Tôi lập' },
          { value: 'waiting_manager', label: 'Chờ tôi duyệt' },
        ],
      },
      { key: 'status', label: 'Tình trạng', options: statusOptions },
    ],
    filterFields: [
      { key: 'status', label: 'Tình trạng', type: 'multi', options: statusOptions },
      ...(access.seesAllBranches
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
        : []),
      { key: 'created', label: 'Ngày tạo', type: 'date' },
    ],
    // Group By ở máy chủ (K1_nhom): tình trạng, hình thức, cơ sở (khi xem nhiều cơ sở).
    groupFields: [
      { key: 'status', label: 'Tình trạng', value: (r) => r.status_code },
      { key: 'method', label: 'Hình thức', value: (r) => r.payment_method_code },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: ReceiptRow) => r.branch_code }]
        : []),
    ],
    dateFields: [{ key: 'created', label: 'Ngày tạo' }],
    views: ['list'],
  };
}
