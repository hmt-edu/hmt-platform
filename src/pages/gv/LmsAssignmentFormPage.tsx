// GV-17 Giao bài, Sửa bài đã giao, Gỡ bài (cổng giáo viên, điện thoại trước), theo canvas bổ sung 20/11 (GV17_form*, sua, sua_co_nop, giao_xn, go_xn, roi).
// Một trang hai chế độ: /gv/lop/:classId/bai-giao/moi (giao) và /gv/lop/:classId/bai-giao/:id (sửa). Không tự lưu: bấm Giao (có hộp xác nhận K08) hoặc Lưu.
// Luật: R-LMS-01 (cả lớp hoặc từng em; hạn mặc định giờ vào buổi sau; hai công tắc), Q2 (đã có em nộp: khoá nội dung, đổi được hạn; Gỡ chỉ khi chưa em nào nộp),
// Q4 (mặc định Cho nộp lại bật, Nhận bài muộn tắt), Q10 (không có buổi sau: bắt buộc hạn), Q11 (tối thiểu 1 em).
// Lệch khung có chủ đích (Chat 02:29, phương án B): chưa bật lưu tệp (ô đính kèm tắt, nói rõ lý do); mô tả bắt buộc; không có «Lưu nháp» (máy chủ chưa có bài nháp).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { ConfirmDialog, UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Checkbox, TextAreaField, TextField } from '../../ui/Field';
import { Switch } from '../../ui/Lms';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { useToast } from '../../ui/toastContext';
import type { ClassOverview } from './classOverviewLogic';
import {
  createPayload,
  giveableSessions,
  nextSessionOf,
  validateLmsForm,
  vnParts,
  type LmsAssignmentRow,
  type LmsFormErrors,
  type LmsList,
  type LmsSessionLite,
} from './lms';

const PAGE_SIZE = 100; // allow-number: tối đa một trang theo quy ước hiệu năng

function sessionLabel(s: {
  session_no: number | null;
  session_date: string;
  start_time: string;
  end_time?: string;
}) {
  const [, m, d] = s.session_date.split('-');
  const range = s.end_time
    ? `${s.start_time.slice(0, 5)}–${s.end_time.slice(0, 5)}`
    : s.start_time.slice(0, 5);
  return `Buổi ${s.session_no ?? '?'} · ${d}/${m} ${range}`;
}

export function LmsAssignmentFormPage() {
  const supabase = useDb();
  const { classId = '', assignmentId } = useParams();
  const [search] = useSearchParams();
  const editing = assignmentId !== undefined;
  const klass = useQuery({
    queryKey: ['gv-class', classId],
    queryFn: () => rpc<ClassOverview>(supabase, 'teacher_class_overview', { p_class_id: classId }),
  });
  const list = useQuery({
    queryKey: ['gv-lms-list', classId],
    enabled: editing,
    queryFn: () =>
      rpc<LmsList>(supabase, 'lms_list_assignments', {
        p_class_id: classId,
        p_limit: PAGE_SIZE,
        p_offset: 0,
      }),
  });
  const existing = editing ? list.data?.rows.find((r) => r.id === assignmentId) : undefined;
  // Buổi giao chọn được: máy chủ chỉ trả buổi mà người này giao bài được (giáo viên, trợ giảng của buổi), tránh chọn buổi của người khác.
  const giveable = useQuery({
    queryKey: ['gv-lms-giveable', classId],
    enabled: !editing,
    queryFn: () =>
      rpc<LmsSessionLite[]>(supabase, 'lms_giveable_sessions', { p_class_id: classId }),
  });

  const back = (
    <Link className="text-link underline" to={`/gv/lop/${classId}/bai-giao`}>
      Bài đã giao
    </Link>
  );

  if (klass.isPending || (editing && list.isPending) || (!editing && giveable.isPending))
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">{editing ? 'Sửa bài đã giao' : 'Giao bài trên LMS'}</h1>
        <Spinner />
      </div>
    );
  if (klass.isError || (editing && list.isError) || (!editing && giveable.isError))
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <QueryErrorView
          error={klass.error ?? list.error ?? giveable.error}
          subject="lớp này"
          onRetry={() => {
            void klass.refetch();
            if (editing) void list.refetch();
            else void giveable.refetch();
          }}
        />
      </div>
    );
  if (editing && existing === undefined)
    return (
      <StateView kind="not-found" title="Không tìm thấy bài giao" actions={back}>
        Bài này không còn trong lớp hoặc bạn không xem được.
      </StateView>
    );

  return (
    <LmsForm
      key={assignmentId ?? 'moi'}
      klass={klass.data}
      giveable={giveable.data ?? []}
      existing={existing}
      classId={classId}
      assignmentId={assignmentId}
      wantedSession={search.get('buoi')}
    />
  );
}

