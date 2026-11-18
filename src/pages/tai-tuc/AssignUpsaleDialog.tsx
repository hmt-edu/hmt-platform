// «Giao người phụ trách» của phiếu tái tục (khuôn K4 ③ FormDialog; canvas 9933 TT03_tao, hộp thứ hai): chọn người trong cơ sở của phiếu.
// Máy chủ kiểm quyền Giao việc và cùng cơ sở; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import type { UpsaleRow } from './upsaleTypes';
import { assignUpsale, useUpsaleAssignees } from './useUpsaleData';

type Props = {
  row: UpsaleRow | null;
  onOpenChange: (open: boolean) => void;
  onAssigned: (ownerName: string) => void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function AssignUpsaleDialog(props: Props) {
  return props.row ? <AssignForm {...props} row={props.row} /> : null;
}

function AssignForm({ row, onOpenChange, onAssigned }: Props & { row: UpsaleRow }) {
  const supabase = useDb();
  const people = useUpsaleAssignees(row.id, true);
  const [ownerId, setOwnerId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    const owner = people.data?.find((p) => p.id === ownerId);
    if (!owner) return;
    setBusy(true);
    setError(null);
    try {
      await assignUpsale(supabase, row.id, owner.id);
      onAssigned(owner.name);
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title="Giao người phụ trách"
      subtitle={`${row.code} · ${row.student_name} · ${row.class_code}`}
      confirmLabel="Giao"
      cancelLabel="Đóng"
      canSubmit={ownerId !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <Field
        label="Người phụ trách"
        required
        error={people.isError ? errorOf(people.error).message : null}
      >
        {(field) => (
          <Select
            id={field.id}
            label="Người phụ trách"
            value={ownerId}
            onChange={setOwnerId}
            options={(people.data ?? []).map((p) => ({ value: p.id, label: p.name }))}
            placeholder={people.isPending ? 'Đang tải…' : 'Chọn người'}
            disabled={people.isPending}
            className="w-full"
          />
        )}
      </Field>
    </FormDialog>
  );
}
