// BUOI-12 Buổi chưa hoàn tất (khuôn K03): buổi Đã chốt đã kết thúc mà giáo viên chưa hoàn tất, kèm hạn (R-GV-05) và lý do chưa Done (R-GIO-06). "Nhắc GV" ghi một
// thông báo cho giáo viên của buổi (app.remind_teacher_session); cổng giáo viên CHƯA có chỗ đọc thông báo nên nút "Nhắc GV" tạm mờ kèm chữ giải thích (Chat 11/11, làm sau 17/11).
// Hàm DB và hook useRemindTeacher giữ nguyên để bật lại khi có hộp thông báo. "Mở buổi" sang BUOI-02.
// Done hàng loạt (R-GIO-12): Điểm danh · Duyệt, chọn dòng ở danh sách, lý do bắt buộc; số buổi tối đa là tham số session_bulk_done_max.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import { Button } from '../../ui/Button';
import { BulkActionBar } from '../../ui/Data';
import { Alert } from '../../ui/Feedback';
import { BulkDoneDialog } from './BulkDoneDialog';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { buildPendingConfig } from './sessionConfig';
import {
  EMPTY_ABSENT_STATE,
  PENDING_GROUP_FIELD_OF,
  buildPendingFilters,
  pendingGroupFilter,
  sessionNoLabel,
} from './sessionLogic';
import type { BulkFinishResult, PendingRow } from './sessionTypes';
import { usePendingGroupCounts, usePendingPage, useRefreshSessions } from './useSessionData';

export function SessionPendingPage() {
  const access = useAccess();
  const refreshData = useRefreshSessions();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_ABSENT_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildPendingFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  // Group By ở máy chủ: số đếm từ session_pending_group_counts, dòng tải khi mở nhóm lá (session_pending_list, không có p_sort).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    PENDING_GROUP_FIELD_OF[k] ? [PENDING_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const canBulk = access.can('ATTENDANCE', 'DUYET');
  const bulkMax = useIntSetting('session_bulk_done_max');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkResult, setBulkResult] = useState<BulkFinishResult | null>(null);
  const list = usePendingPage(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = usePendingGroupCounts(filters, groupFields);
  const leaves = useLeafRows<PendingRow>(
    filters,
    null,
    pageSize,
    `${pagingKey}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'session_pending_list',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<PendingRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            pendingGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const config = useMemo(() => buildPendingConfig(access, access.can('SESSION', 'SUA')), [access]);

  return (
    <>
      <ListScreen
        {...(canBulk ? { selected, onSelectedChange: setSelected } : {})}
        bulk={
          canBulk ? (
            <>
              {bulkResult && (
                <Alert tone={bulkResult.skipped.length > 0 ? 'warning' : 'success'}>
                  <b>
                    Đã Done {bulkResult.done.length} buổi, bỏ qua {bulkResult.skipped.length}.
                  </b>
                  <ul className="list-disc pl-5">
                    {bulkResult.skipped.map((x) => (
                      <li key={x.session_id}>
                        {x.class_code} {sessionNoLabel(x.session_no)}: {x.reason}
                      </li>
                    ))}
                  </ul>
                </Alert>
              )}
              <BulkActionBar count={selected.size} onClear={() => setSelected(new Set())}>
                <Button
                  disabled={bulkMax === null || selected.size > bulkMax}
                  onClick={() => setBulkOpen(true)}
                >
                  Done hàng loạt
                </Button>
                {bulkMax !== null && selected.size > bulkMax && (
                  <span className="text-caption">Mỗi lượt tối đa {bulkMax} buổi.</span>
                )}
              </BulkActionBar>
            </>
          ) : undefined
        }
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.class_code} ${r.start_time}`}
        loading={activeQuery.isPending || activeQuery.isPlaceholderData}
        error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
        onRetry={() => void activeQuery.refetch()}
        onRefresh={() => {
          setTick((t) => t + 1);
          void refreshData();
        }}
        groupTree={grouping?.tree}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
        pager={
          grouped
            ? undefined
            : {
                from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
                to: page * (pageSize ?? 0) + rows.length,
                total,
                ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
                ...(page * (pageSize ?? 0) + rows.length < total
                  ? { onNext: () => setPage(page + 1) }
                  : {}),
              }
        }
        emptyMessage={{
          title: 'Không có buổi nào chưa hoàn tất',
          hint: 'Buổi đã chốt mà giáo viên chưa hoàn tất trong hạn sẽ hiện ở đây.',
        }}
      />
      <BulkDoneDialog
        sessionIds={[...selected]}
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        onDone={(result) => {
          setBulkResult(result);
          setSelected(new Set());
          setTick((t) => t + 1);
        }}
      />
    </>
  );
}
