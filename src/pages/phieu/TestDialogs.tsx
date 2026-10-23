// Các hộp thoại của trang Phiếu kiểm tra (TS-17): Nhập kết quả (R-CRM-10, 11), lý do bằng chữ (lùi từ Hoàn thành về Nháp R-CRM-21,
// mở lại phiếu huỷ R-CRM-10), Đổi lịch (chỉ phiếu Nháp, R-CRM-05). Mỗi lần mở là một biểu mẫu mới (thân dựng khi mở).
import { useState } from 'react';
import { Chips } from '../../features/appointments/Chips';
import {
  QUICK_HOURS,
  combineVn,
  parseTime,
  quickDays,
} from '../../features/appointments/appointmentTime';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { FormDialog } from '../../ui/Dialogs';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { formatScore, parseScore } from './testLogic';
import type { TestRecord } from './testTypes';
import type { PickRow } from './useTestData';

const NONE = '__none';

// ---------------------------------------------------------------------------
// Nhập kết quả: điểm 0–10 (một chữ số thập phân), nhận xét, trình độ đề xuất, phân loại đề xuất, giáo viên chấm.
// Người phụ trách nhập thay giáo viên thì lịch sử ghi "nhập thay" (R-CRM-11, do hàm DB quyết định).
// ---------------------------------------------------------------------------
export type ResultSubmit = {
  score: number;
  note: string;
  levelCode: string | null;
  frameworkCode: string | null;
  graderId: string | null;
};

export function ResultDialog(props: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  record: TestRecord;
  catalogs: LeadCatalogs;
  graders: PickRow[];
  onSubmit: (data: ResultSubmit) => Promise<void>;
}) {
  return props.open ? <ResultForm {...props} /> : null;
}

function ResultForm({
  onOpenChange,
  record,
  catalogs,
  graders,
  onSubmit,
}: {
  onOpenChange: (open: boolean) => void;
  record: TestRecord;
  catalogs: LeadCatalogs;
  graders: PickRow[];
  onSubmit: (data: ResultSubmit) => Promise<void>;
}) {
  const [score, setScore] = useState(
    record.score === null ? '' : String(record.score).replace('.', ','),
  );
  const [note, setNote] = useState(record.result_note ?? '');
  const [level, setLevel] = useState(record.suggested_level_code ?? NONE);
  const [framework, setFramework] = useState(record.suggested_framework_code ?? NONE);
  const [grader, setGrader] = useState(record.grader_id ?? NONE);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const parsed = parseScore(score);
  const scoreError =
    score.trim() !== '' && parsed === null
      ? 'Điểm từ 0 đến 10, một chữ số thập phân (ví dụ 7,5).'
      : null;
  const graderOptions = [
    ...(record.grader_id && !graders.some((g) => g.id === record.grader_id)
      ? [{ value: record.grader_id, label: record.grader_name ?? 'Giáo viên hiện tại' }]
      : []),
    ...graders.map((g) => ({ value: g.id, label: g.name })),
  ];

  async function submit() {
    if (parsed === null) return;
    setBusy(true);
    setError(null);
    try {
      await onSubmit({
        score: parsed,
        note,
        levelCode: level === NONE ? null : level,
        frameworkCode: framework === NONE ? null : framework,
        graderId: grader === NONE ? null : grader,
      });
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
      title="Nhập kết quả"
      subtitle={`${record.code} · ${record.student_name}`}
      confirmLabel="Lưu kết quả"
      canSubmit={parsed !== null && note.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-3">
          <Field label="Điểm (0–10)" required error={scoreError}>
            {(field) => (
              <input
                {...field}
                inputMode="decimal"
                value={score}
                placeholder="7,5"
                onChange={(e) => setScore(e.target.value)}
                className={INPUT_CLASS}
              />
            )}
          </Field>
          <Field
            label="Giáo viên chấm"
            help="Chọn khi chưa có; để Hoàn thành phiếu phải có giáo viên chấm."
          >
            {(field) => (
              <Select
                id={field.id}
                label="Giáo viên chấm"
                value={grader}
                onChange={setGrader}
                options={[{ value: NONE, label: 'Chưa chọn' }, ...graderOptions]}
                className="w-full"
              />
            )}
          </Field>
          <Field label="Trình độ đề xuất">
            {(field) => (
              <Select
                id={field.id}
                label="Trình độ đề xuất"
                value={level}
                onChange={setLevel}
                options={[{ value: NONE, label: 'Chưa chọn' }, ...catalogs.options('LEVEL')]}
                className="w-full"
              />
            )}
          </Field>
          <Field label="Phân loại đề xuất">
            {(field) => (
              <Select
                id={field.id}
                label="Phân loại đề xuất"
                value={framework}
                onChange={setFramework}
                options={[
                  { value: NONE, label: 'Chưa chọn' },
                  ...catalogs.options('FRAMEWORK_LEVEL'),
                ]}
                className="w-full"
              />
            )}
          </Field>
        </div>
        <TextAreaField
          label="Nhận xét"
          required
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Ví dụ: Nắm chắc phần Đại số, yếu phần Hình."
          help="Bắt buộc. Người phụ trách nhập thay giáo viên thì lịch sử ghi rõ 'nhập thay'."
        />
        {record.score !== null && (
          <p className="text-caption text-fg-muted">
            Kết quả hiện tại: {formatScore(record.score)}. Lưu sẽ ghi lịch sử mỗi ô đổi.
          </p>
        )}
      </div>
    </FormDialog>
  );
}

// ---------------------------------------------------------------------------
// Lý do bằng chữ: lùi từ Hoàn thành về Nháp (bắt buộc, R-CRM-21), mở lại phiếu huỷ về Nháp (bắt buộc, R-CRM-10).
// ---------------------------------------------------------------------------
export function TextReasonDialog(props: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  subtitle: string;
  hint: string;
  confirmLabel: string;
  onSubmit: (reason: string) => Promise<void>;
}) {
  return props.open ? <TextReasonForm {...props} /> : null;
}

function TextReasonForm({
  onOpenChange,
  title,
  subtitle,
  hint,
  confirmLabel,
  onSubmit,
}: {
  onOpenChange: (open: boolean) => void;
  title: string;
  subtitle: string;
  hint: string;
  confirmLabel: string;
  onSubmit: (reason: string) => Promise<void>;
}) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await onSubmit(reason.trim());
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
      title={title}
      subtitle={subtitle}
      confirmLabel={confirmLabel}
      canSubmit={reason.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <TextAreaField
        label="Lý do"
        required
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Ví dụ: Nhập nhầm điểm, cần chấm lại."
        help={hint}
      />
    </FormDialog>
  );
}

