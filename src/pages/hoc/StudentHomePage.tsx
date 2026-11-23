// HT-01 Trang chủ học sinh (khung HT01_ds, _tai, _trong, _loi): buổi học hôm nay và sắp tới, bài cần làm.
// Ghép từ hai hàm đọc có sẵn (app.portal_schedule, app.portal_assignments), không migration. Khối chuỗi/sao (R-LMS-05) thêm cùng HT-08.
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/datetime';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { addDays, formatDayHeading } from '../gv/todayLogic';
import {
  dueNote,
  timeRange,
  useChildren,
  usePortalAssignments,
  usePortalSchedule,
} from './portalData';

const UPCOMING_DAYS = 7; // allow-number: khoảng «sắp tới» hiển thị trên trang chủ (không phải số nghiệp vụ)
const SHOWN_ASSIGNMENTS = 3; // allow-number: số bài cần làm hiện ở trang chủ, còn lại xem ở Bài tập (hiển thị)

export function StudentHomePage() {
  const todayKey = vnDayBounds().dateKey;
  const children = useChildren();
  const student = children.data?.[0];
  const schedule = usePortalSchedule(student?.id, todayKey, addDays(todayKey, UPCOMING_DAYS));
  const todo = usePortalAssignments(student?.id, 'CAN_LAM', 0);

  if (children.isPending || (student !== undefined && (schedule.isPending || todo.isPending)))
    return <Spinner label="Đang tải…" />;
  if (children.isError || schedule.isError || todo.isError)
    return (
      <div className="flex flex-col gap-3">
        <Alert tone="danger">
          {errorOf(children.error ?? schedule.error ?? todo.error).message}
        </Alert>
        <div>
          <Button
            onClick={() => {
              void children.refetch();
              void schedule.refetch();
              void todo.refetch();
            }}
          >
            Thử lại
          </Button>
        </div>
      </div>
    );
  if (student === undefined)
    return (
      <StateView kind="empty" title="Chưa có thông tin học tập" headingLevel={2}>
        Tài khoản chưa gắn với học sinh hoặc cơ sở chưa bật Học tập. Liên hệ trung tâm để được hỗ
        trợ.
      </StateView>
    );

  const sessions = (schedule.data?.rows ?? []).filter(
    (s) => !['HUY_CO_PHI', 'HUY_KHONG_PHI'].includes(s.status_code),
  );
  const today = sessions.filter((s) => s.session_date === todayKey);
  const next = sessions.filter((s) => s.session_date > todayKey).slice(0, SHOWN_ASSIGNMENTS);
  const assignments = todo.data?.rows.slice(0, SHOWN_ASSIGNMENTS) ?? [];
  const nothing = today.length === 0 && next.length === 0 && assignments.length === 0;

  return (
    <div className="flex flex-col gap-5">
      <h1 className="text-h2">Chào {student.full_name}</h1>
      {nothing && (
        <StateView kind="empty" title="Hôm nay em không có việc cần làm" headingLevel={2}>
          Khi có buổi học hoặc bài tập mới, em sẽ thấy ở đây.
        </StateView>
      )}
      {today.length > 0 && (
        <section aria-label="Hôm nay" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold text-fg-label">HÔM NAY</h2>
          <ul className="flex flex-col gap-2">
            {today.map((s) => (
              <li key={s.session_id} className="rounded-lg border border-border bg-surface p-3">
                <p className="tabular font-semibold">{timeRange(s)}</p>
                <p>{[s.subject_name ?? 'Buổi học', s.class_code].join(' · ')}</p>
                {s.is_makeup && <Tag tone="info">{s.type_name ?? 'Buổi bù'}</Tag>}
              </li>
            ))}
          </ul>
        </section>
      )}
      {assignments.length > 0 && (
        <section aria-label="Bài cần làm" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold text-fg-label">BÀI CẦN LÀM</h2>
          <ul className="flex flex-col gap-2">
            {assignments.map((a) => (
              <li key={a.assignment_id}>
                <Link
                  to={`/hoc/bai-tap/${a.assignment_id}`}
                  className="focus-ring flex flex-col gap-1 rounded-lg border border-border bg-surface p-3 hover:bg-surface-subtle"
                >
                  <span className="flex flex-wrap items-center gap-2">
                    <span className="font-semibold">{a.title}</span>
                    {a.is_overdue && <Tag tone="danger">Quá hạn</Tag>}
                  </span>
                  <span className="text-caption text-fg-muted">
                    {dueNote(a)}: {formatDateTime(a.due_at)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
          <Link to="/hoc/bai-tap" className="font-medium text-link hover:underline">
            Xem tất cả bài tập
          </Link>
        </section>
      )}
      {next.length > 0 && (
        <section aria-label="Sắp tới" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold text-fg-label">BUỔI HỌC SẮP TỚI</h2>
          <ul className="flex flex-col gap-2">
            {next.map((s) => (
              <li key={s.session_id} className="rounded-lg border border-border bg-surface p-3">
                <p className="text-caption text-fg-muted">{formatDayHeading(s.session_date)}</p>
                <p className="tabular font-semibold">{timeRange(s)}</p>
                <p>{[s.subject_name ?? 'Buổi học', s.class_code].join(' · ')}</p>
              </li>
            ))}
          </ul>
          <Link to="/hoc/lich" className="font-medium text-link hover:underline">
            Xem lịch học
          </Link>
        </section>
      )}
    </div>
  );
}
