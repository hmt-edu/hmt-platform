// Cấu hình bảng CHUNG-15 «Việc chờ tôi duyệt» cho khuôn K03 (canvas 1aab CHUNG15_pc, CHUNG15_kt_pc, CHUNG15_ad_pc).
// Cột: Loại việc, Mã, Học sinh · đối tượng, Cấp duyệt, Người tạo, Cơ sở (khi thấy nhiều cơ sở), Thời gian chờ. Dòng chỉ để mở bản ghi; không có nút Duyệt hàng loạt.
import type { AccessView } from '../../nav/access';
import { Tag } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import { KIND_LABELS, KIND_ORDER, waitingText } from './approvalsLogic';
import type { ApprovalKind, ApprovalPage, ApprovalRow } from './approvalsTypes';

export const APPROVALS_SCREEN_CODE = 'CHUNG-15';
const MUTED = <span className="text-fg-muted">—</span>;

export function buildApprovalsConfig(
  access: AccessView,
  counts: ApprovalPage['counts'] | undefined,
): ListConfig<ApprovalRow> {
  const multiBranch = access.seesAllBranches;
  return {
    screenCode: APPROVALS_SCREEN_CODE,
    title: 'Việc chờ tôi duyệt',
    searchPlaceholder: '',
    columns: [
      {
        key: 'kind',
        label: 'Loại việc',
        locked: true,
        primary: true,
        render: (r) => <Tag tone="info">{KIND_LABELS[r.kind]}</Tag>,
      },
      { key: 'code', label: 'Mã', render: (r) => <span className="font-medium">{r.code}</span> },
      {
        key: 'subject',
        label: 'Học sinh · đối tượng',
        render: (r) =>
          r.subject_name || r.detail ? (
            <span>
              {r.subject_name ?? r.detail}
              {r.subject_code ? <span className="text-fg-muted"> {r.subject_code}</span> : null}
            </span>
          ) : (
            MUTED
          ),
      },
      {
        key: 'level',
        label: 'Cấp duyệt',
        render: (r) => (
          <span>
            {r.level_no}/{r.level_total} <span className="text-fg-muted">{r.level_label}</span>
          </span>
        ),
      },
      { key: 'creator', label: 'Người tạo', render: (r) => r.creator_name ?? MUTED },
      ...(multiBranch
        ? [{ key: 'branch', label: 'Cơ sở', render: (r: ApprovalRow) => r.branch_code ?? MUTED }]
        : []),
      { key: 'waiting', label: 'Thời gian chờ', render: (r) => waitingText(r.waiting_since) },
    ],
    quickGroups: [
      {
        key: 'kind',
        label: 'Loại việc',
        options: KIND_ORDER.map((k: ApprovalKind) => ({
          value: k,
          label: `${KIND_LABELS[k]}${counts?.[k] ? ` (${counts[k]})` : ''}`,
        })),
      },
    ],
    filterFields: multiBranch
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
      : [],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
