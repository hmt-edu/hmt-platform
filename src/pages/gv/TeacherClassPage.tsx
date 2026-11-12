// GV-11 Chi tiết lớp (cổng giáo viên, chỉ đọc): tab Học sinh (chuyên cần, TB tiêu chí), Lịch, Buổi (Đúng hạn/Trễ hạn), BTVN.
// Máy chủ quyết lớp nào xem được (app.teacher_class_overview, R-GV-08) và tính mọi con số; trang chỉ đặt chữ. Nút «Yêu cầu bổ trợ», «Tạo ticket» CHƯA làm (sau 17/11): ẩn.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Tabs } from '../../ui/Overlays';
import {
  attendanceText,
  homeworkSessions,
  scoreText,
  shortDate,
  slotText,
  timelinessLabel,
  type ClassOverview,
} from './classOverviewLogic';
import { classTitle } from './classesLogic';
import { hhmm } from './todayLogic';

export function TeacherClassPage() {
  const supabase = useDb();
  const { classId = '' } = useParams();
  const [tab, setTab] = useState('hoc-sinh');
  const query = useQuery({
    queryKey: ['gv-class', classId],
    queryFn: () => rpc<ClassOverview>(supabase, 'teacher_class_overview', { p_class_id: classId }),
    refetchOnWindowFocus: true,
  });
  const back = (
    <Link className="text-link underline" to="/gv/lop">
      Lớp của tôi
    </Link>
  );
  if (query.isPending)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <h1 className="text-h2">Lớp</h1>
        <Spinner />
      </div>
    );
  if (query.isError)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <h1 className="text-h2">Lớp</h1>
        <Alert tone="danger">{errorOf(query.error).message}</Alert>
        <div className="flex gap-3">
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
          {back}
        </div>
      </div>
    );

  const o = query.data;
  const homework = homeworkSessions(o.sessions);
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4">
      <div>
        <p className="text-caption">{back}</p>
        <h1 className="text-h2">{classTitle(o.class) || o.class.code}</h1>
        <p className="text-body text-fg-muted">{o.class.code}</p>
      </div>
      <Tabs
        label="Chi tiết lớp"
        value={tab}
        onChange={setTab}
        items={[
          {
            value: 'hoc-sinh',
            label: 'Học sinh',
            count: o.students.length,
            content:
              o.students.length === 0 ? (
                <StateView kind="empty" title="Lớp chưa có học sinh" headingLevel={2}>
                  Khi có học sinh xếp lớp, danh sách sẽ hiện ở đây.
                </StateView>
              ) : (
                <ul className="flex flex-col gap-2">
                  {o.students.map((s) => (
                    <li
                      key={s.student_id}
                      className="rounded-control border border-border bg-surface p-3"
                    >
                      <p className="font-semibold">{s.full_name}</p>
                      <p className="text-caption text-fg-muted">
                        {attendanceText(s)} · {scoreText(s.avg_score)}
                      </p>
                    </li>
                  ))}
                </ul>
              ),
          },
          {
            value: 'lich',
            label: 'Lịch',
            content:
              o.slots.length === 0 ? (
                <p className="text-body text-fg-muted">Lớp chưa có lịch học cố định.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {o.slots.map((s, i) => (
                    <li
                      key={`${s.weekday}-${s.start_time}-${i}`}
                      className="rounded-control border border-border bg-surface p-3"
                    >
                      <p className="font-semibold">{slotText(s)}</p>
                      <p className="text-caption text-fg-muted">
                        {[
                          s.room_name,
                          s.teacher_name && `GV ${s.teacher_name}`,
                          s.assistant_name && `TG ${s.assistant_name}`,
                        ]
                          .filter(Boolean)
                          .join(' · ')}
                      </p>
                    </li>
                  ))}
                </ul>
              ),
          },
          {
            value: 'buoi',
            label: 'Buổi',
            count: o.sessions.length,
            content:
              o.sessions.length === 0 ? (
                <p className="text-body text-fg-muted">Lớp chưa có buổi nào.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {o.sessions.map((s) => {
                    const label = timelinessLabel(s.timeliness);
                    return (
                      <li
                        key={s.id}
                        className="flex items-start justify-between gap-2 rounded-control border border-border bg-surface p-3"
                      >
                        <div>
                          <p className="font-semibold">
                            {s.session_no ? `Buổi ${s.session_no}` : 'Buổi'} ·{' '}
                            {shortDate(s.session_date)}
                          </p>
                          <p className="text-caption text-fg-muted">
                            {hhmm(s.start_time)}–{hhmm(s.end_time)} · {s.type_name ?? s.type_code}
                          </p>
                        </div>
                        <div className="flex flex-col items-end gap-1">
                          {s.status_code === 'DONE' && <Tag tone="success">Đã hoàn tất</Tag>}
                          {label && (
                            <Tag tone={s.timeliness === 'TRE_HAN' ? 'danger' : 'success'}>
                              {label}
                            </Tag>
                          )}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              ),
          },
          {
            value: 'btvn',
            label: 'BTVN',
            count: homework.length,
            content:
              homework.length === 0 ? (
                <p className="text-body text-fg-muted">Chưa có buổi nào giao BTVN.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {homework.map((s) => (
                    <li key={s.id} className="rounded-control border border-border bg-surface p-3">
                      <p className="text-caption font-semibold text-fg-label">
                        {s.session_no ? `Buổi ${s.session_no}` : 'Buổi'} ·{' '}
                        {shortDate(s.session_date)}
                      </p>
                      <p className="whitespace-pre-line">{s.homework_text}</p>
                    </li>
                  ))}
                </ul>
              ),
          },
        ]}
      />
    </div>
  );
}
