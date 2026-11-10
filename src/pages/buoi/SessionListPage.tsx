// BUOI-01 Buổi học (danh sách, khuôn K03): nối với session_list. Mặc định lọc hôm nay. Lọc, sắp xếp, phân trang làm ở máy chủ. Bấm dòng mở BUOI-02.
// Chưa có bộ lọc theo giáo viên, lớp riêng (chỉ tìm theo mã lớp): thêm khi có ô chọn giáo viên dùng chung.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { buildSessionConfig } from './sessionConfig';
import { EMPTY_SESSION_STATE, buildSessionFilters, sessionSortParam } from './sessionLogic';
import type { SessionRow } from './sessionTypes';
import { useRefreshSessions, useSessionPage } from './useSessionData';

export function SessionListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const refreshData = useRefreshSessions();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildSessionConfig(catalogs, access), [catalogs, access]);
  const statusCodes = useMemo(
    () => catalogs.filterOptions('SESSION_STATUS').map((o) => o.value),
    [catalogs],
  );
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_SESSION_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildSessionFilters({ ...state, search: debouncedSearch }, statusCodes),
    [state, debouncedSearch, statusCodes],
  );
  const sortValue = sessionSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useSessionPage(filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows: SessionRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.class_code} ${r.start_time}`}
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void refreshData()}
      onRowClick={(r) => void navigate(`/crm/buoi-hoc/${r.id}`)}
      pager={{
        from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
        to: page * (pageSize ?? 0) + rows.length,
        total,
        ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
        ...(page * (pageSize ?? 0) + rows.length < total
          ? { onNext: () => setPage(page + 1) }
          : {}),
      }}
      sort={sort}
      onSortChange={setSort}
      emptyMessage={{
        title: 'Không có buổi nào',
        hint: 'Đổi ngày hoặc bộ lọc để xem buổi khác. Buổi sinh khi lớp được duyệt.',
      }}
    />
  );
}
