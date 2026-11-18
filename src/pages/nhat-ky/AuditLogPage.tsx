// QT-11 Nhật ký thao tác (khuôn K03 danh sách, chỉ đọc, chỉ Admin): ai, lúc nào, bảng nào, trường nào đổi từ gì sang gì.
// Lọc, phân trang ở máy chủ (app.list_audit_log, mới nhất trước). Không có khung canvas riêng: dựng từ khuôn K03.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { buildAuditConfig, EMPTY_AUDIT_STATE } from './auditConfig';
import { buildAuditFilters } from './auditLogic';
import { useAuditedTables, useAuditPage } from './useAuditData';

export function AuditLogPage() {
  const pageSize = useIntSetting('list_page_size_default');
  const tables = useAuditedTables();
  const [state, setState] = useState<ListState>(EMPTY_AUDIT_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildAuditFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useAuditPage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const config = useMemo(() => buildAuditConfig(tables.data ?? []), [tables.data]);

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => String(r.id)}
      rowLabel={(r) => `${r.table_name} ${r.record_id}`}
      loading={list.isPending || list.isPlaceholderData}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      actions={[]}
      onRefresh={() => void list.refetch()}
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
        title: 'Chưa có dòng nhật ký',
        hint: 'Không có thao tác nào khớp bộ lọc này. Đổi bộ lọc để xem tiếp.',
      }}
    />
  );
}
