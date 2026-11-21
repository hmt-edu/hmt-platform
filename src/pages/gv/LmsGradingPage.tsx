// GV-18 Chấm bài nộp online: chấm một em, bốn bước (cổng giáo viên, điện thoại trước), theo canvas bổ sung 20/11 (GV18_b1..b4, b1_*, b3_*, b4_*).
// Bước 1 Xem bài nộp, 2 Điểm 1–5, 3 Trạng thái BTVN (đúng năm trạng thái), 4 Lời phê: Lưu, Lưu và em tiếp theo. Không tự lưu: mỗi em lưu riêng.
// Máy chủ: app.lms_grading_sheet, app.lms_save_grade (ghi vào BTVN của buổi giao, Q1), app.lms_reopen_submission (hộp xác nhận, Q12), app.lms_grading_list (em tiếp theo, Q8).
// Lệch khung có chủ đích (Chat 02:29, phương án B): chưa bật lưu tệp nên bước 1 chưa hiện ảnh bài nộp (nói rõ bằng chữ). Chưa làm bản máy tính «Lưu cả bảng» (Q9).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField } from '../../ui/Field';
import { ChoiceCards } from '../../ui/Lms';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { cn } from '../../ui/cn';
import { useToast } from '../../ui/toastContext';
import { SCORES, type HomeworkStatus } from './homework';
import {
  STATUS_HELP,
  gradeError,
  nextUngraded,
  scoreToSend,
  scoreWillBeDropped,
  statusLabel,
  type GradingList,
  type GradingSheet,
} from './lmsGrading';
import { flushSync } from 'react-dom';

const STEPS = ['XEM BÀI NỘP', 'ĐIỂM', 'TRẠNG THÁI', 'LỜI PHÊ'];

export function LmsGradingPage() {
  const supabase = useDb();
  const { classId = '', assignmentId = '', studentId = '' } = useParams();
  const sheet = useQuery({
    queryKey: ['gv-lms-sheet', assignmentId, studentId],
    queryFn: () =>
      rpc<GradingSheet>(supabase, 'lms_grading_sheet', {
        p_assignment_id: assignmentId,
        p_student_id: studentId,
      }),
  });
  const listPath = `/gv/lop/${classId}/bai-giao/${assignmentId}/cham`;
  const back = (
    <Link className="text-link underline" to={listPath}>
      Chấm bài nộp
    </Link>
  );
  if (sheet.isPending)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">Chấm bài</h1>
        <Spinner />
      </div>
    );
  if (sheet.isError)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <QueryErrorView
          error={sheet.error}
          subject="phiếu chấm này"
          onRetry={() => void sheet.refetch()}
        />
      </div>
    );
  return (
    <GradingForm
      key={studentId}
      sheet={sheet.data}
      classId={classId}
      assignmentId={assignmentId}
      studentId={studentId}
      listPath={listPath}
      back={back}
      onReload={() => void sheet.refetch()}
    />
  );
}

