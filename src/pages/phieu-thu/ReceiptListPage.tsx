// TC-01 Phiếu thu (danh sách) và TC-04 Chờ kế toán duyệt: khuôn K03 nối list_receipts. Lọc, sắp xếp, phân trang làm ở máy chủ.
// Phiếu thu có đơn chỉ tạo từ đơn Đã duyệt (R-TIEN-02); riêng «Thu nợ đầu kỳ» (R-V2-15, không cần đơn) tạo bằng nút ở đầu danh sách. TC-04 là cùng màn với bộ lọc cố định Chờ kế toán.
import { useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { listForbiddenOf } from '../../list/forbiddenSpec';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_RECEIPT_STATE, buildReceiptConfig } from './receiptConfig';
import {
  RECEIPT_GROUP_FIELD_OF,
  buildReceiptFilters,
  nextReceiptSort,
  receiptGroupFilter,
  receiptSortParam,
} from './receiptFilters';
import { OpeningDebtDialog } from './OpeningDebtDialog';
import type { ReceiptRow } from './receiptTypes';
import { useReceiptGroupCounts, useReceiptPage, useRefreshReceipts } from './useReceiptData';

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
            c.key === 'txn_ref' || c.key === 'bank_matched' ? { ...c, defaultVisible: true } : c,
          ),
          // Canvas TC04: nhóm lọc nhanh «Sao kê» (Đã khớp, Chưa khớp).
          quickGroups: [
            ...base.quickGroups,
            {
              key: 'bank',
              label: 'Sao kê',
              options: [
                { value: 'KHOP', label: 'Đã khớp' },
                { value: 'CHUA', label: 'Chưa khớp' },
              ],
            },
          ],
          // Canvas TC04: thêm nhóm Group By «Sao kê» (máy chủ đếm theo cờ đối soát, migration 579).
          groupFields: [
            ...base.groupFields,
            {
              key: 'bank',
              label: 'Sao kê',
              value: (r) => (r.bank_matched ? 'KHOP' : 'CHUA'),
              valueLabel: (v) => (v === 'KHOP' ? 'Đã khớp' : 'Chưa khớp'),
            },
          ],
        }
      : base;
  }, [catalogs, access, waitingAccounting]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_RECEIPT_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const parentOrder = waitingAccounting ? null : params.get('don');
  const parentCode = params.get('ma') ?? '';
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () =>
      buildReceiptFilters(
        { ...state, search: debouncedSearch },
        {
          ...(waitingAccounting ? { waiting_accounting: true } : {}),
          // Mở từ nút số đếm «Phiếu thu» của đơn: chỉ phiếu của đơn đó; bỏ chip thì về danh sách chung.
          ...(parentOrder ? { order_id: parentOrder } : {}),
        },
      ),
    [state, debouncedSearch, waitingAccounting, parentOrder],
  );
  const sortValue = receiptSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    RECEIPT_GROUP_FIELD_OF[k] ? [RECEIPT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useReceiptPage(filters, sortValue, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useReceiptGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<ReceiptRow>(
    filters,
    sortValue,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_receipts',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ReceiptRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            receiptGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const pageRows: ReceiptRow[] = list.data?.rows ?? [];
  const rows: ReceiptRow[] = useMemo(
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
    <>
      <ListScreen
        parent={
          parentOrder
            ? {
                entityLabel: 'Đơn hàng',
                code: parentCode,
                childLabel: 'Phiếu thu',
                onOpenParent: () => void navigate(`/crm/don-hang/${parentOrder}`),
                onClear: () => setParams({}),
              }
            : undefined
        }
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
        forbidden={listForbiddenOf(
          activeQuery.error,
          waitingAccounting ? 'phiếu thu chờ duyệt' : 'phiếu thu',
          'Kế toán',
        )}
        onRetry={() => void activeQuery.refetch()}
        groupTree={grouped ? grouping?.tree : undefined}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
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
