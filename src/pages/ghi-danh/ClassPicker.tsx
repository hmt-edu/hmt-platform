// Danh sách chọn lớp kèm ngày vào lớp, dùng chung cho BH-08 (dòng đơn) và GD-03 (xếp lớp lẻ). Lớp trùng buổi hiện mờ kèm lý do (khung GD03_trung_gio).
// Ngày vào lớp: lớp đã có buổi thì chọn một buổi sắp tới; lớp chưa có buổi thì nhập ngày đúng thứ có lịch (máy chủ kiểm lại, R-GD-14).
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { cn } from '../../ui/cn';
import {
  dateKey,
  defaultStart,
  deliveryMismatchWarning,
  disabledReason,
  keyToDate,
  seatsText,
  startHint,
  upcomingLabel,
} from './enrollLogic';
import type { MatchingClass } from './enrollTypes';

export type ClassPick = { classId: string | null; date: string };

export function ClassPicker({
  classes,
  value,
  onChange,
  name,
  allowLater = false,
  laterLabel = 'Chưa chọn lớp',
  enrollMode,
}: {
  classes: MatchingClass[];
  value: ClassPick;
  onChange: (next: ClassPick) => void;
  /** Tên nhóm nút chọn (để nhiều bộ chọn cùng màn không lẫn). */
  name: string;
  /** BH-08: cho chọn "Chưa chọn lớp" (ghi danh ở Chờ xếp lớp, vận hành xếp sau). */
  allowLater?: boolean;
  laterLabel?: string;
  /** Hình thức học của ghi danh: lớp lệch hình thức chỉ hiện cảnh báo, không chặn. */
  enrollMode?: string | null | undefined;
}) {
  const chosen = classes.find((c) => c.id === value.classId) ?? null;
  return (
    <div className="flex flex-col gap-2">
      <ul className="flex max-h-[320px] flex-col gap-1 overflow-auto" aria-label="Lớp phù hợp">
        {classes.map((c) => {
          const reason = disabledReason(c);
          const on = value.classId === c.id;
          return (
            <li key={c.id} className={cn(reason && 'opacity-60')}>
              <label
                className={cn(
                  'flex cursor-pointer items-start gap-2 rounded-control border p-2',
                  on ? 'border-border-strong bg-selected' : 'border-border',
                  reason && 'cursor-not-allowed',
                )}
              >
                <input
                  type="radio"
                  name={name}
                  disabled={reason !== null}
                  checked={on}
                  onChange={() => onChange({ classId: c.id, date: defaultStart(c) })}
                  className="mt-1"
                />
                <span className="min-w-0 flex-1">
                  <span className="block font-medium">{c.code}</span>
                  <span className="block text-caption text-fg-muted">
                    {[c.subject_name, c.schedule_text, c.teacher_name, seatsText(c)]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                  {reason && (
                    <span className="block text-caption text-on-warning-subtle">{reason}</span>
                  )}
                  {!reason && deliveryMismatchWarning(c.delivery_mode_code, enrollMode) && (
                    <span className="block text-caption text-on-warning-subtle">
                      {deliveryMismatchWarning(c.delivery_mode_code, enrollMode)}
                    </span>
                  )}
                </span>
              </label>
            </li>
          );
        })}
        {allowLater && (
          <li>
            <label className="flex cursor-pointer items-center gap-2 rounded-control border border-border p-2">
              <input
                type="radio"
                name={name}
                checked={value.classId === null}
                onChange={() => onChange({ classId: null, date: '' })}
              />
              <span>{laterLabel}</span>
            </label>
          </li>
        )}
      </ul>
      {classes.length === 0 && (
        <p role="status" className="text-body text-fg-muted">
          Không có lớp phù hợp: chưa có lớp đã duyệt còn chỗ đúng môn, khối, cơ sở của gói này.
        </p>
      )}
      {/* Giữ chỗ cố định cho ô Ngày vào lớp: chọn lớp không làm hộp dài ra, nút Xếp lớp không dịch xuống (T2-21: bấm lần đầu không ăn). */}
      <div className="flex min-h-24 flex-col gap-1">
        {!chosen && classes.length > 0 && (
          <p className="text-caption text-fg-muted">Chọn lớp để chọn ngày vào lớp.</p>
        )}
        {chosen && (
          <div className="flex flex-col gap-1">
            {chosen.has_sessions ? (
              <Select
                label="Ngày vào lớp"
                value={value.date}
                onChange={(date) => onChange({ ...value, date })}
                options={chosen.upcoming.map((u) => ({
                  value: u.date,
                  label: upcomingLabel(u.date, u.session_no),
                }))}
                placeholder="Chọn buổi vào lớp"
              />
            ) : (
              <>
                <DateInput
                  label="Ngày vào lớp"
                  value={keyToDate(value.date)}
                  min={keyToDate(chosen.class_start_date) ?? undefined}
                  onChange={(d) => onChange({ ...value, date: d ? dateKey(d) : '' })}
                />
                <p className="text-caption text-fg-muted">{startHint(chosen)}</p>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
