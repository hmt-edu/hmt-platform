// GV-12 Việc cần làm (cổng giáo viên): buổi chưa hoàn tất kèm hạn, và bài BTVN «Nộp sau» chờ cập nhật. Bấm Mở tới GV-04 (buổi) hoặc GV-08 (BTVN).
// Mục «phiếu test chờ chấm» (R-CRM-11): phiếu kiểm tra đầu vào giao cho giáo viên chấm, bấm Mở tới GV-15. Luật R-GV-05, R-GV-11. Chỉ đọc: màn không đổi tình trạng buổi hay bài.
import { useQueries, useQuery } from '@tanstack/react-query';
import { errorOf, rpc, useDb } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Button, ButtonLink } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { formatDateTime } from '../../lib/format';
import type { PendingTestsResult } from './testGrading';
import { cn } from '../../ui/cn';
import type { GradingSheet } from './homework';
import { addDays, formatDayHeading, hhmm, type MySessionsResult } from './todayLogic';
import {
  deadlineLeftText,
  groupLate,
  isOverdue,
  latestSessionPerClass,
  LOOKBACK_DAYS,
  sessionLine,
  sortByDeadline,
} from './todoLogic';
import { GvForbidden } from './GvForbidden';
import { isForbidden } from './forbidden';

const MAX_ROWS = 100; // allow-number: trần phân trang của máy chủ (app.teacher_my_sessions)

