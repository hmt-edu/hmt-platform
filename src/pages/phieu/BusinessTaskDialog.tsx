// Hộp thoại tạo phiếu Bảo lưu hoặc Chuyển lớp từ chi tiết ticket (CSN-06a, CSN-06b). Dữ liệu gửi app.create_ticket_task; luật chặn thật ở DB.
import { useState } from 'react';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { formatDate } from '../../lib/format';
import {
  buildBusinessPayload,
  classChoices,
  EMPTY_BUSINESS_DRAFT,
  TRANSFER_KINDS,
  validateBusinessDraft,
  type BusinessDraft,
} from './businessTaskForm';
import { TASK_TYPE_LABEL } from './taskLabels';
import { useTaskOptions } from './useTaskCreate';

export function BusinessTaskDialog({
  type,
  ticketId,
  ticketCode,
  hasStudent,
  open,
  onOpenChange,
  busy,
  error,
  onCreate,
}: {
  type: 'BAO_LUU' | 'CHUYEN_LOP';
  ticketId: string;
  ticketCode: string;
  hasStudent: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  busy: boolean;
  error: string | null;
  onCreate: (reason: string, payload: unknown) => void;
}) {
  const options = useTaskOptions(ticketId, open && hasStudent);
  const [draft, setDraft] = useState<BusinessDraft>(EMPTY_BUSINESS_DRAFT);
  const [show, setShow] = useState(false);
  const set = (patch: Partial<BusinessDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const errors = show ? validateBusinessDraft(type, draft, hasStudent) : {};
  const data = options.data;
  const reasons = (type === 'BAO_LUU' ? data?.hold_reasons : data?.transfer_reasons) ?? [];
  const enrollment = data?.enrollments.find((x) => x.id === draft.enrollmentId);
  const classes = data ? classChoices(data, draft.enrollmentId) : [];
  const newClass = classes.find((c) => c.id === draft.toClassId);

  const submit = () => {
    setShow(true);
    if (Object.keys(validateBusinessDraft(type, draft, hasStudent)).length > 0) return;
    onCreate(draft.reason.trim(), buildBusinessPayload(type, draft));
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setDraft(EMPTY_BUSINESS_DRAFT);
          setShow(false);
        }
        onOpenChange(o);
      }}
      title={`Tạo phiếu ${TASK_TYPE_LABEL[type] ?? type}`}
      subtitle={ticketCode}
      confirmLabel="Tạo phiếu"
      canSubmit={!show || Object.keys(errors).length === 0}
      busy={busy || options.isLoading}
      error={error ?? (options.error ? 'Không tải được dữ liệu biểu mẫu. Thử lại sau.' : null)}
      onSubmit={submit}
    >
      <OptionalSelect
        label="Ghi danh"
        value={draft.enrollmentId}
        onChange={(v) => set({ enrollmentId: v, toClassId: '', startDate: '' })}
        options={(data?.enrollments ?? []).map((x) => ({
          value: x.id,
          label: `${x.code}${x.class_code ? ` · ${x.class_code}` : ''}`,
        }))}
        placeholder="Chọn ghi danh"
        invalid={errors.enrollmentId !== undefined}
      />
      {errors.enrollmentId && (
        <p className="text-caption text-on-danger-subtle">{errors.enrollmentId}</p>
      )}
      {enrollment && (
        <p className="text-caption text-fg-muted">
          Giờ còn lại: {enrollment.remaining_hours} giờ
          {type === 'CHUYEN_LOP' &&
            ' · Chuyển lớp không đổi số giờ, giờ đã mua đi theo ghi danh sang lớp mới.'}
        </p>
      )}
      <OptionalSelect
        label="Lý do (danh mục)"
        value={draft.reasonCode}
        onChange={(v) => set({ reasonCode: v })}
        options={reasons.map((r) => ({ value: r.code, label: r.name }))}
        placeholder="Chọn lý do"
        invalid={errors.reasonCode !== undefined}
      />
      {errors.reasonCode && (
        <p className="text-caption text-on-danger-subtle">{errors.reasonCode}</p>
      )}
      {type === 'BAO_LUU' ? (
        <TextField
          label="Số tháng bảo lưu"
          required
          inputMode="numeric"
          value={draft.months}
          error={errors.months ?? null}
          onChange={(e) => set({ months: e.target.value })}
        />
      ) : (
        <>
          <OptionalSelect
            label="Loại chuyển"
            value={draft.kindCode}
            onChange={(v) => set({ kindCode: v })}
            options={TRANSFER_KINDS.map((k) => ({ value: k.value, label: k.label }))}
            placeholder="Chọn loại chuyển"
            invalid={errors.kindCode !== undefined}
          />
          {errors.kindCode && (
            <p className="text-caption text-on-danger-subtle">{errors.kindCode}</p>
          )}
          <OptionalSelect
            label="Lớp mới"
            value={draft.toClassId}
            onChange={(v) => set({ toClassId: v, startDate: '' })}
            options={classes.map((c) => ({ value: c.id, label: c.code }))}
            placeholder="Chọn lớp"
            disabled={draft.enrollmentId === ''}
            invalid={errors.toClassId !== undefined}
          />
          {errors.toClassId && (
            <p className="text-caption text-on-danger-subtle">{errors.toClassId}</p>
          )}
          <OptionalSelect
            label="Hiệu lực từ buổi"
            value={draft.startDate}
            onChange={(v) => set({ startDate: v })}
            options={(newClass?.upcoming ?? []).map((u) => ({
              value: u.date,
              label: `Buổi ${u.session_no} · ${formatDate(u.date)}`,
            }))}
            placeholder="Chọn buổi"
            disabled={newClass === undefined}
            invalid={errors.startDate !== undefined}
          />
          {errors.startDate && (
            <p className="text-caption text-on-danger-subtle">{errors.startDate}</p>
          )}
        </>
      )}
      <TextAreaField
        label="Lý do"
        required
        value={draft.reason}
        error={errors.reason ?? null}
        onChange={(e) => set({ reason: e.target.value })}
      />
      <p className="text-caption text-fg-muted">
        Phiếu tạo ở bước Nháp; trình duyệt ở màn Phiếu nghiệp vụ.
      </p>
    </FormDialog>
  );
}
