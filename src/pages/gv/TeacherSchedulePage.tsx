// GV-03 Lịch dạy (cổng giáo viên). Chỉ buổi của mình (giáo viên hoặc trợ giảng được phân công): máy chủ quyết qua app.teacher_my_sessions (R-GV-08).
// Điện thoại: dải 7 ngày + danh sách theo giờ của ngày chọn. Máy tính: lịch cả tuần. Bấm buổi → GV-04 (các bước của buổi).
// Nút Tuần | Tháng: lịch tháng (khuôn K5 Calendar; canvas GV-03 chỉ vẽ tuần nên ghi "chưa có khung"): máy tính là lưới tháng, bấm số ngày sang tuần của ngày đó; điện thoại là danh sách các ngày có buổi.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { cn } from '../../ui/cn';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import {
  DAYS_IN_WEEK,
  addMonths,
  dayChip,
  defaultDay,
  groupByDay,
  inMonth,
  mondayOf,
  monthLabel,
  monthStartOf,
  monthWeeks,
  timeAndRoom,
  typeLabel,
  typeTone,
  weekDays,
  weekLabel,
} from './scheduleLogic';
import {
  addDays,
  formatDayHeading,
  sessionTitle,
  type MySession,
  type MySessionsResult,
} from './todayLogic';
import { GvForbidden } from './GvForbidden';
import { isForbidden } from './forbidden';

const WEEK_LIMIT = 100; // allow-number: trần số dòng một lần gọi của máy chủ (tối đa 100); một tuần dạy không tới mức này
const MONTH_CELL_MAX = 3; // allow-number: số buổi hiện tối đa trong một ô ngày của lịch tháng (hiển thị), còn lại ghi "+n buổi"

type View = 'tuan' | 'thang';

