// Tab «Ticket» ở hồ sơ phụ huynh (KH02_ticket) và «Đề nghị & khiếu nại» ở hồ sơ học sinh (KH05_de_nghi), canvas 9933.
// Một lần gọi app.list_tickets mỗi trang (lọc parent_id hoặc student_id ở máy chủ, migration 600); chạy dưới RLS ticket nên chỉ thấy ticket trong quyền.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';

import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Pagination, Tag, type Column } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useLeadCatalogs, type LeadCatalogs } from '../lead/useCatalogs';
import { TYPE_LABEL, ticketStatusTone } from '../ticket/ticketConfig';
import type { TicketPage, TicketRow } from '../ticket/ticketTypes';
import { useTicketCategories } from '../ticket/useTicketData';
import { CustTable } from './CustTable';
import { NO_VALUE } from './custColumns';
import type { CustTicketOwner } from './useCustTickets';
import { FromLink } from '../../layout/FromLink';

function ticketColumns(owner: CustTicketOwner['key'], catalogs: LeadCatalogs): Column<TicketRow>[] {
  const code: Column<TicketRow> = {
    key: 'code',
    header: 'Mã',
    primary: true,
    cell: (t) => (
      <FromLink to={`/crm/ticket/${t.id}`} className="font-medium text-link hover:underline">
        {t.code}
      </FromLink>
    ),
  };
  const type: Column<TicketRow> = {
    key: 'type',
    header: 'Loại',
    cell: (t) => TYPE_LABEL[t.ticket_type] ?? t.ticket_type,
  };
  const due: Column<TicketRow> = {
    key: 'due',
    header: 'Hạn',
    cell: (t) => (
      <span className="flex flex-wrap items-center gap-1">
        {formatDateTime(t.resolve_due_at)}
        {t.sla_state === 'QUA_HAN' && <Tag tone="danger">Quá hạn</Tag>}
      </span>
    ),
  };
  const status = (header: string): Column<TicketRow> => ({
    key: 'status',
    header,
    cell: (t) => (
      <Tag tone={ticketStatusTone(t.status_code)} dot>
        {catalogs.name('TICKET_STATUS', t.status_code) ?? t.status_code}
      </Tag>
    ),
  });
  if (owner === 'parent_id') {
    // KH02_ticket: Loại, Mã, Học sinh, Hạn, Tình trạng.
    return [
      type,
      code,
      { key: 'student', header: 'Học sinh', cell: (t) => t.student_name ?? NO_VALUE },
      due,
      status('Tình trạng'),
    ];
  }
  // KH05_de_nghi: Mã, Loại, Nhóm › nhóm con, Nội dung, kết quả, Người xử lý, Cơ sở, Hạn, Trạng thái.
  return [
    code,
    type,
    {
      key: 'group',
      header: 'Nhóm › nhóm con',
      cell: (t) => [t.group_name, t.category_name].filter(Boolean).join(' › ') || NO_VALUE,
    },
    { key: 'title', header: 'Nội dung, kết quả', cell: (t) => t.title },
    { key: 'assignee', header: 'Người xử lý', cell: (t) => t.assignee_name ?? 'Chưa giao' },
    { key: 'branch', header: 'Cơ sở', cell: (t) => t.branch_code },
    due,
    status('Trạng thái'),
  ];
}

export function CustTickets({
  owner,
  ticketType,
  onTypeChange,
}: {
  owner: CustTicketOwner;
  /** Loại ticket đang lọc ở hồ sơ học sinh (nút số «Khiếu nại» đặt sẵn). */
  ticketType?: string | undefined;
  /** Có thì hiện hàng lọc Loại, Trạng thái, Nhóm (khung KH05_de_nghi). */
  onTypeChange?: ((type: string | undefined) => void) | undefined;
}) {
  const supabase = useDb();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const allowed = access.can('TICKET', 'XEM');
  const pageSize = useIntSetting('list_page_size_default');
  const [paging, setPaging] = useState({ key: '', page: 1 });
  const [status, setStatus] = useState('');
  const [group, setGroup] = useState('');
  const categories = useTicketCategories();
  const filters = {
    [owner.key]: owner.id,
    ...(ticketType ? { ticket_type: ticketType } : {}),
    ...(status ? { status_code: status } : {}),
    ...(group ? { group_code: group } : {}),
  };
  const key = JSON.stringify(filters);
  const filtered = Boolean(ticketType || status || group);
  const page = paging.key === key ? paging.page : 1;
  const query = useQuery({
    queryKey: ['cust-tickets', owner.key, owner.id, key, page, pageSize],
    enabled: allowed && pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TicketPage>(supabase, 'list_tickets', {
        p_filters: filters,
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  if (query.isError) {
    return (
      <StateView kind="error" title="Không tải được ticket" headingLevel={2}>
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const total = query.data?.total ?? 0;
  return (
    <div className="flex flex-col gap-2">
      {onTypeChange && (
        <div className="grid gap-2 sm:grid-cols-3">
          <OptionalSelect
            label="Loại ticket"
            value={ticketType ?? ''}
            onChange={(v) => onTypeChange(v || undefined)}
            options={Object.entries(TYPE_LABEL).map(([value, label]) => ({ value, label }))}
            placeholder="Mọi loại"
          />
          <OptionalSelect
            label="Trạng thái ticket"
            value={status}
            onChange={setStatus}
            options={catalogs.filterOptions('TICKET_STATUS')}
            placeholder="Mọi trạng thái"
          />
          <OptionalSelect
            label="Nhóm ticket"
            value={group}
            onChange={setGroup}
            options={(categories.data ?? [])
              .filter((c) => c.parent_code === null)
              .map((c) => ({ value: c.code, label: c.name }))}
            placeholder="Mọi nhóm"
          />
        </div>
      )}
      <CustTable
        caption="Ticket"
        columns={ticketColumns(owner.key, catalogs)}
        rows={query.data?.rows ?? []}
        rowKey={(t) => t.id}
        loading={allowed && query.isPending}
        empty={
          !allowed
            ? 'Bạn không có quyền xem ticket.'
            : filtered
              ? 'Không có ticket nào khớp bộ lọc.'
              : 'Chưa có ticket nào.'
        }
      />
      {total > 0 && pageSize !== null && (
        <Pagination
          page={page}
          pageSize={pageSize}
          total={total}
          onPageChange={(p) => setPaging({ key, page: p })}
        />
      )}
    </div>
  );
}
