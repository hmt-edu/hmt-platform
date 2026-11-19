// GD-01 Ghi danh (danh sách, khuôn K03): nối với enrollment_list. Lọc, sắp xếp, phân trang làm ở máy chủ; chỉ giữ trang đang xem. Không có nút Tạo (ghi danh sinh từ dòng
// đơn khi tiền vào đủ cọc, R-GD-01). Bấm mã hoặc dòng để mở GD-02.
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
import { buildEnrollConfig } from './enrollConfig';
import {
  ENROLL_GROUP_FIELD_OF,
  EMPTY_ENROLL_STATE,
  buildEnrollFilters,
  enrollGroupFilter,
  enrollSortParam,
} from './enrollFilters';
import type { EnrollmentRow } from './enrollTypes';
import {
  useEnrollmentGroupCounts,
  useEnrollmentPage,
  useRefreshEnrollments,
} from './useEnrollmentData';

export function EnrollmentListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const toast = useToast();
  const refreshData = useRefreshEnrollments();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildEnrollConfig(catalogs, access), [catalogs, access]);
  const statusCodes = useMemo(
    () => catalogs.filterOptions('ENROLLMENT_STATUS').map((o) => o.value),
    [catalogs],
  );
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_ENROLL_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildEnrollFilters({ ...state, search: debouncedSearch }, statusCodes),
    [state, debouncedSearch, statusCodes],
  );
  const sortValue = enrollSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (tối đa hai cấp): số đếm từ enrollment_group_counts, dòng tải khi mở từng nhóm lá (enrollment_list).
  const groupFields = state.group.flatMap((k) =>
    ENROLL_GROUP_FIELD_OF[k] ? [ENROLL_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useEnrollmentPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    grouped ? null : pageSize,
  );
  const counts = useEnrollmentGroupCounts(filters, groupFields, true);
  const leaves = useLeafRows<EnrollmentRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'enrollment_list',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<EnrollmentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            enrollGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const activeQuery = grouped ? counts : list;
  const rows: EnrollmentRow[] = list.data?.rows ?? [];
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
      rowLabel={(r) => `${r.code} ${r.student_name}`}
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
      onRowClick={(r) => void navigate(`/crm/ghi-danh/${r.id}`)}
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
        title: 'Chưa có ghi danh nào',
        hint: 'Ghi danh sinh từ dòng đơn khi tiền đã vào đủ cọc tối thiểu (mỗi dòng đơn một ghi danh). Danh sách này không có nút Tạo (R-GD-01).',
      }}
    />
  );
}
