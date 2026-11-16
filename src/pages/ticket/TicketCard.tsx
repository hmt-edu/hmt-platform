// Thẻ ticket của Kanban CSN-02 (khuôn K04): mã, tiêu đề, loại, người gửi, mức độ, hạn xử lý.
import { Tag } from '../../ui/Data';
import { formatDateTime } from '../../lib/format';
import { TYPE_LABEL } from './ticketConfig';
import type { TicketRow } from './ticketTypes';

export function TicketCard({ row }: { row: TicketRow }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="font-medium">{row.code}</span>
      <span>{row.title}</span>
      <span className="text-caption text-fg-muted">
        {[TYPE_LABEL[row.ticket_type], row.sender_name, row.assignee_name, row.branch_code]
          .filter(Boolean)
          .join(' · ')}
      </span>
      <span className="flex flex-wrap items-center gap-1 text-caption">
        {row.priority_code === 'KHAN' ? <Tag tone="danger">Khẩn</Tag> : null}
        {row.sla_state === 'QUA_HAN' ? <Tag tone="danger">Quá hạn</Tag> : null}
        {row.sla_state === 'SAP_QUA_HAN' ? <Tag tone="warning">Sắp quá hạn</Tag> : null}
        <span className="text-fg-muted">Hạn {formatDateTime(row.resolve_due_at)}</span>
      </span>
    </div>
  );
}
