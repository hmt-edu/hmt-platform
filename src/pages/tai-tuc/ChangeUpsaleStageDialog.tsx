// Hộp chuyển giai đoạn của phiếu tái tục, mở khi bấm một giai đoạn trên thanh (khuôn K4 ③ FormDialog, cùng cách với Cơ hội): chọn Sub-stage (bắt buộc, trừ L8), ghi chú tuỳ chọn.
// Đổi bằng tay giữa mọi giai đoạn L1 đến L8; ở L5 giai đoạn con chính là lý do không tái tục; giai đoạn con của L8 do hệ thống đặt theo đơn. Máy chủ kiểm quyền và luật; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { codeAndName } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import type { UpsaleTicketDetail } from './upsaleTypes';
import { changeUpsaleStage } from './useUpsaleData';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  ticket: UpsaleTicketDetail;
  /** Giai đoạn vừa bấm trên thanh. */
  target: string;
  onDone: () => Promise<void> | void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function ChangeUpsaleStageDialog(props: Props) {
  return props.open ? <ChangeForm {...props} /> : null;
}

function ChangeForm({ open, onOpenChange, ticket, target, onDone }: Props) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const [sub, setSub] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const subOptions = catalogs
    .childrenOf('UPSALE_SUBSTAGE', 'UPSALE_STAGE', target)
    .map((o) => ({ value: o.value, label: codeAndName(o.value, o.label) }));

  const choosesSub = target !== 'L8';

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await changeUpsaleStage(
        supabase,
        ticket.id,
        target,
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
      title={`Chuyển sang ${codeAndName(target, catalogs.name('UPSALE_STAGE', target))}`}
      subtitle={`${ticket.code} · ${ticket.student_name} · ${ticket.class_code}`}
      confirmLabel="Chuyển giai đoạn"
      cancelLabel="Đóng"
      canSubmit={!choosesSub || sub !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
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
