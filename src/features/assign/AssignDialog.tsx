// TS-05 Giao người phụ trách (khuôn K4 ③ FormDialog): chọn cơ sở rồi chọn nhân sự thuộc cơ sở đó, giao một hoặc nhiều
// bản ghi. Hàm trong cơ sở dữ liệu kiểm quyền Giao việc và cùng cơ sở; hộp chỉ hiện lỗi của hàm.
import { useMemo, useState } from 'react';
import { useAuth } from '../../lib/auth/authContext';
import { toHmtError } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { selectedSummary } from './assignText';
import { useAssignableStaff } from './useAssignableStaff';

export type AssignDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** LEAD, OPPORTUNITY… (hàm list_assignable_staff). */
  entityType: string;
  /** "lead", "cơ hội": dùng trong tiêu đề và dòng mô tả. */
  noun: string;
  /** Mã các bản ghi đã chọn. */
  codes: string[];
  /** Mã cơ sở của các bản ghi đã chọn: cùng một cơ sở thì chọn sẵn cơ sở đó. */
  branchCodes: string[];
  /** Giao thật. Ném lỗi (HmtError) thì hộp hiện câu lỗi. */
  onAssign: (ownerId: string, ownerName: string) => Promise<void>;
};

/** Mỗi lần mở là một biểu mẫu mới (chọn lại từ đầu, chọn sẵn cơ sở nếu rõ). */
export function AssignDialog(props: AssignDialogProps) {
  return props.open ? <AssignForm {...props} /> : null;
}

function AssignForm({
  open,
  onOpenChange,
  entityType,
  noun,
  codes,
  branchCodes,
  onAssign,
}: AssignDialogProps) {
  const { claims } = useAuth();
  const access = useAccess();
  const branchOptions = useMemo(
    () =>
      access.teachingBranches
        .filter((b) => access.seesAllBranches || b.code === claims?.branchCode)
        .map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
    [access.teachingBranches, access.seesAllBranches, claims?.branchCode],
  );
  const [branchId, setBranchId] = useState(() => {
    const codesOnly = [...new Set(branchCodes)];
    const byRows =
      codesOnly.length === 1
        ? access.teachingBranches.find((b) => b.code === codesOnly[0])
        : undefined;
    return byRows?.id ?? (branchOptions.length === 1 ? (branchOptions[0]?.value ?? '') : '');
  });
  const [ownerId, setOwnerId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const staff = useAssignableStaff(entityType, branchId || null, branchId !== '');
  const staffOptions = (staff.data ?? []).map((s) => ({
    value: s.id,
    label:
      s.role_names.length > 0 ? `${s.display_name} · ${s.role_names.join(', ')}` : s.display_name,
  }));
  const staffError = staff.isError ? toHmtError(staff.error).message : null;

  async function submit() {
    const owner = staff.data?.find((s) => s.id === ownerId);
    if (!owner) return;
    setBusy(true);
    setError(null);
    try {
      await onAssign(owner.id, owner.display_name);
      onOpenChange(false);
    } catch (e) {
      setError(toHmtError(e as { message: string }).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Assign ${noun}`}
      subtitle={selectedSummary(noun, codes)}
      confirmLabel="Assign"
      canSubmit={branchId !== '' && ownerId !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <Field label="Cơ sở" required>
          {(field) => (
            <Select
              id={field.id}
              label="Cơ sở"
              value={branchId}
              onChange={(v) => {
                setBranchId(v);
                setOwnerId('');
              }}
              options={branchOptions}
              placeholder="Chọn cơ sở"
              className="w-full"
            />
          )}
        </Field>
        <Field label="Nhân sự phụ trách" required error={staffError}>
          {(field) => (
            <Select
              id={field.id}
              label="Nhân sự phụ trách"
              value={ownerId}
              onChange={setOwnerId}
              options={staffOptions}
              placeholder={
                branchId === ''
                  ? 'Chọn cơ sở trước'
                  : staff.isPending
                    ? 'Đang tải…'
                    : 'Chọn nhân sự'
              }
              disabled={branchId === '' || staff.isPending}
              className="w-full"
            />
          )}
        </Field>
      </div>
    </FormDialog>
  );
}
