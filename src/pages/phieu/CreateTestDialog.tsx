// TS-15 Tạo phiếu kiểm tra từ cơ hội (khuôn ③ FormDialog): khối chọn khi tạo (cơ hội chưa có khối), môn, hình thức, cấp độ, cơ sở test,
// đề test, người phụ trách, ngày giờ test (bắt buộc, ở tương lai), lịch hẹn nhắc tạo cùng phiếu (R-CRM-05). Phòng và giáo viên chấm
// chọn sau trên phiếu. Giờ nhắc mặc định tính theo ba tham số Cài đặt, cùng công thức hàm DB (defaultReminder), sửa được.
import { useState } from 'react';
import { Chips } from '../../features/appointments/Chips';
import {
  QUICK_HOURS,
  combineVn,
  parseTime,
  quickDays,
} from '../../features/appointments/appointmentTime';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAuth } from '../../lib/auth/authContext';
import { useAccess } from '../../nav/AccessContext';
import { FormDialog } from '../../ui/Dialogs';
import { Field, INPUT_CLASS } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { defaultReminder } from './testLogic';
import { createTest } from './useTestData';

export type TestSource = {
  id: string;
  code: string;
  student_name: string | null;
  parent_name: string;
  branch_id: string;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  opportunity: TestSource;
  catalogs: LeadCatalogs;
  onCreated: (created: { id: string; code: string }) => Promise<void>;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function CreateTestDialog(props: Props) {
  return props.open ? <CreateForm {...props} /> : null;
}

const timeOf = (d: Date) =>
  new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(d);
const dayLabelOf = (d: Date) =>
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(d); // yyyy-mm-dd

function CreateForm({ onOpenChange, opportunity, catalogs, onCreated }: Props) {
  const supabase = useDb();
  const { claims } = useAuth();
  const access = useAccess();
  const canAssign = access.can('STUDENT_TEST', 'GIAO_VIEC');
  const staff = useAssignableStaff('STUDENT_TEST', opportunity.branch_id, canAssign);
  const timeMinutes = useIntSetting('test_reminder_time_minutes');
  const shortWindow = useIntSetting('test_reminder_short_window_hours');
  const shortLead = useIntSetting('test_reminder_short_lead_hours');

  const myBranch = access.teachingBranches.find((b) => b.code === claims?.branchCode);
  const [grade, setGrade] = useState('');
  const [subject, setSubject] = useState('');
  const [mode, setMode] = useState('');
  const [level, setLevel] = useState('');
  const [branch, setBranch] = useState(myBranch?.id ?? '');
  const [exam, setExam] = useState('');
  const [owner, setOwner] = useState(claims?.userId ?? '');
  const [date, setDate] = useState<Date | null>(null);
  const [time, setTime] = useState('');
  const [remDate, setRemDate] = useState<Date | null>(null);
  const [remTime, setRemTime] = useState('');
  const [remTouched, setRemTouched] = useState(false);
  const [activity, setActivity] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Lúc mở hộp: mốc so "giờ test ở tương lai" và tính giờ nhắc (hàm DB kiểm lại bằng giờ thật).
  const [openedAt] = useState(() => new Date());

  const days = quickDays();
  const pickedDay = days.find((d) => date && d.date.getTime() === date.getTime())?.label ?? null;
  const when = combineVn(date, time);
  const future = when !== null && when.getTime() > openedAt.getTime();
  const settingsReady = timeMinutes !== null && shortWindow !== null && shortLead !== null;

  // Giờ nhắc mặc định theo ngày giờ test (cho tới khi người dùng sửa tay).
  const suggested =
    when && future && settingsReady && date
      ? defaultReminder(when, openedAt, combineVn(date, '00:00') ?? when, {
          timeMinutes,
          shortWindowHours: shortWindow,
          shortLeadHours: shortLead,
        })
      : null;
  const shownRemDate = remTouched ? remDate : suggested ? vnDate(suggested) : null;
  const shownRemTime = remTouched ? remTime : suggested ? timeOf(suggested) : '';
  const reminder = combineVn(shownRemDate, shownRemTime);
  const reminderOk = reminder !== null && when !== null && reminder.getTime() < when.getTime();

  const activityOptions = catalogs.options('ACTIVITY_TYPE');
  const activityValue =
    activity !== ''
      ? activity
      : (activityOptions.find((o) => o.value === 'GOI_DIEN')?.value ??
        activityOptions[0]?.value ??
        '');
  const staffOptions = [
    ...(claims && !(staff.data ?? []).some((s) => s.id === claims.userId)
      ? [{ value: claims.userId, label: 'Bạn' }]
      : []),
    ...(staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name })),
  ];

  const canSubmit =
    grade !== '' &&
    subject !== '' &&
    mode !== '' &&
    level !== '' &&
    branch !== '' &&
    owner !== '' &&
    future &&
    reminderOk;

  async function submit() {
    if (!when || !reminder) return;
    setBusy(true);
    setError(null);
    try {
      const created = await createTest(supabase, {
        opportunityId: opportunity.id,
        data: {
          subject_code: subject,
          grade_code: grade,
          mode_code: mode,
          level_code: level,
          exam_name: exam.trim() === '' ? null : exam.trim(),
          scheduled_at: when.toISOString(),
          test_branch_id: branch,
          owner_id: owner,
        },
        reminderAt: reminder,
        reminderActivity: activityValue === '' ? null : activityValue,
      });
      await onCreated(created);
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const select = (
    label: string,
    value: string,
    onChange: (v: string) => void,
    options: { value: string; label: string }[],
    required = true,
  ) => (
    <Field label={label} required={required}>
      {(field) => (
        <Select
          id={field.id}
          label={label}
          value={value}
          onChange={onChange}
          options={options}
          placeholder={`Chọn ${label.toLowerCase()}`}
          className="w-full"
        />
      )}
    </Field>
  );

  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      wide
      title="Tạo phiếu kiểm tra"
      subtitle={`Từ cơ hội ${opportunity.code} · Phụ huynh ${opportunity.parent_name}`}
      confirmLabel="Tạo phiếu"
      canSubmit={canSubmit}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-3">
          <Field
            label="Tên học sinh"
            required
            help="Tên học sinh lấy từ cơ hội (mỗi cơ hội một học sinh)."
          >
            {(field) => (
              <input
                {...field}
                readOnly
                value={opportunity.student_name ?? ''}
                className={INPUT_CLASS}
              />
            )}
          </Field>
          {select('Lớp', grade, setGrade, catalogs.options('GRADE'))}
          {select('Môn', subject, setSubject, catalogs.options('SUBJECT'))}
          {select('Hình thức test', mode, setMode, catalogs.options('TEST_MODE'))}
          {select('Cấp độ đề', level, setLevel, catalogs.options('TEST_LEVEL'))}
          {select(
            'Cơ sở test',
            branch,
            setBranch,
            access.teachingBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
          )}
        </div>
        <Field label="Đề test" help="Ô gõ chữ, ghi tên đề. Không cần tải file đề.">
          {(field) => (
            <input
              {...field}
              value={exam}
              placeholder="Ví dụ: Toán 9 cơ bản – đề 2"
              onChange={(e) => setExam(e.target.value)}
              className={INPUT_CLASS}
            />
          )}
        </Field>
        <Field
          label="Người phụ trách"
          required
          help="Mặc định là người tạo; nhận lịch hẹn nhắc và theo dõi phiếu."
        >
          {(field) =>
            canAssign ? (
              <Select
                id={field.id}
                label="Người phụ trách"
                value={owner}
                onChange={setOwner}
                options={staffOptions}
                className="w-full"
              />
            ) : (
              <input {...field} readOnly value="Bạn" className={INPUT_CLASS} />
            )
          }
        </Field>
        <div className="grid grid-cols-2 gap-3 border-t border-border pt-4">
          <DateInput label="Ngày test" required value={date} onChange={setDate} />
          <Field label="Giờ test" required>
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
        {when !== null && !future && (
          <p className="text-caption text-on-danger-subtle">Giờ test phải ở tương lai.</p>
        )}
        <div className="flex flex-col gap-3 border-t border-border pt-4">
          <h3 className="font-semibold">Lịch hẹn nhắc (tạo cùng phiếu)</h3>
          <div className="grid grid-cols-3 gap-3">
            <DateInput
              label="Ngày nhắc"
              required
              value={shownRemDate}
              onChange={(d) => {
                setRemTouched(true);
                setRemDate(d);
                if (!remTouched) setRemTime(shownRemTime);
              }}
            />
            <Field label="Giờ nhắc" required>
              {(field) => (
                <input
                  {...field}
                  type="time"
                  value={shownRemTime}
                  onChange={(e) => {
                    setRemTouched(true);
                    setRemTime(e.target.value);
                    if (!remTouched) setRemDate(shownRemDate);
                  }}
                  className={INPUT_CLASS}
                />
              )}
            </Field>
            {select('Loại hoạt động', activityValue, setActivity, activityOptions)}
          </div>
          <p className="text-caption text-fg-muted">
            Gọi nhắc phụ huynh, gắn với phiếu và cơ hội {opportunity.code}, người phụ trách là người
            phiếu. Tự điền 17:00 ngày hôm trước ngày test (test trong 24 giờ tới thì 2 giờ trước),
            sửa được. Phòng và giáo viên chấm chọn sau ở phiếu chi tiết.
            {reminder && when && !reminderOk ? ' Giờ nhắc phải trước giờ test.' : ''}
          </p>
          {reminder && reminderOk && (
            <p className="text-caption text-fg-muted">Nhắc lúc {formatDateTime(reminder)}.</p>
          )}
        </div>
        {!canSubmit && (
          <p className="text-caption text-fg-muted">
            Chọn đủ các ô bắt buộc, ngày và giờ test để bật nút Tạo phiếu.
          </p>
        )}
      </div>
    </FormDialog>
  );
}

/** Ngày (giờ Việt Nam) của một thời điểm, dạng Date địa phương 00:00 cho ô ngày. */
function vnDate(at: Date): Date {
  const [y, m, d] = dayLabelOf(at).split('-').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1); // allow-number: năm dự phòng khi chuỗi ngày hỏng
}
