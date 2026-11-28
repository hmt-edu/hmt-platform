// Cấu hình bảng TT-04 Đối chiếu tái tục theo tháng (canvas 9933 TT04) cho khuôn K03. Cột: Học sinh, Lớp, Ghi danh (n), Cơ sở, Giờ còn, Hết giờ dự kiến,
// Tháng hết giờ, Lý do chưa có phiếu, Xử lý. Lọc, tìm kiếm, phân trang làm ở máy chủ; tháng đổi bằng bộ lọc «Tháng hết giờ». Ghi danh (n): số đếm, bấm mở danh sách mã.
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import { EnrollmentCodes } from './EnrollmentCodes';
import { reasonLabel } from './reconcileLogic';
import type { ReconcileRow } from './reconcileTypes';

export const RECONCILE_SCREEN_CODE = 'TT-04';
const MUTED = <span className="text-fg-muted">—</span>;

export function buildReconcileConfig(
  access: AccessView,
  onCreate: (row: ReconcileRow) => void,
  busyKey: string | null,
): ListConfig<ReconcileRow> {
  const canCreate = access.can('UPSALE', 'TAO') && access.featureOn('BAN_HANG');
  return {
    screenCode: RECONCILE_SCREEN_CODE,
    title: 'Đối chiếu tái tục theo tháng',
    searchPlaceholder: 'Tìm tên, mã học sinh hoặc mã lớp…',
    columns: [
      {
        key: 'student',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => (
          <span>
            <span className="font-medium">{r.student_name}</span>{' '}
            <span className="text-fg-muted">{r.student_code}</span>
          </span>
        ),
      },
      { key: 'class', label: 'Lớp', render: (r) => r.class_code },
      {
        key: 'enroll',
        label: 'Ghi danh (n)',
        render: (r) =>
          r.enrollment_codes ? <EnrollmentCodes codes={r.enrollment_codes} /> : MUTED,
      },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'hours',
        label: 'Giờ còn',
        render: (r) => (r.hours_left === null ? MUTED : r.hours_left),
      },
      {
        key: 'end',
        label: 'Hết giờ dự kiến',
        render: (r) => (r.expected_end_date ? formatDate(r.expected_end_date) : MUTED),
      },
      { key: 'campaign', label: 'Tháng hết giờ', render: (r) => r.campaign_label },
      {
        key: 'reason',
        label: 'Lý do chưa có phiếu',
        render: (r) =>
          r.ticket_code ? (
            <Tag tone="success">Đã có phiếu {r.ticket_code}</Tag>
          ) : (
            reasonLabel(r.missing_reason)
          ),
      },
      {
        key: 'actions',
        label: 'Xử lý',
        render: (r) =>
          canCreate && !r.ticket_id ? (
            <Button
              disabled={busyKey === `${r.student_id}:${r.class_id}`}
              onClick={(e) => {
                e.stopPropagation();
                onCreate(r);
              }}
            >
              Tạo phiếu
            </Button>
          ) : (
            MUTED
          ),
      },
    ],
    quickGroups: [
      { key: 'missing', label: 'Phiếu', options: [{ value: 'missing', label: 'Còn thiếu phiếu' }] },
    ],
    filterFields: [
      { key: 'month', label: 'Tháng hết giờ (YYYY-MM)', type: 'text', ops: ['eq'] },
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
    // Group By ở máy chủ (Kho #19, doi-chieu-group-by.md): Cơ sở (người xem nhiều cơ sở), Tháng hết giờ, Lý do chưa có phiếu.
    groupFields: [
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: ReconcileRow) => r.branch_code }]
        : []),
      { key: 'campaign', label: 'Tháng hết giờ', value: (r) => r.campaign_label },
      {
        key: 'reason',
        label: 'Lý do chưa có phiếu',
        value: (r) => r.missing_reason ?? 'DA_CO_PHIEU',
      },
    ],
    dateFields: [],
    views: ['list'],
  };
}
