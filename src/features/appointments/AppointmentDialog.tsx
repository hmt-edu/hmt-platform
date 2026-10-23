// TS-13 Tạo và Dời lịch hẹn (khuôn K4 ③ FormDialog). Tạo: gắn cố định với hồ sơ đang mở (ô tìm hồ sơ khác làm cùng màn
// Lịch hẹn). Dời (R-CRM-38): giờ mới, người phụ trách (chỉ đổi được khi có quyền Giao việc), ghi chú.
import { useState, type ReactNode } from 'react';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { useAuth } from '../../lib/auth/authContext';
import { cn } from '../../ui/cn';
import { FormDialog } from '../../ui/Dialogs';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useAssignableStaff } from '../assign/useAssignableStaff';
import { QUICK_HOURS, combineVn, parseTime, pickActivity, quickDays } from './appointmentTime';

type Option = { value: string; label: string };

export type AppointmentTarget = {
  /** "LD000227 · Chị Lê Thu Hằng · Lê Gia Huy" (ô Gắn với, chỉ đọc). */
  label: string;
  branchId: string;
};

export type AppointmentToReschedule = {
  id: string;
  /** "Gọi điện · Gọi lại hỏi lịch học". */
  label: string;
  scheduledAt: string;
  ownerId: string;
  ownerName: string | null;
  branchId: string;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Hồ sơ gắn cố định; `null` khi dùng `targetPicker` mà chưa chọn. */
  target: AppointmentTarget | null;
  /** Có thì ô "Gắn với" là ô chọn này (tạo từ màn Lịch hẹn), thay cho ô chỉ đọc. */
  targetPicker?: ReactNode | undefined;
  activityOptions: Option[];
  /** Có thì là hộp Dời lịch hẹn, không có là hộp Tạo. */
  reschedule?: AppointmentToReschedule | undefined;
  /** Tạo: gọi create_appointment. Ném lỗi (HmtError) thì hộp hiện câu lỗi. */
  onCreate: (args: {
    activityCode: string;
    scheduledAt: Date;
    note: string;
    ownerId: string | null;
  }) => Promise<void>;
  onReschedule: (args: {
    id: string;
    scheduledAt: Date;
    ownerId: string | null;
    note: string;
  }) => Promise<void>;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function AppointmentDialog(props: Props) {
  return props.open ? <AppointmentForm {...props} /> : null;
}

function Chips({
  label,
  items,
  selected,
  onPick,
}: {
  label: string;
  items: { key: string; label: string }[];
  selected: string | null;
  onPick: (key: string) => void;
}) {
  return (
    <div role="group" aria-label={label} className="flex flex-col gap-1">
      <span className="text-caption font-semibold text-fg-label">{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {items.map((item) => (
          <button
            key={item.key}
            type="button"
            aria-pressed={selected === item.key}
            onClick={() => onPick(item.key)}
            className={cn(
              'focus-ring tap h-control-sm rounded-full border px-3 text-caption font-medium',
              selected === item.key
                ? 'border-brand-300 bg-brand-100 text-brand-800'
                : 'border-border-strong bg-surface hover:bg-hover',
            )}
          >
            {item.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function AppointmentForm({
  onOpenChange,
  target,
  targetPicker,
  activityOptions,
  reschedule,
  onCreate,
  onReschedule,
}: Props) {
  const { claims } = useAuth();
  const access = useAccess();
  const rescheduling = reschedule !== undefined;
  const canAssign = access.can('APPOINTMENT', 'GIAO_VIEC');
  const branchId = reschedule?.branchId ?? target?.branchId ?? null;
  const staff = useAssignableStaff('APPOINTMENT', branchId, canAssign && branchId !== null);

  // Loại hoạt động: người dùng chưa chọn thì lấy mục đầu của danh mục ĐANG có. Danh mục có thể tải sau khi hộp đã mở, nên không
  // chốt mặc định lúc mở (lỗi cũ: mở hộp trước khi danh mục tải xong thì ô trống mãi, nút Tạo không bao giờ sáng).
  const [chosenActivity, setActivity] = useState('');
  const activity = pickActivity(chosenActivity, activityOptions);
  const [date, setDate] = useState<Date | null>(null);
  const [time, setTime] = useState('');
  const [ownerId, setOwnerId] = useState(reschedule?.ownerId ?? claims?.userId ?? '');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const days = quickDays();
  const pickedDay = days.find((d) => date && d.date.getTime() === date.getTime())?.label ?? null;
  const when = combineVn(date, time);
  const staffOptions: Option[] = (staff.data ?? []).map((s) => ({
    value: s.id,
    label: s.display_name,
  }));
  // Người phụ trách hiện tại luôn có mặt trong ô chọn (kể cả khi danh sách chưa tải xong).
  const withCurrent =
    reschedule && !staffOptions.some((o) => o.value === reschedule.ownerId)
      ? [
          { value: reschedule.ownerId, label: reschedule.ownerName ?? 'Người phụ trách hiện tại' },
          ...staffOptions,
        ]
      : staffOptions;

  const canSubmit = when !== null && (rescheduling || (activity !== '' && target !== null));

  async function submit() {
    if (!when) return;
    setBusy(true);
    setError(null);
    try {
      if (reschedule) {
        await onReschedule({
          id: reschedule.id,
          scheduledAt: when,
          ownerId: canAssign && ownerId !== reschedule.ownerId ? ownerId : null,
          note,
        });
      } else {
        await onCreate({
          activityCode: activity,
          scheduledAt: when,
          note,
          ownerId: canAssign && ownerId !== claims?.userId ? ownerId : null,
        });
      }
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
      title={rescheduling ? 'Dời lịch hẹn' : 'Tạo lịch hẹn'}
      subtitle={rescheduling ? `${reschedule.label} · ${target?.label ?? ''}` : undefined}
      confirmLabel={rescheduling ? 'Dời lịch' : 'Tạo lịch hẹn'}
      canSubmit={canSubmit}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        {rescheduling ? (
          <div className="flex items-center justify-between rounded-control bg-surface-subtle px-3 py-2.5">
            <span className="text-fg-muted">Lịch hiện tại</span>
            <b className="tabular">{formatDateTime(reschedule.scheduledAt)}</b>
          </div>
        ) : (
          <>
            <Field label="Loại hoạt động" required>
              {(field) => (
                <Select
                  id={field.id}
                  label="Loại hoạt động"
                  value={activity}
                  onChange={setActivity}
                  options={activityOptions}
                  className="w-full"
                />
              )}
            </Field>
            {targetPicker ?? (
              <Field
                label="Gắn với"
                required
                help="Bắt buộc: lịch hẹn phải gắn với 1 đối tượng. Tạo từ trang Lead thì tự điền và khoá."
              >
                {(field) => (
                  <input {...field} readOnly value={target?.label ?? ''} className={INPUT_CLASS} />
                )}
              </Field>
            )}
          </>
        )}
        <div className="grid grid-cols-2 gap-3">
          <DateInput
            label={rescheduling ? 'Ngày mới' : 'Ngày'}
            required
            value={date}
            onChange={setDate}
          />
          <Field label={rescheduling ? 'Giờ mới' : 'Giờ'} required>
            {(field) => (
              <input
                {...field}
                type="time"
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className={INPUT_CLASS}
              />
            )}
          </Field>
        </div>
        <Chips
          label="Chọn nhanh ngày"
          items={days.map((d) => ({ key: d.label, label: d.label }))}
          selected={pickedDay}
          onPick={(key) => setDate(days.find((d) => d.label === key)?.date ?? null)}
        />
        <Chips
          label="Chọn nhanh giờ"
          items={QUICK_HOURS.map((h) => ({ key: h, label: h }))}
          selected={parseTime(time) !== null ? time : null}
          onPick={setTime}
        />
        <Field label="Người phụ trách" required>
          {(field) =>
            canAssign ? (
              <Select
                id={field.id}
                label="Người phụ trách"
                value={ownerId}
                onChange={setOwnerId}
                options={withCurrent}
                placeholder={staff.isPending ? 'Đang tải…' : 'Chọn nhân sự'}
                className="w-full"
              />
            ) : (
              <input
                {...field}
                readOnly
                value={reschedule ? (reschedule.ownerName ?? '') : 'Bạn'}
                className={INPUT_CLASS}
              />
            )
          }
        </Field>
        <TextAreaField
          label="Ghi chú"
          placeholder={rescheduling ? 'Không bắt buộc' : 'Ví dụ: Gọi lại hỏi lịch học'}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
