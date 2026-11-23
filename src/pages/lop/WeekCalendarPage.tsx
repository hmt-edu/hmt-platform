// LOP-08 Lịch tuần cơ sở (khuôn K05): mọi buổi trong tuần theo phòng hoặc theo giáo viên; trùng phòng, trùng giáo viên chỉ cảnh báo, không chặn
// (R-LOP-08); hai lớp cùng nhóm cùng màu viền (R-LOP-14). Dữ liệu một lần gọi app.week_sessions cho cả tuần.
import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { errorOf } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Tag } from '../../ui/Data';
import { WEEKDAY_LABEL, timeText } from './classLabels';
import { classPath } from './classConfig';
import {
  addDays,
  buildRows,
  clashCount,
  groupColor,
  weekDays,
  weekStart,
  type GroupBy,
} from './weekLogic';
import { useWeekSessions } from './useClassData';

export function WeekCalendarPage() {
  const access = useAccess();
  const today = vnDayBounds().dateKey;
  const [start, setStart] = useState(() => weekStart(today));
  const [by, setBy] = useState<GroupBy>('ROOM');
  const branches = access.viewableBranches;
  const [chosen, setChosen] = useState<string | undefined>(undefined);
  const branchId =
    chosen ?? (access.selectedBranch !== 'all' ? access.selectedBranch : access.defaultBranchId);
  const days = useMemo(() => weekDays(start), [start]);
  const query = useWeekSessions(branchId, days[0] ?? start, days[6] ?? start);
  const sessions = useMemo(() => query.data ?? [], [query.data]);
  const rows = useMemo(() => buildRows(sessions, days, by), [sessions, days, by]);
  const clashes = clashCount(sessions);

  if (query.isError) {
    return (
      <StateView
        kind="error"
        title="Không tải được lịch tuần"
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }

  return (
    <div className="flex flex-col gap-3 p-4">
      <header className="flex flex-wrap items-center gap-3">
        <h1 className="text-h3">Lịch tuần cơ sở</h1>
        <div className="flex items-center gap-2">
          <Button onClick={() => setStart(addDays(start, -7))}>Tuần trước</Button>
          <Button onClick={() => setStart(weekStart(today))}>Tuần này</Button>
          <Button onClick={() => setStart(addDays(start, 7))}>Tuần sau</Button>
        </div>
        <span className="text-caption text-fg-muted">
          {formatDate(days[0] ?? start)} – {formatDate(days[6] ?? start)}
        </span>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {branches.length > 1 && (
            <select
              aria-label="Cơ sở"
              className="h-control rounded-control border border-border bg-surface px-2"
              value={branchId ?? ''}
              onChange={(e) => setChosen(e.target.value)}
            >
              {branches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.code} {b.name}
                </option>
              ))}
            </select>
          )}
          <div role="group" aria-label="Xem theo" className="flex gap-1">
            <Button
              variant={by === 'ROOM' ? 'primary' : 'secondary'}
              aria-pressed={by === 'ROOM'}
              onClick={() => setBy('ROOM')}
            >
              Theo phòng
            </Button>
            <Button
              variant={by === 'TEACHER' ? 'primary' : 'secondary'}
              aria-pressed={by === 'TEACHER'}
              onClick={() => setBy('TEACHER')}
            >
              Theo giáo viên
            </Button>
          </div>
        </div>
      </header>

      <ul
        className="flex flex-wrap gap-x-4 gap-y-1 text-caption text-fg-muted"
        aria-label="Chú giải"
      >
        <li>Cùng nhóm: cùng màu viền</li>
        <li>Luân phiên: không báo trùng</li>
        <li>Cảnh báo trùng phòng hoặc giáo viên (không chặn)</li>
      </ul>

      {clashes > 0 && (
        <Alert tone="warning" title={`${clashes} buổi trùng phòng hoặc giáo viên`}>
          Chỉ cảnh báo, không chặn (R-LOP-08). Lớp luân phiên cùng nhóm không báo trùng.
        </Alert>
      )}

      {query.isPending ? (
        <div className="flex min-h-40 items-center justify-center">
          <Spinner />
        </div>
      ) : rows.length === 0 ? (
        <StateView kind="empty" title="Không có buổi nào trong tuần này" headingLevel={2}>
          Đổi tuần hoặc cơ sở để xem tiếp.
        </StateView>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[56rem] border-collapse text-body" aria-label="Lịch tuần">
            <thead>
              <tr>
                <th className="w-40 border-b border-border p-2 text-left">
                  {by === 'ROOM' ? 'Phòng' : 'Giáo viên'}
                </th>
                {days.map((d, i) => (
                  <th key={d} className="border-b border-border p-2 text-left">
                    {WEEKDAY_LABEL[i + 1]}{' '}
                    <span className="text-caption font-normal text-fg-muted">{formatDate(d)}</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.label} className="align-top">
                  <th scope="row" className="border-b border-border p-2 text-left font-medium">
                    {row.label}
                  </th>
                  {row.cells.map((cell, i) => (
                    <td key={days[i]} className="border-b border-border p-1">
                      <ul className="flex flex-col gap-1">
                        {cell.map((s) => (
                          <li
                            key={s.session_id}
                            className="rounded-control border border-border bg-surface p-1.5"
                            style={{ borderLeft: `4px solid ${groupColor(s.group_id)}` }}
                          >
                            <Link
                              to={classPath(s.class_id)}
                              className="font-medium text-link hover:underline"
                            >
                              {s.class_code}
                            </Link>
                            <div className="text-caption text-fg-muted">
                              {timeText(s.start_time)}–{timeText(s.end_time)}
                              {by === 'ROOM'
                                ? s.teacher_name
                                  ? ` · ${s.teacher_name}`
                                  : ''
                                : s.room_name
                                  ? ` · ${s.room_name}`
                                  : ''}
                            </div>
                            {(s.room_clash || s.teacher_clash) && (
                              <Tag tone="warning">
                                {s.room_clash ? 'Trùng phòng' : 'Trùng giáo viên'}
                              </Tag>
                            )}
                          </li>
                        ))}
                      </ul>
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
