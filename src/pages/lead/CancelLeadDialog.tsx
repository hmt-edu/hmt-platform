// CHUNG-20 · Hộp «Huỷ lead nhập nhầm» (K08, chỉ Admin). Máy chủ (app.cancel_wrong_lead) quyết định: chỉ Admin, lý do bắt buộc,
// chặn khi lead đã có cơ hội hoặc lịch hẹn. Không xoá: lead chuyển sang «Đã huỷ», mọi lần huỷ ghi nhật ký.
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';

export function CancelLeadDialog({
  leadId,
  summary,
  open,
  onClose,
  onCancelled,
}: {
  leadId: string;
  /** Mô tả lead sẽ huỷ, ví dụ «LD000123 · Chị Thử · 0900 000 000». */
  summary: string;
  open: boolean;
  onClose: () => void;
  onCancelled: () => void;
}) {
  // Dựng lại trạng thái nhập mỗi lần mở.
  return open ? (
    <Body leadId={leadId} summary={summary} onClose={onClose} onCancelled={onCancelled} />
  ) : null;
}

function Body({
  leadId,
  summary,
  onClose,
  onCancelled,
}: {
  leadId: string;
  summary: string;
  onClose: () => void;
  onCancelled: () => void;
}) {
  const supabase = useDb();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await rpc<unknown>(supabase, 'cancel_wrong_lead', { p_id: leadId, p_reason: reason.trim() });
      onCancelled();
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Huỷ lead nhập nhầm"
      subtitle={summary}
      confirmLabel="Huỷ lead"
      cancelLabel="Giữ lại"
      canSubmit={reason.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Lead sẽ chuyển sang «Đã huỷ», không xoá và không tính trùng số điện thoại. Chỉ huỷ được
          lead chưa có cơ hội hay lịch hẹn. Mọi lần huỷ đều ghi nhật ký.
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
