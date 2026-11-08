// Cấu hình màn Lead cho khuôn danh sách K1: cột, lọc nhanh, trường lọc nâng cao, trường nhóm (TS-01).
// Mọi lọc, nhóm làm ở máy chủ nên cấu hình không có hàm `test`/`value` chạy ở trình duyệt.
import { Link } from 'react-router';
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Code, Tag } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import { appointmentTag, codeAndName, formatPhone } from './leadFormat';
import type { LeadRow } from './leadTypes';
import { Stacked } from './LeadCells';
import type { LeadCatalogs } from './useCatalogs';

export const LEAD_SCREEN_CODE = 'TS-01';

/** Trạng thái ban đầu: chưa lọc, chưa nhóm, ô Ngày dùng "Ngày tạo". */
export const EMPTY_LEAD_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

export function buildLeadConfig(catalogs: LeadCatalogs, access: AccessView): ListConfig<LeadRow> {
  const stageLabel = (code: string) => codeAndName(code, catalogs.name('LEAD_STAGE', code));
  const withCode = (catalog: string) =>
    catalogs.options(catalog).map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));
  const now = new Date();
  return {
    screenCode: LEAD_SCREEN_CODE,
    title: 'Lead',
    searchPlaceholder: 'Tìm tên, SĐT, mã (cả mã cũ)…',
    columns: [
      { key: 'code', label: 'Mã', locked: true, render: (r) => <Code>{r.code}</Code> },
      {
        key: 'parent',
        label: 'Phụ huynh · SĐT',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <Stacked
            top={
              <Link to={`/crm/lead/${r.id}`} className="font-medium text-link hover:underline">
                {r.parent_name}
              </Link>
            }
            bottom={formatPhone(r.parent_phone)}
          />
        ),
      },
      {
        key: 'student',
        label: 'Học sinh',
        render: (r) => r.student_name ?? <span className="text-fg-muted">—</span>,
      },
      {
        key: 'source',
        label: 'Source · Sub-source',
        render: (r) => (
          <Stacked
            top={catalogs.name('SOURCE', r.source_code) ?? r.source_code}
            bottom={catalogs.name('SOURCE_CHANNEL', r.channel_code)}
          />
        ),
      },
      {
        key: 'stage',
        label: 'Stage · Sub-stage',
        render: (r) =>
          r.record_status === 'DA_GOP' ? (
            <Stacked
              top={<Tag>Đã gộp</Tag>}
              bottom={r.merged_into_code ? `vào ${r.merged_into_code}` : undefined}
            />
          ) : (
            <Stacked
              top={<Tag>{stageLabel(r.stage_code)}</Tag>}
              bottom={
                r.substage_code
                  ? codeAndName(r.substage_code, catalogs.name('LEAD_SUBSTAGE', r.substage_code))
                  : undefined
              }
            />
          ),
      },
      { key: 'owner', label: 'Sale phụ trách', render: (r) => r.owner_name ?? '' },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'next',
        label: 'Lịch hẹn kế tiếp',
        sortable: true,
        render: (r) => {
          if (r.record_status === 'DA_GOP') return <span className="text-fg-muted">—</span>;
          const tag = appointmentTag(r.next_appointment_at, now);
          return (
            <Tag tone={tag.tone} dot>
              {tag.label}
            </Tag>
          );
        },
      },
      {
        key: 'created',
        label: 'Ngày tạo',
        numeric: true,
        sortable: true,
        render: (r) => formatDate(r.created_at),
      },
    ],
    quickGroups: [
      { key: 'mine', label: 'Của tôi', options: [{ value: 'owner', label: 'Tôi phụ trách' }] },
      {
        key: 'appt',
        label: 'Lịch hẹn',
        options: [
          { value: 'overdue', label: 'Quá hạn', hint: 'lịch hẹn kế tiếp trước đầu ngày hôm nay' },
          { value: 'today', label: 'Hôm nay' },
          { value: 'upcoming', label: 'Sắp tới', hint: 'từ ngày mai trở đi' },
          { value: 'none', label: 'Chưa có lịch hẹn' },
        ],
      },
      {
        key: 'status',
        label: 'Trạng thái bản ghi',
        options: [{ value: 'merged', label: 'Đã gộp', hint: 'hiện cả bản đã gộp (chỉ đọc)' }],
      },
    ],
    filterFields: [
      { key: 'stage', label: 'Stage', type: 'multi', options: withCode('LEAD_STAGE') },
      { key: 'substage', label: 'Sub-stage', type: 'multi', options: withCode('LEAD_SUBSTAGE') },
      {
        key: 'source_type',
        label: 'Loại nguồn',
        type: 'multi',
        options: catalogs.options('SOURCE_TYPE'),
      },
      { key: 'source', label: 'Source', type: 'multi', options: catalogs.options('SOURCE') },
      {
        key: 'channel',
        label: 'Sub-source',
        type: 'multi',
        // Q-127: bộ lọc liệt kê cả kênh đã Ngừng, kèm nhãn (ngừng), để lọc dữ liệu cũ.
        options: catalogs.filterOptions('SOURCE_CHANNEL'),
      },
      {
        key: 'campaign',
        label: 'Chiến dịch',
        type: 'select',
        ops: ['eq'],
        options: catalogs.campaigns,
      },
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
      { key: 'created', label: 'Ngày tạo', type: 'date' },
    ],
    groupFields: [
      { key: 'stage', label: 'Stage', value: (r) => r.stage_code },
      { key: 'source', label: 'Source', value: (r) => r.source_code },
      { key: 'owner', label: 'Sale phụ trách', value: (r) => r.owner_id },
    ],
    dateFields: [{ key: 'created', label: 'Ngày tạo' }],
    views: ['list', 'kanban'],
  };
}
