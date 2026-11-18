// TC-08 Khoản tiền vào và TC-13 Công nợ: khuôn K03 nối list_money_in và list_receivables. Chỉ đọc; không có nút Tạo.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { emptyTreasuryState, buildMoneyInConfig, buildReceivableConfig } from './treasuryConfig';
import {
  buildMoneyInFilters,
  buildReceivableFilters,
  moneyInSortParam,
  nextReceivableSort,
  receivableSortParam,
} from './treasuryFilters';
import type { MoneyInRow, ReceivableRow } from './treasuryTypes';
import { useMoneyInPage, useReceivablePage, useRefreshTreasury } from './useTreasuryData';

export function MoneyInListPage() {
  const access = useAccess();
  const refresh = useRefreshTreasury();
  const config = useMemo(() => buildMoneyInConfig(access), [access]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(() => emptyTreasuryState('created'));
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const size = pageSize ?? 0;
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildMoneyInFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const sortValue = moneyInSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useMoneyInPage(filters, sortValue, page * size, pageSize);
  const rows: MoneyInRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.code} ${r.parent_name}`}
        loading={list.isPending || list.isPlaceholderData}
        error={list.isError ? errorOf(list.error).message : null}
        onRetry={() => void list.refetch()}
        actions={[]}
        onRefresh={() => void refresh()}
        pager={{
          from: total === 0 ? 0 : page * size + 1,
          to: page * size + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * size + rows.length < total ? { onNext: () => setPage(page + 1) } : {}),
        }}
        sort={sort}
        onSortChange={setSort}
        emptyMessage={{
          title: 'Chưa có khoản tiền vào nào',
          hint: 'Khoản tiền vào tự sinh khi Kế toán duyệt phiếu thu, không ai tạo tay. Sổ này chỉ đọc (R-TIEN-01).',
        }}
      />
      {list.data && (
        <p className="px-4 pb-3 text-caption text-fg-muted">
          Tổng số tiền (theo bộ lọc): {formatNumber(list.data.sum)} đ
        </p>
      )}
    </>
  );
}

export function ReceivableListPage() {
  const access = useAccess();
  const refresh = useRefreshTreasury();
  const config = useMemo(() => buildReceivableConfig(access), [access]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(() => emptyTreasuryState('due'));
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const size = pageSize ?? 0;
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildReceivableFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const sortValue = receivableSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useReceivablePage(filters, sortValue, page * size, pageSize);
  const rows: ReceivableRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => `${r.order_id}:${r.seq}`}
        rowLabel={(r) => `${r.order_code} đợt ${r.seq} ${r.parent_name}`}
        loading={list.isPending || list.isPlaceholderData}
        error={list.isError ? errorOf(list.error).message : null}
        onRetry={() => void list.refetch()}
        actions={[]}
        onRefresh={() => void refresh()}
        pager={{
          from: total === 0 ? 0 : page * size + 1,
          to: page * size + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * size + rows.length < total ? { onNext: () => setPage(page + 1) } : {}),
        }}
        sort={sort}
        onSortChange={(next) => setSort(nextReceivableSort(next))}
        emptyMessage={{
          title: 'Không có công nợ nào',
          hint: 'Công nợ đọc từ lịch đợt tự tính theo Điều khoản thanh toán của đơn đã duyệt (BH-05). Đợt nào đóng đủ thì biến khỏi danh sách.',
        }}
      />
      {list.data && (
        <p className="px-4 pb-3 text-caption text-fg-muted">
          Tổng còn nợ (theo bộ lọc): {formatNumber(list.data.owed_sum)} đ
        </p>
      )}
    </>
  );
}
