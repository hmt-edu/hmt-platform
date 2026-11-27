// Huỷ nhiều lead nhập nhầm và khôi phục lead đã huỷ (K08, cùng khuôn CHUNG-20). Máy chủ kiểm quyền và luật từng lead;
// lead vướng luật thì bỏ qua, hộp nêu mã và lý do.
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { skippedLines } from './skippedLines';
import type { BulkResult } from './useLeadData';

function SkippedList({ result }: { result: BulkResult }) {
  return (
    <ul className="flex max-h-60 list-disc flex-col gap-1 overflow-y-auto pl-5 text-body">
      {skippedLines(result).map((line, i) => (
        <li key={i}>{line}</li>
      ))}
    </ul>
  );
}

type Props = {
  ids: string[];
  onClose: () => void;
  /** Gọi ngay khi máy chủ làm xong (để tải lại danh sách, kể cả khi còn dòng bỏ qua). */
  onDone: (result: BulkResult) => void;
};

export function BulkCancelLeadDialog({
  ids,
  max,
  onClose,
  onDone,
}: Props & { max: number | null }) {
  const supabase = useDb();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<BulkResult | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const r = await rpc<BulkResult>(supabase, 'cancel_wrong_leads', {
        p_ids: ids,
        p_reason: reason.trim(),
      });
      onDone(r);
      if (r.skipped.length === 0) onClose();
      else setResult(r);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  if (result) {
    return (
      <ConfirmDialog
        open
        onOpenChange={(o) => !o && onClose()}
        title={`Đã huỷ ${result.done} lead, bỏ qua ${result.skipped.length}`}
        description={<SkippedList result={result} />}
        confirmLabel="Đã xem"
        cancelLabel="Đóng"
        onConfirm={onClose}
      />
    );
  }
  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Huỷ lead nhập nhầm"
      subtitle={`Đã chọn ${ids.length} lead${max === null ? '' : ` (tối đa ${max} mỗi lần)`}`}
      confirmLabel="Huỷ lead"
      cancelLabel="Giữ lại"
      canSubmit={reason.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Các lead sẽ chuyển sang «Đã huỷ», không xoá. Lead đã có cơ hội hay lịch hẹn được bỏ qua.
          Mọi lần huỷ đều ghi nhật ký.
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

export function RestoreLeadDialog({ ids, onClose, onDone }: Props) {
  const supabase = useDb();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<BulkResult | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const r = await rpc<BulkResult>(supabase, 'restore_cancelled_leads', { p_ids: ids });
      onDone(r);
      if (r.skipped.length === 0) onClose();
      else setResult(r);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={
        result
          ? `Đã khôi phục ${result.done} lead, bỏ qua ${result.skipped.length}`
          : 'Khôi phục lead đã huỷ'
      }
      description={
        result ? (
          <SkippedList result={result} />
        ) : (
          `Đã chọn ${ids.length} lead. Lead trở lại «Đang dùng»; lý do huỷ cũ được giữ trong ghi chú.`
        )
      }
      confirmLabel={result ? 'Đã xem' : 'Khôi phục'}
      cancelLabel={result ? 'Đóng' : 'Huỷ'}
      busy={busy}
      error={error}
      onConfirm={() => (result ? onClose() : void submit())}
    />
  );
}
