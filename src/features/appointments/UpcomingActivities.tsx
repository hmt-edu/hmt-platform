// Khối "Hoạt động sắp tới" của cột Ghi chú và hoạt động (TS-02, TS-13): lịch hẹn Chưa làm của hồ sơ, mỗi lịch có
// Hoàn thành, Dời, Huỷ (nút hiện theo quyền). "Mở lại" lịch đã xong để màn Lịch hẹn (P3c-3).
import { formatDateTime } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Icon } from '../../ui/icons';
import { activityIcon, type UpcomingAppointment } from './appointmentApi';

export function UpcomingActivities({
  rows,
  activityName,
  canEdit,
  canCancel,
  busyId,
  onComplete,
  onReschedule,
  onCancel,
}: {
  rows: UpcomingAppointment[];
  activityName: (code: string) => string;
  canEdit: boolean;
  canCancel: boolean;
  /** Lịch đang xử lý (khoá nút để không bấm hai lần). */
  busyId: string | null;
  onComplete: (row: UpcomingAppointment) => void;
  onReschedule: (row: UpcomingAppointment) => void;
  onCancel: (row: UpcomingAppointment) => void;
}) {
  const { start, end } = vnDayBounds();
  return (
    <section aria-label="Hoạt động sắp tới" className="border-t border-border px-4 py-3">
      <h3 className="mb-2 text-caption font-semibold tracking-wide text-fg-muted uppercase">
        Hoạt động sắp tới ({rows.length})
      </h3>
      {rows.length === 0 ? (
        <p className="text-fg-muted">Chưa có lịch hẹn nào sắp tới.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((row) => {
            const at = new Date(row.scheduled_at);
            const overdue = at < start;
            const today = !overdue && at < end;
            const name = activityName(row.activity_code);
            const busy = busyId === row.id;
            return (
              <li
                key={row.id}
                className="flex flex-col gap-1.5 rounded-box border border-border bg-surface-subtle px-3 py-2.5"
              >
                <div className="flex items-start gap-2">
                  <Icon name={activityIcon(row.activity_code)} className="mt-0.5 shrink-0" />
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold break-words">
                      {row.title === name ? name : `${name} · ${row.title}`}
                    </p>
                    <p className="text-caption text-fg-muted">
                      {overdue ? (
                        <b className="text-on-danger-subtle">Quá hạn</b>
                      ) : today ? (
                        <b className="text-on-warning-subtle">Hôm nay</b>
                      ) : null}
                      {overdue || today ? ' · ' : ''}
                      {formatDateTime(row.scheduled_at)}
                      {row.owner_name ? ` · ${row.owner_name}` : ''}
                    </p>
                  </div>
                  <Tag>Chưa làm</Tag>
                </div>
                {(canEdit || canCancel) && (
                  <div className="flex flex-wrap gap-2">
                    {canEdit && (
                      <>
                        <Button
                          size="sm"
                          icon="checkMark"
                          loading={busy}
                          onClick={() => onComplete(row)}
                        >
                          Hoàn thành
                        </Button>
                        <Button
                          size="sm"
                          icon="calendar"
                          disabled={busy}
                          onClick={() => onReschedule(row)}
                        >
                          Dời
                        </Button>
                      </>
                    )}
                    {canCancel && (
                      <Button
                        size="sm"
                        variant="danger"
                        icon="close"
                        disabled={busy}
                        onClick={() => onCancel(row)}
                      >
                        Huỷ
                      </Button>
                    )}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
