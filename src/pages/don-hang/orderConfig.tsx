// Cấu hình màn Đơn hàng (BH-06) cho khuôn danh sách K03: cột, lọc nhanh, trường lọc nâng cao. Cột và chữ theo canvas BH06.
// Lọc, sắp xếp, phân trang làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình duyệt. Không có nút Tạo: đơn chỉ sinh từ báo giá,
// cơ hội hoặc phiếu tái tục (R-CRM-19, R-TIEN-02). Đ262: cột Đã thu, Còn phải thu để "—" và không có bộ lọc đã thu đủ, nút Thu tiền cho tới khi
// có phiếu thu.
import { formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import { formatPhone } from '../lead/leadFormat';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { orderCollection } from './orderCollection';
import type { OrderRow } from './orderTypes';
import { FromLink } from '../../layout/FromLink';

export const ORDER_SCREEN_CODE = 'BH-06';

/** Trạng thái ban đầu: chưa lọc, ô Ngày dùng "Ngày tạo". */
export const EMPTY_ORDER_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_TRINH: 'info',
  DA_DUYET: 'success',
  HUY: 'neutral',
};

const MUTED_DASH = <span className="text-fg-muted">—</span>;

export function buildOrderConfig(catalogs: LeadCatalogs, access: AccessView): ListConfig<OrderRow> {
  const statusName = (code: string) => catalogs.name('ORDER_STATUS', code) ?? code;
  const statusOptions = ['NHAP', 'DA_TRINH', 'DA_DUYET', 'HUY'].map((value) => ({
    value,
    label: statusName(value),
  }));
  return {
    screenCode: ORDER_SCREEN_CODE,
    title: 'Đơn hàng',
    searchPlaceholder: 'Tìm mã, phụ huynh, SĐT, tên học sinh…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        render: (r) => (
          <FromLink to={`/crm/don-hang/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </FromLink>
        ),
      },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      {
        key: 'phone',
        label: 'SĐT',
        render: (r) => <span className="tabular">{formatPhone(r.parent_phone)}</span>,
      },
      {
        key: 'students',
        label: 'Học sinh',
        render: (r) =>
          r.student_names.length > 0 ? (
            r.student_names.join(', ')
          ) : (
            <span className="text-fg-muted">Chưa có học sinh</span>
          ),
      },
      { key: 'branch', defaultVisible: false, label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'sale', defaultVisible: false, label: 'Sale', render: (r) => r.created_by_name ?? '' },
      {
        key: 'total',
        label: 'Tổng tiền (đ)',
        numeric: true,
        sortable: true,
        render: (r) => formatNumber(r.total_amount),
      },
      {
        key: 'paid',
        defaultVisible: false,
        label: 'Đã thu (đ)',
        numeric: true,
        render: (r) => formatNumber(r.paid_amount ?? 0),
      },
      {
        key: 'due',
        label: 'Còn phải thu (đ)',
        numeric: true,
        render: (r) => {
          const c = orderCollection(r.status_code, r.total_amount, r.paid_amount ?? 0);
          return c.receivable === null ? MUTED_DASH : formatNumber(c.receivable);
        },
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={STATUS_TONE[r.status_code] ?? 'neutral'} dot>
            {r.status_code === 'DA_DUYET'
              ? `${statusName('DA_DUYET')} · khoá`
              : statusName(r.status_code)}
          </Tag>
        ),
      },
      {
        key: 'collect',
        label: 'Thu tiền',
        render: (r) =>
          orderCollection(r.status_code, r.total_amount, r.paid_amount ?? 0).label ?? MUTED_DASH,
      },
    ],
    quickGroups: [
      {
        key: 'mine',
        label: 'Của tôi',
        options: [{ value: 'mine', label: 'Tôi lập' }],
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
    // Group By ở máy chủ (K1_nhom): tình trạng, cơ sở (khi xem nhiều cơ sở).
    groupFields: [
      { key: 'status', label: 'Tình trạng', value: (r) => r.status_code },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: OrderRow) => r.branch_code }]
        : []),
      // Canvas BH06: nhóm «Sale» = người lập đơn.
      { key: 'sale', label: 'Sale', value: (r) => r.created_by_name ?? '' },
    ],
    dateFields: [{ key: 'created', label: 'Ngày tạo' }],
    views: ['list'],
  };
}
