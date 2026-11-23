// Cấu hình hai màn danh sách cụm Buổi A cho khuôn K03: BUOI-01 Buổi học và BUOI-11 Học sinh vắng / chưa đến. Cột và chữ theo canvas BUOI01, BUOI11.
// Lọc, sắp xếp, phân trang làm ở máy chủ nên cấu hình không có hàm `test` chạy ở trình duyệt.
import { Link } from 'react-router';
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { deadlineLabel, sessionNoLabel } from './sessionLogic';
import type { AbsentRow, PendingRow, SessionRow } from './sessionTypes';

export const SESSION_SCREEN_CODE = 'BUOI-01';
export const ABSENT_SCREEN_CODE = 'BUOI-11';
export const PENDING_SCREEN_CODE = 'BUOI-12';

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
      { key: 'subject', label: 'Môn', render: (r) => r.subject_name ?? MUTED },
      { key: 'class', label: 'Lớp', render: (r) => r.class_code },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'no', label: 'Buổi', render: (r) => sessionNoLabel(r.session_no, r.type_name) },
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
    // Group By ở máy chủ (Kho #17, F65): giá trị đọc từ dòng chỉ để khoá nhóm, nhãn do máy chủ trả.
    groupFields: [
      { key: 'date', label: 'Ngày học', value: (r) => r.session_date },
      { key: 'class', label: 'Lớp', value: (r) => r.class_id },
      { key: 'branch', label: 'Cơ sở', value: (r) => r.branch_code },
      { key: 'teacher', label: 'Giáo viên', value: (r) => r.teacher_name ?? '' },
      { key: 'type', label: 'Loại buổi', value: (r) => r.type_code },
      { key: 'status', label: 'Tình trạng', value: (r) => r.status_code },
    ],
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
      { key: 'subject', label: 'Môn', render: (r) => r.subject_name ?? MUTED },
      { key: 'class', label: 'Lớp', render: (r) => r.class_code },
      { key: 'session_date', label: 'Ngày học', render: (r) => formatDate(r.session_date) },
      { key: 'start_time', label: 'Giờ bắt đầu', render: (r) => r.start_time },
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
    // Canvas BUOI11: nhóm Tình trạng (Vắng, Chưa tới); máy chủ đếm (migration 614).
    groupFields: [{ key: 'status', label: 'Tình trạng', value: (r) => r.kind }],
    dateFields: [],
    views: ['list'],
  };
}

const PENDING_KINDS = [
  { value: 'QUA_HAN', label: 'Quá hạn' },
  { value: 'CON_HAN', label: 'Còn hạn' },
];

/** BUOI-12: buổi Đã chốt đã kết thúc mà giáo viên chưa hoàn tất; "Nhắc GV" tạm mờ (cổng giáo viên chưa có hộp thông báo, Chat 11/11), "Mở buổi" sang BUOI-02. */
export function buildPendingConfig(access: AccessView, canRemind: boolean): ListConfig<PendingRow> {
  return {
    screenCode: PENDING_SCREEN_CODE,
    title: 'Buổi chưa hoàn tất',
    searchPlaceholder: 'Tìm mã lớp…',
    columns: [
      {
        key: 'class',
        label: 'Lớp',
        locked: true,
        primary: true,
        render: (r) => r.class_code,
      },
      { key: 'subject', label: 'Môn', render: (r) => r.subject_name ?? MUTED },
      { key: 'no', label: 'Buổi', render: (r) => sessionNoLabel(r.session_no) },
      { key: 'date', label: 'Ngày học', render: (r) => formatDate(r.session_date) },
      { key: 'time', label: 'Giờ bắt đầu', render: (r) => r.start_time },
      { key: 'teacher', label: 'Giáo viên', render: (r) => r.teacher_name ?? MUTED },
      {
        key: 'deadline',
        label: 'Hạn hoàn tất',
        render: (r) => (
          <Tag tone={r.minutes_left < 0 ? 'danger' : 'warning'} dot>
            {deadlineLabel(r.minutes_left)}
          </Tag>
        ),
      },
      { key: 'reason', label: 'Lý do chưa hoàn tất', render: (r) => r.reason ?? MUTED },
      {
        key: 'action',
        label: 'Xử lý',
        render: (r) => (
          <span className="flex flex-wrap gap-3">
            {canRemind && (
              <span className="flex flex-col">
                <button
                  type="button"
                  disabled
                  aria-describedby="nhac-gv-ghi-chu"
                  className="focus-ring cursor-not-allowed text-left text-fg-muted opacity-60"
                >
                  Nhắc GV
                </button>
                <span id="nhac-gv-ghi-chu" className="text-caption text-fg-muted">
                  Giáo viên chưa có hộp thông báo, làm sau 17/11
                </span>
              </span>
            )}
            <Link to={`/crm/buoi-hoc/${r.id}`} className="focus-ring text-link hover:underline">
              Mở buổi
            </Link>
          </span>
        ),
      },
    ],
    quickGroups: [{ key: 'kind', label: 'Hạn', options: PENDING_KINDS }],
    filterFields: [
      { key: 'kind', label: 'Hạn', type: 'multi', options: PENDING_KINDS },
      ...branchField(access),
    ],
    // Canvas BUOI12: nhóm Giáo viên (khoá nhóm là mã giáo viên, máy chủ trả tên); máy chủ đếm (migration 614).
    groupFields: [{ key: 'teacher', label: 'Giáo viên', value: (r) => r.teacher_name ?? '' }],
    dateFields: [],
    views: ['list'],
  };
}
