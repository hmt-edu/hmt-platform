import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { Button, ButtonLink } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDate, formatDateTime, formatNumber } from '../../lib/format';
import { cn } from '../../ui/cn';
import { Tag } from '../../ui/Data';
import type { SessionOverview } from './sessionContent';
import {
  buildSteps,
  deadlineText,
  nextStep,
  progressOf,
  STATE_LABEL,
  stepCountWord,
  type SessionStep,
  type StepState,
} from './sessionSteps';
import { useSessionOverview } from './useSessionContent';
import { CompleteDialog } from './CompleteDialog';

/** Đường dẫn mở từng bước. Điểm danh do Code 1 thêm đường dẫn; nhận xét chưa có màn (Sắp có). */
function stepPath(sessionId: string, key: SessionStep['key']): string | null {
  if (key === 'attendance') return `/gv/buoi/${sessionId}/diem-danh`;
  if (key === 'content') return `/gv/buoi/${sessionId}/noi-dung`;
  if (key === 'grading') return `/gv/buoi/${sessionId}/cham-nhan-xet`;
  if (key === 'homework') return `/gv/buoi/${sessionId}/cham-btvn`;
  return null;
}

const TONE: Record<StepState, string> = {
  DONE: 'border-success text-success',
  DOING: 'border-brand-600 text-brand-700',
  TODO: 'border-border text-fg-muted',
  WAIT: 'border-border text-fg-muted',
  SKIP: 'border-border text-fg-muted',
};

/**
 * GV-04 · Buổi dạy: các bước của một buổi (điểm danh, nội dung và BTVN, chấm nhận xét, chấm BTVN buổi trước), tiến độ, hạn hoàn tất.
 * Luật R-GIO-06, R-GV-04, R-GV-05, R-V2-35. Dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done (migration 135): buổi Done hiện dấu; buổi chưa Done chỉ hiện hạn.
 */
export function SessionStepsPage() {
  const { sessionId } = useParams();
  const query = useSessionOverview(sessionId);

  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const error = errorOf(query.error);
    return (
      <StateView
        kind={error.code === FORBIDDEN_CODE ? 'forbidden' : 'error'}
        title={
          error.code === FORBIDDEN_CODE ? 'Bạn không có quyền xem buổi này' : 'Không mở được buổi'
        }
        actions={
          error.code === FORBIDDEN_CODE ? undefined : (
            <Button variant="primary" onClick={() => void query.refetch()}>
              Thử lại
            </Button>
          )
        }
      >
        {error.message}
      </StateView>
    );
  }
  return <Steps overview={query.data} />;
}

function Steps({ overview }: { overview: SessionOverview }) {
  const steps = buildSteps(overview);
  const { done, total } = progressOf(steps);
  const next = nextStep(steps);
  const listed = overview.status_code === 'DA_CHOT' || overview.status_code === 'DONE';
  const isDone = overview.status_code === 'DONE';
  const missing = overview.grading_missing;
  const [completing, setCompleting] = useState(false);

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-4 p-4">
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link to="/gv" className="inline-flex min-h-11 items-center underline">
          Hôm nay
        </Link>
        {' › Buổi dạy'}
      </nav>
      <header className="flex flex-col gap-1">
        <p className="text-caption text-fg-muted uppercase">
          {overview.class_code}
          {overview.subject_name ? ` · ${overview.subject_name}` : ''}
        </p>
        <h1 className="text-h3">
          {overview.session_no ? `Buổi ${overview.session_no} · ` : ''}Buổi dạy
        </h1>
        <p className="text-caption text-fg-muted">
          {formatDate(overview.session_date)} · {overview.start_time.slice(0, 5)}–
          {overview.end_time.slice(0, 5)}
          {overview.type_name ? ` · ${overview.type_name}` : ''}
        </p>
      </header>

      {!listed && (
        <Alert tone="info" title="Buổi chưa chốt danh sách.">
          Chưa có dòng điểm danh nên chưa điểm danh, chưa chấm được. Giáo viên không tạo dòng điểm
          danh. Danh sách sẽ được hệ thống chốt trước giờ học. Dấu thời hạn chỉ tính khi buổi đã
          chốt danh sách và đủ các bước (bước Bỏ qua không tính).
        </Alert>
      )}

      <section
        aria-labelledby="gv04-progress"
        className="flex flex-col gap-1 rounded-lg border border-border p-3"
      >
        <div className="flex items-center justify-between gap-2">
          <h2 id="gv04-progress" className="text-h4">
            Tiến độ
          </h2>
          <span className="text-body font-medium">
            {done}/{total} bước
          </span>
        </div>
        {isDone ? (
          <p className="text-caption text-fg-muted">
            Buổi đã Done.
            {overview.completion != null && (
              <>
                {' '}
                <Tag tone={overview.completion.late ? 'danger' : 'success'}>
                  {overview.completion.late
                    ? `Trễ hạn ${formatNumber(overview.completion.late_hours)} giờ`
                    : 'Đúng hạn'}
                </Tag>{' '}
                (hệ thống ghi lúc Done, không đổi khi sửa sau).
              </>
            )}
          </p>
        ) : (
          <p className="text-caption text-fg-muted">
            Hạn hoàn tất {formatDateTime(overview.deadline_at)} ·{' '}
            {deadlineText(overview.deadline_at, new Date())}
          </p>
        )}
        {!isDone && (
          <p className="text-caption text-fg-muted">
            Dấu Đúng hạn hoặc Trễ hạn tự đóng khi đủ {stepCountWord(total)} bước.
          </p>
        )}
      </section>

      <ol className="flex flex-col gap-2" aria-label="Các bước của buổi">
        {steps.map((step, index) => {
          const path = stepPath(overview.session_id, step.key);
          const open =
            path && (step.state === 'TODO' || step.state === 'DOING' || step.state === 'DONE');
          return (
            <li
              key={step.key}
              className="flex items-center gap-3 rounded-lg border border-border p-3"
            >
              <span
                aria-hidden="true"
                className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand-100 text-caption text-brand-700"
              >
                {index + 1}
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-body font-medium">{step.title}</p>
                <p className="text-caption text-fg-muted">{step.detail}</p>
              </div>
              <span
                className={cn(
                  'shrink-0 rounded-full border px-2 py-0.5 text-caption',
                  TONE[step.state],
                )}
              >
                {STATE_LABEL[step.state]}
              </span>
              {open ? (
                <ButtonLink to={path} size="sm">
                  Mở
                </ButtonLink>
              ) : step.state === 'TODO' || step.state === 'DOING' ? (
                <span className="shrink-0 text-caption text-fg-muted">Sắp có</span>
              ) : null}
            </li>
          );
        })}
      </ol>

      {listed && (
        <Button variant={isDone ? 'secondary' : 'primary'} onClick={() => setCompleting(true)}>
          Hoàn tất
        </Button>
      )}
      <CompleteDialog overview={overview} open={completing} onOpenChange={setCompleting} />

      {!isDone && listed && (done < total || overview.pending_reason) && (
        <Alert tone="warning" title="Kiểm còn thiếu">
          {overview.pending_reason ?? 'Chưa đủ các bước.'}
          {missing.length > 0 && <> Chưa đủ: {missing.join(', ')} (em có mặt cần đủ điểm).</>}
          {next && stepPath(overview.session_id, next.key) && (
            <span className="mt-2 block">
              <ButtonLink to={stepPath(overview.session_id, next.key)!} variant="primary" size="sm">
                Mở bước {next.title.toLowerCase()}
              </ButtonLink>
            </span>
          )}
        </Alert>
      )}
    </div>
  );
}
