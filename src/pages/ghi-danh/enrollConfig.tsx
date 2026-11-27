// Cấu hình các màn danh sách cụm Ghi danh cho khuôn K03: GD-01 Ghi danh, GD-06 Hàng chờ xếp lớp, GD-04 Sổ giờ. Cột và chữ theo canvas GD01, GD04, GD06.
// Lọc, sắp xếp, phân trang làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình trình duyệt. Giao diện không tính giờ: số do hàm DB trả.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { waitingDaysLabel } from './waitingDays';
import type { EnrollmentRow, LedgerRow, QueueRow } from './enrollTypes';

export const ENROLL_SCREEN_CODE = 'GD-01';
export const QUEUE_SCREEN_CODE = 'GD-06';
export const LEDGER_SCREEN_CODE = 'GD-04';

const MUTED = <span className="text-fg-muted">—</span>;

const STATUS_TONE: Record<string, TagTone> = {
  CHO_XEP_LOP: 'warning',
  DA_XEP_LOP: 'info',
  DANG_HOC: 'success',
  BAO_LUU: 'neutral',
  HOAN_THANH: 'neutral',
  CHUYEN_LOP: 'neutral',
  DUNG: 'neutral',
  HOAN_PHI: 'neutral',
};
export const statusTone = (code: string): TagTone => STATUS_TONE[code] ?? 'neutral';

const hours = (n: number) => formatNumber(n);

export function buildEnrollConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
): ListConfig<EnrollmentRow> {
  const statusOptions = catalogs.filterOptions('ENROLLMENT_STATUS');
  return {
    screenCode: ENROLL_SCREEN_CODE,
    title: 'Ghi danh',
    searchPlaceholder: 'Tìm mã ghi danh, tên học sinh…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <Link to={`/crm/ghi-danh/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </Link>
        ),
      },
      { key: 'student', label: 'Học sinh', sortable: true, render: (r) => r.student_name },
      { key: 'package', label: 'Gói', render: (r) => r.package_code ?? MUTED },
      {
        key: 'mode',
        defaultVisible: false,
        label: 'Hình thức học',
        render: (r) => r.delivery_mode_name ?? MUTED,
      },
      {
        key: 'class',
        label: 'Lớp',
        render: (r) => r.class_code ?? <span className="text-fg-muted">chưa có lớp</span>,
      },
      { key: 'granted', label: 'Giờ cấp', numeric: true, render: (r) => hours(r.granted_hours) },
      { key: 'used', label: 'Đã học', numeric: true, render: (r) => hours(r.used_hours) },
      {
        key: 'remaining',
        label: 'Còn lại',
        numeric: true,
        sortable: true,
        render: (r) => hours(r.remaining_hours),
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={statusTone(r.status_code)} dot>
            {r.status_name}
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
    ],
    // Group By ở máy chủ (Kho #17, F65): hình thức học, lớp hiện tại, tình trạng; giá trị đọc từ dòng chỉ để khoá nhóm, nhãn do máy chủ trả.
    groupFields: [
      { key: 'mode', label: 'Hình thức học', value: (r) => r.delivery_mode_code ?? '' },
      { key: 'class', label: 'Lớp', value: (r) => r.class_id ?? '' },
      { key: 'status', label: 'Tình trạng', value: (r) => r.status_code },
    ],
    dateFields: [],
    views: ['list'],
  };
}

/** GD-06: lý do chờ luôn là "Chưa có lớp" (hàng chờ chỉ gồm ghi danh Chờ xếp lớp, R-GD-05). */
export function buildQueueConfig(
  catalogs: LeadCatalogs,
  onAssign: (row: QueueRow) => void,
  canAssign: boolean,
): ListConfig<QueueRow> {
  const modeOptions = catalogs.filterOptions('STUDY_MODE');
  return {
    screenCode: QUEUE_SCREEN_CODE,
    title: 'Hàng chờ xếp lớp',
    searchPlaceholder: 'Tìm mã ghi danh, tên học sinh…',
    columns: [
      {
        key: 'code',
        label: 'Ghi danh',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={`/crm/ghi-danh/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </Link>
        ),
      },
      { key: 'student', label: 'Học sinh', render: (r) => r.student_name },
      { key: 'subject', label: 'Môn', render: (r) => r.package_name ?? r.package_code ?? MUTED },
      { key: 'mode', label: 'Hình thức', render: (r) => r.delivery_mode_name ?? MUTED },
      { key: 'reason', label: 'Lý do chờ', render: () => 'Chưa có lớp' },
      {
        key: 'since',
        label: 'Chờ từ',
        render: (r) => `${formatDate(r.waiting_since)} · ${waitingDaysLabel(r.waiting_since)}`,
      },
      {
        key: 'action',
        label: 'Xử lý',
        render: (r) =>
          canAssign ? (
            <button
              type="button"
              className="focus-ring text-link hover:underline"
              onClick={() => onAssign(r)}
            >
              Xếp lớp
            </button>
          ) : (
            MUTED
          ),
      },
    ],
    quickGroups: [{ key: 'mode', label: 'Hình thức học', options: modeOptions }],
    filterFields: [{ key: 'mode', label: 'Hình thức học', type: 'multi', options: modeOptions }],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}

/** GD-04 Sổ giờ: chỉ thêm, không sửa (R-GD-04). Dòng chuyển phí nêu nguồn "Phiếu chuyển phí" kèm mã ticket (R-GD-18), ticket chưa có thì để trống. */
export function buildLedgerConfig(): ListConfig<LedgerRow> {
  const signed = (n: number) => `${n > 0 ? '+' : n < 0 ? '−' : ''}${formatNumber(Math.abs(n))}`;
  return {
    screenCode: LEDGER_SCREEN_CODE,
    title: 'Sổ giờ',
    searchPlaceholder: 'Tìm trong sổ giờ…',
    columns: [
      {
        key: 'date',
        label: 'Ngày',
        locked: true,
        primary: true,
        render: (r) => formatDate(r.on_date),
      },
      { key: 'type', label: 'Loại', render: (r) => r.entry_name },
      { key: 'class', label: 'Lớp', render: (r) => r.class_code ?? MUTED },
      {
        key: 'session',
        label: 'Buổi',
        render: (r) => (r.session_no ? `Buổi ${r.session_no}` : MUTED),
      },
      { key: 'receipt', label: 'Phiếu thu', render: (r) => r.receipt_code ?? MUTED },
      { key: 'ticket', label: 'Mã ticket', render: (r) => r.ticket_code ?? MUTED },
      { key: 'by', label: 'Người điều chỉnh', render: (r) => r.adjusted_by ?? MUTED },
      { key: 'reason', label: 'Lý do', render: (r) => r.note ?? r.reason_name ?? MUTED },
      { key: 'hours', label: 'Giờ +/−', numeric: true, render: (r) => signed(r.hours) },
      {
        key: 'balance',
        label: 'Số dư (giờ)',
        numeric: true,
        render: (r) => formatNumber(r.balance),
      },
    ],
    quickGroups: [],
    filterFields: [],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
