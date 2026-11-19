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
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import { buildSessionConfig } from './sessionConfig';
import {
  EMPTY_SESSION_STATE,
  SESSION_GROUP_FIELD_OF,
  buildSessionFilters,
  sessionGroupFilter,
  sessionSortParam,
} from './sessionLogic';
import type { SessionRow } from './sessionTypes';
import { useRefreshSessions, useSessionGroupCounts, useSessionPage } from './useSessionData';

export function SessionListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const toast = useToast();
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

  // Group By ở máy chủ (tối đa hai cấp): số đếm từ session_group_counts, dòng tải khi mở từng nhóm lá (session_list).
  const groupFields = state.group.flatMap((k) =>
    SESSION_GROUP_FIELD_OF[k] ? [SESSION_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useSessionPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    grouped ? null : pageSize,
  );
  const counts = useSessionGroupCounts(filters, groupFields, true);
  const leaves = useLeafRows<SessionRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'session_list',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<SessionRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            sessionGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const activeQuery = grouped ? counts : list;
  const rows: SessionRow[] = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);

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
      onRowClick={(r) => void navigate(`/crm/buoi-hoc/${r.id}`)}
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
      sort={sort}
      onSortChange={setSort}
      emptyMessage={{
        title: 'Không có buổi nào',
        hint: 'Đổi ngày hoặc bộ lọc để xem buổi khác. Buổi sinh khi lớp được duyệt.',
      }}
    />
  );
}
