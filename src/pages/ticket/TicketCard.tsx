// Thẻ ticket của Kanban CSN-02 (khuôn K04), theo canvas 9189: dòng mã + người xử lý (chữ cái đầu, «?» khi chưa giao), «Loại · Nhóm con», «Học sinh · Mức: …», nhãn hạn.
import { Tag } from '../../ui/Data';
import { TYPE_LABEL } from './ticketConfig';
import { assigneeInitials } from './ticketInitials';
import type { TicketRow } from './ticketTypes';

export function TicketCard({
  row,
  priorityName,
}: {
  row: TicketRow;
  priorityName: (code: string) => string;
}) {
  return (
    <div className="flex flex-col gap-1">
      <span className="flex items-center justify-between gap-2">
        <span className="font-medium">{row.code}</span>
        <span
          className="rounded-full bg-surface-subtle px-1.5 text-caption text-fg-muted"
          title={row.assignee_name ?? 'Chưa giao'}
        >
          {assigneeInitials(row.assignee_name)}
        </span>
      </span>
      <span>{row.title}</span>
      <span className="text-caption text-fg-muted">
        {[TYPE_LABEL[row.ticket_type], row.category_name].filter(Boolean).join(' · ')}
      </span>
      <span className="text-caption text-fg-muted">
        {row.student_name ?? '—'} · Mức: {priorityName(row.priority_code)}
      </span>
      <span className="flex flex-wrap items-center gap-1 text-caption">
        {row.sla_state === 'QUA_HAN' ? <Tag tone="danger">Quá hạn</Tag> : null}
        {row.sla_state === 'SAP_QUA_HAN' ? <Tag tone="warning">Sắp quá hạn</Tag> : null}
      </span>
    </div>
  );
}
