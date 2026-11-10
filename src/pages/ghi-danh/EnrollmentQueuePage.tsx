// GD-06 Hàng chờ xếp lớp (danh sách, khuôn K03): CHỈ ghi danh Chờ xếp lớp (R-GD-05). Cột Xử lý "Xếp lớp" mở GD-03. Em đã có lớp, em học trước chưa đóng tiền,
// em Toán 7+ mới xếp một lớp không vào hàng chờ (là cảnh báo ở GD-02, GD-03).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignClassDialog } from './AssignClassDialog';
import { buildQueueConfig } from './enrollConfig';
import { EMPTY_ENROLL_STATE, buildEnrollFilters } from './enrollFilters';
import type { QueueRow } from './enrollTypes';
import { useEnrollmentQueue, useRefreshEnrollments } from './useEnrollmentData';

export function EnrollmentQueuePage() {
  const access = useAccess();
  const refreshData = useRefreshEnrollments();
  const catalogs = useLeadCatalogs();
  const [assigning, setAssigning] = useState<string | null>(null);
  const config = useMemo(
    () => buildQueueConfig(catalogs, (r) => setAssigning(r.id), access.can('ENROLLMENT', 'SUA')),
    [catalogs, access],
  );
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_ENROLL_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildEnrollFilters({ ...state, search: debouncedSearch }, []),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useEnrollmentQueue(filters, page * (pageSize ?? 0), pageSize);
  const rows: QueueRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

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
          title: 'Không có ghi danh nào đang chờ xếp lớp',
          hint: 'Ghi danh sinh ra ở tình trạng Chờ xếp lớp khi tiền đã vào đủ cọc; xếp lớp xong thì rời hàng chờ.',
        }}
      />
      <AssignClassDialog enrollmentId={assigning} onClose={() => setAssigning(null)} />
    </>
  );
}
