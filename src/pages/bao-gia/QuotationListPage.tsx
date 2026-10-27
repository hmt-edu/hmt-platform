// BH-01 Báo giá (danh sách): khuôn K03 nối với list_quotations. Lọc, sắp xếp, phân trang làm ở máy chủ; trình duyệt chỉ giữ trang đang xem.
// Không có nút Tạo (báo giá sinh từ cơ hội, R-TIEN-02); có nút Xuất cho vai có quyền Xuất (Trưởng cơ sở, Kế toán, Admin, Đ105).
// Giao diện không tính tiền: tổng tiền, quá hạn đều do hàm cơ sở dữ liệu trả.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_QUOTE_STATE, buildQuoteConfig } from './quoteConfig';
import { buildQuoteFilters, nextQuoteSort, quoteSortParam } from './quoteFilters';
import type { QuotationRow } from './quoteTypes';
import { exportQuotations, useQuotationPage, useRefreshQuotations } from './useQuoteData';

const EXPORT_COLUMNS = [
  { key: 'code', label: 'Mã' },
  { key: 'status', label: 'Tình trạng' },
  { key: 'parent_name', label: 'Phụ huynh' },
  { key: 'parent_phone', label: 'SĐT' },
  { key: 'opportunity', label: 'Cơ hội' },
  { key: 'students', label: 'Học sinh' },
  { key: 'total_amount', label: 'Tổng tiền (đ)' },
  { key: 'valid_until', label: 'Hạn hiệu lực' },
  { key: 'sent_at', label: 'Ngày gửi' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'created_by', label: 'Người lập' },
  { key: 'created_at', label: 'Ngày tạo' },
];

export function QuotationListPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshQuotations();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildQuoteConfig(catalogs, access), [catalogs, access]);
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_QUOTE_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [exporting, setExporting] = useState(false);

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildQuoteFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const sortValue = quoteSortParam(sort);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useQuotationPage(filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows: QuotationRow[] = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportQuotations(supabase, filters);
      const out = result.rows.map((r) => ({
        ...r,
        valid_until: r.valid_until ? formatDate(r.valid_until) : '',
        sent_at: r.sent_at ? formatDateTime(r.sent_at) : '',
        created_at: formatDateTime(r.created_at),
      }));
      downloadText(`bao-gia-${vnDayBounds().dateKey}.csv`, toCsv(out, EXPORT_COLUMNS));
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

  const canExport = access.can('QUOTATION', 'XUAT');

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.parent_name}`}
      loading={list.isPending || list.isPlaceholderData}
      error={errorText}
      onRetry={() => void list.refetch()}
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
      onSortChange={(next) => setSort(nextQuoteSort(next))}
      emptyMessage={{
        title: 'Chưa có báo giá nào',
        hint: 'Báo giá sinh từ cơ hội: mở cơ hội rồi bấm Tạo báo giá. Danh sách này không có nút Tạo (R-TIEN-02).',
      }}
    />
  );
}
