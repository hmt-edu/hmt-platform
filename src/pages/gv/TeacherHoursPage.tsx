// GV-16 Giờ dạy của tôi (cổng giáo viên, chỉ đọc): giờ dạy làm căn cứ lương theo tháng (R-GV-14): buổi đã Hoàn thành của chính mình, cả giáo viên lẫn trợ giảng,
// mọi loại buổi thực dạy (kể cả học bổ trợ), tính theo ngày buổi diễn ra; buổi huỷ không tính. Số buổi, tổng giờ, buổi trễ hạn, giờ trễ do máy chủ tính
// (app.teacher_my_hours); trang chỉ đổi tháng và đặt chữ. Chưa có trạng thái "chốt tháng" (Kế toán hoặc Admin chốt, làm cùng BC-09).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import {
  hoursText,
  lateText,
  monthTitle,
  roleText,
  rowDay,
  shiftMonth,
  type MyHours,
} from './hoursLogic';

export function TeacherHoursPage() {
  const supabase = useDb();
  const narrow = useMedia(NARROW_TABLE);
  const todayKey = vnDayBounds().dateKey;
  const thisMonth = `${todayKey.slice(0, 8)}01`; // allow-number: cắt chuỗi yyyy-mm-dd
  const [month, setMonth] = useState(thisMonth);
  const query = useQuery({
    queryKey: ['gv-hours', month],
    queryFn: () => rpc<MyHours>(supabase, 'teacher_my_hours', { p_month: month }),
    refetchOnWindowFocus: true,
  });
  const header = (
    <div className="flex flex-col gap-2">
      <p className="text-caption text-fg-muted">
        <Link className="text-link underline" to="/gv/lich-day">
          Lịch dạy
        </Link>{' '}
        › Giờ dạy của tôi
      </p>
      <h1 className="text-h2">Giờ dạy của tôi</h1>
      <p className="text-caption text-fg-muted">
        Giờ dạy tính cho người dạy thật, buổi đã Hoàn thành, gồm cả học bổ trợ.
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <Button variant="secondary" onClick={() => setMonth(shiftMonth(month, -1))}>
          Tháng trước
        </Button>
        <Button variant="secondary" onClick={() => setMonth(thisMonth)}>
          Tháng này
        </Button>
        <Button variant="secondary" onClick={() => setMonth(shiftMonth(month, 1))}>
          Tháng sau
        </Button>
        <p className="text-body text-fg-muted" aria-live="polite">
          {monthTitle(month)}
        </p>
      </div>
    </div>
  );
  if (query.isPending)
    return (
      <div className="mx-auto flex max-w-4xl flex-col gap-3">
        {header}
        <Spinner />
      </div>
    );
  if (query.isError)
    return (
      <div className="mx-auto flex max-w-4xl flex-col gap-3">
        {header}
        <Alert tone="danger">{errorOf(query.error).message}</Alert>
        <div>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      </div>
    );
  const d = query.data;
  const cards: [string, string][] = [
    ['Số buổi', String(d.summary.sessions)],
    ['Tổng giờ', hoursText(d.summary.hours)],
    ['Buổi trễ hạn', String(d.summary.late_sessions)],
    ['Giờ trễ', hoursText(d.summary.late_hours)],
  ];
  return (
    <div className="mx-auto flex max-w-4xl flex-col gap-4">
      {header}
      <section aria-label="Tóm tắt" className="grid grid-cols-2 gap-2 md:grid-cols-4">
        {cards.map(([label, value]) => (
          <div key={label} className="rounded-control border border-border bg-surface p-3">
            <p className="text-caption text-fg-muted">{label}</p>
            <p className="text-h3 tabular font-semibold">{value}</p>
          </div>
        ))}
      </section>
      {d.rows.length === 0 ? (
        <StateView kind="empty" title="Tháng này chưa có buổi dạy" headingLevel={2}>
          Tháng không có buổi nào đã hoàn tất thì không có giờ để tính. Chọn tháng khác bằng nút
          Tháng trước, Tháng sau.
        </StateView>
      ) : (
        <>
          <section aria-label="Giờ theo loại buổi" className="flex flex-col gap-1">
            <h2 className="text-h4">Giờ theo loại buổi</h2>
            <ul className="flex flex-wrap gap-2">
              {d.by_type.map((t) => (
                <li
                  key={t.type_code}
                  className="rounded-control border border-border bg-surface px-3 py-1 text-body"
                >
                  {t.type_name ?? t.type_code}: {hoursText(t.hours)} giờ · {t.sessions} buổi
                </li>
              ))}
            </ul>
          </section>
          <h2 className="text-h4">Buổi trong tháng</h2>
          {narrow ? (
            <ul className="flex flex-col gap-2">
              {d.rows.map((r) => (
                <li
                  key={r.session_id}
                  className="rounded-control border border-border bg-surface p-3"
                >
                  <p className="font-semibold">{rowDay(r)}</p>
                  <p className="text-body">
                    {r.subject_name ?? r.class_code} · {r.type_name ?? r.type_code} ·{' '}
                    {hoursText(r.hours)} giờ
                  </p>
                  <p className="text-caption text-fg-muted">
                    {roleText(r.my_role)} · {lateText(r)}
                  </p>
                </li>
              ))}
            </ul>
          ) : (
            <div className="overflow-x-auto rounded-control border border-border">
              <table aria-label="Buổi trong tháng" className="w-full text-body">
                <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
                  <tr>
                    <th className="px-3 py-2">Ngày</th>
                    <th className="px-3 py-2">Lớp</th>
                    <th className="px-3 py-2">Loại</th>
                    <th className="px-3 py-2">Vai trò</th>
                    <th className="px-3 py-2 text-right">Giờ</th>
                    <th className="px-3 py-2">Thời hạn</th>
                  </tr>
                </thead>
                <tbody>
                  {d.rows.map((r) => (
                    <tr key={r.session_id} className="border-t border-border">
                      <td className="px-3 py-2">{rowDay(r)}</td>
                      <td className="px-3 py-2">{r.subject_name ?? r.class_code}</td>
                      <td className="px-3 py-2">{r.type_name ?? r.type_code}</td>
                      <td className="px-3 py-2">{roleText(r.my_role)}</td>
                      <td className="tabular px-3 py-2 text-right">{hoursText(r.hours)}</td>
                      <td className="px-3 py-2">{lateText(r)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
      <p className="text-caption text-fg-muted">
        Tính theo ngày buổi diễn ra (R-GV-14). Buổi huỷ không tính. Buổi chưa hoàn tất chưa được
        tính giờ, xem ở Cần làm.
      </p>
    </div>
  );
}
