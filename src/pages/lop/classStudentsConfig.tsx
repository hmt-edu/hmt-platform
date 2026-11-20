// Cấu hình màn Học sinh của lớp (LOP-09, khuôn K03 danh sách): cột theo canvas 9933 khung LOP09. Tìm, lọc, sắp xếp, phân trang ở máy chủ.
import { formatDate } from '../../lib/format';
import type { ListConfig } from '../../list/types';
import { Tag } from '../../ui/Data';
import type { ClassStudentRow } from './classStudents';

export const CLASS_STUDENTS_SCREEN_CODE = 'LOP-09';

type Option = { value: string; label: string };

/** «Tình trạng» của dòng xếp lớp: đã rời thì ghi Đã rời; còn trong lớp thì tình trạng ghi danh (Đang học, Bảo lưu…). */
export function studentStateLabel(
  r: Pick<ClassStudentRow, 'end_date' | 'enrollment_status'>,
  statusName: (code: string) => string | undefined,
): string {
  if (r.end_date) return 'Đã rời';
  return statusName(r.enrollment_status) ?? r.enrollment_status;
}

export function buildClassStudentsConfig(opts: {
  /** Tên lớp nối sau tiêu đề (canvas LOP09: «Học sinh của lớp · Đại số 9 · cơ bản A»); chưa tải xong thì chỉ có tiêu đề. */
  classLabel?: string | undefined;
  modes: Option[];
  modeName: (code: string | null) => string;
  statusName: (code: string) => string | undefined;
}): ListConfig<ClassStudentRow> {
  return {
    screenCode: CLASS_STUDENTS_SCREEN_CODE,
    title: opts.classLabel ? `Học sinh của lớp · ${opts.classLabel}` : 'Học sinh của lớp',
    searchPlaceholder: 'Tìm tên, mã học sinh, mã ghi danh…',
    columns: [
      {
        key: 'code',
        label: 'Mã học sinh',
        locked: true,
        render: (r) => <span className="tabular">{r.student_code}</span>,
      },
      {
        key: 'name',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.full_name}</span>,
      },
      { key: 'enrollment', label: 'Ghi danh', render: (r) => r.enrollment_code },
      { key: 'branch', label: 'Cơ sở phụ trách', render: (r) => r.branch_code ?? '—' },
      {
        key: 'mode',
        label: 'Hình thức học',
        render: (r) => opts.modeName(r.delivery_mode_code),
      },
      {
        key: 'start',
        label: 'Ngày vào',
        sortable: true,
        render: (r) => <span className="tabular">{formatDate(r.start_date)}</span>,
      },
      {
        key: 'end',
        label: 'Ngày rời',
        render: (r) => <span className="tabular">{r.end_date ? formatDate(r.end_date) : '—'}</span>,
      },
      {
        key: 'state',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={r.end_date ? 'neutral' : 'success'}>
            {studentStateLabel(r, opts.statusName)}
          </Tag>
        ),
      },
      {
        key: 'hours',
        label: 'Giờ còn',
        numeric: true,
        sortable: true,
        render: (r) => r.hours_left,
      },
    ],
    quickGroups: [
      {
        key: 'state',
        label: 'Tình trạng',
        options: [
          { value: 'DANG_HOC', label: 'Còn trong lớp' },
          { value: 'DA_ROI', label: 'Đã rời' },
        ],
      },
      { key: 'delivery', label: 'Hình thức học', options: opts.modes },
    ],
    filterFields: [],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
