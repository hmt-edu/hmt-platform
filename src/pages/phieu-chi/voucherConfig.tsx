// Cấu hình màn Phiếu chi (TC-10) cho khuôn danh sách K03: cột, lọc nhanh, trường lọc nâng cao. Lọc, phân trang làm ở máy chủ.
// Phiếu chi chỉ sinh khi Kế toán duyệt yêu cầu hoàn phí (R-TIEN-34), không tạo tay nên không có nút Tạo.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import type { VoucherRow } from './voucherTypes';

export const VOUCHER_SCREEN_CODE = 'TC-10';

export const EMPTY_VOUCHER_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

export const VOUCHER_STATUS_NAME: Record<string, string> = {
  CHO_CHI: 'Chờ chi',
  DA_CHI: 'Đã chi',
};
export const VOUCHER_STATUS_TONE: Record<string, TagTone> = {
  CHO_CHI: 'warning',
  DA_CHI: 'success',
};

const statusOptions = Object.entries(VOUCHER_STATUS_NAME).map(([value, label]) => ({
  value,
  label,
}));

export function buildVoucherConfig(access: AccessView): ListConfig<VoucherRow> {
  return {
    screenCode: VOUCHER_SCREEN_CODE,
    title: 'Phiếu chi',
    searchPlaceholder: 'Tìm mã phiếu chi, ticket, phụ huynh…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={`/crm/phieu-chi/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </Link>
        ),
      },
      { key: 'ticket', label: 'Ticket hoàn tiền', render: (r) => r.ticket_ref ?? '—' },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      {
        key: 'amount',
        label: 'Số tiền hoàn (đ)',
        numeric: true,
        render: (r) => formatNumber(r.amount),
      },
      { key: 'created', label: 'Ngày lập', render: (r) => formatDate(r.created_at) },
      { key: 'paid', label: 'Ngày chi', render: (r) => (r.paid_at ? formatDate(r.paid_at) : '—') },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={VOUCHER_STATUS_TONE[r.status_code] ?? 'neutral'} dot>
            {VOUCHER_STATUS_NAME[r.status_code] ?? r.status_code}
          </Tag>
        ),
      },
    ],
    quickGroups: [{ key: 'status', label: 'Tình trạng', options: statusOptions }],
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
      { key: 'created', label: 'Ngày lập', type: 'date' },
    ],
    // Group By ở máy chủ (K1_nhom): tình trạng, cơ sở (khi xem nhiều cơ sở).
    groupFields: [
      { key: 'status', label: 'Tình trạng', value: (r) => r.status_code },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: VoucherRow) => r.branch_code }]
        : []),
    ],
    dateFields: [{ key: 'created', label: 'Ngày lập' }],
    views: ['list'],
  };
}
