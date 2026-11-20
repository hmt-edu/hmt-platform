// TC-10 Phiếu chi (danh sách): khuôn K03 nối list_payment_vouchers. Lọc, phân trang làm ở máy chủ. Không có nút Tạo (R-TIEN-34).
import { useMemo, useState } from 'react';
import { listForbiddenOf } from '../../list/forbiddenSpec';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { EMPTY_VOUCHER_STATE, buildVoucherConfig } from './voucherConfig';
import { VOUCHER_GROUP_FIELD_OF, buildVoucherFilters, voucherGroupFilter } from './voucherFilters';
import type { VoucherRow } from './voucherTypes';
import { useRefreshVouchers, useVoucherGroupCounts, useVoucherPage } from './useVoucherData';

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
  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    VOUCHER_GROUP_FIELD_OF[k] ? [VOUCHER_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useVoucherPage(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useVoucherGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<VoucherRow>(
    filters,
    undefined,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_payment_vouchers_grouped',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<VoucherRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            voucherGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const pageRows: VoucherRow[] = list.data?.rows ?? [];
  const rows: VoucherRow[] = useMemo(
    () =>
      grouping
        ? grouping.tree
            .flatMap((g) => (g.children.length > 0 ? g.children : [g]))
            .flatMap((g) => g.rows)
        : pageRows,
    // pageRows suy ra từ list.data.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouping, list.data],
  );
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;
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
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={errorText}
      forbidden={listForbiddenOf(activeQuery.error, 'phiếu chi', 'Bán hàng và thu chi')}
      onRetry={() => void activeQuery.refetch()}
      groupTree={grouped ? grouping?.tree : undefined}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
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
