// Cấu hình khuôn K03 của màn «Điểm danh» (canvas «Đào tạo — menu và điểm danh», khung Main): cột, lọc nhanh (chọn nhiều là HOẶC), trường nhóm.
import { FromLink } from '../../layout/FromLink';
import { formatDate, formatDateTime } from '../../lib/format';
import type { ListConfig } from '../../list/types';
import { Tag } from '../../ui/Data';
import { isMismatch } from './attendanceLogic';
import { ContactCell, OpsCell, type Option } from './AttendanceCells';
import type { BoardRow } from './attendanceTypes';

/** Đủ cột theo canvas: khung K03 mặc định chỉ hiện 8 cột nên màn đặt sẵn cả danh sách. */
export const COLUMN_KEYS = [
  'time',
  'class',
  'student',
  'parent',
  'teacher',
  'teacher_status',
  'ops',
  'mismatch',
  'contact',
  'cskh',
];

export const GROUP_LABELS: Record<string, string> = {
  date: 'Ngày',
  class: 'Lớp',
  teacher: 'Giáo viên',
  cskh: 'Phụ trách',
};

export function buildAttendanceConfig(options: {
  statuses: Option[];
  reasons: Option[];
  canEdit: boolean;
}): ListConfig<BoardRow> {
  const { statuses, reasons, canEdit } = options;
  const statusName = (code: string) => statuses.find((s) => s.value === code)?.label ?? code;
  const two = (main: React.ReactNode, sub: React.ReactNode) => (
    <span className="flex flex-col">
      <span>{main}</span>
      <span className="text-caption text-fg-muted">{sub}</span>
    </span>
  );
  return {
    screenCode: 'BUOI-11',
    title: 'Điểm danh',
    searchPlaceholder: '',
    views: ['list'],
    dateFields: [],
    filterFields: [],
    quickGroups: [
      {
        key: 'quick',
        label: 'Lọc nhanh',
        options: [
          {
            value: 'CHUA_VAO_LOP',
            label: 'Chưa vào lớp',
            hint: 'buổi đã bắt đầu, còn vắng, đi muộn hoặc chưa ai điểm danh',
          },
          { value: 'VANG', label: 'Vắng' },
          { value: 'DI_MUON', label: 'Đi muộn' },
          { value: 'CHUA_DIEM_DANH', label: 'Chưa điểm danh' },
          { value: 'LECH', label: 'Lệch' },
        ],
      },
    ],
    groupFields: Object.entries(GROUP_LABELS).map(([key, label]) => ({
      key,
      label,
      // Nhóm ở máy chủ: giá trị nhóm đi theo dòng (k1, k2), khung không tự nhóm.
      value: () => '',
    })),
    columns: [
      {
        key: 'time',
        label: 'Giờ',
        locked: true,
        render: (r) =>
          two(
            <FromLink to={`/crm/buoi-hoc/${r.session_id}`} className="focus-ring text-link">
              {r.start_time}–{r.end_time}
            </FromLink>,
            formatDate(r.session_date),
          ),
      },
      {
        key: 'class',
        label: 'Lớp',
        locked: true,
        render: (r) => two([r.subject_name, r.grade_code].filter(Boolean).join(' '), r.class_code),
      },
      {
        key: 'student',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => two(r.student_name, r.student_code),
      },
      {
        key: 'parent',
        label: 'Phụ huynh · SĐT',
        render: (r) =>
          two(
            r.parent_name,
            r.parent_phone ? (
              <a href={`tel:${r.parent_phone}`} className="focus-ring tabular text-link">
                {r.parent_phone}
              </a>
            ) : (
              '—'
            ),
          ),
      },
      { key: 'teacher', label: 'Giáo viên', render: (r) => r.teacher_name ?? '—' },
      {
        key: 'teacher_status',
        label: 'GV điểm danh',
        render: (r) =>
          r.teacher_status_code
            ? two(
                statusName(r.teacher_status_code),
                r.teacher_marked_at ? `tích lúc ${formatDateTime(r.teacher_marked_at)}` : '',
              )
            : 'Chưa tích',
      },
      {
        key: 'ops',
        label: 'Vận hành',
        render: (r) => <OpsCell row={r} statuses={statuses} canEdit={canEdit} />,
      },
      {
        key: 'mismatch',
        label: 'Lệch',
        render: (r) => (isMismatch(r) ? <Tag tone="warning">Lệch</Tag> : '—'),
      },
      {
        key: 'contact',
        label: 'Liên hệ phụ huynh',
        render: (r) => <ContactCell row={r} reasons={reasons} canEdit={canEdit} />,
      },
      { key: 'cskh', label: 'Phụ trách', render: (r) => r.cskh_name ?? 'Chưa giao' },
    ],
  };
}
