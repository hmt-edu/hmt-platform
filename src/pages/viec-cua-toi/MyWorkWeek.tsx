// Lịch tuần của «Việc của tôi» (canvas 1bcc, VC06): lịch hẹn và phiếu Test của tôi trong tuần, bấm một ô để thao tác.
// Dùng app.list_appointments theo cửa sổ tuần đang xem; thao tác dùng chung với màn Lịch hẹn.
import { useMemo, useState } from 'react';
import { useAppointmentActions } from '../../features/appointments/useAppointmentActions';
import { CalendarView } from '../../list/Calendar';
import { calendarWindowVn, vnToday } from '../../list/calendarLogic';
import { errorOf, useIntSetting } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Skeleton } from '../../ui/Data';
import { Alert, StateView } from '../../ui/Feedback';
import { CalendarDetail } from '../lich-hen/AppointmentParts';
import { closingActions } from '../lich-hen/closingActions';
import { useCalendarAppointments } from '../lich-hen/useAppointmentData';
import { WEEK_KINDS, weekEvent } from './weekLogic';

// Lịch hẹn chỉ có giờ bắt đầu: ô trên lưới vẽ cao nửa giờ, chỉ để hiển thị (không lưu).
const EVENT_MINUTES = 30; // allow-number: độ cao hiển thị của một lịch hẹn trên lưới Lịch
const CALENDAR_START_HOUR = 7; // allow-number: giờ đầu của lưới Lịch
const CALENDAR_END_HOUR = 21; // allow-number: giờ cuối của lưới Lịch
const CALENDAR_MAX_PAGES = 5; // allow-number: số trang tối đa tải cho một tuần

const TONE_BOX = {
  done: 'bg-success-subtle',
  overdue: 'bg-danger-subtle',
  open: 'bg-warning-subtle',
} as const;

export function MyWorkWeek({
  branchId,
  actionsApi,
}: {
  branchId: string | null;
  actionsApi: ReturnType<typeof useAppointmentActions>;
}) {
  const maxPage = useIntSetting('list_page_size_max');
  const [anchor, setAnchor] = useState(() => vnToday());
  const filters = useMemo(() => {
    const { from, to } = calendarWindowVn('week', anchor);
    return {
      mine: true,
      status: ['CHUA_LAM', 'HOAN_THANH'],
      from: from.toISOString(),
      to: to.toISOString(),
      ...(branchId ? { branch_id: branchId } : {}),
    };
  }, [anchor, branchId]);
  const query = useCalendarAppointments(filters, maxPage, CALENDAR_MAX_PAGES, true);

  if (query.isError) {
    return (
      <StateView
        kind="error"
        headingLevel={2}
        title="Chưa tải được lịch tuần."
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  if (!query.data) {
    return (
      <div role="status" aria-label="Đang tải">
        <Skeleton className="h-96" />
      </div>
    );
  }

  const rows = query.data.rows;
  const now = new Date(query.dataUpdatedAt);
  const { actions, activityName } = actionsApi;

  return (
    <div className="flex flex-col gap-3">
      <p className="text-fg-muted">
        Lịch hẹn và phiếu test của tôi trong tuần. Bấm vào một ô để mở lịch hẹn.
      </p>
      {query.data.truncated && (
        <Alert tone="warning">
          Tuần này có {query.data.total} lịch hẹn, đang hiện {rows.length}.
        </Alert>
      )}
      <CalendarView
        events={rows.map((r) => weekEvent(r, activityName(r.activity_code), now, EVENT_MINUTES))}
        kinds={WEEK_KINDS}
        mode="week"
        modes={['week']}
        onModeChange={() => undefined}
        anchor={anchor}
        onAnchorChange={setAnchor}
        startHour={CALENDAR_START_HOUR}
        endHour={CALENDAR_END_HOUR}
        now={new Date()}
        legend={
          <ul className="flex flex-wrap gap-3 border-b border-border px-4 py-2 text-caption text-fg-label">
            {WEEK_KINDS.map((k) => (
              <li key={k.key} className="inline-flex items-center gap-1.5">
                <span
                  aria-hidden="true"
                  className={`size-3 rounded-tag border border-border ${TONE_BOX[k.key]}`}
                />
                {k.label}
              </li>
            ))}
          </ul>
        }
        renderDetail={(event, close) => {
          const row = rows.find((r) => r.id === event.id);
          if (!row) return null;
          return (
            <CalendarDetail
              row={row}
              activity={activityName(row.activity_code)}
              actions={closingActions(actions, close)}
            />
          );
        }}
      />
    </div>
  );
}
