// TC-17 «Chuyển người duyệt» (khuôn K4 ③ FormDialog; canvas 9933 TC17_admin). Admin chọn quản lý khác nhận bước duyệt; KHÔNG duyệt thay (R-HT-01, R-V2-44).
// Hàm reassign_approver kiểm mọi điều kiện (cờ, người đã chốt không duyệt được, người nhận hợp lệ, lý do); hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useLeadCatalogs } from '../../pages/lead/useCatalogs';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { noteForReassign, reassignReasonText, suggestedReasonCode } from './reassignText';
import { useReassignCandidates, type ReassignKind, type ReassignState } from './useReassign';

export type ReassignApproverDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  kind: ReassignKind;
  id: string;
  /** "phiếu thu PT-CS1-2610-0015": dùng trong tiêu đề. */
  subject: string;
  state: ReassignState;
  /** Chuyển xong (tải lại bản ghi, báo thành công). */
  onDone: () => Promise<void> | void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function ReassignApproverDialog(props: ReassignApproverDialogProps) {
  return props.open ? <ReassignForm {...props} /> : null;
}

function ReassignForm({
  open,
  onOpenChange,
  kind,
  id,
  subject,
  state,
  onDone,
}: ReassignApproverDialogProps) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const candidates = useReassignCandidates(kind, id, true);
  const [toId, setToId] = useState('');
  const [reason, setReason] = useState(() => suggestedReasonCode(state.reason));
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reasonOptions = catalogs.optionsFor('REASSIGN_REASON', kind);
  const needsNote = catalogs.requiresNote('REASSIGN_REASON', reason);
  const people = (candidates.data ?? []).map((c) => ({ value: c.id, label: c.name }));

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await rpc(supabase, 'reassign_approver', {
        p_kind: kind,
        p_id: id,
        p_new_approver: toId,
        p_reason_code: reason,
        p_note: noteForReassign(note),
      });
      await onDone();
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Chuyển người duyệt ${subject}`}
      subtitle="Admin không duyệt ở bước quản lý. Chọn quản lý khác của cơ sở để nhận duyệt. Việc chuyển được ghi nhật ký."
      confirmLabel="Chuyển"
      canSubmit={toId !== '' && reason !== '' && (!needsNote || note.trim() !== '')}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <p className="text-sm text-secondary">
          Người duyệt hiện tại: <b>{state.approver_name ?? 'chưa rõ'}</b>.{' '}
          {reassignReasonText(state.reason)}
        </p>
        <Field
          label="Chuyển cho"
          required
          error={candidates.isError ? errorOf(candidates.error).message : null}
        >
          {(field) => (
            <Select
              id={field.id}
              label="Chuyển cho"
              value={toId}
              onChange={setToId}
              options={people}
              placeholder={candidates.isPending ? 'Đang tải…' : 'Chọn người duyệt…'}
              disabled={candidates.isPending}
              className="w-full"
            />
          )}
        </Field>
        <Field label="Lý do" required>
          {(field) => (
            <Select
              id={field.id}
              label="Lý do"
              value={reason}
              onChange={setReason}
              options={reasonOptions}
              placeholder="Chọn lý do"
              className="w-full"
            />
          )}
        </Field>
        <TextAreaField
          label="Ghi chú"
          required={needsNote}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={3}
        />
      </div>
    </FormDialog>
  );
}
