// Cấu hình màn Nhật ký thao tác (QT-11, khuôn K03 danh sách): cột, lọc nhanh, điều kiện. Lọc, phân trang ở máy chủ.
import { formatDateTime } from '../../lib/format';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import { ACTION_LABEL, summarizeChanges } from './auditLogic';
import type { AuditRow } from './auditTypes';

export const AUDIT_SCREEN_CODE = 'QT-11';

export const EMPTY_AUDIT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const TONE = { I: 'success', U: 'neutral', D: 'danger' } as const;

export function buildAuditConfig(tables: string[]): ListConfig<AuditRow> {
  return {
    screenCode: AUDIT_SCREEN_CODE,
    title: 'Nhật ký thao tác',
    searchPlaceholder: 'Dán mã bản ghi (uuid) để xem lịch sử của nó…',
    columns: [
      {
        key: 'at',
        label: 'Lúc',
        locked: true,
        primary: true,
        render: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
      },
      { key: 'actor', label: 'Ai', render: (r) => r.actor_name ?? 'Hệ thống' },
      { key: 'table', label: 'Bảng', render: (r) => r.table_name },
      {
        key: 'action',
        label: 'Thao tác',
        render: (r) => <Tag tone={TONE[r.action]}>{ACTION_LABEL[r.action]}</Tag>,
      },
      {
        key: 'changes',
        label: 'Nội dung đổi',
        render: (r) => <span title={summarizeChanges(r)}>{summarizeChanges(r)}</span>,
      },
      {
        key: 'record',
        label: 'Mã bản ghi',
        defaultVisible: false,
        render: (r) => <span className="tabular">{r.record_id}</span>,
      },
    ],
    quickGroups: [
      {
        key: 'action',
        label: 'Thao tác',
        options: [
          { value: 'I', label: 'Tạo' },
          { value: 'U', label: 'Sửa' },
          { value: 'D', label: 'Xoá' },
        ],
      },
    ],
    filterFields: [
      {
        key: 'table',
        label: 'Bảng',
        type: 'select',
        ops: ['eq'],
        options: tables.map((t) => ({ value: t, label: t })),
      },
      { key: 'at', label: 'Ngày', type: 'date' },
    ],
    groupFields: [],
    dateFields: [{ key: 'at', label: 'Ngày thao tác' }],
    views: ['list'],
  };
}
