// TC-08 Khoản tiền vào và TC-13 Công nợ: khuôn K03 nối list_money_in và list_receivables. Chỉ đọc; không có nút Tạo.
// TC-09 Đảo khoản tiền (lý do): hành động «Hoàn tác khoản tiền» ở từng dòng TC-08, hộp thoại lý do K08 (danh mục REVERSAL_REASON), gọi reverse_money_in.
import { useMemo, useState } from 'react';
import { listForbiddenOf } from '../../list/forbiddenSpec';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useBoolSetting, useDb, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { ReasonDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import type { SortState } from '../../ui/Data';
import { emptyTreasuryState, buildMoneyInConfig, buildReceivableConfig } from './treasuryConfig';
import {
  buildMoneyInFilters,
  buildReceivableFilters,
  MONEY_IN_GROUP_FIELD_OF,
  RECEIVABLE_GROUP_FIELD_OF,
  moneyInGroupFilter,
  moneyInSortParam,
  nextReceivableSort,
  receivableGroupFilter,
  receivableSortParam,
} from './treasuryFilters';
import type { MoneyInRow, ReceivableRow } from './treasuryTypes';
import {
  reverseMoneyIn,
  useMoneyInPage,
  useReceivablePage,
  useRefreshTreasury,
  useTreasuryGroupCounts,
} from './useTreasuryData';

export function MoneyInListPage() {
  const access = useAccess();
  const refresh = useRefreshTreasury();
  const supabase = useDb();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  // TC-09: khoản đang chọn hoàn tác; hộp thoại lý do (K08).
  const [target, setTarget] = useState<MoneyInRow | null>(null);
  const [busy, setBusy] = useState(false);
  const [reverseError, setReverseError] = useState<string | null>(null);
  const reversalEnabled = useBoolSetting('money_reversal_enabled') === true;
  const config = useMemo(
    () => buildMoneyInConfig(access, setTarget, reversalEnabled),
    [access, reversalEnabled],
  );
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
  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const groupFields = state.group.flatMap((k) =>
    MONEY_IN_GROUP_FIELD_OF[k] ? [MONEY_IN_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useMoneyInPage(filters, sortValue, page * size, pageSize, !grouped);
  const counts = useTreasuryGroupCounts(
    'money_in_group_counts',
    filters,
    groupFields,
    view === 'list',
  );
  const leaves = useLeafRows<MoneyInRow>(
    filters,
    sortValue,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_money_in',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<MoneyInRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            moneyInGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const pageRows: MoneyInRow[] = list.data?.rows ?? [];
  const rows: MoneyInRow[] = useMemo(
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
        loading={activeQuery.isPending || activeQuery.isPlaceholderData}
        error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
        forbidden={listForbiddenOf(activeQuery.error, 'khoản tiền vào', 'Bán hàng và thu chi')}
        onRetry={() => void activeQuery.refetch()}
        groupTree={grouped ? grouping?.tree : undefined}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
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
          hint: 'Khoản tiền vào tự sinh khi Kế toán duyệt phiếu thu, không ai tạo tay. Sổ không sửa, không xoá; chỉ Kế toán hoàn tác từng khoản, có lý do (R-TIEN-01, R-TIEN-26).',
        }}
      />
      <ReasonDialog
        open={target !== null}
        onOpenChange={(open) => {
          if (!open) {
            setTarget(null);
            setReverseError(null);
          }
        }}
        title="Hoàn tác khoản tiền"
        description={
          target
            ? `${target.code} · ${formatNumber(target.amount)} đ. Thêm một khoản âm trỏ về khoản này; giờ đã cấp tính lại theo tiền còn lại.`
            : undefined
        }
        options={catalogs.options('REVERSAL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('REVERSAL_REASON', o.value),
        }))}
        confirmLabel="Hoàn tác"
        cancelLabel="Giữ nguyên"
        busy={busy}
        error={reverseError}
        onConfirm={(result) => {
          if (!target) return;
          setBusy(true);
          setReverseError(null);
          void reverseMoneyIn(
            supabase,
            target.id,
            result.option,
            result.note === '' ? null : result.note,
          )
            .then(refresh)
            .then(() => {
              setTarget(null);
              toast({ title: 'Đã hoàn tác khoản tiền.' });
            })
            .catch((e: unknown) => setReverseError(errorOf(e).message))
            .finally(() => setBusy(false));
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
  const toast = useToast();
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
  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const groupFields = state.group.flatMap((k) =>
    RECEIVABLE_GROUP_FIELD_OF[k] ? [RECEIVABLE_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useReceivablePage(filters, sortValue, page * size, pageSize, !grouped);
  const counts = useTreasuryGroupCounts(
    'receivable_group_counts',
    filters,
    groupFields,
    view === 'list',
  );
  const leaves = useLeafRows<ReceivableRow>(
    filters,
    sortValue,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_receivables',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ReceivableRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            receivableGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const pageRows: ReceivableRow[] = list.data?.rows ?? [];
  const rows: ReceivableRow[] = useMemo(
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
        loading={activeQuery.isPending || activeQuery.isPlaceholderData}
        error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
        forbidden={listForbiddenOf(activeQuery.error, 'khoản công nợ', 'Bán hàng và thu chi')}
        onRetry={() => void activeQuery.refetch()}
        groupTree={grouped ? grouping?.tree : undefined}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
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
