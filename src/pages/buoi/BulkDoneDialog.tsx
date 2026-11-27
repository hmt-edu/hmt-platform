// BUOI-12 Done hàng loạt (hộp thoại K08, R-GIO-12): một lý do bắt buộc cho cả lượt. Luật loại buổi nằm ở máy chủ (app.bulk_finish_sessions).
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import type { BulkFinishResult } from './sessionTypes';
import { useBulkFinish } from './useSessionData';

type Props = {
  sessionIds: string[];
  onClose: () => void;
  onDone: (result: BulkFinishResult) => void;
};

export function BulkDoneDialog({ open, ...props }: Props & { open: boolean }) {
  // Dựng lại mỗi lần mở để ô lý do trống.
  return open ? <Body {...props} /> : null;
}

function Body({ sessionIds, onClose, onDone }: Props) {
  const bulk = useBulkFinish();
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setError(null);
    try {
      onDone(await bulk.mutateAsync({ sessionIds, reason: reason.trim() }));
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Done hàng loạt"
      confirmLabel={`Done ${sessionIds.length} buổi`}
      cancelLabel="Đóng"
      canSubmit={reason.trim() !== ''}
      busy={bulk.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Bỏ qua điều kiện khớp hai cột, nội dung buổi, nhận xét, bài tập và điểm. Buổi giáo viên
          chưa điểm danh đủ sẽ bị loại. Buổi Done còn thiếu nội dung hoặc nhận xét được gắn cờ Thiếu
          nhận xét.
        </p>
        <TextAreaField
          label="Lý do"
          required
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
