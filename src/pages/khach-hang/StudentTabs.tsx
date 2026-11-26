// Tab Học tập, Điểm danh, Điểm kiểm tra, Chăm sóc của hồ sơ học sinh (khung KH05_hoc_tap, _diem_danh, _diem_danh_chi_tiet,
// _diem_kiem_tra, _cham_soc, canvas 9933). Cột chưa có trong app.get_student_record để gạch, không điền chữ thay thế.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import { Tag, type Column } from '../../ui/Data';
import { CustSection, CustTable } from './CustTable';
import { blankColumns, NO_VALUE } from './custColumns';
import { ATTENDANCE_LABEL, type StudentRecord } from './custTypes';

export function StudentStudyTab({ record }: { record: StudentRecord }) {
  type Row = StudentRecord['enrollments'][number];
  const columns: Column<Row>[] = [
    {
      key: 'class',
      header: 'Lớp',
      primary: true,
      cell: (e) => (
        <span className="flex flex-col">
          {e.class_id && e.class_code ? (
            <Link className="font-medium text-link hover:underline" to={`/crm/lop/${e.class_id}`}>
              {e.class_code}
            </Link>
          ) : (
            'Chưa xếp lớp'
          )}
          <span className="text-caption text-fg-muted">
            {e.code} · {e.subject_name ?? e.subject_code}
          </span>
        </span>
      ),
    },
    ...blankColumns<Row>([
      'Giáo viên',
      'Lịch học',
      'Ngày bắt đầu',
      'Ngày kết thúc',
      'Ngày hết phí',
    ]),
    {
      key: 'status',
      header: 'Tình trạng',
      cell: (e) => <Tag>{e.status_name ?? e.status_code}</Tag>,
    },
    ...blankColumns<Row>(
      ['Giờ đăng ký', 'Đã phân bổ cho lớp', 'Đã học'],
      ['Giờ đăng ký', 'Đã phân bổ cho lớp', 'Đã học'],
    ),
    { key: 'left', header: 'Còn lại', numeric: true, cell: (e) => formatNumber(e.hours_left) },
  ];
  return (
    <CustTable
      caption="Ghi danh và lớp"
      columns={columns}
      rows={record.enrollments}
      rowKey={(e) => e.id}
      empty="Chưa có ghi danh."
    />
  );
}

const CLASS_SUMMARY = [
  'Lớp',
  'Buổi đã học',
  'Có mặt',
  'Muộn',
  'Vắng phép',
  'Vắng không phép',
  'Chuyên cần',
  'Thái độ',
  'Kiến thức',
  'Vận dụng',
  'BTVN giao',
  'BTVN nộp',
  'BTVN điểm TB',
];

export function StudentAttendanceTab({ record }: { record: StudentRecord }) {
  type Row = StudentRecord['attendance'][number] & { key: string };
  const summary = Object.entries(record.attendance_summary);
  const sessions: Row[] = record.attendance.map((a, i) => ({ ...a, key: String(i) }));
  const columns: Column<Row>[] = [
    {
      key: 'date',
      header: 'Ngày',
      primary: true,
      cell: (a) => `${formatDate(a.session_date)} ${a.start_time.slice(0, 5)}`,
    },
    { key: 'class', header: 'Lớp', cell: (a) => a.class_code },
    {
      key: 'status',
      header: 'Điểm danh',
      cell: (a) => ATTENDANCE_LABEL[a.status ?? 'CHUA'] ?? a.status,
    },
    ...blankColumns<Row>(['Giờ trừ', 'BTVN', 'Nhận xét buổi học'], ['Giờ trừ']),
  ];
  return (
    <div className="flex flex-col gap-3">
      <p className="text-fg-muted">
        {summary.length === 0
          ? 'Chưa có điểm danh.'
          : summary.map(([k, n]) => `${ATTENDANCE_LABEL[k] ?? k}: ${n}`).join(' · ')}
      </p>
      <CustSection title="Theo từng lớp">
        <CustTable<never>
          caption="Điểm danh theo từng lớp"
          columns={blankColumns(CLASS_SUMMARY)}
          rows={[]}
          rowKey={(r) => r}
          empty="Chưa có số liệu tổng hợp theo lớp."
        />
      </CustSection>
      <CustSection title="Các buổi gần nhất">
        <CustTable
          caption="Các buổi học gần nhất"
          columns={columns}
          rows={sessions}
          rowKey={(a) => a.key}
          empty="Chưa có buổi học nào."
        />
      </CustSection>
    </div>
  );
}

export function StudentExamTab({ record }: { record: StudentRecord }) {
  type Row = {
    key: string;
    date: string | null;
    kind: string;
    classCode: string | null;
    score: string | null;
    test: { id: string; code: string } | null;
  };
  // Khung KH05_diem_kiem_tra gộp bài trong lớp và bài đầu vào vào một bảng, mới nhất ở trên.
  const rows: Row[] = [
    ...record.exam_scores.map((x, i) => ({
      key: `lop-${i}`,
      date: x.session_date,
      kind: 'Trong lớp',
      classCode: x.class_code,
      score:
        x.total_score === null
          ? null
          : `${formatNumber(x.total_score)}${x.max_score ? ` / ${formatNumber(x.max_score)}` : ''}`,
      test: null,
    })),
    ...record.tests.map((t) => ({
      key: t.id,
      date: t.scheduled_at,
      kind: 'Đầu vào',
      classCode: null,
      score: t.score === null ? null : formatNumber(t.score),
      test: { id: t.id, code: t.code },
    })),
  ].sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
  const columns: Column<Row>[] = [
    {
      key: 'date',
      header: 'Tháng',
      primary: true,
      cell: (r) => (r.date ? formatDate(r.date) : NO_VALUE),
    },
    {
      key: 'kind',
      header: 'Loại',
      cell: (r) => (
        <span className="flex flex-col">
          {r.kind}
          {r.test && (
            <Link
              to={`/crm/phieu-kiem-tra/${r.test.id}`}
              className="font-medium text-link hover:underline"
            >
              {r.test.code}
            </Link>
          )}
        </span>
      ),
    },
    { key: 'class', header: 'Môn / lớp', cell: (r) => r.classCode ?? NO_VALUE },
    { key: 'score', header: 'Điểm', numeric: true, cell: (r) => r.score ?? NO_VALUE },
    ...blankColumns<Row>(['TB lớp', 'Nhận xét giáo viên', 'Người nhập'], ['TB lớp']),
  ];
  return (
    <CustTable
      caption="Chi tiết các bài kiểm tra"
      columns={columns}
      rows={rows}
      rowKey={(r) => r.key}
      empty="Chưa có điểm kiểm tra."
    />
  );
}

export function StudentCareTab() {
  return (
    <CustTable<never>
      caption="Ticket chăm sóc định kỳ"
      columns={blankColumns([
        'Kỳ',
        'Người phụ trách',
        'Cơ sở',
        'Hạn',
        'Trạng thái',
        'Tóm tắt, phản hồi',
        'Hài lòng',
      ])}
      rows={[]}
      rowKey={(r) => r}
      empty="Chưa có dữ liệu chăm sóc."
    />
  );
}
