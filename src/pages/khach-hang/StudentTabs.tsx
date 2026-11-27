// Tab Học tập, Điểm danh, Điểm kiểm tra, Chăm sóc của hồ sơ học sinh (khung KH05_hoc_tap, _diem_danh, _diem_danh_chi_tiet,
// _diem_kiem_tra, _cham_soc, canvas 9933). Cột chưa có trong app.get_student_record để gạch, không điền chữ thay thế.
import { useState } from 'react';

import { formatDate, formatDateTime, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Tag, type Column } from '../../ui/Data';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { statusTone } from '../ghi-danh/enrollConfig';
import type { EnrollmentRow } from '../ghi-danh/enrollTypes';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { TEST_TONE } from '../phieu/testConfig';
import { STATUS_LABEL, type TestRow } from '../phieu/testTypes';
import { CustSection, CustTable } from './CustTable';
import { blankColumns, NO_VALUE } from './custColumns';
import { ATTENDANCE_LABEL, type StudentRecord } from './custTypes';
import { PagedTable } from './PagedTable';
import { FromLink } from '../../layout/FromLink';

const STUDY_COLUMNS: Column<EnrollmentRow>[] = [
  {
    key: 'class',
    header: 'Lớp',
    primary: true,
    cell: (e) => (
      <span className="flex flex-col">
        {e.class_id && e.class_code ? (
          <FromLink className="font-medium text-link hover:underline" to={`/crm/lop/${e.class_id}`}>
            {e.class_code}
          </FromLink>
        ) : (
          'Chưa xếp lớp'
        )}
        <span className="text-caption text-fg-muted">
          <FromLink className="text-link hover:underline" to={`/crm/ghi-danh/${e.id}`}>
            {e.code}
          </FromLink>
          {e.package_name ? ` · ${e.package_name}` : ''}
        </span>
      </span>
    ),
  },
  ...blankColumns<EnrollmentRow>([
    'Giáo viên',
    'Lịch học',
    'Ngày bắt đầu',
    'Ngày kết thúc',
    'Ngày hết phí',
  ]),
  {
    key: 'status',
    header: 'Tình trạng',
    cell: (e) => (
      <Tag tone={statusTone(e.status_code)} dot>
        {e.status_name}
      </Tag>
    ),
  },
  {
    key: 'granted',
    header: 'Giờ đăng ký',
    numeric: true,
    cell: (e) => formatNumber(e.granted_hours),
  },
  ...blankColumns<EnrollmentRow>(['Đã phân bổ cho lớp'], ['Đã phân bổ cho lớp']),
  { key: 'used', header: 'Đã học', numeric: true, cell: (e) => formatNumber(e.used_hours) },
  { key: 'left', header: 'Còn lại', numeric: true, cell: (e) => formatNumber(e.remaining_hours) },
];

export function StudentStudyTab({ record }: { record: StudentRecord }) {
  const allowed = useAccess().can('ENROLLMENT', 'XEM');
  const catalogs = useLeadCatalogs();
  const [status, setStatus] = useState('');
  return (
    <div className="flex flex-col gap-2">
      <div className="max-w-xs">
        <OptionalSelect
          label="Tình trạng ghi danh"
          value={status}
          onChange={setStatus}
          options={catalogs.filterOptions('ENROLLMENT_STATUS')}
          placeholder="Mọi tình trạng"
        />
      </div>
      <PagedTable
        caption="Ghi danh và lớp"
        fn="enrollment_list"
        filters={{ student_id: record.id, ...(status ? { status: [status] } : {}) }}
        sort="code_desc"
        columns={STUDY_COLUMNS}
        rowKey={(e) => e.id}
        allowed={allowed}
        empty={status ? 'Không có ghi danh ở tình trạng này.' : 'Chưa có ghi danh.'}
        denied="Bạn không có quyền xem ghi danh."
        total={record.counts.enrollments}
      />
    </div>
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
            <FromLink
              to={`/crm/phieu-kiem-tra/${r.test.id}`}
              className="font-medium text-link hover:underline"
            >
              {r.test.code}
            </FromLink>
          )}
        </span>
      ),
    },
    { key: 'class', header: 'Môn / lớp', cell: (r) => r.classCode ?? NO_VALUE },
    { key: 'score', header: 'Điểm', numeric: true, cell: (r) => r.score ?? NO_VALUE },
    ...blankColumns<Row>(['TB lớp', 'Nhận xét giáo viên', 'Người nhập'], ['TB lớp']),
  ];
  return (
    <div className="flex flex-col gap-3">
      <CustSection title="Chi tiết các bài kiểm tra">
        <CustTable
          caption="Chi tiết các bài kiểm tra"
          columns={columns}
          rows={rows}
          rowKey={(r) => r.key}
          empty="Chưa có điểm kiểm tra."
        />
      </CustSection>
      <StudentTestsSection record={record} />
    </div>
  );
}

const TEST_COLUMNS: Column<TestRow>[] = [
  {
    key: 'code',
    header: 'Mã',
    primary: true,
    cell: (t) => (
      <FromLink
        to={`/crm/phieu-kiem-tra/${t.id}`}
        className="font-medium text-link hover:underline"
      >
        {t.code}
      </FromLink>
    ),
  },
  { key: 'subject', header: 'Môn', cell: (t) => <SubjectName code={t.subject_code} /> },
  { key: 'time', header: 'Ngày giờ test', cell: (t) => formatDateTime(t.scheduled_at) },
  { key: 'branch', header: 'Cơ sở test', cell: (t) => t.test_branch_code },
  { key: 'grader', header: 'GV chấm', cell: (t) => t.grader_name ?? NO_VALUE },
  {
    key: 'score',
    header: 'Điểm',
    numeric: true,
    cell: (t) => (t.score === null ? NO_VALUE : formatNumber(t.score)),
  },
  {
    key: 'status',
    header: 'Trạng thái',
    cell: (t) => <Tag tone={TEST_TONE[t.status_code]}>{STATUS_LABEL[t.status_code]}</Tag>,
  },
];

function SubjectName({ code }: { code: string }) {
  return useLeadCatalogs().name('SUBJECT', code) ?? code;
}

function StudentTestsSection({ record }: { record: StudentRecord }) {
  const allowed = useAccess().can('STUDENT_TEST', 'XEM');
  const [status, setStatus] = useState('');
  return (
    <CustSection title="Phiếu Test">
      <div className="flex flex-col gap-2">
        <div className="max-w-xs">
          <OptionalSelect
            label="Trạng thái phiếu Test"
            value={status}
            onChange={setStatus}
            options={Object.entries(STATUS_LABEL).map(([value, label]) => ({ value, label }))}
            placeholder="Mọi trạng thái"
          />
        </div>
        <PagedTable
          caption="Phiếu Test"
          fn="list_student_tests"
          filters={{ student_id: record.id, ...(status ? { status: [status] } : {}) }}
          sort="time_desc"
          columns={TEST_COLUMNS}
          rowKey={(t) => t.id}
          allowed={allowed}
          empty={status ? 'Không có phiếu Test ở trạng thái này.' : 'Chưa có phiếu Test.'}
          denied="Bạn không có quyền xem phiếu Test."
          total={record.counts.tests}
        />
      </div>
    </CustSection>
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
