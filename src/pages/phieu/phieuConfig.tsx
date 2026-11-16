// Cấu hình danh sách phiếu nghiệp vụ cho khuôn K03: CS-05 (canvas CSN05). Cột: mã phiếu, loại phiếu, ticket gốc, học sinh, trạng thái, cấp duyệt,
// người duyệt kế tiếp, cơ sở, ngày tạo. Lọc nhanh: Hàng chờ (Chờ tôi duyệt, Chờ kế toán), Loại phiếu, Trạng thái. Lọc, phân trang làm ở máy chủ.
import { Link } from 'react-router';
import { formatDateTime } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import type { ListConfig } from '../../list/types';
import { Tag, type TagTone } from '../../ui/Data';
import { LEVEL_ROLE_LABEL, TASK_STATUS_LABEL, TASK_TYPE_LABEL, type TaskRow } from './phieuTypes';

export const TASK_SCREEN_CODE = 'CS-05';
const MUTED = <span className="text-fg-muted">—</span>;

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  CHO_DUYET: 'warning',
  DA_DUYET: 'info',
  DA_THUC_HIEN: 'success',
  TU_CHOI: 'danger',
  DA_HUY: 'neutral',
};
export const taskStatusTone = (code: string): TagTone => STATUS_TONE[code] ?? 'neutral';

export function buildTaskConfig(access: AccessView): ListConfig<TaskRow> {
  return {
    screenCode: TASK_SCREEN_CODE,
    title: 'Phiếu nghiệp vụ',
    searchPlaceholder: 'Tìm mã phiếu hoặc mã ticket…',
    columns: [
      {
        key: 'code',
        label: 'Mã phiếu',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.code}</span>,
      },
      {
        key: 'type',
        label: 'Loại phiếu',
        render: (r) => TASK_TYPE_LABEL[r.task_type] ?? r.task_type,
      },
      {
        key: 'ticket',
        label: 'Ticket gốc',
        render: (r) => (
          <Link
            className="text-link underline"
            to={`/crm/ticket/${r.ticket_id}`}
            onClick={(e) => e.stopPropagation()}
          >
            {r.ticket_code}
          </Link>
        ),
      },
      { key: 'student', label: 'Học sinh', render: (r) => r.student_name ?? MUTED },
      {
        key: 'status',
        label: 'Trạng thái',
        render: (r) => (
          <Tag tone={taskStatusTone(r.status_code)} dot>
            {TASK_STATUS_LABEL[r.status_code] ?? r.status_code}
          </Tag>
        ),
      },
      {
        key: 'level',
        label: 'Cấp duyệt',
        render: (r) => (r.status_code === 'CHO_DUYET' ? `Cấp ${r.level}/${r.level_total}` : MUTED),
      },
      {
        key: 'next',
        label: 'Người duyệt kế tiếp',
        render: (r) => (r.next_role ? (LEVEL_ROLE_LABEL[r.next_role] ?? r.next_role) : MUTED),
      },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'created', label: 'Ngày tạo', render: (r) => formatDateTime(r.created_at) },
    ],
    quickGroups: [
      {
        key: 'queue',
        label: 'Hàng chờ',
        options: [
          { value: 'cho_toi', label: 'Chờ tôi duyệt' },
          { value: 'cho_ke_toan', label: 'Chờ kế toán' },
        ],
      },
      {
        key: 'type',
        label: 'Loại phiếu',
        options: Object.entries(TASK_TYPE_LABEL).map(([value, label]) => ({ value, label })),
      },
      {
        key: 'status',
        label: 'Trạng thái',
        options: Object.entries(TASK_STATUS_LABEL).map(([value, label]) => ({ value, label })),
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