export function TeacherSchedulePage() {
  const supabase = useDb();
  const todayKey = vnDayBounds().dateKey;
  const [monday, setMonday] = useState(() => mondayOf(todayKey));
  const [picked, setPicked] = useState<string | null>(null);
  const [view, setView] = useState<View>('tuan');
  const [month, setMonth] = useState(() => monthStartOf(todayKey));
  const narrow = useMedia(NARROW_TABLE);
  const days = weekDays(monday);
  const weeks = monthWeeks(month);
  // Khoảng ngày cần tải: một tuần, hoặc cả lưới tháng (từ Thứ Hai đầu tới Chủ Nhật cuối).
  const from = view === 'tuan' ? monday : (weeks[0]?.[0] ?? monday);
  const to = view === 'tuan' ? addDays(monday, DAYS_IN_WEEK - 1) : (weeks.at(-1)?.at(-1) ?? monday);
  const query = useQuery({
    queryKey: ['gv-schedule', from, to],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: from,
        p_to: to,
        p_limit: WEEK_LIMIT,
      }),
    refetchOnWindowFocus: true,
  });
  const go = (key: string) => {
    setMonday(key);
    setPicked(null);
  };
  const header = (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-h2">Lịch dạy</h1>
        <Link className="tap inline-flex items-center text-link underline" to="/gv/gio-day">
          Giờ dạy của tôi
        </Link>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Tag>Chỉ buổi của tôi (R-GV-08)</Tag>
        <div role="group" aria-label="Kiểu xem" className="flex gap-1">
          <Button
            variant={view === 'tuan' ? 'primary' : 'secondary'}
            aria-pressed={view === 'tuan'}
            onClick={() => setView('tuan')}
          >
            Tuần
          </Button>
          <Button
            variant={view === 'thang' ? 'primary' : 'secondary'}
            aria-pressed={view === 'thang'}
            onClick={() => setView('thang')}
          >
            Tháng
          </Button>
        </div>
        {view === 'tuan' ? (
          <>
            <Button variant="secondary" onClick={() => go(addDays(monday, -DAYS_IN_WEEK))}>
              Tuần trước
            </Button>
            <Button variant="secondary" onClick={() => go(mondayOf(todayKey))}>
              Tuần này
            </Button>
            <Button variant="secondary" onClick={() => go(addDays(monday, DAYS_IN_WEEK))}>
              Tuần sau
            </Button>
            <p className="text-body text-fg-muted" aria-live="polite">
              Tuần {weekLabel(monday)}
            </p>
          </>
        ) : (
          <>
            <Button variant="secondary" onClick={() => setMonth(addMonths(month, -1))}>
              Tháng trước
            </Button>
            <Button variant="secondary" onClick={() => setMonth(monthStartOf(todayKey))}>
              Tháng này
            </Button>
            <Button variant="secondary" onClick={() => setMonth(addMonths(month, 1))}>
              Tháng sau
            </Button>
            <p className="text-body text-fg-muted" aria-live="polite">
              {monthLabel(month)}
            </p>
          </>
        )}
      </div>
    </div>
  );

  if (query.isPending)
    return (
      <div className="mx-auto flex max-w-5xl flex-col gap-3">
        {header}
        <Spinner />
      </div>
    );
  if (query.isError)
    return (
      <div className="mx-auto flex max-w-5xl flex-col gap-3">
        {header}
        {isForbidden(query.error) ? (
          <GvForbidden kind="schedule" />
        ) : (
          <Alert tone="danger">{errorOf(query.error).message}</Alert>
        )}
        <div>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      </div>
    );

  if (view === 'thang') {
    const allDays = weeks.flat();
    const byMonthDay = groupByDay(query.data.rows, allDays);
    const truncated = query.data.total > query.data.rows.length;
    return (
      <div className="mx-auto flex max-w-5xl flex-col gap-4">
        {header}
        {truncated && (
          <Alert tone="warning">
            Chỉ hiện {query.data.rows.length}/{query.data.total} buổi của tháng này; xem theo tuần
            để thấy đủ.
          </Alert>
        )}
        {query.data.rows.length === 0 && (
          <StateView kind="empty" title="Tháng này bạn không có buổi dạy" headingLevel={2}>
            Chọn tháng khác để xem lịch.
          </StateView>
        )}
        {narrow ? (
          <div className="flex flex-col gap-3">
            {allDays
              .filter((d) => inMonth(d, month) && (byMonthDay[d]?.length ?? 0) > 0)
              .map((d) => (
                <section key={d} aria-label={formatDayHeading(d)} className="flex flex-col gap-2">
                  <h2 className="text-caption font-semibold text-fg-label">
                    {formatDayHeading(d).toUpperCase()}
                  </h2>
                  <SessionList sessions={byMonthDay[d] ?? []} emptyText="" />
                </section>
              ))}
          </div>
        ) : (
          <div role="grid" aria-label={monthLabel(month)} className="flex flex-col gap-1">
            {weeks.map((week) => (
              <div role="row" key={week[0]} className="grid grid-cols-7 gap-1">
                {week.map((d) => {
                  const list = byMonthDay[d] ?? [];
                  const dim = !inMonth(d, month);
                  return (
                    <div
                      role="gridcell"
                      key={d}
                      aria-label={`${formatDayHeading(d)}, ${list.length} buổi`}
                      className={cn(
                        'flex min-h-24 min-w-0 flex-col gap-1 rounded-control border p-1 text-caption',
                        d === todayKey ? 'border-brand-600' : 'border-border',
                        dim && 'bg-surface-subtle text-fg-muted',
                      )}
                    >
                      <button
                        type="button"
                        className="self-start font-semibold text-link hover:underline"
                        aria-label={`Xem tuần của ngày ${d.slice(8, 10)}`}
                        onClick={() => {
                          setMonday(mondayOf(d));
                          setPicked(d);
                          setView('tuan');
                        }}
                      >
                        {d.slice(8, 10)}
                      </button>
                      {list.slice(0, MONTH_CELL_MAX).map((s) => (
                        <Link
                          key={s.session_id}
                          to={`/gv/buoi/${s.session_id}`}
                          className="truncate rounded-control bg-brand-100 px-1 text-brand-800 hover:underline"
                        >
                          {`${s.start_time.slice(0, 5)} ${sessionTitle(s)}`}
                        </Link>
                      ))}
                      {list.length > MONTH_CELL_MAX && (
                        <span className="text-fg-muted">+{list.length - MONTH_CELL_MAX} buổi</span>
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  const byDay = groupByDay(query.data.rows, days);
  const selected = picked && days.includes(picked) ? picked : defaultDay(days, todayKey);
  const empty = query.data.rows.length === 0;
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-4">
      {header}
      {empty && (
        <StateView
          kind="empty"
          title="Tuần này bạn chưa có buổi dạy"
          headingLevel={2}
          actions={
            monday !== mondayOf(todayKey) ? (
              <Button variant="secondary" onClick={() => go(mondayOf(todayKey))}>
                Về tuần này
              </Button>
            ) : undefined
          }
        >
          Chỉ hiện buổi của lớp bạn được phân công (R-GV-08).
        </StateView>
      )}
      {narrow ? (
        <>
          <div role="group" aria-label="Chọn ngày" className="grid grid-cols-7 gap-1">
            {days.map((d) => {
              const chip = dayChip(d);
              const n = byDay[d]?.length ?? 0;
              return (
                <button
                  key={d}
                  type="button"
                  aria-pressed={d === selected}
                  onClick={() => setPicked(d)}
                  className={cn(
                    'flex min-h-11 flex-col items-center rounded-control border px-1 py-1 text-caption',
                    d === selected
                      ? 'border-brand-600 bg-brand-100 text-brand-800'
                      : 'border-border bg-surface',
                  )}
                >
                  <span>{chip.weekday}</span>
                  <span className="font-semibold">{chip.day}</span>
                  {/* Tên đọc lấy từ chữ trong nút rồi thêm ngày đầy đủ, số buổi (luật axe label-content-name-mismatch). */}
                  <span className="sr-only">{`${formatDayHeading(d)}, ${n} buổi`}</span>
                  <span
                    aria-hidden="true"
                    className={cn('size-1.5 rounded-full', n > 0 ? 'bg-current' : 'bg-transparent')}
                  />
                </button>
              );
            })}
          </div>
          <section aria-label={formatDayHeading(selected)} className="flex flex-col gap-2">
            <h2 className="text-caption font-semibold text-fg-label">
              {formatDayHeading(selected).toUpperCase()}
            </h2>
            <SessionList sessions={byDay[selected] ?? []} emptyText="Ngày này không có buổi dạy." />
          </section>
        </>
      ) : (
        <div className="grid grid-cols-7 gap-2">
          {days.map((d) => (
            <section
              key={d}
              aria-label={formatDayHeading(d)}
              className={cn(
                'flex min-w-0 flex-col gap-2 rounded-control border p-2',
                d === todayKey ? 'border-brand-600' : 'border-border',
              )}
            >
              <h2 className="text-caption font-semibold text-fg-label">{formatDayHeading(d)}</h2>
              <SessionList sessions={byDay[d] ?? []} emptyText="Không có buổi." />
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

function SessionList({ sessions, emptyText }: { sessions: MySession[]; emptyText: string }) {
  if (sessions.length === 0) return <p className="text-caption text-fg-muted">{emptyText}</p>;
  return (
    <ul className="flex flex-col gap-2">
      {sessions.map((s) => (
        <li key={s.session_id}>
          <Link
            to={`/gv/buoi/${s.session_id}`}
            className="flex min-h-11 flex-col gap-1 rounded-control border border-border bg-surface p-2 hover:bg-surface-subtle"
          >
            <span className="text-caption tabular text-fg-muted">{timeAndRoom(s)}</span>
            <span className="font-semibold">{sessionTitle(s)}</span>
            {s.my_role === 'TRO_GIANG' && (
              <span className="text-caption text-fg-muted">Trợ giảng</span>
            )}
            <span>
              <Tag tone={typeTone(s.type_code)}>{typeLabel(s)}</Tag>
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
