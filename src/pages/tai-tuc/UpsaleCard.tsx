// Thẻ phiếu tái tục của Kanban TT-01 (khuôn K04): mã, học sinh, lớp, giờ còn, hết giờ dự kiến, nhóm con, phụ trách.
import { Tag } from '../../ui/Data';
import { formatDate } from '../../lib/format';
import type { UpsaleRow } from './upsaleTypes';

export function UpsaleCard({ row }: { row: UpsaleRow }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="font-medium">{row.code}</span>
      <span>{row.student_name}</span>
      <span className="text-caption text-fg-muted">
        {[row.class_code, row.enrollment_count > 1 ? `${row.enrollment_count} ghi danh` : null]
          .filter(Boolean)
          .join(' · ')}
      </span>
      <span className="text-caption text-fg-muted">
        {[
          row.hours_left === null ? null : `Giờ còn ${row.hours_left}`,
          row.campaign_label,
          row.expected_end_date ? `hết giờ ${formatDate(row.expected_end_date)}` : null,
          row.substage_code,
        ]
          .filter(Boolean)
          .join(' · ')}
      </span>
      <span className="flex flex-wrap items-center gap-1 text-caption">
        {row.risk_flag ? <Tag tone="danger">Rủi ro vắng</Tag> : null}
        <span className="text-fg-muted">{row.owner_name ?? 'chưa giao'}</span>
      </span>
    </div>
  );
}
