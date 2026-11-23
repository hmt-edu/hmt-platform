// TS-11 Hoàn thành lịch hẹn (khuôn K08 FormDialog): Kết quả (bắt buộc với Gọi điện, danh mục từ DB), Hẹn lần sau (tuỳ chọn), Ghi chú (tuỳ chọn).
// Luật chặn thật ở app.complete_appointment (migration 628); giao diện chỉ kiểm sớm.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { combineVn } from './appointmentTime';
import { completeErrors, resultRequired, type CompleteDraft } from './completeAppointmentForm';

/** Mã kết quả gợi ý bật «Hẹn lần sau» (nhắc người dùng chọn ngày gọi lại); DB không ép. */
const CALL_BACK = 'HEN_GOI_LAI';

export type CompleteTarget = {
  id: string;
  activityCode: string;
  /** «Gọi điện · Gọi lại hỏi lịch học». */
  label: string;
  /** «Cơ hội CO000121 · 11/10/2026 09:00 · Trần Thu Hà». */
  context: string;
};

export type CompleteArgs = { resultCode: string | null; note: string; nextAt: Date | null };

export function CompleteAppointmentDialog({
  open,
  onOpenChange,
  target,
  resultOptions,
  onComplete,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  target: CompleteTarget | null;
  resultOptions: { value: string; label: string }[];
  onComplete: (id: string, args: CompleteArgs) => Promise<void>;
}) {
  // Mỗi lần mở là một biểu mẫu mới: đổi key theo lịch hẹn đang hoàn thành.
  if (!open || target === null) return null;
  return (
    <Body
      key={target.id}
      onOpenChange={onOpenChange}
      target={target}
      resultOptions={resultOptions}
      onComplete={onComplete}
    />
  );
}

function Body({
  onOpenChange,
  target,
  resultOptions,
  onComplete,
}: {
  onOpenChange: (open: boolean) => void;
  target: CompleteTarget;
  resultOptions: { value: string; label: string }[];
  onComplete: (id: string, args: CompleteArgs) => Promise<void>;
}) {
  const [draft, setDraft] = useState<CompleteDraft>({
    resultCode: '',
    nextDate: null,
    nextTime: '',
    note: '',
  });
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const nextAt = combineVn(draft.nextDate, draft.nextTime);
  const errors = completeErrors(target.activityCode, draft, nextAt, new Date());
  const required = resultRequired(target.activityCode);
  // Nút Hoàn thành mờ tới khi chọn Kết quả (nếu bắt buộc); lỗi ô khác hiện sau khi bấm.
  const canSubmit = !busy && errors.result === undefined && (!show || errors.next === undefined);

  const submit = () => {
    setShow(true);
    if (Object.keys(errors).length > 0) return;
    setBusy(true);
    setError(null);
    onComplete(target.id, {
      resultCode: draft.resultCode === '' ? null : draft.resultCode,
      note: draft.note,
      nextAt,
    })
      .then(() => onOpenChange(false))
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  return (
    <FormDialog
      open
      onOpenChange={(o) => !busy && onOpenChange(o)}
      title="Hoàn thành lịch hẹn"
      subtitle={
        <>
          <span className="block">{target.label}</span>
          <span className="block text-fg-muted">{target.context}</span>
        </>
      }
      confirmLabel="Hoàn thành"
      canSubmit={canSubmit}
      busy={busy}
      error={error}
      onSubmit={submit}
    >
      <OptionalSelect
        label={required ? 'Kết quả *' : 'Kết quả'}
        value={draft.resultCode}
        onChange={(v) => setDraft((d) => ({ ...d, resultCode: v }))}
        options={resultOptions}
        placeholder="Chọn kết quả"
        invalid={show && errors.result !== undefined}
      />
      {show && errors.result && (
        <p className="text-caption text-on-danger-subtle">{errors.result}</p>
      )}
      <div className="grid grid-cols-2 gap-3">
        <DateInput
          label="Hẹn lần sau"
          value={draft.nextDate}
          onChange={(d) => setDraft((s) => ({ ...s, nextDate: d }))}
        />
        <Field label="Giờ">
          {(field) => (
            <input
              {...field}
              type="time"
              value={draft.nextTime}
              onChange={(e) => setDraft((s) => ({ ...s, nextTime: e.target.value }))}
              className={INPUT_CLASS}
            />
          )}
        </Field>
      </div>
      {show && errors.next ? (
        <p className="text-caption text-on-danger-subtle">{errors.next}</p>
      ) : (
        <p className="text-caption text-fg-muted">
          {draft.resultCode === CALL_BACK && draft.nextDate === null ? 'Chọn ngày gọi lại. ' : ''}
          Không bắt buộc. Nếu chọn, hệ thống tự tạo lịch hẹn kế tiếp.
        </p>
      )}
      <TextAreaField
        label="Ghi chú"
        value={draft.note}
        onChange={(e) => setDraft((s) => ({ ...s, note: e.target.value }))}
      />
    </FormDialog>
  );
}
