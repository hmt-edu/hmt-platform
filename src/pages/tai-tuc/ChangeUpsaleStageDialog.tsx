// «Chuyển giai đoạn» của phiếu tái tục (khuôn K4 ③ FormDialog; canvas 9933 TT02_chuyen): chọn giai đoạn mới và giai đoạn con (bắt buộc, trừ L8).
// Đổi bằng tay giữa mọi giai đoạn L1 đến L8; ở L5 giai đoạn con chính là lý do không tái tục; giai đoạn con của L8 do hệ thống đặt theo đơn. Máy chủ kiểm quyền và luật; hộp chỉ hiện lỗi của hàm.
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
  const [sub, setSub] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Giữ cả giai đoạn đang đứng để đổi giai đoạn con; L8 không chọn tay giai đoạn con nên đang ở L8 thì không liệt kê.
  const stageOptions = catalogs
    .options('UPSALE_STAGE')
    .filter((o) => !(o.value === 'L8' && ticket.stage_code === 'L8'))
    .map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));
  const subOptions = catalogs
    .childrenOf('UPSALE_SUBSTAGE', 'UPSALE_STAGE', to || null)
    .filter((o) => o.value !== ticket.substage_code)
    .map((o) => ({ value: o.value, label: `${o.value} ${o.label}` }));

  const choosesSub = to !== '' && to !== 'L8';

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await changeUpsaleStage(
        supabase,
        ticket.id,
        to,
        null,
        note.trim() || null,
        choosesSub ? sub : null,
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
      canSubmit={to !== '' && (!choosesSub || sub !== '')}
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
              onChange={(value) => {
                setTo(value);
                setSub('');
              }}
              options={stageOptions}
              placeholder="Chọn giai đoạn"
              className="w-full"
            />
          )}
        </Field>
        {choosesSub && (
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
        <TextAreaField
          label="Ghi chú"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={3}
        />
      </div>
    </FormDialog>
  );
}
