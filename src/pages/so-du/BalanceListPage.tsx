// TC-14 Số dư khách hàng (danh sách): khuôn K03 nối list_customer_balances. Lọc, phân trang làm ở máy chủ. Chỉ xem.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { EMPTY_BALANCE_STATE, buildBalanceConfig } from './balanceConfig';
import { buildBalanceFilters } from './balanceFilters';
import type { BalanceRow } from './balanceTypes';
import { useBalancePage, useRefreshBalances } from './useBalanceData';

export function BalanceListPage() {
  const access = useAccess();
  const refreshData = useRefreshBalances();
  const config = useMemo(() => buildBalanceConfig(access), [access]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_BALANCE_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildBalanceFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useBalancePage(filters, page * (pageSize ?? 0), pageSize);
  const rows: BalanceRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;
  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={rows}
      rowKey={(r) => r.parent_id}
      rowLabel={(r) => `${r.parent_code} ${r.parent_name}`}
      loading={list.isPending || list.isPlaceholderData}
      error={errorText}
      onRetry={() => void list.refetch()}
      actions={[]}
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
        title: 'Chưa có số dư khách hàng nào',
        hint: 'Số dư sinh từ dừng học, chuyển phí hoặc số dư đầu kỳ.',
      }}
    />
  );
}
