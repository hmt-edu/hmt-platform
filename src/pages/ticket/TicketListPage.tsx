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
import { useLeadCatalogs } from '../lead/useCatalogs';
import { TicketCard } from './TicketCard';
import { buildTicketConfig } from './ticketConfig';
import { EMPTY_TICKET_STATE, buildTicketFilters } from './ticketFilters';
import type { TicketRow } from './ticketTypes';
import { useRefreshTickets, useTicketBoard, useTicketPage } from './useTicketData';

export function TicketListPage() {
  const access = useAccess();
  const toast = useToast();
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

  const list = useTicketPage(filters, page * (pageSize ?? 0), pageSize);
  const board = useTicketBoard(filters, pageSize, view === 'kanban');
  const rows: TicketRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

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
              reason: 'Đổi trạng thái ticket bằng nút Hành động trong hồ sơ ticket.',
            })}
            onMove={() => undefined}
            onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
            note="Đổi trạng thái ticket bằng nút Hành động trong hồ sơ ticket (Giao, Đang xử lý, Đã xử lý, Đóng, Huỷ)."
            renderCard={(c) => <TicketCard row={c} />}
          />
        )
      }
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.title}`}
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void refreshData()}
      pager={{
        from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
        to: page * (pageSize ?? 0) + rows.length,
        total,
        ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
        ...(page * (pageSize ?? 0) + rows.length < total
          ? { onNext: () => setPage(page + 1) }
          : {}),
      }}
      emptyMessage={{
        title: 'Chưa có ticket nào',
        hint: 'Ticket đề nghị, khiếu nại của phụ huynh và ticket của giáo viên hiện ở đây. Nếu phân hệ Aftersale chưa bật ở cơ sở của bạn thì danh sách luôn trống.',
      }}
    />
  );
}
