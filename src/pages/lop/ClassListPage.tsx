// LOP-01 Lớp (danh sách, khuôn K03): tình trạng duyệt và vận hành, sĩ số, còn chỗ; lọc cơ sở, môn, khối; tìm theo mã lớp hoặc mã cũ (R-LOP-15).
// Trưởng cơ sở, CSKH, Sale chỉ thấy lớp cơ sở mình, Admin xem toàn hệ thống: phạm vi do máy chủ quyết định (app.list_classes).
// Lọc, tìm, sắp xếp, phân trang ở máy chủ. Nút Tạo lớp dẫn tới LOP-03.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import {
  buildClassFilters,
  CLASS_GROUP_FIELD_OF,
  classGroupFilter,
  classSortParam,
} from './classFilters';
import { buildClassConfig, classPath, EMPTY_CLASS_STATE, NEW_CLASS_PATH } from './classConfig';
import { ClassCard } from './ClassCard';
import type { ClassRow } from './classTypes';
import {
  KANBAN_STATUSES,
  useClassBoard,
  useClassCatalogs,
  useClassGroupCounts,
  useClassPage,
  useRefreshClasses,
} from './useClassData';

export function ClassListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const toast = useToast();
  const refreshData = useRefreshClasses();
  const pageSize = useIntSetting('list_page_size_default');
  const catalogs = useClassCatalogs();

  const [state, setState] = useState<ListState>(EMPTY_CLASS_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const canCreate = access.can('CLASS', 'TAO');
  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildClassFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = classSortParam(sort?.key ?? null, sort?.direction ?? null);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (tối đa hai cấp): số đếm từ class_group_counts, dòng tải khi mở từng nhóm lá (list_classes).
  const groupFields = state.group.flatMap((k) =>
    CLASS_GROUP_FIELD_OF[k] ? [CLASS_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useClassPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list' && !grouped,
  );
  const counts = useClassGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<ClassRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_classes',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ClassRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            classGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const board = useClassBoard(filters, pageSize, view === 'kanban');
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;

  const config = useMemo(
    () =>
      buildClassConfig({
        branches: access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
        subjects: catalogs.options('SUBJECT'),
        grades: catalogs.options('GRADE'),
        types: catalogs.options('CLASS_TYPE'),
        statuses: catalogs.options('CLASS_STATUS'),
      }),
    [access, catalogs],
  );

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      kanban={
        board.some((q) => q.isPending) ? (
          <Spinner label="Đang tải Kanban…" />
        ) : (
          <KanbanBoard
            columns={KANBAN_STATUSES.map((code, i) => ({
              code,
              label: catalogs.name('CLASS_STATUS', code) ?? code,
              cards: board[i]?.data?.rows ?? [],
              total: board[i]?.data?.total ?? 0,
            }))}
            cardKey={(c) => c.id}
            cardLabel={(c) => c.code}
            rule={() => ({
              ok: false,
              reason: 'Đổi tình trạng duyệt bằng nút Hành động trong hồ sơ lớp.',
            })}
            onMove={() => undefined}
            onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
            note="Đổi tình trạng duyệt bằng nút Hành động trong hồ sơ lớp (Trình, Xác nhận, Duyệt, Từ chối)."
            renderCard={(c) => <ClassCard row={c} />}
          />
        )
      }
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => r.code}
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={errorText}
      onRetry={() => void activeQuery.refetch()}
      actions={
        canCreate
          ? [
              {
                label: 'Tạo lớp',
                icon: 'plus' as const,
                onClick: () => void navigate(NEW_CLASS_PATH),
              },
            ]
          : []
      }
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
      sort={sort}
      onSortChange={(next) => setSort(next?.key === 'code' || next?.key === 'start' ? next : null)}
      onRowClick={(r) => void navigate(classPath(r.id))}
      emptyMessage={{
        title: 'Chưa có lớp',
        hint: 'Không có lớp nào trong bộ lọc này. Đổi bộ lọc hoặc tạo lớp mới.',
      }}
    />
  );
}
