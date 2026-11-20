// QT-07 Lịch sử thay đổi danh mục: hộp chỉ đọc, mới nhất trước (canvas dc47 chỉ vẽ nút; hộp dựng theo hộp lịch sử QT09_lich_su).
// Dữ liệu từ nhật ký (rpc list_catalog_history): lúc, người sửa, mục, nội dung đổi. Phân trang ở máy chủ.
import { useState } from 'react';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Pagination } from '../../ui/Data';
import { Alert, Spinner } from '../../ui/Feedback';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Dialog } from '../../ui/Overlays';
import { describeCatalogChange, type CatalogHistoryRow } from './catalogLogic';
import { useCatalogHistory } from './useCatalogData';

const COLUMNS: LineColumn<CatalogHistoryRow>[] = [
  {
    key: 'at',
    header: 'Lúc',
    width: 'w-40',
    cell: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
  },
  { key: 'actor', header: 'Ai sửa', cell: (r) => r.actor_name ?? 'Hệ thống' },
  { key: 'item', header: 'Mục', cell: (r) => `${r.item_code} · ${r.item_name}` },
  { key: 'change', header: 'Thay đổi', cell: (r) => describeCatalogChange(r) },
];

export function CatalogHistoryDialog({
  open,
  onOpenChange,
  rootCode,
  rootLabel,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  rootCode: string | null;
  rootLabel: string;
}) {
  const pageSize = useIntSetting('list_page_size_default');
  const [paging, setPaging] = useState({ key: '', page: 1 });
  const page = paging.key === rootCode ? paging.page : 1;
  const list = useCatalogHistory(rootCode, (page - 1) * (pageSize ?? 0), pageSize, open);

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Lịch sử thay đổi"
      description={`Danh mục: ${rootLabel}. Ghi từ mới đến cũ. Không ai sửa hay xoá được nhật ký.`}
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
            caption="Lịch sử thay đổi danh mục"
            columns={COLUMNS}
            rows={list.data.rows}
            rowKey={(r) => String(r.id)}
            empty="Chưa có lần sửa nào."
          />
          <Pagination
            page={page}
            pageSize={pageSize ?? 1}
            total={list.data.total}
            onPageChange={(next) => setPaging({ key: rootCode ?? '', page: next })}
          />
        </div>
      )}
    </Dialog>
  );
}
