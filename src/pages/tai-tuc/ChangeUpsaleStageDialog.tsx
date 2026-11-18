// «Chuyển giai đoạn» của phiếu tái tục (khuôn K4 ③ FormDialog; canvas 9933 TT02_chuyen): chọn giai đoạn mới; L5 Không tái tục bắt buộc lý do từ danh mục.
// L7, L8 do hệ thống đặt khi có báo giá, đơn nên không có trong danh sách. Máy chủ kiểm quyền và luật; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useLeadCatalogs } from '../lead/useCatalogs';
import type { UpsaleTicketDetail } from './upsaleTypes';
import { changeUpsaleStage } from './useUpsaleData';

const MANUAL_STAGES = ['L1', 'L2', 'L3', 'L4', 'L5', 'L6'];

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  ticket: UpsaleTicketDetail;
  onDone: () => Promise<void> | void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function ChangeUpsaleStageDialog(props: Props) {
  return props.open ? <ChangeForm {...props} /> : null;
}

function ChangeForm({ open, onOpenChange, ticket, onDone }: Props) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const [to, setTo] = useState('');
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const stageOptions = catalogs
    .options('UPSALE_STAGE')
    .filter((o) => MANUAL_STAGES.includes(o.value) && o.value !== ticket.stage_code)
    .map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));
  const lost = to === 'L5';
  const needsNote = lost && catalogs.requiresNote('RENEWAL_LOST_REASON', reason);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await changeUpsaleStage(supabase, ticket.id, to, lost ? reason : null, note.trim() || null);
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
      title="Chuyển giai đoạn"
      subtitle={`${ticket.code} · ${ticket.student_name} · ${ticket.class_code}`}
      confirmLabel="Chuyển"
      cancelLabel="Đóng"
      canSubmit={to !== '' && (!lost || reason !== '') && (!needsNote || note.trim() !== '')}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <Field label="Giai đoạn mới" required>
          {(field) => (
            <Select
              id={field.id}
              label="Giai đoạn mới"
              value={to}
              onChange={setTo}
              options={stageOptions}
              placeholder="Chọn giai đoạn"
              className="w-full"
            />
          )}
        </Field>
        {lost && (
          <Field label="Lý do không tái tục" required>
            {(field) => (
              <Select
                id={field.id}
                label="Lý do không tái tục"
                value={reason}
                onChange={setReason}
                options={catalogs.options('RENEWAL_LOST_REASON')}
                placeholder="Chọn lý do"
                className="w-full"
              />
            )}
          </Field>
        )}
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
