// KH-08 Lên khối đầu năm học (Admin, đã xác thực hai bước): xem trước từng em (khối cũ → khối mới), loại trừ từng em, xác nhận chạy; hoàn tác cả
// đợt trong số ngày cho phép; bên dưới là các đợt đã chạy. Luật anh Trường chốt 19/11 23:17: chỉ em đang học và đã có khối; lớp 12 tốt nghiệp; em
// bảo lưu, đã dừng học, tiềm năng bỏ qua; nhật ký từng em. Danh sách xem trước phân trang ở máy chủ (khuôn K03); hộp xác nhận K08.
import { useMemo, useState } from 'react';
import { Button } from '../../ui/Button';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { BulkActionBar, Code, Table, Tag } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { StateView } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { afterExclusion, buildPromotionFilters, newGradeText } from './gradePromotionLogic';
import type { PromotionBatch, PromotionRow } from './gradePromotionTypes';
import {
  runPromotion,
  undoPromotion,
  usePromotionBatches,
  usePromotionPreview,
  useRefreshPromotion,
} from './useGradePromotionData';

const EMPTY_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export function GradePromotionPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refresh = useRefreshPromotion();
  const pageSize = useIntSetting('list_page_size_default');
  const canRun = access.can('ADMIN', 'SUA');

  const [state, setState] = useState<ListState>(EMPTY_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  // Em loại trừ khỏi đợt: id → em đó có tốt nghiệp không (để tính lại số em sau khi loại trừ).
  const [excluded, setExcluded] = useState<Map<string, boolean>>(new Map());
  const [confirming, setConfirming] = useState(false);
  const [undoing, setUndoing] = useState<PromotionBatch | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildPromotionFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const preview = usePromotionPreview(filters, page * (pageSize ?? 0), pageSize);
  const batches = usePromotionBatches();
  const rows = preview.data?.rows ?? [];
  const total = preview.data?.total ?? 0;

  const branchFilter = useMemo(
    () => ({ branch_id: typeof filters.branch_id === 'string' ? filters.branch_id : undefined }),
    [filters.branch_id],
  );
  // Lọc cơ sở: chỉ đợt cho cơ sở đã chọn; số liệu cho đúng phạm vi chạy là số của bộ lọc cơ sở, không phải của ô tìm.
  const scope = usePromotionPreview(
    branchFilter.branch_id ? { branch_id: branchFilter.branch_id } : {},
    0,
    1,
  );
  const summary = scope.data;
  const excludedGraduating = [...excluded.values()].filter(Boolean).length;
  const after = summary
    ? afterExclusion(summary, { count: excluded.size, graduating: excludedGraduating })
    : null;

  const config: ListConfig<PromotionRow> = useMemo(
    () => ({
      screenCode: 'KH-08',
      title: 'Lên khối đầu năm học',
      searchPlaceholder: 'Tìm tên em, mã HS…',
      columns: [
        { key: 'code', label: 'Mã HS', locked: true, render: (r) => <Code>{r.code}</Code> },
        {
          key: 'name',
          label: 'Học sinh',
          locked: true,
          primary: true,
          render: (r) => <span className="font-medium">{r.full_name}</span>,
        },
        { key: 'branch', label: 'Cơ sở', render: (r) => r.branch_code },
        { key: 'old', label: 'Khối hiện tại', numeric: true, render: (r) => `Khối ${r.old_grade}` },
        {
          key: 'new',
          label: 'Khối mới',
          render: (r) =>
            r.new_grade === null ? <Tag tone="warning">{newGradeText(r)}</Tag> : newGradeText(r),
        },
        {
          key: 'excluded',
          label: 'Loại trừ',
          render: (r) => (excluded.has(r.student_id) ? <Tag tone="danger">Loại trừ</Tag> : null),
        },
      ],
      quickGroups: [],
      filterFields: [
        {
          key: 'branch',
          label: 'Cơ sở',
          type: 'select',
          ops: ['eq'],
          options: access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
        },
      ],
      groupFields: [],
      dateFields: [],
      views: ['list'],
    }),
    [access, excluded],
  );

  function excludeSelected(on: boolean) {
    const next = new Map(excluded);
    for (const r of rows) {
      if (!selected.has(r.student_id)) continue;
      if (on) next.set(r.student_id, r.new_grade === null);
      else next.delete(r.student_id);
    }
    setExcluded(next);
    setSelected(new Set());
  }

  async function run() {
    setBusy(true);
    setError(null);
    try {
      const scopeFilters = branchFilter.branch_id ? { branch_id: branchFilter.branch_id } : {};
      const result = await runPromotion(supabase, scopeFilters, [...excluded.keys()]);
      setConfirming(false);
      setExcluded(new Map());
      setSelected(new Set());
      await refresh();
      toast({
        title: `Đã lên khối ${result.promoted} em, ${result.graduated} em tốt nghiệp${result.excluded > 0 ? `, ${result.excluded} em loại trừ` : ''}.`,
      });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  async function undo() {
    if (!undoing) return;
    setBusy(true);
    setError(null);
    try {
      const result = await undoPromotion(supabase, undoing.id);
      setUndoing(null);
      await refresh();
      toast({
        title: `Đã hoàn tác: khôi phục ${result.restored} em${result.kept > 0 ? `, giữ nguyên ${result.kept} em đã được sửa khối sau đợt` : ''}.`,
      });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.student_id}
        rowLabel={(r) => `${r.code} ${r.full_name}`}
        loading={preview.isPending || preview.isPlaceholderData}
        error={preview.isError ? errorOf(preview.error).message : null}
        onRetry={() => void preview.refetch()}
        actions={
          canRun
            ? [
                {
                  label: 'Xác nhận lên khối',
                  icon: 'check' as const,
                  onClick: () => {
                    setError(null);
                    setConfirming(true);
                  },
                },
              ]
            : []
        }
        onRefresh={() => void refresh()}
        selected={canRun ? selected : undefined}
        onSelectedChange={canRun ? setSelected : undefined}
        bulk={
          canRun ? (
            <BulkActionBar count={selected.size} onClear={() => setSelected(new Set())}>
              <Button onClick={() => excludeSelected(true)}>Loại trừ khỏi đợt</Button>
              <Button onClick={() => excludeSelected(false)}>Bỏ loại trừ</Button>
            </BulkActionBar>
          ) : undefined
        }
        pager={{
          from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
          to: page * (pageSize ?? 0) + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * (pageSize ?? 0) + rows.length < total
            ? { onNext: () => setPage(page + 1) }
            : {}),
        }}
        sort={null}
        onSortChange={() => undefined}
        emptyMessage={{
          title: 'Không có em nào đủ điều kiện lên khối',
          hint: 'Chỉ em đang học và đã có khối. Em bảo lưu, đã dừng học, chưa có khối, đã tốt nghiệp được bỏ qua.',
        }}
      />
      {summary && (
        <p className="mx-4 mt-3 text-sm text-fg-muted" data-testid="promotion-summary">
          {`Sẽ chạy ${after?.total ?? 0} em (${after?.promoting ?? 0} lên khối, ${after?.graduating ?? 0} tốt nghiệp), loại trừ ${excluded.size} em. Bỏ qua: ${summary.skipped.khong_dang_hoc} em bảo lưu hoặc đã dừng học, ${summary.skipped.tiem_nang} em chưa ghi danh, ${summary.skipped.chua_co_khoi} em chưa có khối, ${summary.skipped.da_tot_nghiep} em đã tốt nghiệp, ${summary.skipped.da_len_khoi_nam_nay} em đã lên khối trong năm học này${summary.last_run_at ? ` (lần chạy trước ${formatDate(summary.last_run_at)})` : ''}.`}
        </p>
      )}
      <section className="mx-4 mt-6 pb-8" aria-labelledby="batches-heading">
        <h2 id="batches-heading" className="mb-2 text-base font-semibold">
          Các đợt đã chạy
        </h2>
        {batches.isError ? (
          <StateView kind="error" title="Chưa tải được các đợt" headingLevel={2}>
            {errorOf(batches.error).message}
          </StateView>
        ) : (
          <Table<PromotionBatch>
            caption="Các đợt lên khối đã chạy"
            columns={[
              {
                key: 'at',
                header: 'Chạy lúc',
                cell: (b) => <span className="tabular">{formatDateTime(b.created_at)}</span>,
              },
              { key: 'by', header: 'Người chạy', cell: (b) => b.created_by_name ?? '' },
              { key: 'branch', header: 'Phạm vi', cell: (b) => b.branch_code ?? 'Mọi cơ sở' },
              { key: 'promoted', header: 'Lên khối', numeric: true, cell: (b) => b.promoted },
              { key: 'graduated', header: 'Tốt nghiệp', numeric: true, cell: (b) => b.graduated },
              { key: 'excluded', header: 'Loại trừ', numeric: true, cell: (b) => b.excluded },
              {
                key: 'status',
                header: 'Tình trạng',
                cell: (b) =>
                  b.status === 'DA_HOAN_TAC' ? (
                    <Tag>Đã hoàn tác</Tag>
                  ) : (
                    <Tag tone="success">{`Hoàn tác được đến ${formatDateTime(b.undo_until)}`}</Tag>
                  ),
              },
              {
                key: 'actions',
                header: '',
                cell: (b) =>
                  canRun && b.can_undo ? (
                    <Button
                      onClick={() => {
                        setError(null);
                        setUndoing(b);
                      }}
                    >
                      Hoàn tác
                    </Button>
                  ) : null,
              },
            ]}
            rows={batches.data?.rows ?? []}
            rowKey={(b) => b.id}
            rowLabel={(b) => formatDateTime(b.created_at)}
            loading={batches.isPending}
            empty={<StateView kind="empty" title="Chưa chạy đợt nào" headingLevel={2} />}
          />
        )}
      </section>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title="Xác nhận lên khối đầu năm học"
        summary={[
          { label: 'Phạm vi', value: branchFilter.branch_id ? 'Cơ sở đã lọc' : 'Mọi cơ sở' },
          { label: 'Lên một khối', value: String(after?.promoting ?? 0) },
          { label: 'Tốt nghiệp (lớp 12)', value: String(after?.graduating ?? 0) },
          { label: 'Loại trừ', value: String(excluded.size) },
        ]}
        description="Mỗi em lên một khối; lớp 12 chuyển sang tốt nghiệp. Hoàn tác cả đợt được trong số ngày cho phép."
        confirmLabel="Lên khối"
        busy={busy}
        error={error}
        onConfirm={() => void run()}
      />
      <ConfirmDialog
        open={undoing !== null}
        onOpenChange={(open) => !open && setUndoing(null)}
        title="Hoàn tác đợt lên khối"
        summary={[
          { label: 'Chạy lúc', value: undoing ? formatDateTime(undoing.created_at) : '' },
          { label: 'Lên khối', value: String(undoing?.promoted ?? 0) },
          { label: 'Tốt nghiệp', value: String(undoing?.graduated ?? 0) },
        ]}
        description="Trả khối cũ cho cả đợt. Em đã được sửa khối tay sau đợt thì giữ nguyên."
        confirmLabel="Hoàn tác"
        tone="danger"
        busy={busy}
        error={error}
        onConfirm={() => void undo()}
      />
    </>
  );
}
