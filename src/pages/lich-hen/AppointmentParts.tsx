// Các phần dùng chung của màn Lịch hẹn: nút thao tác theo trạng thái và quyền (dòng, thẻ Kanban, khung chi tiết Lịch),
// liên kết hồ sơ gắn.
import { Link } from 'react-router';
import { formatDateTime } from '../../lib/format';
import { Button, ButtonLink } from '../../ui/Button';
import { Code, Tag } from '../../ui/Data';
import { STATUS_TONE } from './appointmentTone';
import {
  RECORD_KIND_LABEL,
  STATUS_LABEL,
  recordKind,
  recordPath,
  type AppointmentRow,
} from './appointmentTypes';

export type RowActions = {
  canEdit: boolean;
  canCancel: boolean;
  /** Lịch đang xử lý (khoá nút để không bấm hai lần). */
  busyId: string | null;
  onComplete: (row: AppointmentRow) => void;
  onReschedule: (row: AppointmentRow) => void;
  onCancel: (row: AppointmentRow) => void;
  onReopen: (row: AppointmentRow) => void;
};

/** Các nút thao tác của một lịch hẹn theo trạng thái và quyền (dùng chung cho dòng, thẻ Kanban, khung chi tiết Lịch). */
export function AppointmentButtons({
  row,
  actions,
  size = 'sm',
}: {
  row: AppointmentRow;
  actions: RowActions;
  size?: 'sm' | 'md';
}) {
  const busy = actions.busyId === row.id;
  if (row.status === 'CHUA_LAM') {
    return (
      <div className="flex flex-wrap gap-1.5">
        {actions.canEdit && (
          <>
            <Button
              size={size}
              icon="checkMark"
              loading={busy}
              onClick={() => actions.onComplete(row)}
            >
              Hoàn thành
            </Button>
            <Button
              size={size}
              icon="calendar"
              disabled={busy}
              onClick={() => actions.onReschedule(row)}
            >
              Dời
            </Button>
          </>
        )}
        {actions.canCancel && (
          <Button
            size={size}
            variant="danger"
            icon="close"
            disabled={busy}
            onClick={() => actions.onCancel(row)}
          >
            Huỷ
          </Button>
        )}
      </div>
    );
  }
  return actions.canEdit ? (
    <Button size={size} loading={busy} onClick={() => actions.onReopen(row)}>
      Mở lại
    </Button>
  ) : null;
}

/** "Lead LD000232", "Cơ hội CO000121", "Phiếu PKT000105": mã có liên kết sang bản ghi. */
export function RecordLink({ row }: { row: AppointmentRow }) {
  const kind = recordKind(row);
  const path = recordPath(row);
  if (!row.record_code) return <span className="text-fg-muted">—</span>;
  return (
    <span className="inline-flex flex-wrap items-baseline gap-1.5">
      <span className="text-caption text-fg-muted">{RECORD_KIND_LABEL[kind]}</span>
      {path ? (
        <Link to={path} className="font-medium text-link hover:underline">
          {row.record_code}
        </Link>
      ) : (
        <Code>{row.record_code}</Code>
      )}
    </span>
  );
}

/** Khung chi tiết khi bấm một ô trên Lịch (Lịch hẹn, Việc của tôi). */
export function CalendarDetail({
  row,
  activity,
  actions,
}: {
  row: AppointmentRow;
  activity: string;
  actions: RowActions;
}) {
  return (
    <div className="flex w-[320px] max-w-full flex-col gap-2 p-3">
      <div className="flex items-start justify-between gap-2">
        <p className="font-semibold">
          {activity} · {row.title}
        </p>
        <Tag tone={STATUS_TONE[row.status]}>{STATUS_LABEL[row.status]}</Tag>
      </div>
      {row.record_label && (
        <p className="text-body">
          <Code>{row.record_code ?? ''}</Code> {row.record_label}
        </p>
      )}
      <p className="text-caption text-fg-muted">
        {formatDateTime(row.scheduled_at)}
        {row.owner_name ? ` · ${row.owner_name}` : ''}
      </p>
      {!row.student_test_id && recordPath(row) && (
        <ButtonLink variant="primary" icon="arrowRight" to={recordPath(row) ?? ''}>
          Mở {RECORD_KIND_LABEL[recordKind(row)].toLowerCase()} {row.record_code}
        </ButtonLink>
      )}
      <AppointmentButtons row={row} actions={actions} />
    </div>
  );
}
