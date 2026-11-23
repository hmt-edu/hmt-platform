// KH-01 Phụ huynh và KH-04 Học sinh (danh sách, khuôn K03). Không có Tạo tay: phụ huynh, học sinh sinh từ cơ hội, phiếu kiểm tra (R-CRM-27).
// Xuất CSV chỉ Admin (R-CRM-29): để sau 17/11. Lọc, tìm, sắp xếp, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import type { SortState } from '../../ui/Data';
import {
  buildParentConfig,
  buildStudentConfig,
  EMPTY_CUST_STATE,
  parentPath,
  studentPath,
} from './custConfig';
import {
  PARENT_GROUP_FIELD_OF,
  STUDENT_GROUP_FIELD_OF,
  buildParentFilters,
  buildStudentFilters,
  custSortParam,
  parentGroupFilter,
  studentGroupFilter,
} from './custFilters';
import type { ParentRow, StudentRow } from './custTypes';
import {
  useParentGroupCounts,
  useParentPage,
  useRefreshCustomers,
  useStudentGroupCounts,
  useStudentPage,
} from './useCustData';

function usePaging(filters: object, sortValue: string) {
  const key = `${JSON.stringify(filters)}|${sortValue}`;
  const [paging, setPaging] = useState({ key: '', page: 0 });
  return {
    page: paging.key === key ? paging.page : 0,
    setPage: (page: number) => setPaging({ key, page }),
  };
}

export function ParentListPage() {
  const access = useAccess();
  const toast = useToast();
  const navigate = useNavigate();
  const refresh = useRefreshCustomers();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_CUST_STATE);
  const [sort, setSort] = useState<SortState>(null);
  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildParentFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = custSortParam(sort?.key ?? null, sort?.direction ?? null);
  const { page, setPage } = usePaging(filters, sortValue);
  // Group By ở máy chủ (tối đa hai cấp): số đếm từ parent_group_counts, dòng tải khi mở từng nhóm lá (list_parents).
  const groupFields = state.group.flatMap((k) =>
    PARENT_GROUP_FIELD_OF[k] ? [PARENT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useParentPage(filters, sortValue, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useParentGroupCounts(filters, groupFields, true);
  const leaves = useLeafRows<ParentRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_parents',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ParentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            parentGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const config = useMemo(
    () =>
      buildParentConfig(
        access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
      ),
    [access],
  );
  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => r.full_name}
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
      onRetry={() => void activeQuery.refetch()}
      onRefresh={() => {
        setTick((t) => t + 1);
        void refresh();
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
      sort={sort}
      onSortChange={(next) => setSort(next?.key === 'name' ? next : null)}
      onRowClick={(r) => void navigate(parentPath(r.id))}
      emptyMessage={{
        title: 'Chưa có phụ huynh',
        hint: 'Phụ huynh được tạo tự động từ cơ hội. Đổi bộ lọc để xem tiếp.',
      }}
    />
  );
}

export function StudentListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const refresh = useRefreshCustomers();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_CUST_STATE);
  const [sort, setSort] = useState<SortState>(null);
  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildStudentFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = custSortParam(sort?.key ?? null, sort?.direction ?? null);
  const { page, setPage } = usePaging(filters, sortValue);
  // Group By ở máy chủ (tối đa hai cấp): số đếm từ student_group_counts, dòng tải khi mở từng nhóm lá (list_students).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    STUDENT_GROUP_FIELD_OF[k] ? [STUDENT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useStudentPage(filters, sortValue, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useStudentGroupCounts(filters, groupFields, true);
  const leaves = useLeafRows<StudentRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_students',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<StudentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            studentGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const config = useMemo(
    () =>
      buildStudentConfig(
        access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
        Array.from({ length: 11 }, (_, i) => ({ value: String(i + 2), label: `Lớp ${i + 2}` })), // allow-number: khối từ lớp 2 đến lớp 12
      ),
    [access],
  );
  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => r.full_name}
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
      onRetry={() => void activeQuery.refetch()}
      onRefresh={() => {
        setTick((t) => t + 1);
        void refresh();
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
      sort={sort}
      onSortChange={(next) => setSort(next?.key === 'name' ? next : null)}
      onRowClick={(r) => void navigate(studentPath(r.id))}
      emptyMessage={{
        title: 'Chưa có học sinh',
        hint: 'Học sinh được tạo tự động từ phiếu kiểm tra, cơ hội. Đổi bộ lọc để xem tiếp.',
      }}
    />
  );
}
