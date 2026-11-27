// TC-15 Đối soát thu tiền (khuôn K09, canvas 9933 khung TC15, TC15_trong, TC15_tai, TC15_khong_quyen): phiếu thu Đã duyệt theo ngày, tài khoản nhận, hình thức,
// mã giao dịch; Kế toán, Admin tích chọn phiếu đã thấy trên sao kê rồi «Đánh dấu đã khớp» (có thể gán tài khoản nhận). Quyền kiểm ở máy chủ (app.assert_reconcile_access).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import type { SortState } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { StateView } from '../../ui/Feedback';
import { Field } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  buildReconcileFilters,
  emptyReconcileState,
  markReceiptsMatched,
  reconcileSortParam,
  useReconcilePage,
} from './reconcile';
import { buildReconcileConfig } from './reconcileConfig';
import { useQueryClient } from '@tanstack/react-query';

const KEEP_ACCOUNT = '__giu__';

export function ReceiptReconcilePage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const queryClient = useQueryClient();
  const pageSize = useIntSetting('list_page_size_default');
  const size = pageSize ?? 0;

  const [state, setState] = useState<ListState>(emptyReconcileState);
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [markDialog, setMarkDialog] = useState<{ matched: boolean } | null>(null);
  const [account, setAccount] = useState(KEEP_ACCOUNT);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildReconcileFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = reconcileSortParam(sort?.key ?? null, sort?.direction ?? null);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useReconcilePage(filters, sortValue, page * size, pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;
  const denied = list.isError && /HMT_KHONG_CO_QUYEN|Kế toán và Admin/.test(errorText ?? '');

  const config = useMemo(
    () =>
      buildReconcileConfig({
        branches: access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
        methods: catalogs.options('PAYMENT_METHOD'),
        accounts: catalogs.options('RECEIVING_ACCOUNT'),
        methodName: (code) => catalogs.name('PAYMENT_METHOD', code) ?? code,
        accountName: (code) => (code ? (catalogs.name('RECEIVING_ACCOUNT', code) ?? code) : '—'),
      }),
    [access, catalogs],
  );

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['reconcile-list'] });

  if (denied) {
    return (
      <StateView kind="forbidden" title="Bạn không có quyền xem đối soát thu tiền">
        Đối soát thu tiền dành cho Kế toán và Admin. Nếu cần xem, hãy liên hệ quản trị viên.
      </StateView>
    );
  }

  const confirm = () => {
    if (!markDialog) return;
    setBusy(true);
    setError(null);
    markReceiptsMatched(
      supabase,
      [...selected],
      markDialog.matched,
      account === KEEP_ACCOUNT ? null : account,
    )
      .then(async (n) => {
        await refresh();
        setSelected(new Set());
        setMarkDialog(null);
        toast({
          title: markDialog.matched ? `Đã đánh dấu khớp ${n} phiếu.` : `Đã bỏ đánh dấu ${n} phiếu.`,
        });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  const summary = list.data;
  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => r.code}
        loading={list.isPending || list.isPlaceholderData}
        error={errorText}
        onRetry={() => void list.refetch()}
        actions={[]}
        onRefresh={() => refresh()}
        selected={selected}
        onSelectedChange={setSelected}
        belowToolbar={
          summary ? (
            <dl
              className="grid grid-cols-2 gap-3 px-4 py-3 sm:grid-cols-4"
              aria-label="Tổng hợp đối soát"
            >
              <Stat label="Tổng tiền thu" value={`${formatNumber(summary.sum_all)} đ`} />
              <Stat label="Đã khớp sao kê" value={`${formatNumber(summary.sum_matched)} đ`} />
              <Stat label="Chưa khớp" value={`${formatNumber(summary.sum_unmatched)} đ`} />
              <Stat label="Số phiếu chưa khớp" value={String(summary.count_unmatched)} />
            </dl>
          ) : undefined
        }
        bulk={
          selected.size > 0 ? (
            <div className="flex flex-wrap items-center gap-2 px-4 py-2">
              <span className="text-body">Đã chọn {selected.size} phiếu</span>
              <Button
                variant="primary"
                onClick={() => {
                  setAccount(KEEP_ACCOUNT);
                  setError(null);
                  setMarkDialog({ matched: true });
                }}
              >
                Đánh dấu đã khớp
              </Button>
              <Button
                onClick={() => {
                  setError(null);
                  setMarkDialog({ matched: false });
                }}
              >
                Bỏ đánh dấu khớp
              </Button>
            </div>
          ) : (
            <p className="px-4 py-2 text-caption text-fg-muted">
              Tích chọn các phiếu thu đã thấy trên sao kê, rồi bấm Đánh dấu đã khớp.
            </p>
          )
        }
        pager={{
          from: total === 0 ? 0 : page * size + 1,
          to: page * size + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * size + rows.length < total ? { onNext: () => setPage(page + 1) } : {}),
        }}
        sort={sort}
        onSortChange={(next) =>
          setSort(next?.key === 'paid' || next?.key === 'amount' ? next : null)
        }
        emptyMessage={{
          title: 'Không có phiếu thu nào trong khoảng đã lọc',
          hint: 'Đổi khoảng thời gian, tài khoản nhận hoặc hình thức để xem phiếu thu cần đối soát.',
        }}
      />
      <FormDialog
        open={markDialog !== null}
        onOpenChange={(open) => {
          if (!open) setMarkDialog(null);
        }}
        title={markDialog?.matched ? 'Đánh dấu đã khớp sao kê' : 'Bỏ đánh dấu khớp'}
        subtitle={`${selected.size} phiếu thu đã chọn.`}
        confirmLabel={markDialog?.matched ? 'Đánh dấu đã khớp' : 'Bỏ đánh dấu'}
        canSubmit={selected.size > 0}
        busy={busy}
        error={error}
        onSubmit={confirm}
      >
        {markDialog?.matched && (
          <Field label="Tài khoản nhận (tuỳ chọn)">
            {(field) => (
              <Select
                id={field.id}
                label="Tài khoản nhận"
                value={account}
                onChange={setAccount}
                options={[
                  { value: KEEP_ACCOUNT, label: 'Giữ nguyên' },
                  ...catalogs.options('RECEIVING_ACCOUNT'),
                ]}
              />
            )}
          </Field>
        )}
      </FormDialog>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col">
      <dt className="text-caption text-fg-muted">{label}</dt>
      <dd className="text-h3 font-semibold tabular">{value}</dd>
    </div>
  );
}
