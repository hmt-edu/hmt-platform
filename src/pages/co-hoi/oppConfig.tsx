// Cấu hình màn Cơ hội cho khuôn danh sách K1: cột, lọc nhanh, trường lọc nâng cao, trường nhóm (TS-07).
// Mọi lọc, nhóm làm ở máy chủ nên cấu hình không có hàm `test`/`value` chạy ở trình duyệt.
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Code, Tag } from '../../ui/Data';
import type { ListConfig, ListState } from '../../list/types';
import { appointmentTag, codeAndName, formatPhone } from '../lead/leadFormat';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { OpportunityRow } from './oppTypes';
import { FromLink } from '../../layout/FromLink';

export const OPP_SCREEN_CODE = 'TS-07';

/** Trạng thái ban đầu: chưa lọc, chưa nhóm, ô Ngày dùng "Ngày tạo". */
export const EMPTY_OPP_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

/** Lọc nhanh «Tạo trực tiếp» → khoá `direct_only` của bốn hàm Cơ hội (lead_id trống, R-CRM-01). */
export function directFilter(state: ListState): { direct_only?: true } {
  return (state.quick.origin ?? []).includes('direct') ? { direct_only: true } : {};
}

/** Tên hiển thị của cơ hội: phụ huynh và học sinh (cơ hội chưa lưu môn, lớp). */
export function oppTitle(row: { parent_name: string; student_name: string | null }): string {
  return row.student_name ? `${row.student_name} · ${row.parent_name}` : row.parent_name;
}

export function buildOppConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
  /** Số cơ hội tạo trực tiếp theo bộ lọc đang xem (máy chủ đếm); chưa có thì không ghi số. */
  directTotal?: number,
): ListConfig<OpportunityRow> {
  const stageLabel = (code: string) => codeAndName(code, catalogs.name('OPP_STAGE', code));
  const withCode = (catalog: string) =>
    catalogs.options(catalog).map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));
  const now = new Date();
  return {
    screenCode: OPP_SCREEN_CODE,
    title: 'Cơ hội',
    searchPlaceholder: 'Tìm tên, SĐT, mã (cả mã cũ)…',
    columns: [
      { key: 'code', label: 'Mã', locked: true, render: (r) => <Code>{r.code}</Code> },
      {
        key: 'opportunity',
        label: 'Cơ hội',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <FromLink to={`/crm/co-hoi/${r.id}`} className="font-medium text-link hover:underline">
            {r.student_name ?? <span className="text-fg-muted">Chưa có học sinh</span>}
          </FromLink>
        ),
      },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
      { key: 'phone', label: 'SĐT', render: (r) => formatPhone(r.parent_phone) },
      {
        key: 'stage',
        label: 'Stage',
        render: (r) =>
          r.record_status === 'DA_GOP' ? <Tag>Đã gộp</Tag> : <Tag>{stageLabel(r.stage_code)}</Tag>,
      },
      {
        key: 'substage',
        label: 'Sub-stage',
        render: (r) =>
          r.record_status === 'DA_GOP' ? (
            r.merged_into_code ? (
              `vào ${r.merged_into_code}`
            ) : (
              <span className="text-fg-muted">—</span>
            )
          ) : r.substage_code ? (
            codeAndName(r.substage_code, catalogs.name('OPP_SUBSTAGE', r.substage_code))
          ) : (
            <span className="text-fg-muted">—</span>
          ),
      },
      {
        key: 'source_type',
        label: 'Source type',
        render: (r) => catalogs.name('SOURCE_TYPE', r.source_type_code) ?? r.source_type_code,
      },
      {
        key: 'source',
        label: 'Source',
        render: (r) => catalogs.name('SOURCE', r.source_code) ?? r.source_code,
      },
      {
        key: 'medium',
        label: 'Medium',
        render: (r) =>
          r.channel_code ? (
            (catalogs.name('SOURCE_CHANNEL', r.channel_code) ?? r.channel_code)
          ) : (
            <span className="text-fg-muted">—</span>
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
      {
        key: 'mine',
        label: 'Của tôi',
        options: [
          { value: 'owner', label: 'Tôi phụ trách' },
          { value: 'support', label: 'Tôi hỗ trợ' },
        ],
      },
      {
        key: 'origin',
        label: 'Cách tạo',
        options: [
          {
            value: 'direct',
            label: directTotal === undefined ? 'Tạo trực tiếp' : `Tạo trực tiếp (${directTotal})`,
            hint: 'cơ hội không qua lead',
          },
        ],
      },
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
        options: [{ value: 'merged', label: 'Hiện cả cơ hội đã gộp (chỉ xem, không sửa được)' }],
      },
    ],
    filterFields: [
      { key: 'stage', label: 'Stage', type: 'multi', options: withCode('OPP_STAGE') },
      { key: 'substage', label: 'Sub-stage', type: 'multi', options: withCode('OPP_SUBSTAGE') },
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