export function TeacherTodoPage() {
  const supabase = useDb();
  const todayKey = vnDayBounds().dateKey;
  const open = useQuery({
    queryKey: ['gv-todo-open'],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'CAN_LAM',
        p_limit: MAX_ROWS,
      }),
    refetchOnWindowFocus: true,
  });
  const recent = useQuery({
    queryKey: ['gv-todo-recent', todayKey],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: addDays(todayKey, -LOOKBACK_DAYS),
        p_to: todayKey,
        p_limit: MAX_ROWS,
      }),
    refetchOnWindowFocus: true,
  });
  const tests = useQuery({
    queryKey: ['gv-todo-tests'],
    queryFn: () =>
      rpc<PendingTestsResult>(supabase, 'teacher_my_pending_tests', { p_limit: MAX_ROWS }),
    refetchOnWindowFocus: true,
  });
  const classes = recent.data ? latestSessionPerClass(recent.data.rows, todayKey) : [];
  const sheets = useQueries({
    queries: classes.map((s) => ({
      queryKey: ['gv-todo-late', s.session_id],
      queryFn: () =>
        rpc<GradingSheet>(supabase, 'homework_grading_sheet', { p_session_id: s.session_id }),
      retry: false,
    })),
  });

  const now = new Date();
  return (
    <div className="mx-auto flex w-full max-w-xl flex-col gap-4">
      <div>
        <h1 className="text-h2">Cần làm</h1>
        <p className="text-body text-fg-muted">{formatDayHeading(todayKey)}</p>
        <p className="text-caption text-fg-muted">Sắp theo hạn gần nhất. Chỉ hiện việc của bạn.</p>
      </div>

      <section aria-labelledby="gv12-open" className="flex flex-col gap-2">
        <h2 id="gv12-open" className="text-caption font-semibold text-fg-label">
          BUỔI CHƯA HOÀN TẤT{open.data ? ` · ${open.data.total}` : ''}
        </h2>
        {open.isPending ? (
          <Spinner />
        ) : open.isError && isForbidden(open.error) ? (
          <GvForbidden />
        ) : open.isError ? (
          <Alert tone="danger">
            {errorOf(open.error).message}{' '}
            <Button size="sm" onClick={() => void open.refetch()}>
              Thử lại
            </Button>
          </Alert>
        ) : open.data.rows.length === 0 ? (
          <p
            className="rounded-control border border-border p-3 text-body"
            data-testid="gv12-empty"
          >
            <span className="font-semibold">Không có buổi nào chưa hoàn tất.</span> Thầy cô đã làm
            đủ việc của các buổi đã dạy.
          </p>
        ) : (
          <ul className="flex flex-col gap-2" aria-label="Buổi chưa hoàn tất">
            {sortByDeadline(open.data.rows).map((s) => {
              const late = isOverdue(s.deadline_at, now);
              return (
                <li
                  key={s.session_id}
                  className={cn(
                    'flex items-center gap-3 rounded-control border p-3',
                    late
                      ? 'border-border bg-danger-subtle text-on-danger-subtle'
                      : 'border-border bg-warning-subtle text-on-warning-subtle',
                  )}
                >
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{sessionLine(s)}</p>
                    <p className="text-caption">
                      {formatDayHeading(s.session_date)} · {hhmm(s.start_time)}–{hhmm(s.end_time)}
                    </p>
                    <p className="text-caption font-medium" data-testid="gv12-deadline">
                      {deadlineLeftText(s.deadline_at, now)}
                    </p>
                    {s.pending_reason && <p className="text-caption">{s.pending_reason}</p>}
                  </div>
                  <ButtonLink to={`/gv/buoi/${s.session_id}`} size="sm">
                    Mở
                  </ButtonLink>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section aria-labelledby="gv12-late" className="flex flex-col gap-2">
        <h2 id="gv12-late" className="text-caption font-semibold text-fg-label">
          BÀI NỘP SAU CHỜ CẬP NHẬT
        </h2>
        {recent.isPending || (classes.length > 0 && sheets.some((q) => q.isPending)) ? (
          <Spinner />
        ) : recent.isError ? (
          <Alert tone="danger">
            {errorOf(recent.error).message}{' '}
            <Button size="sm" onClick={() => void recent.refetch()}>
              Thử lại
            </Button>
          </Alert>
        ) : (
          <LateList
            groups={classes.flatMap((s, i) => {
              const data = sheets[i]?.data;
              const g = data ? groupLate(s, data.late) : null;
              return g ? [g] : [];
            })}
            failed={sheets.filter((q) => q.isError).length}
          />
        )}
      </section>

      <section aria-labelledby="gv12-tests" className="flex flex-col gap-2">
        <h2 id="gv12-tests" className="text-caption font-semibold text-fg-label">
          PHIẾU TEST CHỜ CHẤM{tests.data ? ` · ${tests.data.total}` : ''}
        </h2>
        {tests.isPending ? (
          <Spinner />
        ) : tests.isError ? (
          <Alert tone="danger">
            {errorOf(tests.error).message}{' '}
            <Button size="sm" onClick={() => void tests.refetch()}>
              Thử lại
            </Button>
          </Alert>
        ) : tests.data.rows.length === 0 ? (
          <p
            className="rounded-control border border-border p-3 text-body"
            data-testid="gv12-tests-empty"
          >
            <span className="font-semibold">Không có phiếu test chờ chấm.</span>
          </p>
        ) : (
          <ul className="flex flex-col gap-2" aria-label="Phiếu test chờ chấm">
            {tests.data.rows.map((p) => (
              <li
                key={p.test_id}
                className="flex items-center gap-3 rounded-control border border-border bg-surface p-3"
              >
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{p.student_name ?? 'Học sinh'}</p>
                  <p className="text-caption text-fg-muted">
                    {p.exam_name ?? p.subject_name ?? 'Kiểm tra đầu vào'} · làm bài{' '}
                    {formatDateTime(p.scheduled_at)}
                  </p>
                  <p className="text-caption font-medium">Chờ chấm</p>
                </div>
                <ButtonLink to={`/gv/phieu-test/${p.test_id}`} size="sm">
                  Mở
                </ButtonLink>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function LateList({ groups, failed }: { groups: ReturnType<typeof groupLate>[]; failed: number }) {
  const real = groups.filter((g): g is NonNullable<typeof g> => g !== null);
  return (
    <>
      {failed > 0 && (
        <Alert tone="warning" title="Chưa tải được một số lớp">
          {failed} lớp chưa kiểm được bài Nộp sau. Tải lại trang để thử lại.
        </Alert>
      )}
      {real.length === 0 ? (
        <p className="rounded-control border border-border p-3 text-body" data-testid="gv12-empty">
          <span className="font-semibold">Không có bài Nộp sau chờ cập nhật.</span> Các bài BTVN của
          em vắng đều đã có kết quả.
        </p>
      ) : (
        <ul className="flex flex-col gap-2" aria-label="Bài Nộp sau chờ cập nhật">
          {real.map((g) => (
            <li
              key={g.openSessionId}
              className="flex items-start gap-3 rounded-control border border-border bg-surface p-3"
            >
              <div className="min-w-0 flex-1">
                <p className="font-semibold">
                  {g.title} · {g.total} bài
                </p>
                {g.items.map((item) => (
                  <p key={item.assignedSessionId} className="text-caption text-fg-muted">
                    {item.sessionNo ? `Buổi ${item.sessionNo}` : 'BTVN'} ({item.date.slice(8, 10)}/
                    {item.date.slice(5, 7)}): {item.names.join(', ')}
                  </p>
                ))}
              </div>
              <ButtonLink to={`/gv/buoi/${g.openSessionId}/cham-btvn`} size="sm">
                Mở
              </ButtonLink>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