function LmsForm({
  klass,
  giveable,
  existing,
  classId,
  assignmentId,
  wantedSession,
}: {
  klass: ClassOverview;
  giveable: LmsSessionLite[];
  existing: LmsAssignmentRow | undefined;
  classId: string;
  assignmentId: string | undefined;
  wantedSession: string | null;
}) {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const editing = assignmentId !== undefined;
  const due = existing ? vnParts(existing.due_at) : { date: '', time: '' };
  // Chế độ giao: chỉ buổi người này giao được (mới nhất trước). Sửa bài: buổi giao cố định theo bài.
  const sessions = editing ? giveableSessions(klass.sessions) : giveable;
  // Buổi giao mặc định: buổi trong địa chỉ ?buoi=, không thì buổi gần nhất đã diễn ra hoặc đang diễn ra, không có thì buổi sớm nhất sắp tới.
  const todayKey = vnParts(new Date().toISOString()).date;
  const past = sessions.filter((s) => s.session_date <= todayKey);
  const defaultSession =
    sessions.find((s) => s.id === wantedSession) ?? past[0] ?? sessions[sessions.length - 1];
  const [sessionId, setSessionId] = useState(existing?.session_id ?? defaultSession?.id ?? '');
  const [audience, setAudience] = useState<'CA_LOP' | 'CHON_EM'>(existing?.audience ?? 'CA_LOP');
  const [studentIds, setStudentIds] = useState<string[]>([]);
  const [title, setTitle] = useState(existing?.title ?? '');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [date, setDate] = useState(due.date);
  const [time, setTime] = useState(due.time);
  const [allowResubmit, setAllowResubmit] = useState(existing?.allow_resubmit ?? true); // Q4
  const [allowLate, setAllowLate] = useState(existing?.allow_late ?? false); // Q4
  const [errors, setErrors] = useState<LmsFormErrors>({});
  const [error, setError] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  // Đã lưu xong, đang chuyển màn: tắt bộ chặn «chưa lưu» rồi mới chuyển (làm trong effect để bộ chặn chắc chắn đã cập nhật).
  const [leaveTo, setLeaveTo] = useState<string | null>(null);
  useEffect(() => {
    if (leaveTo !== null) void navigate(leaveTo, { replace: true });
  }, [leaveTo, navigate]);
  const [confirm, setConfirm] = useState<'giao' | 'go' | null>(null);

  const next = nextSessionOf(klass.sessions, sessionId);
  const students = klass.students;
  const hasSubmissions = (existing?.submitted ?? 0) > 0;
  const locked = editing && existing?.status === 'DA_GO';
  const recipients = editing
    ? (existing?.targets ?? 0)
    : audience === 'CA_LOP'
      ? students.length
      : studentIds.length;

  const save = useMutation({
    mutationFn: async () => {
      const values = {
        title,
        description,
        date,
        time,
        audience,
        studentIds,
        hasDefaultDue: next !== null,
      };
      if (!editing)
        return rpc<{ id: string }>(supabase, 'lms_create_assignment', {
          p_data: createPayload(sessionId, values, allowResubmit, allowLate),
        });
      const data: Record<string, unknown> = {
        allow_resubmit: allowResubmit,
        allow_late: allowLate,
      };
      if (!hasSubmissions) {
        data.title = title.trim();
        data.description = description.trim();
      }
      const iso = date !== '' && time !== '' ? `${date}T${time}:00+07:00` : undefined;
      if (iso) data.due_at = iso;
      return rpc<{ id: string }>(supabase, 'lms_update_assignment', {
        p_id: assignmentId,
        p_data: data,
        p_version: existing?.version,
      });
    },
  });
  const withdraw = useMutation({
    mutationFn: () =>
      rpc<{ id: string }>(supabase, 'lms_withdraw_assignment', {
        p_id: assignmentId,
        p_version: existing?.version,
      }),
  });

  const listPath = `/gv/lop/${classId}/bai-giao`;
  const back = (
    <Link className="text-link underline" to={listPath}>
      Bài đã giao
    </Link>
  );
  const classTitle = `${klass.class.subject_name ?? ''} · ${klass.class.code}`.replace(/^ · /, '');
  const heading = editing ? 'Sửa bài đã giao' : 'Giao bài trên LMS';

  function validate(): boolean {
    const found = validateLmsForm(
      {
        title,
        description,
        date,
        time,
        audience,
        studentIds,
        hasDefaultDue: editing || next !== null,
      },
      new Date(),
    );
    // Sửa bài đã có em nộp: tiêu đề, mô tả đã khoá nên không báo lỗi các ô đó.
    if (hasSubmissions) {
      delete found.title;
      delete found.description;
    }
    setErrors(found);
    setError(null);
    return Object.keys(found).length === 0;
  }

  async function onSubmit() {
    try {
      await save.mutateAsync();
      setDirty(false);
      setLeaveTo(listPath);
      setConfirm(null);
      void queryClient.invalidateQueries({ queryKey: ['gv-lms-list', classId] });
      toast({ tone: 'success', title: editing ? 'Đã lưu bài giao' : 'Đã giao bài' });
    } catch (e) {
      setConfirm(null);
      setError(errorOf(e).message);
    }
  }
  async function onWithdraw() {
    try {
      await withdraw.mutateAsync();
      setDirty(false);
      setLeaveTo(listPath);
      setConfirm(null);
      void queryClient.invalidateQueries({ queryKey: ['gv-lms-list', classId] });
      toast({ tone: 'success', title: 'Đã gỡ bài' });
    } catch (e) {
      setConfirm(null);
      setError(errorOf(e).message);
    }
  }
  const mark =
    <T,>(set: (v: T) => void) =>
    (v: T) => {
      set(v);
      setDirty(true);
    };

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4 p-3">
      <UnsavedGuard
        when={dirty && leaveTo === null}
        title="Rời màn khi chưa lưu?"
        description="Bài giao bạn vừa nhập chưa được lưu. Rời màn thì các thay đổi này mất."
      />
      <p className="text-caption text-fg-muted">
        {back} › {heading}
      </p>
      <div>
        <h1 className="text-h2">{heading}</h1>
        <p className="text-fg-muted">
          {classTitle}
          {existing ? ` · Buổi ${existing.session_no ?? '?'}` : ''}
        </p>
      </div>
      {locked && (
        <Alert tone="warning" title="Bài này đã gỡ.">
          Bài đã gỡ không sửa được.
        </Alert>
      )}
      {hasSubmissions && (
        <Alert
          tone="warning"
          title={`Đã có ${existing?.submitted}/${existing?.targets} em nộp bài`}
        >
          Nội dung bài khoá; hạn nộp vẫn đổi được. Đổi hạn nộp áp dụng cho cả lớp.
        </Alert>
      )}
      {error !== null && (
        <Alert tone="danger" title="Chưa lưu được.">
          {error}
        </Alert>
      )}
      {Object.keys(errors).length > 0 && (
        <Alert tone="danger" title={`Còn ${Object.keys(errors).length} trường chưa hợp lệ.`}>
          Sửa các ô báo lỗi rồi {editing ? 'lưu' : 'giao'} lại.
        </Alert>
      )}

      <section className="flex flex-col gap-3" aria-label="Lớp và buổi giao">
        <h2 className="text-h3">Lớp và buổi giao</h2>
        <TextField label="Lớp" value={classTitle} readOnly disabled />
        <OptionalSelect
          label="Buổi giao"
          value={sessionId}
          onChange={mark(setSessionId)}
          disabled={editing}
          options={sessions.map((s) => ({ value: s.id, label: sessionLabel(s) }))}
          placeholder="Chọn buổi giao"
        />
        <fieldset className="flex flex-col gap-1">
          <legend className="font-semibold">Giao cho</legend>
          <div className="flex flex-wrap gap-2">
            {(['CA_LOP', 'CHON_EM'] as const).map((value) => (
              <label
                key={value}
                className="inline-flex min-h-target cursor-pointer items-center gap-2 rounded-control border border-border bg-surface px-3"
              >
                <input
                  type="radio"
                  name="audience"
                  checked={audience === value}
                  disabled={editing}
                  onChange={() => mark(setAudience)(value)}
                  className="accent-[var(--action-primary-bg)]"
                />
                {value === 'CA_LOP' ? 'Cả lớp' : 'Chọn từng em'}
              </label>
            ))}
          </div>
          <p className="text-caption text-fg-muted">{recipients} em sẽ nhận bài.</p>
          {!editing && audience === 'CHON_EM' && (
            <ul className="mt-1 flex flex-col" aria-label="Chọn em nhận bài">
              {students.map((s) => (
                <li key={s.student_id}>
                  <Checkbox
                    label={s.full_name}
                    checked={studentIds.includes(s.student_id)}
                    onChange={(e) =>
                      mark(setStudentIds)(
                        e.target.checked
                          ? [...studentIds, s.student_id]
                          : studentIds.filter((x) => x !== s.student_id),
                      )
                    }
                  />
                </li>
              ))}
            </ul>
          )}
          {errors.students && (
            <p role="alert" className="text-caption text-danger">
              {errors.students}
            </p>
          )}
        </fieldset>
      </section>

      <section className="flex flex-col gap-3" aria-label="Nội dung bài">
        <h2 className="text-h3">Nội dung bài</h2>
        <TextField
          label="Tiêu đề bài"
          required
          value={title}
          disabled={hasSubmissions || locked}
          error={errors.title}
          placeholder="Ví dụ: Bài tập về nhà Buổi 5"
          onChange={(e) => mark(setTitle)(e.target.value)}
        />
        <TextAreaField
          label="Mô tả, đề bài"
          required
          value={description}
          disabled={hasSubmissions || locked}
          error={errors.description}
          placeholder="Nhập đề bài hoặc dặn dò cho học sinh"
          onChange={(e) => mark(setDescription)(e.target.value)}
        />
        {/* Đính kèm ảnh/PDF chờ kho tệp (R2 hoãn sang phase sau): ẩn, không hiện ô chưa chạy được (E-23-06). */}
      </section>

      <section className="flex flex-col gap-3" aria-label="Hạn nộp và tuỳ chọn">
        <h2 className="text-h3">Hạn nộp và tuỳ chọn</h2>
        <div className="grid grid-cols-2 gap-2">
          <TextField
            label="Hạn nộp: ngày"
            type="date"
            value={date}
            disabled={locked}
            invalid={errors.due !== undefined}
            onChange={(e) => mark(setDate)(e.target.value)}
          />
          <TextField
            label="Giờ"
            type="time"
            value={time}
            disabled={locked}
            invalid={errors.due !== undefined}
            onChange={(e) => mark(setTime)(e.target.value)}
          />
        </div>
        {errors.due && (
          <p role="alert" className="text-caption text-danger">
            {errors.due}
          </p>
        )}
        {!editing && (
          <p className="text-caption text-fg-muted">
            {next
              ? `Bỏ trống thì hạn là giờ vào ${sessionLabel(next).split(' · ')[0]} (${formatDateTime(`${next.session_date}T${next.start_time}+07:00`)}). Đổi được.`
              : 'Lớp chưa có buổi sau: hãy chọn hạn nộp.'}
          </p>
        )}
        {hasSubmissions && (
          <p className="text-caption text-fg-muted">
            Đã có em nộp. Đổi hạn nộp áp dụng cho cả lớp.
          </p>
        )}
        <Switch
          label="Cho nộp lại"
          description="Bật: em nộp lại được cho đến khi giáo viên chấm."
          checked={allowResubmit}
          disabled={locked}
          onChange={mark(setAllowResubmit)}
        />
        <Switch
          label="Nhận bài muộn"
          description="Tắt: quá hạn thì em không nộp được. Bật: bài nộp sau hạn hiện nhãn Nộp muộn."
          checked={allowLate}
          disabled={locked}
          onChange={mark(setAllowLate)}
        />
      </section>

      <div className="flex flex-wrap gap-2">
        <Button
          variant="primary"
          disabled={locked}
          loading={save.isPending}
          onClick={() => validate() && (editing ? void onSubmit() : setConfirm('giao'))}
        >
          {editing ? 'Lưu' : 'Giao bài'}
        </Button>
        <Button variant="text" onClick={() => void navigate(listPath)}>
          Huỷ
        </Button>
        {editing && !locked && (
          <Button
            variant="danger"
            disabled={hasSubmissions}
            icon="trash"
            onClick={() => setConfirm('go')}
          >
            Gỡ bài
          </Button>
        )}
      </div>
      {hasSubmissions && editing && (
        <p className="text-caption text-fg-muted">Đã có em nộp nên không gỡ được bài.</p>
      )}

      <ConfirmDialog
        open={confirm === 'giao'}
        onOpenChange={(o) => !o && setConfirm(null)}
        title="Giao bài này?"
        summary={[
          { label: 'Số em nhận bài', value: `${recipients} em` },
          {
            label: 'Hạn nộp',
            value:
              date !== '' && time !== ''
                ? formatDateTime(`${date}T${time}:00+07:00`)
                : next
                  ? formatDateTime(`${next.session_date}T${next.start_time}+07:00`)
                  : 'Chưa chọn',
          },
        ]}
        confirmLabel="Giao bài"
        busy={save.isPending}
        onConfirm={() => void onSubmit()}
      />
      <ConfirmDialog
        open={confirm === 'go'}
        onOpenChange={(o) => !o && setConfirm(null)}
        title="Gỡ bài này?"
        description="Bài gỡ xong không còn hiện cho học sinh. Chỉ gỡ được khi chưa em nào nộp."
        confirmLabel="Gỡ bài"
        tone="danger"
        busy={withdraw.isPending}
        onConfirm={() => void onWithdraw()}
      />
    </div>
  );
}
