// Chọn nhiều buổi và Done hàng loạt (R-GIO-12), dùng chung cho danh sách Buổi học và lọc «Chưa hoàn tất»:
// cần Điểm danh · Duyệt; số buổi tối đa mỗi lượt là tham số session_bulk_done_max; luật loại buổi nằm ở máy chủ.
import { useState } from 'react';
import { useIntSetting } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { BulkActionBar } from '../../ui/Data';
import { Alert } from '../../ui/Feedback';
import { BulkDoneDialog } from './BulkDoneDialog';
import { sessionNoLabel } from './sessionLogic';
import type { BulkFinishResult } from './sessionTypes';

/** `listProps` trải vào ListScreen (ô tick và thanh thao tác hàng loạt), `dialog` đặt cạnh danh sách. */
export function useBulkDone(onFinished: () => void) {
  const access = useAccess();
  const canBulk = access.can('ATTENDANCE', 'DUYET');
  const bulkMax = useIntSetting('session_bulk_done_max');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [open, setOpen] = useState(false);
  const [result, setResult] = useState<BulkFinishResult | null>(null);

  const listProps = canBulk
    ? {
        selected,
        onSelectedChange: setSelected,
        bulk: (
          <>
            {result && (
              <Alert tone={result.skipped.length > 0 ? 'warning' : 'success'}>
                <b>
                  Đã Done {result.done.length} buổi, bỏ qua {result.skipped.length}.
                </b>
                <ul className="list-disc pl-5">
                  {result.skipped.map((x) => (
                    <li key={x.session_id}>
                      {x.class_code} {sessionNoLabel(x.session_no)}: {x.reason}
                    </li>
                  ))}
                </ul>
              </Alert>
            )}
            <BulkActionBar count={selected.size} onClear={() => setSelected(new Set())}>
              <Button
                disabled={bulkMax === null || selected.size > bulkMax}
                onClick={() => setOpen(true)}
              >
                Done hàng loạt
              </Button>
              {bulkMax !== null && selected.size > bulkMax && (
                <span className="text-caption">Mỗi lượt tối đa {bulkMax} buổi.</span>
              )}
            </BulkActionBar>
          </>
        ),
      }
    : {};

  const dialog = (
    <BulkDoneDialog
      sessionIds={[...selected]}
      open={open}
      onClose={() => setOpen(false)}
      onDone={(r) => {
        setResult(r);
        setSelected(new Set());
        onFinished();
      }}
    />
  );

  return { listProps, dialog };
}
