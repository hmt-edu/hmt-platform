// Cấu hình hai màn danh sách cụm Buổi A cho khuôn K03: BUOI-01 Buổi học và BUOI-11 Học sinh vắng / chưa đến. Cột và chữ theo canvas BUOI01, BUOI11.
// Lọc, sắp xếp, phân trang làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình duyệt.
import { Link } from 'react-router';
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { classLabel, sessionNoLabel } from './sessionLogic';
import type { AbsentRow, SessionRow } from './sessionTypes';

export const SESSION_SCREEN_CODE = 'BUOI-01';
export const ABSENT_SCREEN_CODE = 'BUOI-11';

const MUTED = <span className="text-fg-muted">—</span>;

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_CHOT: 'info',
  DONE: 'success',
  HUY_CO_PHI: 'warning',
  HUY_KHONG_PHI: 'neutral',
};
export const sessionTone = (code: string): TagTone => STATUS_TONE[code] ?? 'neutral';

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

export function buildSessionConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
): ListConfig<SessionRow> {
  const statusOptions = catalogs
    .filterOptions('SESSION_STATUS')
    .filter((o) => o.value !== 'DA_THAY');
  return {
    screenCode: SESSION_SCREEN_CODE,
    title: 'Buổi học',
    searchPlaceholder: 'Tìm mã lớp…',
    columns: [
      {
        key: 'time',
        label: 'Giờ',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <Link to={`/crm/buoi-hoc/${r.id}`} className="font-medium text-link hover:underline">
            {r.start_time}–{r.end_time}
          </Link>
        ),
      },
      { key: 'date', label: 'Ngày', render: (r) => formatDate(r.session_date) },
      { key: 'class', label: 'Lớp', render: (r) => classLabel(r.subject_name, r.class_code) },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'no', label: 'Buổi', render: (r) => sessionNoLabel(r.session_no) },
      { key: 'type', label: 'Loại', render: (r) => r.type_name },
      { key: 'teacher', label: 'Giáo viên', render: (r) => r.teacher_name ?? MUTED },
      { key: 'room', label: 'Phòng', render: (r) => r.room_name ?? MUTED },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={sessionTone(r.status_code)} dot>
            {r.status_name}
          </Tag>
        ),
      },
      { key: 'note', label: 'Ghi chú', render: (r) => r.note ?? MUTED },
      {
        key: 'open',
        label: 'Xử lý',
        render: (r) => (
          <Link to={`/crm/buoi-hoc/${r.id}`} className="focus-ring text-link hover:underline">
            Mở
          </Link>
        ),
      },
    ],
    quickGroups: [{ key: 'status', label: 'Tình trạng', options: statusOptions }],
    filterFields: [
      { key: 'status', label: 'Tình trạng', type: 'multi', options: statusOptions },
      { key: 'session_date', label: 'Ngày học', type: 'date', ops: ['from', 'to'] },
      ...branchField(access),
    ],
    groupFields: [],
    dateFields: [{ key: 'session_date', label: 'Ngày học' }],
    views: ['list'],
  };
}

const KIND_OPTIONS = [
  { value: 'VANG', label: 'Vắng' },
  { value: 'CHUA_DEN', label: 'Chưa đến' },
];

/** BUOI-11: mỗi dòng một em vắng hoặc chưa đến hôm nay; "Ghi lý do" mở hộp ghi lý do liên hệ, "Mở buổi" sang BUOI-03. */
export function buildAbsentConfig(
  access: AccessView,
  onReason: (row: AbsentRow) => void,
): ListConfig<AbsentRow> {
  return {
    screenCode: ABSENT_SCREEN_CODE,
    title: 'Học sinh vắng / chưa đến',
    searchPlaceholder: 'Tìm tên học sinh, mã lớp…',
    columns: [
      {
        key: 'student',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => r.student_name,
      },
      { key: 'class', label: 'Lớp', render: (r) => classLabel(r.subject_name, r.class_code) },
      {
        key: 'session',
        label: 'Buổi',
        render: (r) => `${formatDate(r.session_date)} · ${r.start_time}`,
      },
      {
        key: 'kind',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={r.kind === 'VANG' ? 'danger' : 'warning'} dot>
            {r.kind === 'VANG' ? 'Vắng' : 'Chưa đến'}
          </Tag>
        ),
      },
      {
        key: 'reason',
        label: 'Lý do liên hệ',
        render: (r) => r.contact_reason_name ?? <span className="text-fg-muted">chưa ghi</span>,
      },
      {
        key: 'action',
        label: 'Xử lý',
        render: (r) => (
          <span className="flex flex-wrap gap-3">
            <button
              type="button"
              className="focus-ring text-link hover:underline"
              onClick={() => onReason(r)}
            >
              Ghi lý do
            </button>
            <Link
              to={`/crm/diem-danh/buoi/${r.session_id}`}
              className="focus-ring text-link hover:underline"
            >
              Mở buổi
            </Link>
          </span>
        ),
      },
    ],
    quickGroups: [{ key: 'kind', label: 'Tình trạng', options: KIND_OPTIONS }],
    filterFields: [
      { key: 'kind', label: 'Tình trạng', type: 'multi', options: KIND_OPTIONS },
      ...branchField(access),
    ],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
