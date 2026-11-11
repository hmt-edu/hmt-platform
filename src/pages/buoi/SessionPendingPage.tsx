// BUOI-12 Buổi chưa hoàn tất (khuôn K03): buổi Đã chốt đã kết thúc mà giáo viên chưa hoàn tất, kèm hạn (R-GV-05) và lý do chưa Done (R-GIO-06). "Nhắc GV" ghi một
// thông báo cho giáo viên của buổi (app.remind_teacher_session); cổng giáo viên CHƯA có chỗ đọc thông báo nên nút "Nhắc GV" tạm mờ kèm chữ giải thích (Chat 11/11, làm sau 17/11).
// Hàm DB và hook useRemindTeacher giữ nguyên để bật lại khi có hộp thông báo. "Mở buổi" sang BUOI-02.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { buildPendingConfig } from './sessionConfig';
import { EMPTY_ABSENT_STATE, buildPendingFilters } from './sessionLogic';
import { usePendingPage, useRefreshSessions } from './useSessionData';

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
  const list = usePendingPage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const config = useMemo(() => buildPendingConfig(access, access.can('SESSION', 'SUA')), [access]);

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.class_code} ${r.start_time}`}
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
        title: 'Không có buổi nào chưa hoàn tất',
        hint: 'Buổi đã chốt mà giáo viên chưa hoàn tất trong hạn sẽ hiện ở đây (R-BUOI-02).',
      }}
    />
  );
}
