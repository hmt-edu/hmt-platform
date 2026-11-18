// TC-10 Phiếu chi (danh sách): khuôn K03 nối list_payment_vouchers. Lọc, phân trang làm ở máy chủ. Không có nút Tạo (R-TIEN-34).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { EMPTY_VOUCHER_STATE, buildVoucherConfig } from './voucherConfig';
import { buildVoucherFilters } from './voucherFilters';
import type { VoucherRow } from './voucherTypes';
import { useRefreshVouchers, useVoucherPage } from './useVoucherData';

export function VoucherListPage() {
  const access = useAccess();
  const refreshData = useRefreshVouchers();
  const config = useMemo(() => buildVoucherConfig(access), [access]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_VOUCHER_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildVoucherFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useVoucherPage(filters, page * (pageSize ?? 0), pageSize);
  const rows: VoucherRow[] = list.data?.rows ?? [];
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
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.parent_name}`}
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
        title: 'Chưa có phiếu chi nào',
        hint: 'Phiếu chi sinh khi Kế toán duyệt yêu cầu hoàn phí.',
      }}
    />
  );
}
