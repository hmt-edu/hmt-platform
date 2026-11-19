// TC-01 Phiếu thu (danh sách) và TC-04 Chờ kế toán duyệt: khuôn K03 nối list_receipts. Lọc, sắp xếp, phân trang làm ở máy chủ.
// Phiếu thu có đơn chỉ tạo từ đơn Đã duyệt (R-TIEN-02); riêng «Thu nợ đầu kỳ» (R-V2-15, không cần đơn) tạo bằng nút ở đầu danh sách. TC-04 là cùng màn với bộ lọc cố định Chờ kế toán.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_RECEIPT_STATE, buildReceiptConfig } from './receiptConfig';
import { buildReceiptFilters, nextReceiptSort, receiptSortParam } from './receiptFilters';
import { OpeningDebtDialog } from './OpeningDebtDialog';
import type { ReceiptRow } from './receiptTypes';
import { useReceiptPage, useRefreshReceipts } from './useReceiptData';

export function ReceiptListPage({ waitingAccounting = false }: { waitingAccounting?: boolean }) {
  const access = useAccess();
  const refreshData = useRefreshReceipts();
  const [creating, setCreating] = useState(false);
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => {
    const base = buildReceiptConfig(catalogs, access);
    return waitingAccounting
      ? {
          ...base,
          screenCode: 'TC-04',
          title: 'Chờ kế toán duyệt',
          // Canvas TC04: có cột «Mã giao dịch» hiện sẵn.
          columns: base.columns.map((c) =>
            c.key === 'txn_ref' ? { ...c, defaultVisible: true } : c,
          ),
        }
      : base;
  }, [catalogs, access, waitingAccounting]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_RECEIPT_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () =>
      buildReceiptFilters(
        { ...state, search: debouncedSearch },
        waitingAccounting ? { waiting_accounting: true } : {},
      ),
    [state, debouncedSearch, waitingAccounting],
  );
  const sortValue = receiptSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useReceiptPage(filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows: ReceiptRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;
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
        error={errorText}
        onRetry={() => void list.refetch()}
        actions={
          access.can('RECEIPT', 'TAO') && access.featureOn('BAN_HANG') && !waitingAccounting
            ? [
                {
                  label: 'Thu nợ đầu kỳ',
                  icon: 'plus' as const,
                  primary: false,
                  onClick: () => setCreating(true),
                },
              ]
            : []
        }
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
        sort={sort}
        onSortChange={(next) => setSort(nextReceiptSort(next))}
        emptyMessage={{
          title: waitingAccounting
            ? 'Không có phiếu nào chờ kế toán duyệt'
            : 'Chưa có phiếu thu nào',
          hint: waitingAccounting
            ? 'Phiếu thu đã qua bước quản lý sẽ hiện ở đây.'
            : 'Phiếu thu tạo từ đơn hàng đã duyệt: mở đơn rồi bấm Tạo phiếu thu.',
        }}
      />
      <OpeningDebtDialog open={creating} onOpenChange={setCreating} />
    </>
  );
}
