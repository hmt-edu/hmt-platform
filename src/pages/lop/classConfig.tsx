// Cấu hình màn Lớp (LOP-01, khuôn K03 danh sách): cột, lọc nhanh, điều kiện. Tìm, lọc, sắp xếp, phân trang ở máy chủ.
import { Link } from 'react-router';
import { formatDate } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import { WEEKDAY_LABEL, timeText } from './classLabels';
import { OPERATING_LABEL, type ClassRow } from './classTypes';

/**
 * Lịch học ở danh sách Lớp (LOP-01, T13 «một ô một thông tin»): mỗi khung là một dòng, ba cột riêng Thứ, Giờ học, Phòng cùng thứ tự để các dòng thẳng hàng.
 * Giáo viên đã có cột riêng nên không ghép vào lịch. Khung chưa có phòng thì để «—».
 */
export type ScheduleSlot = { day: string; time: string; room: string };
export function scheduleSlots(schedule: ClassRow['schedule']): ScheduleSlot[] {
  return [...schedule]
    .sort((x, y) => x.weekday - y.weekday || x.start_time.localeCompare(y.start_time))
    .map((s) => ({
      day: WEEKDAY_LABEL[s.weekday] ?? String(s.weekday),
      time: `${timeText(s.start_time)}–${timeText(s.end_time)}`,
      room: s.room_name ?? '—',
    }));
}

/** Ô nhiều dòng: mỗi khung một dòng, cùng thứ tự giữa các cột lịch. */
function slotLines(schedule: ClassRow['schedule'], pick: (s: ScheduleSlot) => string) {
  const slots = scheduleSlots(schedule);
  if (slots.length === 0) return '';
  return (
    <span className="flex flex-col">
      {slots.map((s, i) => (
        <span key={i}>{pick(s)}</span>
      ))}
    </span>
  );
}

export const CLASS_SCREEN_CODE = 'LOP-01';

export const EMPTY_CLASS_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const classPath = (id: string) => `/crm/lop/${id}`;
export const editClassPath = (id: string) => `/crm/lop/${id}/sua`;
export const NEW_CLASS_PATH = '/crm/lop/tao';

type Option = { value: string; label: string };

const STATUS_TONE: Record<string, 'neutral' | 'info' | 'success' | 'warning' | 'danger'> = {
  NHAP: 'neutral',
  DA_TRINH: 'info',
  DA_XAC_NHAN: 'info',
  DA_DUYET: 'success',
  TU_CHOI: 'danger',
  DA_DONG: 'neutral',
  HUY: 'neutral',
};

export function buildClassConfig(opts: {
  branches: Option[];
  subjects: Option[];
  grades: Option[];
  types: Option[];
  statuses: Option[];
}): ListConfig<ClassRow> {
  return {
    screenCode: CLASS_SCREEN_CODE,
    title: 'Lớp',
    searchPlaceholder: 'Tìm mã lớp hoặc mã cũ…',
    columns: [
      {
        key: 'code',
        label: 'Mã lớp',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <span className="flex flex-col">
            <Link to={classPath(r.id)} className="font-medium text-link hover:underline">
              {r.code}
            </Link>
            {(r.group_name || r.legacy_ref) && (
              <span className="text-caption text-fg-muted">
                {[
                  r.group_name && `tên chung ${r.group_name}`,
                  r.legacy_ref && `mã cũ ${r.legacy_ref}`,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </span>
            )}
          </span>
        ),
      },
      { key: 'subject', label: 'Môn', render: (r) => r.subject_name ?? r.subject_code },
      {
        key: 'grade',
        defaultVisible: false,
        label: 'Khối',
        render: (r) => r.grade_code.replace(/^K0?/, ''),
      },
      {
        key: 'type',
        defaultVisible: false,
        label: 'Phân loại',
        render: (r) => r.class_type_name ?? r.class_type_code,
      },
      { key: 'level', defaultVisible: false, label: 'Trình độ', render: (r) => r.level_name ?? '' },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      { key: 'weekday', label: 'Thứ', render: (r) => slotLines(r.schedule, (s) => s.day) },
      { key: 'time', label: 'Giờ học', render: (r) => slotLines(r.schedule, (s) => s.time) },
      {
        key: 'room',
        defaultVisible: false,
        label: 'Phòng',
        render: (r) => slotLines(r.schedule, (s) => s.room),
      },
      { key: 'teacher', label: 'Giáo viên', render: (r) => r.teacher_names ?? '' },
      {
        key: 'size',
        label: 'Sĩ số',
        numeric: true,
        render: (r) => (r.max_students > 0 ? `${r.enrolled}/${r.max_students}` : `${r.enrolled}`),
      },
      {
        key: 'start',
        defaultVisible: false,
        label: 'Bắt đầu',
        sortable: true,
        render: (r) => <span className="tabular">{formatDate(r.start_date)}</span>,
      },
      {
        key: 'status',
        label: 'Tình trạng duyệt',
        render: (r) => (
          <Tag tone={STATUS_TONE[r.status_code] ?? 'neutral'}>{r.status_name ?? r.status_code}</Tag>
        ),
      },
      {
        key: 'operating',
        defaultVisible: false,
        label: 'Vận hành',
        render: (r) => (r.operating_status ? OPERATING_LABEL[r.operating_status] : '—'),
      },
      { key: 'legacy', label: 'Mã cũ', defaultVisible: false, render: (r) => r.legacy_ref ?? '' },
      {
        key: 'seats',
        label: 'Còn chỗ',
        numeric: true,
        defaultVisible: false,
        render: (r) => (r.seats_left === null ? 'Không giới hạn' : r.seats_left),
      },
      { key: 'group', label: 'Nhóm lớp', defaultVisible: false, render: (r) => r.group_name ?? '' },
    ],
    quickGroups: [
      { key: 'status', label: 'Tình trạng duyệt', options: opts.statuses },
      {
        key: 'operating',
        label: 'Tình trạng vận hành',
        options: Object.entries(OPERATING_LABEL).map(([value, label]) => ({ value, label })),
      },
    ],
    filterFields: [
      { key: 'branch', label: 'Cơ sở', type: 'select', ops: ['eq'], options: opts.branches },
      { key: 'subject', label: 'Môn', type: 'select', ops: ['eq'], options: opts.subjects },
      { key: 'grade', label: 'Khối', type: 'select', ops: ['eq'], options: opts.grades },
      { key: 'type', label: 'Phân loại', type: 'select', ops: ['eq'], options: opts.types },
    ],
    groupFields: [
      { key: 'subject', label: 'Môn', value: (r) => r.subject_code },
      { key: 'grade', label: 'Khối', value: (r) => r.grade_code },
      { key: 'type', label: 'Phân loại', value: (r) => r.class_type_code },
      { key: 'branch', label: 'Cơ sở', value: (r) => r.branch_id },
      { key: 'status', label: 'Tình trạng duyệt', value: (r) => r.status_code },
      { key: 'operating', label: 'Vận hành', value: (r) => r.operating_status ?? '' },
    ],
    dateFields: [],
    views: ['list', 'kanban'],
  };
}
