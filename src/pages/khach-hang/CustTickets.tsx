// Tab «Ticket» ở hồ sơ phụ huynh (KH-02) và học sinh (KH-05), canvas 9933 (KH02_ticket): ticket của phụ huynh, học sinh đó.
// Một lần gọi app.list_tickets mỗi trang (lọc parent_id hoặc student_id ở máy chủ, migration 600); chạy dưới RLS ticket nên người không có quyền thấy 0 dòng.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Pagination, Tag } from '../../ui/Data';
import { StateView, Spinner } from '../../ui/Feedback';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { TYPE_LABEL, ticketStatusTone } from '../ticket/ticketConfig';
import type { TicketPage } from '../ticket/ticketTypes';

export type CustTicketOwner = { key: 'parent_id' | 'student_id'; id: string };

export function CustTickets({ owner }: { owner: CustTicketOwner }) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const pageSize = useIntSetting('list_page_size_default');
  const [page, setPage] = useState(1);
  const query = useQuery({
    queryKey: ['cust-tickets', owner.key, owner.id, page, pageSize],
    enabled: pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TicketPage>(supabase, 'list_tickets', {
        p_filters: { [owner.key]: owner.id },
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  if (query.isPending || pageSize === null) return <Spinner label="Đang tải ticket…" />;
  if (query.isError) {
    return (
      <StateView kind="error" title="Không tải được ticket" headingLevel={2}>
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const { rows, total } = query.data;
  if (total === 0) return <p className="py-2 text-fg-muted">Chưa có ticket nào.</p>;
  return (
    <div className="flex flex-col gap-2">
      <ul className="flex flex-col divide-y divide-border">
        {rows.map((t) => (
          <li key={t.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
            <span className="flex min-w-0 flex-col">
              <Link to={`/crm/ticket/${t.id}`} className="font-medium text-link hover:underline">
                {t.code} · {t.title}
              </Link>
              <span className="text-caption text-fg-muted">
                {TYPE_LABEL[t.ticket_type] ?? t.ticket_type}
                {t.category_name ? ` · ${t.category_name}` : ''} · {formatDateTime(t.created_at)}
              </span>
            </span>
            <Tag tone={ticketStatusTone(t.status_code)}>
              {catalogs.name('TICKET_STATUS', t.status_code) ?? t.status_code}
            </Tag>
          </li>
        ))}
      </ul>
      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </div>
  );
}
