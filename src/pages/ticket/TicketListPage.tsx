// CS-01 Ticket (danh sách, khuôn K03, canvas CSN-01): nối với list_tickets. Lọc, phân trang làm ở máy chủ; chỉ giữ trang đang xem.
// Phân hệ Aftersale tắt ở cơ sở thì hiện câu trung tính (công tắc kiểm cả ở giao diện và trong hàm DB, AS-13).
import { useMemo, useState } from 'react';

import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { useLeafRows } from '../lead/useLeadData';
import { TicketCard } from './TicketCard';
import { buildTicketConfig } from './ticketConfig';
import {
  EMPTY_TICKET_STATE,
  TICKET_GROUP_FIELD_OF,
  buildTicketFilters,
  ticketGroupFilter,
} from './ticketFilters';
import type { TicketRow } from './ticketTypes';
import {
  useRefreshTickets,
  useTicketBoard,
  useTicketGroupCounts,
  useTicketPage,
} from './useTicketData';
import { useNavigateFrom } from '../../layout/crumbTrail';

export function TicketListPage() {
  const access = useAccess();
  const toast = useToast();
  const openFrom = useNavigateFrom();
  const refreshData = useRefreshTickets();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildTicketConfig(catalogs, access), [catalogs, access]);
  const statusCodes = useMemo(
    () => catalogs.filterOptions('TICKET_STATUS').map((o) => o.value),
    [catalogs],
  );
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_TICKET_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildTicketFilters({ ...state, search: debouncedSearch }, statusCodes),
    [state, debouncedSearch, statusCodes],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (tối đa hai cấp, chỉ ở dạng danh sách): số đếm từ ticket_group_counts, dòng tải khi mở từng nhóm lá (list_tickets).
  const groupFields = state.group.flatMap((k) =>
    TICKET_GROUP_FIELD_OF[k] ? [TICKET_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0 && view === 'list';
  const [tick, setTick] = useState(0);
  const list = useTicketPage(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const board = useTicketBoard(filters, pageSize, view === 'kanban');
  const counts = useTicketGroupCounts(filters, groupFields, grouped);
  const leaves = useLeafRows<TicketRow>(
    filters,
    null,
    pageSize,
    `${JSON.stringify(filters)}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_tickets',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<TicketRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            ticketGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows: TicketRow[] = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      kanban={
        board.isPending ? (
          <Spinner label="Đang tải Kanban…" />
        ) : (
          <KanbanBoard
            columns={(board.data ?? []).map((c) => ({
              code: c.status_code,
              label: c.name,
              cards: c.rows,
              total: c.total,
            }))}
            cardKey={(c) => c.id}
            cardLabel={(c) => c.code}
            rule={() => ({
              ok: false,
              reason: 'Đổi trạng thái ticket bằng thanh trạng thái trong hồ sơ ticket.',
            })}
            onMove={() => undefined}
            onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
            note="Đổi trạng thái ticket bằng thanh trạng thái trong hồ sơ ticket (Đang xử lý, Đã xử lý, Đóng, Huỷ)."
            renderCard={(c) => (
              <TicketCard
                row={c}
                priorityName={(code) =>
                  catalogs.filterOptions('TICKET_PRIORITY').find((o) => o.value === code)?.label ??
                  code
                }
              />
            )}
          />
        )
      }
      actions={
        access.can('TICKET', 'TAO')
          ? [
              {
                label: 'Tạo',
                icon: 'plus' as const,
                primary: true,
                onClick: () => openFrom('/crm/ticket/moi'),
              },
            ]
          : []
      }
      rows={rows}
      onRowClick={(r) => openFrom(`/crm/ticket/${r.id}`)}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.title}`}
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
      onRetry={() => void activeQuery.refetch()}
      onRefresh={() => {
        setTick((t) => t + 1);
        void refreshData();
      }}
      groupTree={grouping?.tree}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      pager={
        grouped
          ? undefined
          : {
              from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
              to: page * (pageSize ?? 0) + rows.length,
              total,
              ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
              ...(page * (pageSize ?? 0) + rows.length < total
                ? { onNext: () => setPage(page + 1) }
                : {}),
            }
      }
      emptyMessage={{
        title: 'Chưa có ticket nào',
        hint: 'Ticket đề nghị, khiếu nại của phụ huynh và ticket của giáo viên hiện ở đây. Nếu phân hệ Aftersale chưa bật ở cơ sở của bạn thì danh sách luôn trống.',
      }}
    />
  );
}
