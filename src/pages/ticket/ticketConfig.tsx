// Cấu hình danh sách ticket cho khuôn K03: CS-01 (canvas CSN-01). Cột và chữ theo canvas CSN01 (mã, tiêu đề, loại, người gửi, nhóm con, cơ sở, mức độ,
// người phụ trách, trạng thái, hạn). Lọc nhanh: Loại, Hạn (Quá hạn, Sắp quá hạn, Chờ đóng), Trạng thái, Của tôi. Lọc, sắp xếp, phân trang làm ở máy chủ.
import { formatDateTime } from '../../lib/format';
import type { AccessView } from '../../nav/access';
import { Tag, type TagTone } from '../../ui/Data';
import type { ListConfig } from '../../list/types';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { TicketRow } from './ticketTypes';

export const TICKET_SCREEN_CODE = 'CS-01';

const MUTED = <span className="text-fg-muted">—</span>;

export const TYPE_LABEL: Record<string, string> = {
  DN: 'Đề nghị',
  KN: 'Khiếu nại',
  GV: 'Giáo viên',
};

const STATUS_TONE: Record<string, TagTone> = {
  MOI: 'info',
  DA_GIAO: 'info',
  DANG_XU_LY: 'warning',
  CHO_THONG_TIN: 'neutral',
  DA_XU_LY: 'success',
  DA_DONG: 'neutral',
  DA_HUY: 'neutral',
};
export const ticketStatusTone = (code: string): TagTone => STATUS_TONE[code] ?? 'neutral';

const PRIORITY_TONE: Record<string, TagTone> = {
  KHAN: 'danger',
  CAO: 'warning',
  THUONG: 'neutral',
  THAP: 'neutral',
};

export function buildTicketConfig(
  catalogs: LeadCatalogs,
  access: AccessView,
): ListConfig<TicketRow> {
  const statusOptions = catalogs.filterOptions('TICKET_STATUS');
  const priorityOptions = catalogs.filterOptions('TICKET_PRIORITY');
  const nameOf = (catalog: string, code: string) =>
    catalogs.filterOptions(catalog).find((o) => o.value === code)?.label ?? code;
  return {
    screenCode: TICKET_SCREEN_CODE,
    title: 'Ticket',
    searchPlaceholder: 'Tìm mã hoặc tiêu đề ticket…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        primary: true,
        render: (r) => <span className="font-medium">{r.code}</span>,
      },
      { key: 'title', label: 'Tiêu đề', render: (r) => r.title },
      { key: 'type', label: 'Loại', render: (r) => TYPE_LABEL[r.ticket_type] ?? r.ticket_type },
      { key: 'sender', label: 'Người gửi', render: (r) => r.sender_name ?? MUTED },
      {
        key: 'category',
        label: 'Nhóm · Nhóm con',
        render: (r) =>
          r.category_name
            ? r.group_name
              ? `${r.group_name} · ${r.category_name}`
              : r.category_name
            : MUTED,
      },
      { key: 'student', label: 'Học sinh', render: (r) => r.student_name ?? MUTED },
      { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
      {
        key: 'priority',
        label: 'Mức độ',
        render: (r) => (
          <Tag tone={PRIORITY_TONE[r.priority_code] ?? 'neutral'}>
            {nameOf('TICKET_PRIORITY', r.priority_code)}
          </Tag>
        ),
      },
      { key: 'assignee', label: 'Người phụ trách', render: (r) => r.assignee_name ?? MUTED },
      {
        key: 'status',
        label: 'Trạng thái',
        render: (r) => (
          <Tag tone={ticketStatusTone(r.status_code)} dot>
            {nameOf('TICKET_STATUS', r.status_code)}
          </Tag>
        ),
      },
      {
        key: 'due',
        label: 'Hạn xử lý',
        render: (r) => (
          <span
            className={
              r.sla_state === 'QUA_HAN'
                ? 'text-danger'
                : r.sla_state === 'SAP_QUA_HAN'
                  ? 'text-warning'
                  : undefined
            }
          >
            {formatDateTime(r.resolve_due_at)}
            {r.sla_state === 'QUA_HAN' ? ' · Quá hạn' : ''}
            {r.sla_state === 'SAP_QUA_HAN' ? ' · Sắp quá hạn' : ''}
            {r.sla_state === 'CHO_DONG' ? ' · Chờ đóng' : ''}
          </span>
        ),
      },
      { key: 'created', label: 'Tạo lúc', render: (r) => formatDateTime(r.created_at) },
    ],
    quickGroups: [
      {
        key: 'type',
        label: 'Loại',
        options: [
          { value: 'DN', label: 'Đề nghị' },
          { value: 'KN', label: 'Khiếu nại' },
          { value: 'GV', label: 'Giáo viên' },
        ],
      },
      {
        key: 'sla',
        label: 'Hạn xử lý',
        options: [
          { value: 'QUA_HAN', label: 'Quá hạn' },
          { value: 'SAP_QUA_HAN', label: 'Sắp quá hạn' },
          { value: 'CHO_DONG', label: 'Chờ đóng' },
        ],
      },
      { key: 'status', label: 'Trạng thái', options: statusOptions },
      { key: 'mine', label: 'Của tôi', options: [{ value: 'mine', label: 'Ticket của tôi' }] },
    ],
    filterFields: [
      { key: 'priority', label: 'Mức độ', type: 'select', ops: ['eq'], options: priorityOptions },
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
    groupFields: [],
    dateFields: [],
    views: ['list', 'kanban'],
  };
}
