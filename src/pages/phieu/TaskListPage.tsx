// CS-05 Phiếu nghiệp vụ (danh sách, khuôn K03, canvas CSN05): nối với list_ticket_tasks. Lọc, phân trang làm ở máy chủ; chỉ giữ trang đang xem.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { buildTaskConfig } from './phieuConfig';
import { EMPTY_TASK_STATE, buildTaskFilters } from './phieuFilters';
import { TASK_STATUS_LABEL, TASK_TYPE_LABEL, type TaskRow } from './phieuTypes';
import { useRefreshTasks, useTaskPage } from './usePhieuData';

const TYPE_CODES = Object.keys(TASK_TYPE_LABEL);
const STATUS_CODES = Object.keys(TASK_STATUS_LABEL);

export function TaskListPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const refreshData = useRefreshTasks();
  const config = useMemo(() => buildTaskConfig(access), [access]);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_TASK_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildTaskFilters({ ...state, search: debouncedSearch }, TYPE_CODES, STATUS_CODES),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useTaskPage(filters, page * (pageSize ?? 0), pageSize);
  const rows: TaskRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.ticket_code}`}
      onRowClick={(r) => void navigate(`/crm/phieu-nghiep-vu/${r.id}`)}
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
        title: 'Chưa có phiếu nghiệp vụ nào',
        hint: 'Phiếu tạo từ ticket đề nghị có nghiệp vụ (cập nhật hồ sơ, chuyển lớp…). Nếu phân hệ Aftersale chưa bật ở cơ sở của bạn thì danh sách trống.',
      }}
    />
  );
}
