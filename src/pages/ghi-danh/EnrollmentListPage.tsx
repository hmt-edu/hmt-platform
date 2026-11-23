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
  EMPTY_ENROLL_STATE,
  ENROLL_GROUP_FIELD_OF,
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

  // Group By ở máy chủ (Kho #17, F65): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; mở nhóm mới tải dòng.
  const groupFields = state.group.flatMap((k) =>
    ENROLL_GROUP_FIELD_OF[k] ? [ENROLL_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const toast = useToast();
  const list = useEnrollmentPage(filters, sortValue, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useEnrollmentGroupCounts(filters, groupFields);
  const leaves = useLeafRows<EnrollmentRow>(
    filters,
    sortValue ?? 'code_desc',
    pageSize,
    `${JSON.stringify(filters)}|${sortValue ?? ''}`,
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
    // groupFields suy ra từ state.group.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows: EnrollmentRow[] = useMemo(
    () =>
      grouping
        ? grouping.tree
            .flatMap((g) => (g.children.length > 0 ? g.children : [g]))
            .flatMap((g) => g.rows)
        : (list.data?.rows ?? []),
    [grouping, list.data],
  );
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const active = grouped ? counts : list;

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
      loading={active.isPending || active.isPlaceholderData}
      error={active.isError ? errorOf(active.error).message : null}
      onRetry={() => void active.refetch()}
      onRefresh={() => void refreshData()}
      onRowClick={(r) => void navigate(`/crm/ghi-danh/${r.id}`)}
      pager={{
        from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
        to: page * (pageSize ?? 0) + rows.length,
        total,
        ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
        ...(page * (pageSize ?? 0) + rows.length < total
          ? { onNext: () => setPage(page + 1) }
          : {}),
      }}
      groupTree={grouped ? grouping?.tree : undefined}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      sort={sort}
      onSortChange={setSort}
      emptyMessage={{
        title: 'Chưa có ghi danh nào',
        hint: 'Ghi danh sinh từ dòng đơn khi tiền đã vào đủ cọc tối thiểu (mỗi dòng đơn một ghi danh). Danh sách này không có nút Tạo.',
      }}
    />
  );
}
