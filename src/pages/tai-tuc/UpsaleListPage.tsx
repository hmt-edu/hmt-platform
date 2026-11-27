// TT-01 Phiếu tái tục (danh sách và Kanban, khuôn K03, K04; canvas 9933 TT01, TT01_kanban): nối với list_upsale_tickets, upsale_board.
// Lọc, phân trang làm ở máy chủ; chỉ giữ trang đang xem. Nút Tạo (TT-03) cho người có quyền Tạo; cột Xử lý có Giao (quyền Giao việc).
// Bấm một dòng mở bản ghi phiếu (TT-02).
import { useMemo, useState } from 'react';
import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { useLeafRows } from '../lead/useLeadData';
import { AssignUpsaleDialog } from './AssignUpsaleDialog';
import { CreateUpsaleDialog } from './CreateUpsaleDialog';
import { UpsaleCard } from './UpsaleCard';
import { buildUpsaleConfig } from './upsaleConfig';
import {
  EMPTY_UPSALE_STATE,
  UPSALE_GROUP_FIELD_OF,
  buildUpsaleFilters,
  upsaleGroupFilter,
} from './upsaleFilters';
import type { UpsaleRow } from './upsaleTypes';
import {
  useRefreshUpsale,
  useUpsaleBoard,
  useUpsaleGroupCounts,
  useUpsalePage,
} from './useUpsaleData';
import { useNavigateFrom } from '../../layout/crumbTrail';

export function UpsaleListPage() {
  const access = useAccess();
  const toast = useToast();
  const openFrom = useNavigateFrom();
  const refreshData = useRefreshUpsale();
  const catalogs = useLeadCatalogs();
  const [assigning, setAssigning] = useState<UpsaleRow | null>(null);
  const [creating, setCreating] = useState(false);
  const config = useMemo(
    () => buildUpsaleConfig(catalogs, access, setAssigning),
    [catalogs, access],
  );
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_UPSALE_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildUpsaleFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const groupFields = state.group.flatMap((k) =>
    UPSALE_GROUP_FIELD_OF[k] ? [UPSALE_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useUpsalePage(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useUpsaleGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<UpsaleRow>(
    filters,
    undefined,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_upsale_tickets_grouped',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<UpsaleRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            upsaleGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const board = useUpsaleBoard(filters, pageSize, view === 'kanban');
  const pageRows: UpsaleRow[] = list.data?.rows ?? [];
  const rows: UpsaleRow[] = useMemo(
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
        kanban={
          board.isPending ? (
            <Spinner label="Đang tải Kanban…" />
          ) : (
            <KanbanBoard
              columns={(board.data ?? []).map((c) => ({
                code: c.stage_code,
                label: `${c.stage_code} ${c.name}`,
                cards: c.rows,
                total: c.total,
              }))}
              cardKey={(c) => c.id}
              cardLabel={(c) => c.code}
              rule={() => ({
                ok: false,
                reason: 'Đổi giai đoạn phiếu tái tục trong bản ghi phiếu.',
              })}
              onMove={() => undefined}
              onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
              note="Đổi giai đoạn phiếu tái tục trong bản ghi phiếu (L7, L8 do hệ thống đặt khi có báo giá, đơn)."
              renderCard={(c) => <UpsaleCard row={c} />}
            />
          )
        }
        actions={
          access.can('UPSALE', 'TAO') && access.featureOn('BAN_HANG')
            ? [
                {
                  label: 'Tạo',
                  icon: 'plus' as const,
                  primary: true,
                  onClick: () => setCreating(true),
                },
              ]
            : []
        }
        rows={rows}
        onRowClick={(r) => openFrom(`/crm/tai-tuc/${r.id}`)}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.code} ${r.student_name}`}
        loading={activeQuery.isPending || activeQuery.isPlaceholderData}
        error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
        onRetry={() => void activeQuery.refetch()}
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
          title: 'Chưa có phiếu tái tục nào',
          hint: 'Phiếu tái tục tự sinh khi học sinh sắp hết giờ ở một lớp, hoặc tạo tay bằng nút Tạo.',
        }}
      />
      <CreateUpsaleDialog
        open={creating}
        onOpenChange={setCreating}
        onCreated={(code) => {
          void refreshData();
          toast({ title: `Đã tạo phiếu ${code}.` });
        }}
      />
      <AssignUpsaleDialog
        row={assigning}
        onOpenChange={(o) => !o && setAssigning(null)}
        onAssigned={(name) => {
          void refreshData();
          toast({ title: `Đã giao cho ${name}.` });
        }}
      />
    </>
  );
}
