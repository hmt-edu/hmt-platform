// Cấu hình danh sách phiếu tái tục cho khuôn K03: TT-01. Cột (anh Trường chốt 27/11): Phiếu, Học sinh, Phụ huynh, Môn, Lớp, Giờ còn, Hết giờ dự kiến, Phụ trách,
// Liên hệ gần nhất, Giai đoạn, Xử lý; Ghi danh (n), Tháng hết giờ, Sub-stage ẩn sẵn. Phụ huynh, Môn, Liên hệ gần nhất: máy chủ chưa trả. Lọc, sắp xếp, phân trang ở máy chủ.
import { formatDate } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import { Button } from '../../ui/Button';
import type { ListConfig } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { UpsaleRow } from './upsaleTypes';

export const UPSALE_SCREEN_CODE = 'TT-01';

const MUTED = <span className="text-fg-muted">—</span>;

const STAGE_TONE: Record<string, TagTone> = {
  L1: 'info',
  L2: 'info',
  L3: 'warning',
  L4: 'warning',
  L5: 'neutral',
  L6: 'success',
  L7: 'success',
  L8: 'success',
};
export const upsaleStageTone = (code: string): TagTone => STAGE_TONE[code] ?? 'neutral';

export function buildUpsaleConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
  onAssign: (row: UpsaleRow) => void,
): ListConfig<UpsaleRow> {
  const stageOptions = catalogs.filterOptions('UPSALE_STAGE');
  const canAssign = access.can('UPSALE', 'GIAO_VIEC');
  return {
    screenCode: UPSALE_SCREEN_CODE,
    title: 'Tái tục',
    searchPlaceholder: 'Tìm mã phiếu, tên học sinh hoặc mã lớp…',
    columns: [
      {
        key: 'code',
        label: 'Phiếu',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.code}</span>,
      },
      {
        key: 'student',
        label: 'Học sinh',
        render: (r) => (
          <span>
            {r.student_name}
            {r.risk_flag ? <Tag tone="danger">Rủi ro vắng</Tag> : null}
          </span>
        ),
      },
      { key: 'parent', label: 'Phụ huynh', render: () => MUTED },
      { key: 'subject', label: 'Môn', render: () => MUTED },
      { key: 'class', label: 'Lớp', render: (r) => r.class_code },
      {
        key: 'hours',
        label: 'Giờ còn',
        render: (r) => (r.hours_left === null ? MUTED : r.hours_left),
      },
      {
        key: 'end',
        label: 'Hết giờ dự kiến',
        render: (r) => (r.expected_end_date ? formatDate(r.expected_end_date) : MUTED),
      },
      { key: 'owner', label: 'Phụ trách', render: (r) => r.owner_name ?? 'chưa giao' },
      { key: 'last-contact', label: 'Liên hệ gần nhất', render: () => MUTED },
      {
        key: 'stage',
        label: 'Giai đoạn',
        render: (r) => (
          <Tag tone={upsaleStageTone(r.stage_code)} dot>
            {r.stage_code} {catalogs.name('UPSALE_STAGE', r.stage_code) ?? ''}
          </Tag>
        ),
      },
      {
        key: 'enrollments',
        label: 'Ghi danh (n)',
        defaultVisible: false,
        render: (r) => r.enrollment_count,
      },
      {
        key: 'campaign',
        label: 'Tháng hết giờ',
        defaultVisible: false,
        render: (r) => r.campaign_label ?? MUTED,
      },
      {
        key: 'substage',
        label: 'Sub-stage',
        defaultVisible: false,
        render: (r) =>
          r.substage_code
            ? (catalogs.name('UPSALE_SUBSTAGE', r.substage_code) ?? r.substage_code)
            : MUTED,
      },
      {
        key: 'actions',
        label: 'Xử lý',
        render: (r) =>
          canAssign && r.stage_code !== 'L5' && r.stage_code !== 'L8' ? (
            <Button
              onClick={(e) => {
                e.stopPropagation();
                onAssign(r);
              }}
            >
              Giao
            </Button>
          ) : (
            MUTED
          ),
      },
    ],
    quickGroups: [
      { key: 'stage', label: 'Giai đoạn', options: stageOptions },
      {
        key: 'owner',
        label: 'Phụ trách',
        options: [
          { value: 'mine', label: 'Của tôi' },
          { value: 'unassigned', label: 'Chưa giao' },
        ],
      },
      { key: 'risk', label: 'Rủi ro', options: [{ value: 'risk', label: 'Rủi ro vắng nhiều' }] },
    ],
    filterFields: [
      {
        key: 'month',
        label: 'Tháng hết giờ (YYYY-MM)',
        type: 'text',
        ops: ['eq'],
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
    ],
    // Group By ở máy chủ (K1_nhom): giai đoạn, nhóm con, đợt tái tục, phụ trách, cơ sở (khi xem nhiều cơ sở).
    groupFields: [
      { key: 'stage', label: 'Giai đoạn', value: (r) => r.stage_code },
      { key: 'substage', label: 'Sub-stage', value: (r) => r.substage_code ?? '' },
      { key: 'campaign', label: 'Tháng hết giờ', value: (r) => r.campaign_label ?? '' },
      { key: 'owner', label: 'Phụ trách', value: (r) => r.owner_id ?? '' },
      ...(access.seesAllBranches
        ? [{ key: 'branch', label: 'Cơ sở', value: (r: UpsaleRow) => r.branch_code }]
        : []),
    ],
    dateFields: [],
    views: ['list', 'kanban'],
  };
}
