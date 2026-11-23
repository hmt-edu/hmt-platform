// Cấu hình bảng CHUNG-15 «Việc chờ tôi duyệt» cho khuôn K03 (canvas 1aab CHUNG15_pc, CHUNG15_kt_pc, CHUNG15_ad_pc).
// Cột: Loại việc, Mã, Học sinh hoặc Phụ huynh, Mã đối tượng, Nội dung, Cấp, Vai trò duyệt, Người tạo, Cơ sở (khi thấy nhiều cơ sở), Thời gian chờ. Dòng chỉ để mở bản ghi; không có nút Duyệt hàng loạt.
import type { AccessView } from '../../nav/access';
import { Tag } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import { KIND_LABELS, KIND_ORDER, detailText, waitingText } from './approvalsLogic';
import type { ApprovalKind, ApprovalPage, ApprovalRow } from './approvalsTypes';

export const APPROVALS_SCREEN_CODE = 'CHUNG-15';
const MUTED = <span className="text-fg-muted">—</span>;

export function buildApprovalsConfig(
  access: AccessView,
  counts: ApprovalPage['counts'] | undefined,
  /** Trang này có dòng nào có tên học sinh/phụ huynh không; không có thì ẩn hai cột đối tượng mặc định (còn bật được ở «Cột»). */
  hasSubject = true,
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
      // T13 «một ô một thông tin»: đối tượng được tách thành tên, mã, nội dung; cấp duyệt tách thành Cấp và Vai trò duyệt.
      {
        key: 'subject',
        label: 'Học sinh / Phụ huynh',
        defaultVisible: hasSubject,
        render: (r) => r.subject_name ?? MUTED,
      },
      {
        key: 'subject_code',
        label: 'Mã đối tượng',
        defaultVisible: hasSubject,
        render: (r) => r.subject_code ?? MUTED,
      },
      { key: 'detail', label: 'Nội dung', render: (r) => detailText(r) ?? MUTED },
      { key: 'level', label: 'Cấp', render: (r) => `${r.level_no}/${r.level_total}` },
      { key: 'level_role', label: 'Vai trò duyệt', render: (r) => r.level_label ?? MUTED },
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
