// TT-04 Đối chiếu tái tục theo tháng (khuôn K03 + thẻ tổng; canvas 9933 TT04, TT04_trong, TT04_tai, TT04_khong_quyen): học sinh + lớp hết giờ trong tháng,
// đã có phiếu, còn thiếu, theo cơ sở. Nút Tạo phiếu ở dòng thiếu dùng hàm tạo tay TT-03. Chỉ xem số liệu; lọc, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { buildReconcileConfig } from './reconcileConfig';
import { EMPTY_RECONCILE_STATE, buildReconcileQuery } from './reconcileLogic';
import type { ReconcileRow } from './reconcileTypes';
import {
  createEarlyUpsale,
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

  const list = useReconcilePage(query, page * (pageSize ?? 0), pageSize);
  const summary = useReconcileSummary(query);
  const rows: ReconcileRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
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
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
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