function GradingForm({
  sheet,
  classId,
  assignmentId,
  studentId,
  listPath,
  back,
  onReload,
}: {
  sheet: GradingSheet;
  classId: string;
  assignmentId: string;
  studentId: string;
  listPath: string;
  back: React.ReactNode;
  onReload: () => void;
}) {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const submitted = sheet.submission?.submitted_at != null;
  const locked = sheet.submission?.graded_at != null;
  const [step, setStep] = useState(1);
  const [score, setScore] = useState<number | null>(sheet.grade?.score ?? null);
  const [status, setStatus] = useState<HomeworkStatus | null>(
    sheet.grade?.status_code ?? sheet.default_status,
  );
  const [note, setNote] = useState(sheet.grade?.note ?? '');
  const [dirty, setDirty] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reopen, setReopen] = useState(false);
  const mark =
    <T,>(set: (v: T) => void) =>
    (v: T) => {
      set(v);
      setDirty(true);
    };

  const save = useMutation({
    mutationFn: () =>
      rpc<{ version: number }>(supabase, 'lms_save_grade', {
        p_assignment_id: assignmentId,
        p_student_id: studentId,
        p_status: status,
        p_score: status === null ? null : scoreToSend(status, score),
        p_note: note.trim() === '' ? null : note.trim(),
        p_version: sheet.grade?.version ?? 0,
      }),
  });
  const reopenMut = useMutation({
    mutationFn: () =>
      rpc<{ id: string }>(supabase, 'lms_reopen_submission', {
        p_assignment_id: assignmentId,
        p_student_id: studentId,
      }),
  });

  async function afterSave(goNext: boolean) {
    flushSync(() => setDirty(false));
    await queryClient.invalidateQueries({ queryKey: ['gv-lms-grading', assignmentId] });
    await queryClient.invalidateQueries({ queryKey: ['gv-lms-list', classId] });
    await queryClient.invalidateQueries({ queryKey: ['gv-lms-sheet', assignmentId] });
    toast({ tone: 'success', title: 'Đã lưu kết quả chấm' });
    if (!goNext) return void navigate(listPath, { replace: true });
    const list = await rpc<GradingList>(supabase, 'lms_grading_list', {
      p_assignment_id: assignmentId,
      p_filter: null,
    });
    const next = nextUngraded(list.rows, studentId);
    void navigate(next ? `${listPath}/${next.student_id}` : listPath, { replace: true });
  }
  async function onSave(goNext: boolean) {
    const problem = gradeError(status, score);
    if (problem) return setError(problem);
    setError(null);
    try {
      await save.mutateAsync();
      await afterSave(goNext);
    } catch (e) {
      setError(errorOf(e).message);
    }
  }
  async function onReopen() {
    try {
      await reopenMut.mutateAsync();
      setReopen(false);
      toast({ tone: 'success', title: 'Đã mở lại bài' });
      onReload();
      void queryClient.invalidateQueries({ queryKey: ['gv-lms-grading', assignmentId] });
    } catch (e) {
      setReopen(false);
      setError(errorOf(e).message);
    }
  }

  const dropped = scoreWillBeDropped(status, score);
  const sub = sheet.submission;
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4 p-3">
      <UnsavedGuard
        when={dirty}
        title="Rời màn khi chưa lưu?"
        description="Kết quả chấm của em này chưa được lưu. Rời màn thì các thay đổi này mất."
      />
      <p className="text-caption text-fg-muted">
        {back} › {sheet.student.full_name}
      </p>
      <div>
        <h1 className="text-h2">{sheet.student.full_name}</h1>
        <p className="text-fg-muted">Chấm bài · {sheet.assignment.title}</p>
        <p className="text-caption font-semibold text-fg-muted" aria-live="polite">
          BƯỚC {step}/4 · {STEPS[step - 1]}
        </p>
      </div>
      {error !== null && (
        <Alert tone="danger" title="Chưa lưu được.">
          {error}
        </Alert>
      )}
      {sheet.assignment.status === 'DA_GO' && (
        <Alert tone="warning" title="Bài này đã gỡ.">
          Bài đã gỡ không chấm được.
        </Alert>
      )}
      {locked && (
        <Alert tone="info" title="Bài đã chấm, bài nộp đang khoá.">
          Mở lại để em nộp lại được; điểm cũ giữ đến khi chấm lại.
          <div className="mt-2">
            <Button onClick={() => setReopen(true)}>Mở lại</Button>
          </div>
        </Alert>
      )}

      <div className="flex flex-wrap items-center gap-2">
        {submitted ? (
          <>
            {sub?.is_late && <Tag tone="warning">Nộp muộn</Tag>}
            {sub?.submitted_at && (
              <span className="text-caption text-fg-muted">
                Nộp lúc {formatDateTime(sub.submitted_at)}
              </span>
            )}
            {sub && sub.attempt_count > 1 && <Tag>Nộp lại {sub.attempt_count - 1} lần</Tag>}
          </>
        ) : (
          <Tag>Chưa nộp</Tag>
        )}
        {sheet.student.absent_at_session && <Tag tone="neutral">Vắng buổi giao bài</Tag>}
      </div>

      {step === 1 && (
        <section className="flex flex-col gap-2" aria-label="Xem bài nộp">
          {submitted ? (
            <Alert tone="info" title="Chưa bật lưu tệp.">
              Bài nộp có {sub?.pages.length ?? 0} trang nhưng chưa xem được ảnh ở bản này. Bạn vẫn
              chấm điểm và trạng thái ở các bước sau.
            </Alert>
          ) : (
            <StateView kind="empty" title="Em chưa nộp bài">
              Tới lúc chấm, chọn Nộp sau hoặc Không làm
              {sheet.student.absent_at_session
                ? ' (em vắng buổi giao bài: mặc định Không áp dụng)'
                : ''}{' '}
              ở bước 3.
            </StateView>
          )}
        </section>
      )}

      {step === 2 && (
        <section className="flex flex-col gap-2" aria-label="Điểm">
          <h2 className="text-h3">Điểm 1–5</h2>
          <div role="group" aria-label="Điểm từ 1 đến 5" className="flex gap-2">
            {SCORES.map((s) => (
              <button
                key={s}
                type="button"
                aria-pressed={score === s}
                disabled={!submitted || locked}
                onClick={() => mark(setScore)(score === s ? null : s)}
                className={cn(
                  'focus-ring min-h-target min-w-12 rounded-control border px-3 text-body font-semibold disabled:cursor-not-allowed disabled:opacity-50',
                  score === s ? 'border-border-selected bg-selected' : 'border-border bg-surface',
                )}
              >
                {s}
              </button>
            ))}
          </div>
          <p className="text-caption text-fg-muted">
            Điểm tính khi trạng thái ở bước sau là Đã chấm hoặc Làm chưa xong (R-GV-11).
          </p>
          {!submitted && (
            <p className="text-caption text-fg-muted">Em chưa nộp nên không chấm điểm được.</p>
          )}
        </section>
      )}

      {step === 3 && (
        <section className="flex flex-col gap-2" aria-label="Trạng thái">
          <ChoiceCards
            legend="Trạng thái BTVN"
            value={status}
            onChange={mark(setStatus)}
            options={(
              [
                'DA_CHAM',
                'LAM_CHUA_XONG',
                'KHONG_LAM',
                'NOP_SAU',
                'KHONG_AP_DUNG',
              ] as HomeworkStatus[]
            ).map((code) => {
              const allowed = sheet.allowed_statuses.includes(code) && !locked;
              return {
                value: code,
                label: statusLabel(code),
                description: STATUS_HELP[code],
                disabled: !allowed,
                disabledReason: locked
                  ? 'Mở lại bài để sửa.'
                  : !allowed
                    ? 'Em chưa nộp bài: chỉ chọn được Nộp sau hoặc Không làm.'
                    : undefined,
              };
            })}
          />
          <p className="text-caption text-fg-muted">
            Điểm đã chọn ở bước 2: {score ?? 'chưa chọn'}
          </p>
          {dropped && (
            <Alert tone="warning">
              Trạng thái này không có điểm: điểm đã chọn sẽ bị bỏ khi lưu.
            </Alert>
          )}
        </section>
      )}

      {step === 4 && (
        <section className="flex flex-col gap-2" aria-label="Lời phê">
          <dl className="flex flex-col gap-1 rounded-control bg-canvas px-3 py-2.5">
            <div className="flex justify-between gap-3">
              <dt className="text-fg-muted">Điểm</dt>
              <dd className="font-semibold">
                {status !== null && scoreToSend(status, score) !== null
                  ? scoreToSend(status, score)
                  : '—'}
              </dd>
            </div>
            <div className="flex justify-between gap-3">
              <dt className="text-fg-muted">Trạng thái</dt>
              <dd className="font-semibold">{status ? statusLabel(status) : 'Chưa chọn'}</dd>
            </div>
          </dl>
          <TextAreaField
            label="Lời phê"
            disabled={locked}
            value={note}
            placeholder="Viết lời phê cho em (không bắt buộc)"
            onChange={(e) => mark(setNote)(e.target.value)}
          />
          <p className="text-caption text-fg-muted">Học sinh thấy lời phê ở màn Kết quả bài.</p>
        </section>
      )}

      <div className="flex flex-wrap gap-2">
        {step > 1 && <Button onClick={() => setStep(step - 1)}>Quay lại</Button>}
        {step < 4 && (
          <Button variant="primary" onClick={() => setStep(step + 1)}>
            Tiếp
          </Button>
        )}
        {step === 4 && (
          <>
            <Button
              variant="primary"
              loading={save.isPending}
              disabled={locked || sheet.assignment.status === 'DA_GO'}
              onClick={() => void onSave(false)}
            >
              Lưu
            </Button>
            <Button
              loading={save.isPending}
              disabled={locked || sheet.assignment.status === 'DA_GO'}
              onClick={() => void onSave(true)}
            >
              Lưu và em tiếp theo
            </Button>
          </>
        )}
      </div>
      <p className="text-caption text-fg-muted">Không tự lưu. Mỗi em lưu riêng.</p>

      <ConfirmDialog
        open={reopen}
        onOpenChange={setReopen}
        title="Mở lại bài của em này?"
        description="Bài nộp được mở khoá để em nộp lại. Điểm cũ giữ đến khi bạn chấm lại."
        confirmLabel="Mở lại"
        busy={reopenMut.isPending}
        onConfirm={() => void onReopen()}
      />
    </div>
  );
}
