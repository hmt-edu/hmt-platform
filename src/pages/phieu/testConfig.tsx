// Cấu hình màn Phiếu kiểm tra cho khuôn danh sách K1 (TS-16): cột, lọc nhanh, trường lọc nâng cao, trường nhóm.
// Mọi lọc, nhóm làm ở máy chủ nên cấu hình không có hàm `test`/`value` chạy ở trình duyệt.
import { Link } from 'react-router';
import { formatDateTime, formatNumber } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import type { ListConfig, ListState } from '../../list/types';
import { Code, Tag, type TagTone } from '../../ui/Data';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { STATUS_LABEL, type TestRow, type TestStatus } from './testTypes';

export const TEST_SCREEN_CODE = 'TS-16';

/** Trạng thái ban đầu: xem tuần này (bản vẽ TS16), chưa lọc gì khác. */
export const EMPTY_TEST_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'time',
  datePreset: 'week',
};

export const TEST_TONE: Record<TestStatus, TagTone> = {
  DRAFT: 'neutral',
  TESTING: 'info',
  TEACHER_REVIEW: 'warning',
  COMPLETED: 'success',
  CANCELLED: 'neutral',
};

export function buildTestConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
  people: { value: string; label: string }[],
): ListConfig<TestRow> {
  const name = (catalog: string, code: string) => catalogs.name(catalog, code) ?? code;
  return {
    screenCode: TEST_SCREEN_CODE,
    title: 'Phiếu Test',
    searchPlaceholder: 'Tìm tên, SĐT, mã (cả mã cũ)…',
    columns: [
      { key: 'code', label: 'Mã PKT', locked: true, render: (r) => <Code>{r.code}</Code> },
      {
        key: 'student',
        label: 'Học sinh',
        locked: true,
        primary: true,
        render: (r) => (
          <Link
            to={`/crm/phieu-kiem-tra/${r.id}`}
            className="font-medium text-link hover:underline"
          >
            {r.student_name}
          </Link>
        ),
      },
      { key: 'creator', label: 'Người tạo', render: (r) => r.created_by_name ?? '' },
      { key: 'subject', label: 'Môn', render: (r) => name('SUBJECT', r.subject_code) },
      { key: 'mode', label: 'Hình thức', render: (r) => name('TEST_MODE', r.mode_code) },
      { key: 'level', label: 'Cấp độ', render: (r) => name('TEST_LEVEL', r.level_code) },
      {
        key: 'time',
        label: 'Ngày giờ test',
        sortable: true,
        render: (r) => <span className="tabular">{formatDateTime(r.scheduled_at)}</span>,
      },
      { key: 'test_branch', label: 'Cơ sở test', render: (r) => r.test_branch_code },
      { key: 'owner', label: 'Người phụ trách', render: (r) => r.owner_name ?? '' },
      {
        key: 'grader',
        label: 'GV chấm',
        render: (r) => r.grader_name ?? <span className="text-fg-muted">—</span>,
      },
      {
        key: 'score',
        label: 'Điểm',
        render: (r) =>
          r.score === null ? (
            <span className="text-fg-muted">—</span>
          ) : (
            <span className="tabular">{formatNumber(r.score)}</span>
          ),
      },
      {
        key: 'status',
        label: 'Trạng thái',
        render: (r) => <Tag tone={TEST_TONE[r.status_code]}>{STATUS_LABEL[r.status_code]}</Tag>,
      },
      {
        key: 'opportunity',
        label: 'Cơ hội gốc',
        render: (r) => (
          <Link to={`/crm/co-hoi/${r.opportunity_id}`} className="text-link hover:underline">
            {r.opportunity_code}
          </Link>
        ),
      },
      { key: 'branch', label: 'Cơ sở tạo', render: (r) => r.branch_code },
    ],
    quickGroups: [
      {
        key: 'mine',
        label: 'Của tôi',
        options: [
          { value: 'creator', label: 'Tôi tạo' },
          { value: 'owner', label: 'Tôi phụ trách' },
          { value: 'grader', label: 'Tôi chấm bài' },
        ],
      },
      {
        key: 'when',
        label: 'Thời gian',
        options: [
          { value: 'overdue', label: 'Quá giờ', hint: 'phiếu Nháp đã quá giờ test, chưa bắt đầu' },
          { value: 'today', label: 'Hôm nay' },
          { value: 'upcoming', label: 'Sắp tới', hint: 'từ ngày mai trở đi' },
        ],
      },
      {
        key: 'status',
        label: 'Trạng thái',
        options: [
          { value: 'draft', label: STATUS_LABEL.DRAFT },
          { value: 'testing', label: STATUS_LABEL.TESTING },
          { value: 'review', label: STATUS_LABEL.TEACHER_REVIEW },
          { value: 'done', label: STATUS_LABEL.COMPLETED },
          { value: 'cancelled', label: STATUS_LABEL.CANCELLED },
        ],
      },
    ],
    filterFields: [
      { key: 'subject', label: 'Môn', type: 'multi', options: catalogs.options('SUBJECT') },
      { key: 'mode', label: 'Hình thức', type: 'multi', options: catalogs.options('TEST_MODE') },
      { key: 'level', label: 'Cấp độ', type: 'multi', options: catalogs.options('TEST_LEVEL') },
      ...(access.seesAllBranches
        ? [
            {
              key: 'test_branch',
              label: 'Cơ sở test',
              type: 'select' as const,
              ops: ['eq' as const],
              options: access.teachingBranches.map((b) => ({
                value: b.id,
                label: `${b.code} ${b.name}`,
              })),
            },
          ]
        : []),
      { key: 'owner', label: 'Người phụ trách', type: 'select', ops: ['eq'], options: people },
      { key: 'grader', label: 'GV chấm', type: 'select', ops: ['eq'], options: people },
      { key: 'time', label: 'Ngày giờ test', type: 'date' },
    ],
    groupFields: [
      { key: 'status', label: 'Trạng thái', value: (r) => r.status_code },
      { key: 'subject', label: 'Môn', value: (r) => r.subject_code },
      { key: 'mode', label: 'Hình thức', value: (r) => r.mode_code },
      { key: 'level', label: 'Cấp độ', value: (r) => r.level_code },
      { key: 'owner', label: 'Người phụ trách', value: (r) => r.owner_id },
      { key: 'grader', label: 'GV chấm', value: (r) => r.grader_id ?? '' },
      { key: 'test_branch', label: 'Cơ sở test', value: (r) => r.test_branch_code },
    ],
    dateFields: [{ key: 'time', label: 'Ngày giờ test' }],
    views: ['list', 'kanban', 'calendar'],
  };
}
