// GV-05 Điểm danh (cổng giáo viên, đường dẫn /gv/buoi/:id/diem-danh). Điện thoại: từng em một thẻ; laptop: bảng chấm nhanh (phím 1 đến 4).
// Không tự lưu: bấm Lưu mới ghi. Ô của giáo viên là trạng thái chính thức (R-DD-02); giáo viên không tạo dòng, không đổi tình trạng buổi (R-GV-08).
// Lệch khung có chủ đích: không hiện "Vận hành: …" (lý do liên hệ của vận hành), vì luật R-GV-13 không nói giáo viên được thấy.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type KeyboardEvent } from 'react';
import { useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { cn } from '../../ui/cn';
import {
  buildEntries,
  countMarked,
  effectiveStatus,
  fillRemaining,
  needsAbsenceConfirm,
  otherEditorLabel,
  setDraft,
  sheetTitle,
  sheetWhen,
  type AttendanceConflict,
  type AttendanceSheet,
  type AttendanceStatus,
  type AttendanceStudent,
  type Draft,
  type SaveResult,
} from './attendanceLogic';

export function TeacherAttendancePage() {
  const { id = '' } = useParams();
  const supabase = useDb();
  const client = useQueryClient();
  const toast = useToast();
  const query = useQuery({
    queryKey: ['gv-attendance', id],
    queryFn: () => rpc<AttendanceSheet>(supabase, 'teacher_attendance_sheet', { p_session_id: id }),
    retry: false,
    refetchOnWindowFocus: false,
  });
  const [draft, setDraftState] = useState<Draft>({});
  // Giờ ghi của từng ô lúc mở màn (hoặc sau lần lưu gần nhất): máy chủ so với giờ ghi hiện tại để phát hiện người khác vừa sửa.
  const [baseMarked, setBaseMarked] = useState<Record<string, string | null>>({});
  const [loadedFor, setLoadedFor] = useState<unknown>(null);
  const [absence, setAbsence] = useState<{ student: AttendanceStudent; code: string } | null>(null);
  const [conflicts, setConflicts] = useState<AttendanceConflict[] | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const rows = useRef<Record<string, HTMLElement | null>>({});

  // Nạp lại bảng (mở màn, sau khi lưu): lấy giờ ghi làm gốc so xung đột.
  const sheet = query.data;
  if (sheet && loadedFor !== sheet) {
    setLoadedFor(sheet);
    setBaseMarked(
      Object.fromEntries(sheet.students.map((s) => [s.student_id, s.teacher_marked_at])),
    );
  }

  const save = useMutation({
    mutationFn: (args: { entries: ReturnType<typeof buildEntries> }) =>
      rpc<SaveResult>(supabase, 'save_attendance_teacher', {
        p_session_id: id,
        p_entries: args.entries,
      }),
  });

  if (query.isPending) {
    return (
      <Shell title="Điểm danh">
        <Spinner />
      </Shell>
    );
  }
  if (query.isError) {
    const err = errorOf(query.error);
    if (err.code === 'HMT_KHONG_CO_QUYEN' || err.code === 'HMT_KHONG_TIM_THAY') {
      return (
        <StateView
          kind="forbidden"
          title="Bạn không xem được buổi này"
          actions={
            <ButtonLink to="/gv" variant="primary">
              Về trang Hôm nay
            </ButtonLink>
          }
        >
          Giáo viên và trợ giảng chỉ thấy buổi của lớp mình được phân công (R-GV-08, R-GV-09). Nếu
          đây là lớp của bạn, hãy liên hệ quản trị viên.
        </StateView>
      );
    }
    return (
      <Shell title="Điểm danh">
        <Alert tone="danger">{err.message}</Alert>
        <div>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      </Shell>
    );
  }

  const data = query.data;
  const subtitle = `${sheetTitle(data.session)} · ${sheetWhen(data.session)}`;
  if (!data.listed) {
    return (
      <Shell title="Điểm danh" subtitle={subtitle}>
        <Alert tone="info">
          <b>Buổi chưa chốt danh sách.</b> Chưa có dòng điểm danh nên chưa điểm danh được. Giáo viên
          không tạo dòng điểm danh (R-GV-08, R-GIO-02).
        </Alert>
        <StateView kind="empty" title="Chưa có danh sách để điểm danh" headingLevel={2}>
          Danh sách sẽ được hệ thống chốt trước giờ học. Khi chốt xong, các em hiện ở đây.
          <span className="mt-2 block">
            <ButtonLink to="/gv" variant="secondary">
              Về các bước của buổi
            </ButtonLink>
          </span>
        </StateView>
      </Shell>
    );
  }

  const done = data.session.status_code === 'DONE';
  const dirty = Object.keys(draft).length > 0;
  const total = data.students.length;
  const marked = countMarked(data.students, draft);
  const firstStatus = data.statuses[0];

  function choose(student: AttendanceStudent, code: string | null) {
    if (done) return;
    if (needsAbsenceConfirm(student, draft, code)) {
      setAbsence({ student, code: code ?? '' });
      return;
    }
    setDraftState((d) => setDraft(d, student, code));
  }

  async function doSave(entries: ReturnType<typeof buildEntries>) {
    setSaveError(null);
    try {
      const result = await save.mutateAsync({ entries });
      if (result.conflicts.length > 0) {
        setConflicts(result.conflicts);
        return;
      }
      setConflicts(null);
      setDraftState({});
      await client.invalidateQueries({ queryKey: ['gv-attendance', id] });
      toast({ tone: 'success', title: 'Đã lưu điểm danh' });
    } catch (e) {
      setSaveError(errorOf(e).message);
    }
  }

  // "Giữ của tôi": ghi đè, lấy giờ ghi hiện tại của ô vênh làm gốc. "Lấy của …": bỏ ô vênh khỏi bản nháp, ghi các ô còn lại.
  async function keepMine(list: AttendanceConflict[]) {
    const bases = {
      ...baseMarked,
      ...Object.fromEntries(list.map((c) => [c.student_id, c.marked_at])),
    };
    setBaseMarked(bases);
    await doSave(buildEntries(data.students, draft, bases));
  }
  async function takeTheirs(list: AttendanceConflict[]) {
    const ids = new Set(list.map((c) => c.student_id));
    const rest: Draft = Object.fromEntries(Object.entries(draft).filter(([k]) => !ids.has(k)));
    setDraftState(rest);
    setConflicts(null);
    if (Object.keys(rest).length === 0) {
      await client.invalidateQueries({ queryKey: ['gv-attendance', id] });
      return;
    }
    await doSave(buildEntries(data.students, rest, baseMarked));
  }

  function onRowKey(event: KeyboardEvent, index: number) {
    if (done) return;
    const student = data.students[index];
    if (!student) return;
    const digit = Number(event.key);
    if (digit >= 1 && digit <= data.statuses.length) {
      event.preventDefault();
      choose(student, data.statuses[digit - 1]?.code ?? null);
      const next = data.students[index + 1];
      if (next) rows.current[next.student_id]?.focus();
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const target = data.students[index + (event.key === 'ArrowDown' ? 1 : -1)];
      if (target) rows.current[target.student_id]?.focus();
    }
  }

  return (
    <Shell title="Điểm danh" subtitle={subtitle}>
      <UnsavedGuard
        when={dirty}
        title="Chưa lưu thay đổi"
        description="Bạn đã sửa nhưng chưa bấm Lưu. Rời màn bây giờ thì các thay đổi này mất."
        stayLabel="Ở lại để lưu"
        leaveLabel="Rời đi, bỏ thay đổi"
      />
      {done && (
        <Alert tone="info">
          <b>Buổi đã Hoàn thành: chỉ xem.</b> Sai thì Trưởng cơ sở sửa ở BUOI-14.
        </Alert>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <p className="text-body font-semibold">
          Đã điểm danh {marked}/{total}
        </p>
        {!done && firstStatus && marked < total && (
          <Button
            variant="secondary"
            onClick={() => setDraftState((d) => fillRemaining(data.students, d, firstStatus.code))}
          >
            Còn lại: {firstStatus.name}
          </Button>
        )}
        {dirty && <Tag tone="warning">Chưa lưu</Tag>}
      </div>
      <p className="text-caption text-fg-muted">
        Ô của giáo viên là trạng thái chính thức (R-DD-02). Ô trống là chưa điểm danh.
      </p>
      {!done && (
        <p className="hidden text-caption text-fg-muted lg:block">
          Bấm 1–4 chọn trạng thái ({data.statuses.map((s, i) => `${i + 1} ${s.name}`).join(' · ')}),
          tự sang em kế. Mũi tên lên xuống đổi hàng. Không tự lưu: bấm Lưu.
        </p>
      )}

      <ul className="flex flex-col gap-2" aria-label="Danh sách em">
        {data.students.map((s, index) => {
          const current = effectiveStatus(s, draft);
          return (
            <li
              key={s.student_id}
              ref={(el) => {
                rows.current[s.student_id] = el;
              }}
              tabIndex={done ? -1 : 0}
              onKeyDown={(e) => onRowKey(e, index)}
              className="focus-ring flex flex-col gap-2 rounded-control border border-border bg-surface p-3 lg:flex-row lg:items-center lg:gap-4"
            >
              <div className="min-w-0 lg:w-64 lg:shrink-0">
                <p className="font-semibold">
                  {s.full_name} {s.is_trial && <Tag tone="info">Học thử</Tag>}
                </p>
                {s.has_review && (
                  <p className="text-caption text-fg-muted">
                    Đã chấm nhận xét. Đổi sang Vắng thì điểm không được tính.
                  </p>
                )}
              </div>
              <StatusButtons
                name={s.full_name}
                statuses={data.statuses}
                value={current}
                disabled={done}
                onChange={(code) => choose(s, code)}
              />
            </li>
          );
        })}
      </ul>

      {saveError && <Alert tone="danger">{saveError}</Alert>}
      {!done && (
        <div className="sticky bottom-20 flex flex-col gap-1 lg:bottom-4">
          <Button
            variant="primary"
            icon="check"
            loading={save.isPending}
            disabled={!dirty || save.isPending}
            onClick={() => void doSave(buildEntries(data.students, draft, baseMarked))}
          >
            Lưu điểm danh
          </Button>
          <p className="text-caption text-fg-muted">Bấm Lưu mới ghi. Không tự lưu.</p>
        </div>
      )}
      {done && <p className="text-caption text-fg-muted">Không sửa được ở cổng giáo viên.</p>}

      <ConfirmDialog
        open={absence !== null}
        onOpenChange={(open) => !open && setAbsence(null)}
        title="Đổi sang Vắng?"
        description={
          <>
            <b>{absence?.student.full_name}</b>
            <br />
            Điểm đã nhập của em này sẽ không được tính. Đổi lại Có mặt thì hiện lại.
          </>
        }
        confirmLabel="Đổi sang Vắng"
        cancelLabel="Giữ nguyên"
        onConfirm={() => {
          if (absence) setDraftState((d) => setDraft(d, absence.student, absence.code));
          setAbsence(null);
        }}
      />

      <Dialog
        open={conflicts !== null}
        onOpenChange={(open) => !open && setConflicts(null)}
        title={`Có ô vừa được ${conflicts?.[0]?.marked_by_name ?? 'người khác'} sửa`}
        description={`Từ lúc bạn mở màn, ${conflicts?.[0]?.marked_by_name ?? 'người khác'} đã sửa các ô dưới đây. Chọn bên nào sẽ được ghi.`}
        dismissible
        footer={
          <>
            <Button onClick={() => conflicts && void takeTheirs(conflicts)}>
              {conflicts ? otherEditorLabel(conflicts) : ''}
            </Button>
            <Button variant="primary" onClick={() => conflicts && void keepMine(conflicts)}>
              Giữ của tôi
            </Button>
          </>
        }
      >
        <ul className="flex flex-col gap-1 text-body">
          {(conflicts ?? []).map((c) => (
            <li key={c.student_id}>
              <b>{c.full_name}</b>: của bạn {statusName(data.statuses, draft[c.student_id] ?? null)}
              , của {c.marked_by_name ?? 'người kia'}{' '}
              {statusName(data.statuses, c.current_status_code)}
            </li>
          ))}
        </ul>
      </Dialog>
    </Shell>
  );
}

function statusName(statuses: AttendanceStatus[], code: string | null): string {
  return statuses.find((s) => s.code === code)?.name ?? 'chưa điểm danh';
}

function Shell({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string | undefined;
  children: React.ReactNode;
}) {
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-3">
      <div>
        <h1 className="text-h2">{title}</h1>
        {subtitle && <p className="text-body text-fg-muted">{subtitle}</p>}
      </div>
      {children}
    </div>
  );
}

/** Bốn nút chọn một trạng thái (radiogroup); bấm lại nút đang chọn thì bỏ chọn về "chưa điểm danh". */
function StatusButtons({
  name,
  statuses,
  value,
  disabled,
  onChange,
}: {
  name: string;
  statuses: AttendanceStatus[];
  value: string | null;
  disabled: boolean;
  onChange: (code: string | null) => void;
}) {
  return (
    <div role="radiogroup" aria-label={`Trạng thái của ${name}`} className="flex flex-wrap gap-2">
      {statuses.map((s) => {
        const on = value === s.code;
        return (
          <button
            key={s.code}
            type="button"
            role="radio"
            aria-checked={on}
            disabled={disabled}
            onClick={() => onChange(on ? null : s.code)}
            className={cn(
              'focus-ring min-h-11 rounded-control border px-3 text-body',
              on
                ? 'border-border-strong bg-selected font-semibold text-on-selected'
                : 'border-border bg-surface hover:bg-hover',
              disabled && 'opacity-60',
            )}
          >
            {s.name}
          </button>
        );
      })}
    </div>
  );
}
