// BH-06 Đơn hàng (danh sách): khuôn K03 nối với list_orders. Lọc, sắp xếp, phân trang làm ở máy chủ; trình duyệt chỉ giữ trang đang xem.
// Không có nút Tạo (đơn sinh từ báo giá, cơ hội, phiếu tái tục; R-CRM-19, R-TIEN-02); có nút Xuất cho vai có quyền Xuất (Trưởng cơ sở, Kế toán, Admin, Đ105).
// Giao diện không tính tiền: tổng tiền do hàm cơ sở dữ liệu trả. Chưa có màn bản ghi đơn (BH-05) nên dòng chưa mở được.
import { useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { listForbiddenOf } from '../../list/forbiddenSpec';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_ORDER_STATE, buildOrderConfig } from './orderConfig';
import {
  ORDER_GROUP_FIELD_OF,
  buildOrderFilters,
  nextOrderSort,
  orderGroupFilter,
  orderSortParam,
} from './orderFilters';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import type { OrderRow } from './orderTypes';
import { exportOrders, useOrderGroupCounts, useOrderPage, useRefreshOrders } from './useOrderData';

const EXPORT_COLUMNS = [
  { key: 'code', label: 'Mã' },
  { key: 'status', label: 'Tình trạng' },
  { key: 'parent_name', label: 'Phụ huynh' },
  { key: 'parent_phone', label: 'SĐT' },
  { key: 'opportunity', label: 'Cơ hội' },
  { key: 'quotation', label: 'Báo giá' },
  { key: 'students', label: 'Học sinh' },
  { key: 'total_amount', label: 'Tổng tiền (đ)' },
  { key: 'submitted_at', label: 'Ngày trình' },
  { key: 'approved_at', label: 'Ngày duyệt' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'created_by', label: 'Người lập' },
  { key: 'created_at', label: 'Ngày tạo' },
];

export function OrderListPage() {
  const navigate = useNavigate();
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshOrders();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildOrderConfig(catalogs, access), [catalogs, access]);
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_ORDER_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [exporting, setExporting] = useState(false);

  const [params, setParams] = useSearchParams();
  const parentOpp = params.get('co-hoi');
  const parentCode = params.get('ma') ?? '';
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => ({
      ...buildOrderFilters({ ...state, search: debouncedSearch }),
      // Mở từ nút số đếm của trang Cơ hội (K3): chỉ bản ghi của cơ hội đó; bỏ chip thì về danh sách chung.
      ...(parentOpp ? { opportunity_id: parentOpp } : {}),
    }),
    [state, debouncedSearch, parentOpp],
  );
  const sortValue = orderSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  // Group By ở máy chủ (K1_nhom): chọn trường nhóm thì danh sách thành cây nhóm có số đếm; nhóm lá tải dòng khi mở.
  const groupFields = state.group.flatMap((k) =>
    ORDER_GROUP_FIELD_OF[k] ? [ORDER_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const list = useOrderPage(filters, sortValue, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useOrderGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<OrderRow>(
    filters,
    sortValue,
    pageSize,
    pagingKey,
    (message) => toast({ tone: 'danger', title: message }),
    'list_orders',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<OrderRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            orderGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const pageRows: OrderRow[] = list.data?.rows ?? [];
  const rows: OrderRow[] = useMemo(
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
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportOrders(supabase, filters);
      const out = result.rows.map((r) => ({
        ...r,
        submitted_at: r.submitted_at ? formatDateTime(r.submitted_at) : '',
        approved_at: r.approved_at ? formatDateTime(r.approved_at) : '',
        created_at: formatDateTime(r.created_at),
      }));
      downloadText(`don-hang-${vnDayBounds().dateKey}.csv`, toCsv(out, EXPORT_COLUMNS));
      toast(
        result.truncated
          ? {
              tone: 'warning',
              title: `Đã xuất ${result.exported} trên ${result.total} dòng (quá giới hạn mỗi lần xuất). Thêm bộ lọc để xuất phần còn lại.`,
            }
          : { title: `Đã xuất ${result.exported} dòng.` },
      );
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setExporting(false);
    }
  }

  const canExport = access.can('SALES_ORDER', 'XUAT');

  return (
    <ListScreen
      parent={
        parentOpp
          ? {
              entityLabel: 'Cơ hội',
              code: parentCode,
              childLabel: 'Đơn hàng',
              onOpenParent: () => void navigate(`/crm/co-hoi/${parentOpp}`),
              onClear: () => setParams({}),
            }
          : undefined
      }
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.parent_name}`}
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={errorText}
      forbidden={listForbiddenOf(activeQuery.error, 'đơn hàng', 'Bán hàng và thu chi')}
      onRetry={() => void activeQuery.refetch()}
      groupTree={grouped ? grouping?.tree : undefined}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      actions={
        canExport
          ? [
              {
                label: 'Xuất',
                icon: 'download' as const,
                onClick: () => void exportFile(),
                loading: exporting,
              },
            ]
          : []
      }
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
      sort={sort}
      onSortChange={(next) => setSort(nextOrderSort(next))}
      emptyMessage={{
        title: 'Chưa có đơn hàng nào',
        hint: 'Đơn sinh từ báo giá hoặc cơ hội: mở báo giá rồi bấm Chuyển thành đơn, hoặc mở cơ hội ở L8 rồi bấm Tạo đơn hàng. Danh sách này không có nút Tạo (R-TIEN-02).',
      }}
    />
  );
}
