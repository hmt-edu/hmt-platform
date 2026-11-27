// Bảng phân trang ở máy chủ trong tab hồ sơ khách hàng: gọi đúng hàm danh sách của phân hệ nên quyền và phạm vi do máy chủ quyết
// như ở màn danh sách. Không có quyền thì vẫn hiện đủ cột, không gọi dữ liệu.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Pagination, type Column } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { CustTable } from './CustTable';

export function PagedTable<Row>({
  caption,
  fn,
  filters,
  sort,
  columns,
  rowKey,
  allowed,
  empty,
  denied,
  total: allTotal,
}: {
  caption: string;
  /** Hàm danh sách ở cơ sở dữ liệu, trả { total, rows }. */
  fn:
    | 'list_orders'
    | 'list_receipts'
    | 'enrollment_list'
    | 'list_student_tests'
    | 'list_record_appointments'
    | 'list_record_upsale';
  filters: Record<string, unknown>;
  sort: string;
  columns: Column<Row>[];
  rowKey: (row: Row) => string;
  allowed: boolean;
  empty: string;
  denied: string;
  /** Số đếm trên nút số của hồ sơ (mọi cơ sở): danh sách ít hơn thì nói rõ là theo quyền xem. */
  total?: number | undefined;
}) {
  const supabase = useDb();
  const pageSize = useIntSetting('list_page_size_default');
  const key = JSON.stringify(filters);
  const [paging, setPaging] = useState({ key, page: 1 });
  const page = paging.key === key ? paging.page : 1;
  const query = useQuery({
    // Khoá bắt đầu bằng 'parent-record' để nút Làm mới của hồ sơ tải lại cả bảng.
    queryKey: ['parent-record', 'tab', fn, key, sort, page, pageSize],
    enabled: allowed && pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<{ total: number; rows: Row[] }>(supabase, fn, {
        p_filters: filters,
        p_sort: sort,
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  if (allowed && query.isError) {
    return (
      <StateView
        kind="error"
        title={`Không tải được ${caption.toLowerCase()}`}
        headingLevel={2}
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const total = query.data?.total ?? 0;
  const filtered = Object.keys(filters).length > 1;
  return (
    <div className="flex flex-col gap-2">
      <CustTable
        caption={caption}
        columns={columns}
        rows={allowed ? (query.data?.rows ?? []) : []}
        rowKey={rowKey}
        loading={allowed && query.isPending}
        empty={allowed ? empty : denied}
      />
      {allowed && !filtered && query.data && allTotal !== undefined && total < allTotal && (
        <p className="text-caption text-fg-muted">
          Danh sách chỉ gồm bản ghi trong phạm vi quyền xem của bạn.
        </p>
      )}
      {allowed && total > 0 && pageSize !== null && (
        <Pagination
          page={page}
          pageSize={pageSize}
          total={total}
          onPageChange={(p) => setPaging({ key, page: p })}
        />
      )}
    </div>
  );
}
