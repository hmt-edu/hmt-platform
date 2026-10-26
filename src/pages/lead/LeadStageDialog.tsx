// Hộp chọn nhóm con khi lead đổi sang giai đoạn có nhóm con (R-CRM-41, QĐ-Đ183): cùng khuôn hộp chuyển giai đoạn của cơ hội
// (FormDialog + ô Sub-stage bắt buộc). Dùng ở trang Lead và Kanban. Hàm DB `change_lead_stage` kiểm lại luật.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { codeAndName } from './leadFormat';

type Option = { value: string; label: string };

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** "LD000123 · Chị Lan · đang ở C1 Data mới". */
  subtitle: string;
  /** "C4 Khách hàng tiềm năng". */
  stageLabel: string;
  stageCode: string;
  options: Option[];
  onSubmit: (substage: string) => Promise<void>;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function LeadStageDialog(props: Props) {
  return props.open ? <Form {...props} /> : null;
}

function Form({ onOpenChange, subtitle, stageLabel, stageCode, options, onSubmit }: Props) {
  const [substage, setSubstage] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await onSubmit(substage);
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
      title={`Chuyển sang ${stageLabel}`}
      subtitle={subtitle}
      confirmLabel="Chuyển giai đoạn"
      canSubmit={substage !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <Field label="Sub-stage" required help={`Bắt buộc chọn khi chuyển sang ${stageCode}.`}>
        {(field) => (
          <Select
            id={field.id}
            label="Sub-stage"
            value={substage}
            onChange={setSubstage}
            options={options.map((o) => ({
              value: o.value,
              label: codeAndName(o.value, o.label),
            }))}
            placeholder={`Chọn sub-stage ${stageCode}…`}
            className="w-full"
          />
        )}
      </Field>
    </FormDialog>
  );
}
