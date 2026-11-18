// CHUNG-15 Việc chờ tôi duyệt (khuôn K03; canvas 1aab CHUNG15_*): gộp việc ĐẾN LƯỢT vai của người đăng nhập. Một lần gọi app.list_my_approvals,
// phân trang và lọc loại việc, cơ sở ở máy chủ. Bấm dòng mở bản ghi; Duyệt, Từ chối nằm trong màn từng loại (không duyệt hàng loạt).
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { buildApprovalsConfig } from './approvalsConfig';
import { EMPTY_APPROVAL_STATE, approvalFilters, approvalPath } from './approvalsLogic';
import type { ApprovalRow } from './approvalsTypes';
import { useApprovalsPage, useRefreshApprovals } from './useApprovalsData';

export function ApprovalsPage() {
  const access = useAccess();
  const navigate = useNavigate();
  const refreshData = useRefreshApprovals();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_APPROVAL_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const filters = useMemo(() => approvalFilters(state), [state]);
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useApprovalsPage(filters, page * (pageSize ?? 0), pageSize);
  const rows: ApprovalRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const config = useMemo(
    () => buildApprovalsConfig(access, list.data?.counts),
    [access, list.data?.counts],
  );

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => `${r.kind}:${r.ref_id}:${r.level_no}`}
      rowLabel={(r) => `${r.code}`}
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void refreshData()}
      onRowClick={(r) => void navigate(approvalPath(r))}
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
        title:
          Object.keys(filters).length > 0
            ? 'Không có việc nào khớp bộ lọc'
            : 'Không có việc chờ duyệt',
        hint:
          Object.keys(filters).length > 0
            ? 'Đổi hoặc bỏ bộ lọc loại việc, cơ sở.'
            : 'Khi có đơn, phiếu hay yêu cầu đến lượt bạn duyệt, chúng sẽ hiện ở đây.',
      }}
    />
  );
}