// ---------------------------------------------------------------------------
// Đổi lịch (chỉ phiếu Nháp): giờ test mới ở tương lai; lịch hẹn nhắc đổi theo nếu chưa ai sửa tay (R-CRM-05).
// ---------------------------------------------------------------------------
export function RescheduleTestDialog(props: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  record: TestRecord;
  onSubmit: (at: Date) => Promise<void>;
}) {
  return props.open ? <RescheduleForm {...props} /> : null;
}

function RescheduleForm({
  onOpenChange,
  record,
  onSubmit,
}: {
  onOpenChange: (open: boolean) => void;
  record: TestRecord;
  onSubmit: (at: Date) => Promise<void>;
}) {
  const [date, setDate] = useState<Date | null>(null);
  const [time, setTime] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const days = quickDays();
  const pickedDay = days.find((d) => date && d.date.getTime() === date.getTime())?.label ?? null;
  const when = combineVn(date, time);

  async function submit() {
    if (!when) return;
    setBusy(true);
    setError(null);
    try {
      await onSubmit(when);
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
      title="Đổi lịch test"
      subtitle={`${record.code} · ${record.student_name}`}
      confirmLabel="Đổi lịch"
      canSubmit={when !== null}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between rounded-control bg-surface-subtle px-3 py-2.5">
          <span className="text-fg-muted">Lịch hiện tại</span>
          <b className="tabular">{formatDateTime(record.scheduled_at)}</b>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <DateInput label="Ngày mới" required value={date} onChange={setDate} />
          <Field label="Giờ mới" required>
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
        <p className="text-caption text-fg-muted">
          Giờ test mới phải ở tương lai. Lịch hẹn nhắc của phiếu đổi theo nếu chưa ai sửa tay.
        </p>
      </div>
    </FormDialog>
  );
}
