// Cấu hình màn Lịch hẹn cho khuôn danh sách K1 (TS-11): cột, lọc nhanh, trường lọc nâng cao.
// Lọc và tìm kiếm làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình duyệt. Không có Group By (bản vẽ TS11b
// chia nhóm Quá hạn, Hôm nay, Sắp tới theo thời gian, màn tự dựng từ các dòng đã tải).
import { activityIcon } from '../../features/appointments/appointmentApi';
import { formatDateTime } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import { Icon } from '../../ui/icons';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { AppointmentButtons, RecordLink, type RowActions } from './AppointmentParts';
import { STATUS_TONE } from './appointmentTone';
import { STATUS_LABEL, type AppointmentRow, recordKind } from './appointmentTypes';

export const APPOINTMENT_SCREEN_CODE = 'TS-11';

/** Trạng thái ban đầu: xem tuần này (bản vẽ TS11b), chưa lọc gì khác. */
export const EMPTY_APPOINTMENT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'time',
  datePreset: 'week',
};

export function buildAppointmentConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
  actions: RowActions,
  staff: { value: string; label: string }[],
): ListConfig<AppointmentRow> {
  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;
  return {
    screenCode: APPOINTMENT_SCREEN_CODE,
    title: 'Lịch hẹn',
    searchPlaceholder: 'Tìm tên, SĐT, mã (cả mã cũ)…',
    columns: [
      {
        key: 'activity',
        label: 'Loại hoạt động',
        locked: true,
        render: (r) => (
          <span className="inline-flex items-center gap-2">
            <Icon name={activityIcon(r.activity_code)} className="shrink-0 text-fg-label" />
            {activityName(r.activity_code)}
          </span>
        ),
      },
      {
        key: 'title',
        label: 'Tiêu đề',
        locked: true,
        primary: true,
        render: (r) => (
          <span
            className={r.status === 'HUY' ? 'text-fg-muted line-through' : 'font-medium text-link'}
          >
            {r.title}
          </span>
        ),
      },
      { key: 'record', label: 'Gắn với', render: (r) => <RecordLink row={r} /> },
      {
        key: 'time',
        label: 'Thời gian',
        sortable: true,
        render: (r) => <span className="tabular">{formatDateTime(r.scheduled_at)}</span>,
      },
      { key: 'owner', label: 'Người phụ trách', render: (r) => r.owner_name ?? '' },
      {
        key: 'status',
        label: 'Trạng thái',
        render: (r) => <Tag tone={STATUS_TONE[r.status]}>{STATUS_LABEL[r.status]}</Tag>,
      },
      { key: 'branch', label: 'Cơ sở', defaultVisible: false, render: (r) => r.branch_code },
      {
        key: 'actions',
        label: '',
        locked: true,
        render: (r) => <AppointmentButtons row={r} actions={actions} />,
      },
    ],
    quickGroups: [
      { key: 'mine', label: 'Của tôi', options: [{ value: 'owner', label: 'Tôi phụ trách' }] },
      {
        key: 'status',
        label: 'Trạng thái',
        options: [
          { value: 'open', label: STATUS_LABEL.CHUA_LAM },
          { value: 'done', label: STATUS_LABEL.HOAN_THANH },
          { value: 'cancelled', label: STATUS_LABEL.HUY },
        ],
      },
      {
        key: 'overdue',
        label: 'Quá hạn',
        options: [
          {
            value: 'overdue',
            label: 'Chỉ lịch quá hạn',
            hint: 'chưa làm, trước đầu ngày hôm nay',
          },
        ],
      },
    ],
    filterFields: [
      {
        key: 'activity',
        label: 'Loại hoạt động',
        type: 'multi',
        options: catalogs.options('ACTIVITY_TYPE'),
      },
      { key: 'owner', label: 'Người phụ trách', type: 'select', ops: ['eq'], options: staff },
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
      { key: 'time', label: 'Thời gian', type: 'date' },
    ],
    // Group By ở máy chủ (Đ35): trạng thái, loại hoạt động, người phụ trách, cơ sở (khi xem nhiều cơ sở), loại hồ sơ gắn.
    groupFields: [
      { key: 'status', label: 'Trạng thái', value: (r) => r.status },
      { key: 'activity', label: 'Loại hoạt động', value: (r) => r.activity_code },
      { key: 'owner', label: 'Người phụ trách', value: (r) => r.owner_id },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: AppointmentRow) => r.branch_code }]
        : []),
      {
        key: 'kind',
        label: 'Loại hồ sơ',
        value: (r) => {
          const kind = recordKind(r);
          return kind === 'TEST' ? 'STUDENT_TEST' : kind;
        },
      },
    ],
    dateFields: [{ key: 'time', label: 'Thời gian' }],
    views: ['list', 'kanban', 'calendar'],
  };
}
