// KH-01 Phụ huynh và KH-04 Học sinh (danh sách, khuôn K03). Không có Tạo tay: phụ huynh, học sinh sinh từ cơ hội, phiếu kiểm tra (R-CRM-27).
// Xuất CSV chỉ Admin (R-CRM-29): để sau 17/11. Lọc, tìm, sắp xếp, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import {
  buildParentConfig,
  buildStudentConfig,
  EMPTY_CUST_STATE,
  parentPath,
  studentPath,
} from './custConfig';
import { buildParentFilters, buildStudentFilters, custSortParam } from './custFilters';
import { useParentPage, useRefreshCustomers, useStudentPage } from './useCustData';

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
  const list = useParentPage(filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
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
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void refresh()}
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
  const list = useStudentPage(filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
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
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void refresh()}
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
      onSortChange={(next) => setSort(next?.key === 'name' ? next : null)}
      onRowClick={(r) => void navigate(studentPath(r.id))}
      emptyMessage={{
        title: 'Chưa có học sinh',
        hint: 'Học sinh được tạo tự động từ phiếu kiểm tra, cơ hội. Đổi bộ lọc để xem tiếp.',
      }}
    />
  );
}
