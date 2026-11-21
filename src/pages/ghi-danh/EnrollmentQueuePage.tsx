// GD-06 Hàng chờ xếp lớp (danh sách, khuôn K03): CHỈ ghi danh Chờ xếp lớp (R-GD-05). Cột Xử lý "Xếp lớp" mở GD-03. Em đã có lớp, em học trước chưa đóng tiền,
// em Toán 7+ mới xếp một lớp không vào hàng chờ (là cảnh báo ở GD-02, GD-03).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignClassDialog } from './AssignClassDialog';
import { buildQueueConfig } from './enrollConfig';
import {
  EMPTY_ENROLL_STATE,
  QUEUE_GROUP_FIELD_OF,
  buildEnrollFilters,
  queueGroupFilter,
} from './enrollFilters';
import type { QueueRow } from './enrollTypes';
import {
  useEnrollmentQueue,
  useQueueGroupCounts,
  useRefreshEnrollments,
} from './useEnrollmentData';

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

  // Group By ở máy chủ (tối đa hai cấp): số đếm từ enrollment_queue_group_counts, dòng tải khi mở từng nhóm lá (enrollment_queue, không có p_sort).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    QUEUE_GROUP_FIELD_OF[k] ? [QUEUE_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useEnrollmentQueue(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useQueueGroupCounts(filters, groupFields);
  const leaves = useLeafRows<QueueRow>(
    filters,
    null,
    pageSize,
    `${pagingKey}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'enrollment_queue',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<QueueRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            queueGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows: QueueRow[] = list.data?.rows ?? [];
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
        rowLabel={(r) => `${r.code} ${r.student_name}`}
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
          title: 'Không có ghi danh nào đang chờ xếp lớp',
          hint: 'Ghi danh sinh ra ở tình trạng Chờ xếp lớp khi tiền đã vào đủ cọc; xếp lớp xong thì rời hàng chờ.',
        }}
      />
      <AssignClassDialog enrollmentId={assigning} onClose={() => setAssigning(null)} />
    </>
  );
}
