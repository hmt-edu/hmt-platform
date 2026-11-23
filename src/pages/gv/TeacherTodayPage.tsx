// GV-02 Hôm nay (cổng giáo viên, ưu tiên điện thoại): buổi dạy trong ngày và việc sắp trễ hạn của các buổi đó (R-V2-37).
// Buổi đã quá hạn không hiện ở đây (xem GV-12). Máy chủ quyết buổi nào hiện (hàm app.teacher_today); trang chỉ đổi chữ.
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, StateView } from '../../ui/Feedback';
import {
  NEXT_LOOKAHEAD_DAYS,
  addDays,
  formatDayHeading,
  formatDeadline,
  formatNextSession,
  hhmm,
  hoursLeftText,
  sessionTitle,
  urgentSessions,
  type MySession,
  type MySessionsResult,
} from './todayLogic';
import { useTodoCount } from './useTodoCount';
import { GvForbidden } from './GvForbidden';
import { isForbidden } from './forbidden';

export function TeacherTodayPage() {
  const supabase = useDb();
  const overdue = useTodoCount() ?? 0;
  const todayKey = vnDayBounds().dateKey;
  const query = useQuery({
    queryKey: ['gv-today', todayKey],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: todayKey,
        p_to: todayKey,
      }),
    refetchOnWindowFocus: true,
  });
  // Hôm nay trống: tìm buổi gần nhất sau hôm nay (một dòng) để báo "Buổi tiếp theo".
  const empty = query.data !== undefined && query.data.rows.length === 0;
  const next = useQuery({
    queryKey: ['gv-next', todayKey],
    enabled: empty,
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: addDays(todayKey, 1),
        p_to: addDays(todayKey, NEXT_LOOKAHEAD_DAYS),
        p_limit: 1,
      }),
  });

  if (query.isPending) {
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <div>
          <h1 className="text-h2">Hôm nay</h1>
          <p className="text-body text-fg-muted">{formatDayHeading(todayKey)}</p>
        </div>
        <div role="status" aria-label="Đang tải" className="flex flex-col gap-2">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-16 animate-pulse rounded-control bg-surface-subtle" />
          ))}
        </div>
      </div>
    );
  }
  if (query.isError) {
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <h1 className="text-h2">Hôm nay</h1>
        {isForbidden(query.error) ? (
          <GvForbidden kind="today" />
        ) : (
          <Alert tone="danger">{errorOf(query.error).message}</Alert>
        )}
        <div>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      </div>
    );
  }

  const rows = query.data.rows;
  const now = new Date();
  const urgent = urgentSessions(rows, now);
  const nextSession = next.data?.rows[0] ?? null;
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4">
      <div>
        <h1 className="text-h2">Hôm nay</h1>
        <p className="text-body text-fg-muted">{formatDayHeading(todayKey)}</p>
      </div>

      {rows.length === 0 ? (
        <StateView kind="empty" title="Hôm nay bạn không có buổi dạy" headingLevel={2}>
          {overdue > 0 ? (
            <>
              Có {overdue} việc quá hạn ·{' '}
              <Link className="text-link underline" to="/gv/viec-can-lam">
                Xem
              </Link>
              .
            </>
          ) : (
            'Không có việc sắp trễ hạn.'
          )}
          {nextSession && ` Buổi tiếp theo: ${formatNextSession(nextSession)}.`}
          {
            <span className="mt-2 block">
              <Link className="text-link underline" to="/gv/lich-day">
                Xem lịch dạy
              </Link>
            </span>
          }
        </StateView>
      ) : (
        <>
          {urgent.length > 0 && (
            <section aria-labelledby="gv-urgent" className="flex flex-col gap-2">
              <h2 id="gv-urgent" className="text-caption font-semibold text-fg-label">
                VIỆC SẮP TRỄ HẠN
              </h2>
              <ul className="flex flex-col gap-2">
                {urgent.map((s) => (
                  <li key={s.session_id}>
                    <Link
                      to={`/gv/buoi/${s.session_id}`}
                      className="tap block rounded-control border border-border bg-warning-subtle p-3 text-on-warning-subtle hover:underline"
                    >
                      <p className="font-semibold">{sessionTitle(s)}</p>
                      <p className="text-caption">
                        Kết thúc {hhmm(s.end_time)} · {formatDeadline(s.deadline_at, todayKey)}
                      </p>
                      <p className="text-caption font-medium">
                        {hoursLeftText(s.deadline_at, now)}
                      </p>
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          )}

          <section aria-labelledby="gv-sessions" className="flex flex-col gap-2">
            <h2 id="gv-sessions" className="text-caption font-semibold text-fg-label">
              BUỔI HÔM NAY · {rows.length} BUỔI
            </h2>
            <ul className="flex flex-col gap-2">
              {rows.map((s) => (
                <SessionItem key={s.session_id} session={s} />
              ))}
            </ul>
          </section>
        </>
      )}
    </div>
  );
}

function SessionItem({ session: s }: { session: MySession }) {
  // Thẻ buổi bấm được: mở trang các bước của buổi (như Lịch dạy), T2-23.
  return (
    <li>
      <Link
        to={`/gv/buoi/${s.session_id}`}
        className="tap flex gap-3 rounded-control border border-border bg-surface p-3 hover:bg-surface-subtle"
      >
        <div className="w-12 shrink-0 text-body tabular">
          <p className="font-semibold">{hhmm(s.start_time)}</p>
          <p className="text-fg-muted">{hhmm(s.end_time)}</p>
        </div>
        <div className="min-w-0 flex-1">
          <p className="font-semibold">{sessionTitle(s)}</p>
          {(s.room_name || s.session_type_name) && (
            <p className="text-caption text-fg-muted">
              {[s.room_name, s.session_type_name].filter(Boolean).join(' · ')}
            </p>
          )}
          {s.my_role === 'TRO_GIANG' && <p className="text-caption text-fg-muted">Trợ giảng</p>}
          <div className="mt-1">
            {s.status_code === 'DONE' ? (
              <Tag tone="success">Đã hoàn tất</Tag>
            ) : (
              <Tag tone="warning">Cần hoàn tất</Tag>
            )}
          </div>
        </div>
      </Link>
    </li>
  );
}
