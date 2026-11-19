// GV-13 Học sinh (cổng giáo viên, hồ sơ rút gọn, chỉ đọc): chuyên cần, điểm tiêu chí trung bình và bảng theo buổi (điểm danh, điểm tiêu chí, BTVN)
// trong lớp của giáo viên. Máy chủ quyết quyền xem (app.teacher_student_profile, R-GV-08, R-GV-13) và tính mọi số; KHÔNG có số điện thoại, học phí,
// thông tin phụ huynh. Máy tính: bảng theo buổi; điện thoại: mỗi buổi một thẻ. Mở từ tab Học sinh của GV-11.
import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import {
  criteriaText,
  homeworkText,
  sessionLabel,
  summaryAttendance,
  summaryScore,
  type StudentProfile,
} from './studentProfileLogic';
import { GvForbidden } from './GvForbidden';
import { isForbidden } from './forbidden';

export function TeacherStudentPage() {
  const supabase = useDb();
  const narrow = useMedia(NARROW_TABLE);
  const { classId = '', studentId = '' } = useParams();
  const query = useQuery({
    queryKey: ['gv-student', classId, studentId],
    queryFn: () =>
      rpc<StudentProfile>(supabase, 'teacher_student_profile', {
        p_class_id: classId,
        p_student_id: studentId,
      }),
    refetchOnWindowFocus: true,
  });
  const back = (
    <Link className="text-link underline" to={`/gv/lop/${classId}`}>
      Về lớp
    </Link>
  );
  if (query.isPending)
    return (
      <div className="mx-auto flex max-w-3xl flex-col gap-3">
        <h1 className="text-h2">Học sinh</h1>
        <Spinner />
      </div>
    );
  if (query.isError)
    return (
      <div className="mx-auto flex max-w-3xl flex-col gap-3">
        <h1 className="text-h2">Học sinh</h1>
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
  const p = query.data;
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <p className="text-caption text-fg-muted">{back} › Học sinh</p>
      <div className="flex flex-col gap-1">
        <h1 className="text-h2">{p.student.full_name}</h1>
        <p className="text-body text-fg-muted">
          {[p.class.subject_name, p.class.code, p.branch_name].filter(Boolean).join(' · ')}
        </p>
      </div>
      <section aria-label="Tóm tắt" className="grid grid-cols-2 gap-2">
        <div className="rounded-control border border-border bg-surface p-3">
          <p className="text-caption text-fg-muted">Chuyên cần</p>
          <p className="font-semibold">{summaryAttendance(p.summary)}</p>
        </div>
        <div className="rounded-control border border-border bg-surface p-3">
          <p className="text-caption text-fg-muted">Điểm tiêu chí trung bình</p>
          <p className="font-semibold">{summaryScore(p.summary.avg_score)}</p>
        </div>
      </section>
      <Alert tone="info">
        Hồ sơ rút gọn: chỉ điểm danh, điểm tiêu chí, BTVN trong lớp của bạn (R-GV-13).
      </Alert>
      <h2 className="text-h4">Theo buổi</h2>
      {p.sessions.length === 0 ? (
        <StateView kind="empty" title="Em chưa có buổi nào trong lớp" headingLevel={2}>
          Em mới vào lớp, điểm danh và điểm sẽ hiện sau buổi đầu tiên.
        </StateView>
      ) : narrow ? (
        <ul className="flex flex-col gap-2">
          {p.sessions.map((s) => (
            <li key={s.session_id} className="rounded-control border border-border bg-surface p-3">
              <p className="font-semibold">{sessionLabel(s)}</p>
              <p className="text-body">
                <Tag tone={s.attendance_code === null ? 'neutral' : 'info'}>
                  {s.attendance_name ?? 'Chưa điểm danh'}
                </Tag>
              </p>
              <p className="text-caption text-fg-muted">{criteriaText(s)}</p>
              <p className="text-caption text-fg-muted">{homeworkText(s.homework)}</p>
            </li>
          ))}
        </ul>
      ) : (
        <div className="overflow-x-auto rounded-control border border-border">
          <table aria-label="Theo buổi" className="w-full text-body">
            <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
              <tr>
                <th className="px-3 py-2">Buổi</th>
                <th className="px-3 py-2">Điểm danh</th>
                <th className="px-3 py-2">Điểm tiêu chí</th>
                <th className="px-3 py-2">BTVN</th>
              </tr>
            </thead>
            <tbody>
              {p.sessions.map((s) => (
                <tr key={s.session_id} className="border-t border-border">
                  <td className="px-3 py-2">{sessionLabel(s)}</td>
                  <td className="px-3 py-2">{s.attendance_name ?? 'Chưa điểm danh'}</td>
                  <td className="px-3 py-2">{criteriaText(s)}</td>
                  <td className="px-3 py-2">{homeworkText(s.homework)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
