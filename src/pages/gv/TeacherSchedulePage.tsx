// GV-03 Lịch dạy (cổng giáo viên). Chỉ buổi của mình (giáo viên hoặc trợ giảng được phân công): máy chủ quyết qua app.teacher_my_sessions (R-GV-08).
// Điện thoại: dải 7 ngày + danh sách theo giờ của ngày chọn. Máy tính: lịch cả tuần. Bấm buổi → GV-04 (các bước của buổi).
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
  dayChip,
  defaultDay,
  groupByDay,
  mondayOf,
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

const WEEK_LIMIT = 100; // allow-number: trần số dòng một lần gọi của máy chủ (tối đa 100); một tuần dạy không tới mức này

export function TeacherSchedulePage() {
  const supabase = useDb();
  const todayKey = vnDayBounds().dateKey;
  const [monday, setMonday] = useState(() => mondayOf(todayKey));
  const [picked, setPicked] = useState<string | null>(null);
  const narrow = useMedia(NARROW_TABLE);
  const days = weekDays(monday);
  const query = useQuery({
    queryKey: ['gv-schedule', monday],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: monday,
        p_to: addDays(monday, DAYS_IN_WEEK - 1),
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
      <h1 className="text-h2">Lịch dạy</h1>
      <div className="flex flex-wrap items-center gap-2">
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
        <Alert tone="danger">{errorOf(query.error).message}</Alert>
        <div>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      </div>
    );

  const byDay = groupByDay(query.data.rows, days);
  const selected = picked && days.includes(picked) ? picked : defaultDay(days, todayKey);
  const empty = query.data.rows.length === 0;
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-4">
      {header}
      {empty && (
        <StateView kind="empty" title="Tuần này bạn không có buổi dạy" headingLevel={2}>
          Chọn tuần khác để xem lịch.
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
                  aria-label={`${formatDayHeading(d)}, ${n} buổi`}
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
