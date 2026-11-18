// GV-10 Lớp của tôi (cổng giáo viên, ưu tiên điện thoại): lớp được phân công (giáo viên hoặc trợ giảng), sĩ số, buổi tiếp theo.
// Máy chủ quyết lớp nào hiện (app.list_classes, phạm vi lớp được phân công, R-GV-08); trang chỉ ghép buổi tiếp theo. Bấm lớp → GV-11.
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { QueryErrorBlock } from './QueryErrorBlock';
import { rpc, useDb } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Spinner, StateView } from '../../ui/Feedback';
import {
  capacityText,
  classTitle,
  isTeaching,
  nextByClass,
  nextText,
  scheduleText,
  type MyClassesResult,
} from './classesLogic';
import { NEXT_LOOKAHEAD_DAYS, addDays, type MySessionsResult } from './todayLogic';

const LIST_LIMIT = 100; // allow-number: trần số dòng một lần gọi của máy chủ (tối đa 100)

export function TeacherClassesPage() {
  const supabase = useDb();
  const todayKey = vnDayBounds().dateKey;
  const classes = useQuery({
    queryKey: ['gv-classes'],
    queryFn: () =>
      rpc<MyClassesResult>(supabase, 'list_classes', {
        p_filters: {},
        p_limit: LIST_LIMIT,
      }),
    refetchOnWindowFocus: true,
  });
  // Buổi sắp tới của mình (một lần gọi cho mọi lớp, không gọi theo từng lớp).
  const upcoming = useQuery({
    queryKey: ['gv-classes-next', todayKey],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', {
        p_mode: 'NGAY',
        p_from: todayKey,
        p_to: addDays(todayKey, NEXT_LOOKAHEAD_DAYS),
        p_limit: LIST_LIMIT,
      }),
  });

  if (classes.isPending)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <h1 className="text-h2">Lớp của tôi</h1>
        <Spinner />
      </div>
    );
  if (classes.isError)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <h1 className="text-h2">Lớp của tôi</h1>
        <QueryErrorBlock error={classes.error} onRetry={() => void classes.refetch()} />
      </div>
    );

  const rows = classes.data.rows.filter(isTeaching);
  const next = nextByClass(upcoming.data?.rows ?? []);
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4">
      <div>
        <h1 className="text-h2">Lớp của tôi</h1>
        <p className="text-body text-fg-muted">
          {rows.length} lớp được phân công. Chỉ thấy lớp của mình.
        </p>
        <p className="text-body">
          <Link className="text-link underline" to="/gv/ticket">
            Ticket của lớp tôi
          </Link>
        </p>
      </div>
      {rows.length === 0 ? (
        <StateView kind="empty" title="Bạn chưa được phân công lớp nào" headingLevel={2}>
          Khi có lớp được phân công, lớp sẽ hiện ở đây.
        </StateView>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((c) => (
            <li key={c.id}>
              <Link
                to={`/gv/lop/${c.id}`}
                className="flex min-h-11 flex-col gap-1 rounded-control border border-border bg-surface p-3 hover:bg-surface-subtle"
              >
                <span className="font-semibold">{classTitle(c) || c.code}</span>
                <span className="text-caption text-fg-muted">{c.code}</span>
                <span className="text-body">{capacityText(c)}</span>
                {c.schedule.length > 0 && (
                  <span className="text-caption text-fg-muted">{scheduleText(c)}</span>
                )}
                <span className="text-caption font-medium">
                  {upcoming.isPending
                    ? 'Đang tìm buổi tiếp theo…'
                    : upcoming.isError
                      ? 'Chưa tải được buổi tiếp theo'
                      : nextText(next.get(c.id))}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
