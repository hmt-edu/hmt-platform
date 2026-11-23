// Cấu hình màn Báo giá (BH-01) cho khuôn danh sách K03: cột, lọc nhanh, trường lọc nâng cao. Cột và chữ theo canvas v118 (BH01).
// Mọi lọc, sắp xếp, phân trang làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình duyệt. Không có nút Tạo: báo giá chỉ sinh
// từ cơ hội hoặc phiếu tái tục (R-TIEN-02).
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Code, Tag, type TagTone } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import { formatPhone } from '../lead/leadFormat';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { QuotationRow } from './quoteTypes';

export const QUOTE_SCREEN_CODE = 'BH-01';

/** Trạng thái ban đầu: chưa lọc, ô Ngày dùng "Ngày tạo". */
export const EMPTY_QUOTE_STATE: ListState = {
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
  DA_GUI: 'info',
  DA_CHUYEN_DON: 'success',
  TU_CHOI: 'danger',
  HUY: 'neutral',
};

export function buildQuoteConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
): ListConfig<QuotationRow> {
  const statusName = (code: string) => catalogs.name('QUOTATION_STATUS', code) ?? code;
  return {
    screenCode: QUOTE_SCREEN_CODE,
    title: 'Báo giá',
    searchPlaceholder: 'Tìm mã, phụ huynh, SĐT, tên em…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={`/crm/bao-gia/${r.id}`} className="font-medium text-link hover:underline">
            <Code>{r.code}</Code>
          </Link>
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
      { key: 'opportunity', label: 'Cơ hội', render: (r) => <Code>{r.opportunity_code}</Code> },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'total',
        label: 'Tổng tiền (đ)',
        numeric: true,
        sortable: true,
        render: (r) => formatNumber(r.total_amount),
      },
      {
        key: 'valid',
        label: 'Hạn hiệu lực',
        numeric: true,
        sortable: true,
        render: (r) => (r.valid_until ? formatDate(r.valid_until) : '—'),
      },
      {
        key: 'overdue',
        label: 'Quá hạn',
        render: (r) =>
          r.overdue_days !== null && r.overdue_days > 0 ? (
            <Tag tone="danger">{`Quá hạn ${r.overdue_days} ngày`}</Tag>
          ) : (
            <span className="text-fg-muted">—</span>
          ),
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={STATUS_TONE[r.display_status_code] ?? 'neutral'} dot>
            {statusName(r.display_status_code)}
          </Tag>
        ),
      },
      { key: 'creator', label: 'Người lập', render: (r) => r.created_by_name ?? '' },
    ],
    quickGroups: [
      {
        key: 'mine',
        label: 'Của tôi',
        options: [{ value: 'mine', label: 'Tôi lập' }],
      },
      {
        key: 'status',
        label: 'Tình trạng',
        options: [
          { value: 'NHAP', label: statusName('NHAP') },
          {
            value: 'DA_GUI',
            label: statusName('DA_GUI'),
            hint: 'chưa chuyển hết sang đơn',
          },
          { value: 'DA_CHUYEN_DON', label: statusName('DA_CHUYEN_DON') },
          { value: 'TU_CHOI', label: statusName('TU_CHOI') },
          { value: 'HUY', label: statusName('HUY') },
        ],
      },
      {
        key: 'valid',
        label: 'Hạn hiệu lực',
        options: [
          {
            value: 'expired',
            label: 'Đã quá hạn',
            hint: 'đã gửi và quá hạn; quá hạn chỉ là nhãn, không chặn chuyển đơn (R-TIEN-05)',
          },
        ],
      },
    ],
    filterFields: [
      {
        key: 'status',
        label: 'Tình trạng',
        type: 'multi',
        options: [
          { value: 'NHAP', label: statusName('NHAP') },
          { value: 'DA_GUI', label: statusName('DA_GUI') },
          { value: 'DA_CHUYEN_DON', label: statusName('DA_CHUYEN_DON') },
          { value: 'TU_CHOI', label: statusName('TU_CHOI') },
          { value: 'HUY', label: statusName('HUY') },
        ],
      },
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
    // Group By ở máy chủ (K1_nhom): tình trạng hiển thị, cơ sở (khi xem nhiều cơ sở).
    groupFields: [
      { key: 'status', label: 'Tình trạng', value: (r) => r.display_status_code },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: QuotationRow) => r.branch_code }]
        : []),
      // Canvas BH01: nhóm «Người lập» (khoá nhóm là mã người lập, máy chủ trả tên).
      { key: 'creator', label: 'Người lập', value: (r) => r.created_by_name ?? '' },
    ],
    dateFields: [{ key: 'created', label: 'Ngày tạo' }],
    views: ['list'],
  };
}
