// CH-04 Lịch sử thay đổi chính sách chiết khấu, quà tặng: hộp chỉ đọc, mới nhất trước. Dữ liệu từ nhật ký (rpc list_policy_history, migration 601); phân trang ở máy chủ.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Pagination } from '../../ui/Data';
import { Alert, Spinner } from '../../ui/Feedback';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Dialog } from '../../ui/Overlays';
import {
  POLICY_KIND_LABEL,
  describePolicyChange,
  type PolicyHistoryPage,
  type PolicyHistoryRow,
} from './policyHistory';

function usePolicyHistory(
  kind: 'DISCOUNT' | 'GIFT' | null,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['policy-history', kind, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<PolicyHistoryPage>(supabase, 'list_policy_history', {
        p_kind: kind,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function PolicyHistoryDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const pageSize = useIntSetting('list_page_size_default');
  const [page, setPage] = useState(1);
  const list = usePolicyHistory(null, (page - 1) * (pageSize ?? 0), pageSize, open);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

  const columns: LineColumn<PolicyHistoryRow>[] = [
    {
      key: 'at',
      header: 'Lúc',
      width: 'w-40',
      cell: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
    },
    { key: 'kind', header: 'Loại', width: 'w-28', cell: (r) => POLICY_KIND_LABEL[r.kind] },
    { key: 'policy', header: 'Chính sách', cell: (r) => `${r.name} (${r.code})` },
    { key: 'change', header: 'Thay đổi', cell: (r) => describePolicyChange(r) },
    { key: 'actor', header: 'Ai sửa', cell: (r) => r.actor_name ?? 'Hệ thống' },
  ];

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Lịch sử thay đổi"
      description="Chính sách chiết khấu và quà tặng, ghi từ mới đến cũ. Không ai sửa hay xoá được nhật ký."
      wide
      footer={<Button onClick={() => onOpenChange(false)}>Đóng</Button>}
    >
      {list.isError ? (
        <Alert tone="danger">{errorOf(list.error).message}</Alert>
      ) : list.isPending ? (
        <Spinner />
      ) : (
        <div className="flex flex-col gap-3">
          <LineTable
            caption="Lịch sử thay đổi chính sách"
            columns={columns}
            rows={rows}
            rowKey={(r) => String(r.id)}
            empty="Chưa có lần sửa nào."
          />
          <Pagination page={page} pageSize={pageSize ?? 1} total={total} onPageChange={setPage} />
        </div>
      )}
    </Dialog>
  );
}
