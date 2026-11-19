// QT-09 Lịch sử thay đổi tham số (canvas dc47 QT09_lich_su): hộp xem theo một tham số hoặc mọi tham số; chỉ đọc, mới nhất trước.
// Dữ liệu từ nhật ký (rpc list_setting_history): lúc, người sửa, phạm vi (Chung hoặc cơ sở), giá trị cũ, giá trị mới. Phân trang ở máy chủ.
import { useState } from 'react';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Pagination } from '../../ui/Data';
import { Alert, Spinner } from '../../ui/Feedback';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Dialog } from '../../ui/Overlays';
import {
  formatHistoryValue,
  historyActor,
  historyScope,
  type SettingDef,
  type SettingHistoryRow,
} from './settingsLogic';
import { useSettingHistory } from './useSettingsData';

export function SettingHistoryDialog({
  open,
  onOpenChange,
  target,
  defs,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Tham số cần xem; null = mọi tham số. */
  target: SettingDef | null;
  defs: SettingDef[];
}) {
  const pageSize = useIntSetting('list_page_size_default');
  const [paging, setPaging] = useState({ key: '', page: 1 });
  const key = target?.key ?? null;
  const pagingKey = key ?? '*';
  const page = paging.key === pagingKey ? paging.page : 1;
  const list = useSettingHistory(key, (page - 1) * (pageSize ?? 0), pageSize, open);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const byKey = new Map(defs.map((d) => [d.key, d]));

  const columns: LineColumn<SettingHistoryRow>[] = [
    {
      key: 'at',
      header: 'Lúc',
      width: 'w-40',
      cell: (r) => <span className="tabular">{formatDateTime(r.at)}</span>,
    },
    ...(target
      ? []
      : [
          {
            key: 'setting',
            header: 'Tham số',
            cell: (r: SettingHistoryRow) => byKey.get(r.setting_key)?.name ?? r.setting_key,
          },
        ]),
    { key: 'actor', header: 'Ai sửa', cell: (r) => historyActor(r.actor_name) },
    { key: 'scope', header: 'Phạm vi', width: 'w-24', cell: (r) => historyScope(r) },
    {
      key: 'old',
      header: 'Giá trị cũ',
      cell: (r) => formatHistoryValue(byKey.get(r.setting_key), r.old_value),
    },
    {
      key: 'new',
      header: 'Giá trị mới',
      cell: (r) => formatHistoryValue(byKey.get(r.setting_key), r.new_value),
    },
  ];

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Lịch sử thay đổi"
      description={
        target
          ? `Tham số: ${target.name}. Ghi từ mới đến cũ. Không ai sửa hay xoá được nhật ký.`
          : 'Mọi tham số, ghi từ mới đến cũ. Không ai sửa hay xoá được nhật ký.'
      }
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
            caption="Lịch sử thay đổi tham số"
            columns={columns}
            rows={rows}
            rowKey={(r) => String(r.id)}
            empty="Chưa có lần sửa nào."
          />
          <Pagination
            page={page}
            pageSize={pageSize ?? 1}
            total={total}
            onPageChange={(next) => setPaging({ key: pagingKey, page: next })}
          />
        </div>
      )}
    </Dialog>
  );
}
