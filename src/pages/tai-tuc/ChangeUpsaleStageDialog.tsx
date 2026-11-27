// «Chuyển giai đoạn» của phiếu tái tục (khuôn K4 ③ FormDialog; canvas 9933 TT02_chuyen): chọn giai đoạn mới; L5 Không tái tục bắt buộc lý do từ danh mục.
// Đổi bằng tay giữa mọi giai đoạn L1 đến L8; L7 chọn thêm nhóm con (L8 chỉ có một nhóm con, máy chủ tự đặt). Máy chủ kiểm quyền và luật; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useLeadCatalogs } from '../lead/useCatalogs';
import type { UpsaleTicketDetail } from './upsaleTypes';
import { changeUpsaleStage } from './useUpsaleData';

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
  const [sub, setSub] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const stageOptions = catalogs
    .options('UPSALE_STAGE')
    // L7 giữ lại khi phiếu đang ở L7 để đổi nhóm con.
    .filter((o) => o.value !== ticket.stage_code || o.value === 'L7')
    .map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));
  const lost = to === 'L5';
  const forecast = to === 'L7';
  const subOptions = catalogs
    .options('UPSALE_SUBSTAGE')
    .filter((o) => o.value.startsWith('L7') && o.value !== ticket.substage_code);
  const needsNote = lost && catalogs.requiresNote('RENEWAL_LOST_REASON', reason);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await changeUpsaleStage(
        supabase,
        ticket.id,
        to,
        lost ? reason : null,
        note.trim() || null,
        forecast ? sub : null,
      );
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
      canSubmit={
        to !== '' &&
        (!lost || reason !== '') &&
        (!forecast || sub !== '') &&
        (!needsNote || note.trim() !== '')
      }
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
        {forecast && (
          <Field label="Sub-stage" required>
            {(field) => (
              <Select
                id={field.id}
                label="Sub-stage"
                value={sub}
                onChange={setSub}
                options={subOptions}
                placeholder="Chọn Sub-stage"
                className="w-full"
              />
            )}
          </Field>
        )}
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
