// HT-06 Lịch học (cổng học sinh): các buổi của em trong tuần, nhóm theo ngày. Chỉ đọc; quyền do máy chủ quyết (app.portal_schedule).
// Khung HT06_ds, _tai, _trong, _loi (canvas 9189). Tuần chọn bằng nút Tuần trước/này/sau.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { DAYS_IN_WEEK, mondayOf, weekDays, weekLabel } from '../gv/scheduleLogic';
import { addDays, formatDayHeading } from '../gv/todayLogic';
import {
  groupSessionsByDay,
  timeRange,
  useChildren,
  usePortalSchedule,
  type PortalSession,
} from './portalData';

const CANCELLED = ['HUY_CO_PHI', 'HUY_KHONG_PHI'];

export function StudentSchedulePage() {
  const todayKey = vnDayBounds().dateKey;
  const [monday, setMonday] = useState(() => mondayOf(todayKey));
  const children = useChildren();
  const student = children.data?.[0];
  const days = weekDays(monday);
  const to = addDays(monday, DAYS_IN_WEEK - 1);
  const query = usePortalSchedule(student?.id, monday, to);

  const header = (
    <div className="flex flex-col gap-2">
      <h1 className="text-h2">Lịch học</h1>
      <div className="flex flex-wrap items-center gap-2">
        <Button variant="secondary" onClick={() => setMonday(addDays(monday, -DAYS_IN_WEEK))}>
          Tuần trước
        </Button>
        <Button variant="secondary" onClick={() => setMonday(mondayOf(todayKey))}>
          Tuần này
        </Button>
        <Button variant="secondary" onClick={() => setMonday(addDays(monday, DAYS_IN_WEEK))}>
          Tuần sau
        </Button>
        <p className="text-body text-fg-muted" aria-live="polite">
          Tuần {weekLabel(monday)}
        </p>
      </div>
    </div>
  );

  if (children.isPending || (student !== undefined && query.isPending))
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Spinner label="Đang tải lịch học…" />
      </div>
    );
  if (children.isError || query.isError)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Alert tone="danger">{errorOf(children.error ?? query.error).message}</Alert>
        <div>
          <Button
            onClick={() => {
              void children.refetch();
              void query.refetch();
            }}
          >
            Thử lại
          </Button>
        </div>
      </div>
    );
  if (student === undefined)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <StateView kind="empty" title="Chưa có lịch học" headingLevel={2}>
          Tài khoản chưa gắn với học sinh hoặc cơ sở chưa bật Học tập. Liên hệ trung tâm để được hỗ
          trợ.
        </StateView>
      </div>
    );

  const byDay = groupSessionsByDay(query.data?.rows ?? [], days);
  const empty = (query.data?.rows.length ?? 0) === 0;
  return (
    <div className="flex flex-col gap-4">
      {header}
      {empty ? (
        <StateView kind="empty" title="Tuần này em không có buổi học" headingLevel={2}>
          Chọn tuần khác để xem lịch.
        </StateView>
      ) : (
        days
          .filter((d) => (byDay[d]?.length ?? 0) > 0)
          .map((d) => (
            <section key={d} aria-label={formatDayHeading(d)} className="flex flex-col gap-2">
              <h2 className="text-caption font-semibold text-fg-label">
                {formatDayHeading(d).toUpperCase()}
                {d === todayKey ? ' · HÔM NAY' : ''}
              </h2>
              <ul className="flex flex-col gap-2">
                {(byDay[d] ?? []).map((s) => (
                  <SessionCard key={s.session_id} session={s} />
                ))}
              </ul>
            </section>
          ))
      )}
    </div>
  );
}

function SessionCard({ session: s }: { session: PortalSession }) {
  const cancelled = CANCELLED.includes(s.status_code);
  return (
    <li className="flex flex-col gap-1 rounded-lg border border-border bg-surface p-3">
      <div className="flex flex-wrap items-center gap-2">
        <p className="tabular font-semibold">{timeRange(s)}</p>
        {s.is_makeup && <Tag tone="info">{s.type_name ?? 'Buổi bù'}</Tag>}
        {cancelled && <Tag tone="danger">Buổi nghỉ</Tag>}
      </div>
      <p>
        {s.subject_name ?? 'Buổi học'} · {s.class_code}
      </p>
      <p className="text-caption text-fg-muted">
        {[s.teacher_name, s.room_name].filter((x): x is string => Boolean(x)).join(' · ')}
      </p>
    </li>
  );
}
