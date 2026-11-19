// Hộp thoại tạo phiếu Đổi lịch học từ ticket (CS-11, K08, CSN-06e): dời một buổi hoặc đổi ca cố định. Dữ liệu gửi app.create_ticket_task; luật chặn thật ở DB.
import { useState } from 'react';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { formatDate } from '../../lib/format';
import {
  buildSchedulePayload,
  EMPTY_SCHEDULE_DRAFT,
  SCHEDULE_ACTIONS,
  sessionLabel,
  validateScheduleDraft,
  type ScheduleAction,
  type ScheduleDraft,
  type ScheduleSession,
} from './scheduleTaskForm';
import { useTaskOptions } from './useTaskCreate';

export function ScheduleTaskDialog({
  ticketId,
  ticketCode,
  hasStudent,
  open,
  onOpenChange,
  busy,
  error,
  onCreate,
}: {
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
  const [draft, setDraft] = useState<ScheduleDraft>(EMPTY_SCHEDULE_DRAFT);
  const [show, setShow] = useState(false);
  const set = (patch: Partial<ScheduleDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const errors = show ? validateScheduleDraft(draft, hasStudent) : {};
  const sessions = (options.data?.sessions ?? []) as ScheduleSession[];
<<<<<<< HEAD
  const classes = [
    ...new Map(
      (options.data?.enrollments ?? [])
        .filter((x) => x.class_id !== null && x.class_code !== null)
        .map((x) => [x.class_id as string, x.class_code as string] as const),
    ),
  ];
=======
>>>>>>> origin/main

  const submit = () => {
    setShow(true);
    if (Object.keys(validateScheduleDraft(draft, hasStudent)).length > 0) return;
    onCreate(draft.reason.trim(), buildSchedulePayload(draft));
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setDraft(EMPTY_SCHEDULE_DRAFT);
          setShow(false);
        }
        onOpenChange(o);
      }}
      title="Tạo phiếu Đổi lịch học"
      subtitle={ticketCode}
      confirmLabel="Tạo phiếu"
      canSubmit={!show || Object.keys(errors).length === 0}
      busy={busy || options.isLoading}
      error={error ?? (options.error ? 'Không tải được dữ liệu biểu mẫu. Thử lại sau.' : null)}
      onSubmit={submit}
    >
      <OptionalSelect
        label="Hình thức"
        value={draft.action}
        onChange={(v) => set({ action: v as ScheduleAction })}
        options={SCHEDULE_ACTIONS.map((a) => ({ value: a.value, label: a.label }))}
        placeholder="Chọn hình thức"
      />
<<<<<<< HEAD
      {draft.action === 'DOI_CA' ? (
        <p className="text-caption text-fg-muted">
          Đổi ca cố định là sửa thời khoá biểu của lớp ở màn Sửa lớp (áp dụng từ một ngày). Phiếu
          này chỉ ghi nhận việc đổi ca; sau khi duyệt, mở màn Sửa lớp để đổi thật.
        </p>
      ) : (
        <>
          {draft.action === 'DOI_BUOI' ? (
            <>
              <OptionalSelect
                label="Buổi cần dời"
                value={draft.sessionId}
                onChange={(v) => set({ sessionId: v })}
                options={sessions.map((s) => ({ value: s.id, label: sessionLabel(s, formatDate) }))}
                placeholder="Chọn buổi"
                invalid={errors.sessionId !== undefined}
              />
              {errors.sessionId && (
                <p className="text-caption text-on-danger-subtle">{errors.sessionId}</p>
              )}
            </>
          ) : (
            <>
              <OptionalSelect
                label="Lớp học bù"
                value={draft.classId}
                onChange={(v) => set({ classId: v })}
                options={classes.map(([value, label]) => ({ value, label }))}
                placeholder="Chọn lớp"
                invalid={errors.classId !== undefined}
              />
              {errors.classId && (
                <p className="text-caption text-on-danger-subtle">{errors.classId}</p>
              )}
            </>
          )}
          <TextField
            label={draft.action === 'HOC_BU' ? 'Ngày học bù' : 'Ngày mới'}
=======
      {draft.action === 'DOI_BUOI' ? (
        <>
          <OptionalSelect
            label="Buổi cần dời"
            value={draft.sessionId}
            onChange={(v) => set({ sessionId: v })}
            options={sessions.map((s) => ({ value: s.id, label: sessionLabel(s, formatDate) }))}
            placeholder="Chọn buổi"
            invalid={errors.sessionId !== undefined}
          />
          {errors.sessionId && (
            <p className="text-caption text-on-danger-subtle">{errors.sessionId}</p>
          )}
          <TextField
            label="Ngày mới"
>>>>>>> origin/main
            required
            type="date"
            value={draft.date}
            error={errors.date ?? null}
            onChange={(e) => set({ date: e.target.value })}
          />
          <TextField
            label="Giờ bắt đầu mới"
            required
            type="time"
            value={draft.start}
            error={errors.start ?? null}
            onChange={(e) => set({ start: e.target.value })}
          />
          <TextField
            label="Giờ kết thúc mới"
            required
            type="time"
            value={draft.end}
            error={errors.end ?? null}
            onChange={(e) => set({ end: e.target.value })}
          />
          <p className="text-caption text-fg-muted">
<<<<<<< HEAD
            {draft.action === 'DOI_BUOI'
              ? 'Dời một buổi chưa diễn ra của lớp; trùng phòng hoặc giáo viên chỉ cảnh báo, không chặn.'
              : 'Học bù không trừ giờ. Quản lý cơ sở duyệt xong thì hệ thống sinh một buổi loại Học bù mới cho em (không chọn buổi có sẵn).'}
          </p>
        </>
=======
            Dời một buổi chưa diễn ra của lớp; trùng phòng hoặc giáo viên chỉ cảnh báo, không chặn.
          </p>
        </>
      ) : (
        <p className="text-caption text-fg-muted">
          Đổi ca cố định là sửa thời khoá biểu của lớp ở màn Sửa lớp (áp dụng từ một ngày). Phiếu
          này chỉ ghi nhận việc đổi ca; sau khi duyệt, mở màn Sửa lớp để đổi thật.
        </p>
>>>>>>> origin/main
      )}
      <TextAreaField
        label="Lý do"
        required
        value={draft.reason}
        error={errors.reason ?? null}
        onChange={(e) => set({ reason: e.target.value })}
      />
      <p className="text-caption text-fg-muted">
<<<<<<< HEAD
        Phiếu tạo ở bước Nháp; trình duyệt ở màn Phiếu nghiệp vụ.
=======
        Phiếu tạo ở bước Nháp; trình duyệt ở màn Phiếu nghiệp vụ. Học bù tạo ở màn Yêu cầu buổi.
>>>>>>> origin/main
      </p>
    </FormDialog>
  );
}
