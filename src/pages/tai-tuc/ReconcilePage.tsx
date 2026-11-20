// TT-04 Đối chiếu tái tục theo tháng (khuôn K03 + thẻ tổng; canvas 9933 TT04, TT04_trong, TT04_tai, TT04_khong_quyen): học sinh + lớp hết giờ trong tháng,
// đã có phiếu, còn thiếu, theo cơ sở. Nút Tạo phiếu ở dòng thiếu dùng hàm tạo tay TT-03. Chỉ xem số liệu; lọc, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import { buildReconcileConfig } from './reconcileConfig';
import {
  EMPTY_RECONCILE_STATE,
  RECONCILE_GROUP_FIELD_OF,
  buildReconcileQuery,
  monthStart,
  reconcileGroupFilter,
} from './reconcileLogic';
import type { ReconcileRow } from './reconcileTypes';
import {
  createEarlyUpsale,
  useReconcileGroupCounts,
  useReconcilePage,
  useReconcileSummary,
  useRefreshReconcile,
} from './useReconcileData';

function Tile({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex flex-col gap-1 rounded-card border border-border bg-surface p-3">
      <span className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {label}
      </span>
      <span className="tabular font-display text-display">{formatNumber(value)}</span>
    </div>
  );
}

export function ReconcilePage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshReconcile();
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_RECONCILE_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const query = useMemo(
    () => buildReconcileQuery({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(query);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (Kho #19): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; mở nhóm mới tải dòng.
  const groupFields = state.group.flatMap((k) =>
    RECONCILE_GROUP_FIELD_OF[k] ? [RECONCILE_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useReconcilePage(query, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useReconcileGroupCounts(query, groupFields);
  const leafExtra = useMemo(() => ({ p_month: monthStart(query.month) }), [query.month]);
  const leaves = useLeafRows<ReconcileRow>(
    query.filters,
    null,
    pageSize,
    JSON.stringify(query),
    (message) => toast({ tone: 'danger', title: message }),
    'list_upsale_reconcile',
    leafExtra,
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ReconcileRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            reconcileGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const summary = useReconcileSummary(query);
  const rows: ReconcileRow[] = useMemo(
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
  const s = summary.data;

  async function createTicket(row: ReconcileRow) {
    const key = `${row.student_id}:${row.class_id}`;
    setBusyKey(key);
    try {
      const created = await createEarlyUpsale(supabase, row.student_id, row.class_id);
      toast({ title: `Đã tạo phiếu ${created.code}.` });
      await refreshData();
    } catch (e) {
      toast({ tone: 'warning', title: errorOf(e).message });
    } finally {
      setBusyKey(null);
    }
  }

  const config = useMemo(
    () => buildReconcileConfig(access, (r) => void createTicket(r), busyKey),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- createTicket chỉ dùng supabase, toast, refreshData ổn định
    [access, busyKey],
  );

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      belowToolbar={
        <div className="flex flex-col gap-3 p-4 pt-0">
          <p className="text-body text-fg-muted">
            Tháng hết giờ: {query.month.slice(5)}/{query.month.slice(0, 4)}. Đổi tháng bằng bộ lọc
            Campaign.
          </p>
          {s && (
            <>
              <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
                <Tile label="Học sinh + lớp hết giờ trong tháng" value={s.total} />
                <Tile label="Đã có phiếu" value={s.with_ticket} />
                <Tile label="Còn thiếu phiếu" value={s.missing} />
                <Tile label="Trong đó tạo tay" value={s.manual} />
              </div>
              <ul className="flex flex-wrap gap-x-6 gap-y-1 text-body">
                {s.branches.map((b) => (
                  <li key={b.branch_code}>
                    <span className="font-medium">{b.branch_code}</span>: hết giờ {b.total} · phiếu{' '}
                    {b.with_ticket} · thiếu {b.missing}
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      }
      rows={rows}
      onRowClick={() => undefined}
      rowKey={(r) => `${r.student_id}:${r.class_id}`}
      rowLabel={(r) => `${r.student_name} ${r.class_code}`}
      loading={active.isPending || active.isPlaceholderData}
      error={active.isError ? errorOf(active.error).message : null}
      onRetry={() => void active.refetch()}
      groupTree={grouped ? grouping?.tree : undefined}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
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
        title: 'Không có học sinh nào hết giờ trong tháng này',
        hint: 'Đổi tháng bằng bộ lọc Campaign hoặc đổi cơ sở.',
      }}
    />
  );
}
