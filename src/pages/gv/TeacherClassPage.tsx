// GV-11 Chi tiết lớp (cổng giáo viên, chỉ đọc), theo canvas 9189: một trang gồm thông tin lớp, Học sinh (chuyên cần, TB tiêu chí), Lịch học, Lịch sử buổi (nhãn Trễ hạn), BTVN gần đây, Yêu cầu bổ trợ.
// Khối «Tiến độ khung chương trình»: tạm = buổi đã chốt ÷ buổi dự kiến, nhãn «ước tính» (app.teacher_class_progress, E69).
// Máy chủ quyết lớp nào xem được (app.teacher_class_overview, R-GV-08) và tính mọi con số; trang chỉ đặt chữ. Nút «Yêu cầu bổ trợ», «Tạo ticket» CHƯA làm (sau 17/11): ẩn.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
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
import { GvForbidden } from './GvForbidden';
import { isForbidden } from './forbidden';

/** Số học sinh hiện sẵn trước nút «Xem thêm» (canvas GV-11 hiện 4 em đầu). */
const PREVIEW_STUDENTS = 4;

export function TeacherClassPage() {
  const supabase = useDb();
  const { classId = '' } = useParams();
  const [showAll, setShowAll] = useState(false);
  const query = useQuery({
    queryKey: ['gv-class', classId],
    queryFn: () => rpc<ClassOverview>(supabase, 'teacher_class_overview', { p_class_id: classId }),
    refetchOnWindowFocus: true,
  });
  // E69 (canvas GV-11): «Tiến độ khung chương trình». Tạm tính bằng buổi đã chốt ÷ buổi dự kiến, ghi «ước tính» (Chat 22:52); lỗi thì ẩn khối, không chặn trang.
  const progress = useQuery({
    queryKey: ['gv-class-progress', classId],
    queryFn: () =>
      rpc<{ done_sessions: number; planned_sessions: number | null }>(
        supabase,
        'teacher_class_progress',
        { p_class_id: classId },
      ),
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
        {isForbidden(query.error) ? (
          <GvForbidden kind="generic" />
        ) : (
          <Alert tone="danger">{errorOf(query.error).message}</Alert>
        )}
        <div className="flex gap-3">
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
          {back}
        </div>
      </div>
    );

  const o = query.data;
  const homework = homeworkSessions(o.sessions);
  const todayIso = new Date().toISOString().slice(0, 10);
  const next = [...o.sessions]
    .filter((x) => x.status_code !== 'DONE' && x.session_date >= todayIso)
    .sort((a, b) => a.session_date.localeCompare(b.session_date))[0];
  const teachers = [...new Set(o.slots.map((x) => x.teacher_name).filter(Boolean))].join(', ');
  const shown = showAll ? o.students : o.students.slice(0, PREVIEW_STUDENTS);
  const hidden = o.students.length - shown.length;
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-5">
      <div>
        <p className="text-caption">{back}</p>
        <h1 className="text-h2">{classTitle(o.class) || o.class.code}</h1>
        <p className="text-body text-fg-muted">{o.class.code}</p>
      </div>

      <dl className="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-body">
        <dt className="text-fg-muted">Lớp</dt>
        <dd>{classTitle(o.class) || o.class.code}</dd>
        {teachers && (
          <>
            <dt className="text-fg-muted">Giáo viên</dt>
            <dd>{teachers}</dd>
          </>
        )}
        <dt className="text-fg-muted">Sĩ số</dt>
        <dd>{o.students.length} học sinh</dd>
        {next && (
          <>
            <dt className="text-fg-muted">Buổi tiếp theo</dt>
            <dd>
              {shortDate(next.session_date)} · {hhmm(next.start_time)}
            </dd>
          </>
        )}
      </dl>

      <section aria-labelledby="gv11-hs" className="flex flex-col gap-2">
        <h2 id="gv11-hs" className="text-h4">
          Học sinh · {o.students.length}
        </h2>
        {o.students.length === 0 ? (
          <StateView kind="empty" title="Lớp chưa có học sinh" headingLevel={2}>
            Khi có học sinh xếp lớp, danh sách sẽ hiện ở đây.
          </StateView>
        ) : (
          <>
            <ul className="flex flex-col gap-2">
              {shown.map((s) => (
                <li
                  key={s.student_id}
                  className="rounded-control border border-border bg-surface p-3"
                >
                  <p className="font-semibold">{s.full_name}</p>
                  <p className="text-caption text-fg-muted">
                    {attendanceText(s)} · {scoreText(s.avg_score)}
                  </p>
                  <Link
                    to={`/gv/lop/${o.class.id}/hoc-sinh/${s.student_id}`}
                    className="text-caption text-link hover:underline"
                  >
                    Mở học sinh
                  </Link>
                </li>
              ))}
            </ul>
            {hidden > 0 && <Button onClick={() => setShowAll(true)}>Xem thêm {hidden} em</Button>}
          </>
        )}
      </section>

      <section aria-labelledby="gv11-lich" className="flex flex-col gap-2">
        <h2 id="gv11-lich" className="text-h4">
          Lịch học
        </h2>
        {o.slots.length === 0 ? (
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
        )}
      </section>

      <section aria-labelledby="gv11-buoi" className="flex flex-col gap-2">
        <h2 id="gv11-buoi" className="text-h4">
          Lịch sử buổi
        </h2>
        {o.sessions.length === 0 ? (
          <p className="text-body text-fg-muted">Lớp chưa có buổi nào.</p>
        ) : (
          <>
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
                      {s.status_code === 'DONE' ? (
                        <Tag tone="success">Hoàn thành</Tag>
                      ) : (
                        <Tag tone="warning">Cần hoàn tất</Tag>
                      )}
                      {label && (
                        <Tag tone={s.timeliness === 'TRE_HAN' ? 'danger' : 'success'}>{label}</Tag>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
            <p className="text-caption text-fg-muted">
              Lịch sử buổi chỉ gồm buổi của giáo viên này.
            </p>
          </>
        )}
      </section>

      {progress.data && (
        <section aria-labelledby="gv11-tien-do" className="flex flex-col gap-2">
          <h2 id="gv11-tien-do" className="text-h4">
            Tiến độ khung chương trình
          </h2>
          <p className="text-body">
            {progress.data.planned_sessions
              ? `${progress.data.done_sessions}/${progress.data.planned_sessions} buổi`
              : `${progress.data.done_sessions} buổi đã chốt`}{' '}
            <Tag>ước tính</Tag>
          </p>
          <p className="text-caption text-fg-muted">
            Ước tính theo số buổi đã chốt trên số buổi dự kiến; lớp chưa có khung chương trình theo
            bài.
          </p>
        </section>
      )}
      <section aria-labelledby="gv11-btvn" className="flex flex-col gap-2">
        <h2 id="gv11-btvn" className="text-h4">
          BTVN gần đây
        </h2>
        {homework.length === 0 ? (
          <p className="text-body text-fg-muted">Chưa có buổi nào giao BTVN.</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {homework.map((s) => (
              <li key={s.id} className="rounded-control border border-border bg-surface p-3">
                <p className="text-caption font-semibold text-fg-label">
                  {s.session_no ? `Buổi ${s.session_no}` : 'Buổi'} giao ·{' '}
                  {shortDate(s.session_date)}
                </p>
                <p className="whitespace-pre-line">{s.homework_text}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="gv11-bo-tro" className="flex flex-col gap-2">
        <h2 id="gv11-bo-tro" className="text-h4">
          Yêu cầu bổ trợ
        </h2>
        <p className="text-body text-fg-muted">
          Cần học bù hoặc buổi bổ trợ cho lớp: gửi ticket để vận hành xử lý.
        </p>
        <div>
          <ButtonLink to="/gv/ticket/tao">Tạo ticket</ButtonLink>
        </div>
      </section>
      <section className="flex flex-col gap-2">
        <h2 className="text-h3">Bài đã giao trên LMS</h2>
        <p className="text-fg-muted">Giao bài cho cả lớp hoặc từng em, xem em nào đã nộp.</p>
        <div>
          <ButtonLink to={`/gv/lop/${classId}/bai-giao`}>Bài đã giao</ButtonLink>
        </div>
      </section>
    </div>
  );
}
