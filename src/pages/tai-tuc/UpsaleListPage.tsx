// TT-01 Phiếu tái tục (danh sách và Kanban, khuôn K03, K04; canvas 9933 TT01, TT01_kanban): nối với list_upsale_tickets, upsale_board.
// Lọc, phân trang làm ở máy chủ; chỉ giữ trang đang xem. Nút Tạo (TT-03) cho người có quyền Tạo; cột Xử lý có Giao (quyền Giao việc).
// Bấm một dòng mở bản ghi phiếu (TT-02).
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignUpsaleDialog } from './AssignUpsaleDialog';
import { CreateUpsaleDialog } from './CreateUpsaleDialog';
import { UpsaleCard } from './UpsaleCard';
import { buildUpsaleConfig } from './upsaleConfig';
import { EMPTY_UPSALE_STATE, buildUpsaleFilters } from './upsaleFilters';
import type { UpsaleRow } from './upsaleTypes';
import { useRefreshUpsale, useUpsaleBoard, useUpsalePage } from './useUpsaleData';

export function UpsaleListPage() {
  const access = useAccess();
  const toast = useToast();
  const navigate = useNavigate();
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

  const list = useUpsalePage(filters, page * (pageSize ?? 0), pageSize);
  const board = useUpsaleBoard(filters, pageSize, view === 'kanban');
  const rows: UpsaleRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

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
        onRowClick={(r) => void navigate(`/crm/tai-tuc/${r.id}`)}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.code} ${r.student_name}`}
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
