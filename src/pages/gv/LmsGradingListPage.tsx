// GV-18 Chấm bài nộp online: danh sách em của một bài (cổng giáo viên, điện thoại trước), theo canvas bổ sung 20/11 (GV18_chinh, ds_chua_cham, het, trống,
// tải, lỗi, không quyền). Máy chủ: app.lms_grading_list. Lọc nhanh Tất cả / Chưa chấm / Đã chấm; tiến độ «Đã chấm x/y».
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { ProgressBar } from '../../ui/Lms';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { cn } from '../../ui/cn';
import { gradeText, resubmitText, type GradingFilter, type GradingList } from './lmsGrading';

const FILTERS: { value: GradingFilter; label: string }[] = [
  { value: 'TAT_CA', label: 'Tất cả' },
  { value: 'CHUA_CHAM', label: 'Chưa chấm' },
  { value: 'DA_CHAM', label: 'Đã chấm' },
];

export function LmsGradingListPage() {
  const supabase = useDb();
  const { classId = '', assignmentId = '' } = useParams();
  const [filter, setFilter] = useState<GradingFilter>('TAT_CA');
  const list = useQuery({
    queryKey: ['gv-lms-grading', assignmentId, filter],
    queryFn: () =>
      rpc<GradingList>(supabase, 'lms_grading_list', {
        p_assignment_id: assignmentId,
        p_filter: filter === 'TAT_CA' ? null : filter,
      }),
    refetchOnWindowFocus: true,
  });
  const back = (
    <Link className="text-link underline" to={`/gv/lop/${classId}/bai-giao`}>
      Bài đã giao
    </Link>
  );
  if (list.isPending)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">Chấm bài nộp</h1>
        <Spinner />
      </div>
    );
  if (list.isError)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">Chấm bài nộp</h1>
        <QueryErrorView error={list.error} subject="bài này" onRetry={() => void list.refetch()} />
      </div>
    );
  const { assignment, rows } = list.data;
  const percent = assignment.targets === 0 ? 0 : (assignment.graded / assignment.targets) * 100; // allow-number: phần trăm tiến độ
  const allGraded = assignment.targets > 0 && assignment.graded >= assignment.targets;
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
      <p className="text-caption text-fg-muted">{back} › Chấm bài nộp</p>
      <div>
        <h1 className="text-h2">Chấm bài nộp</h1>
        <p className="font-semibold">{assignment.title}</p>
        <p className="text-caption text-fg-muted">Hạn nộp {formatDateTime(assignment.due_at)}</p>
      </div>
      <div className="flex flex-col gap-1">
        <p className="font-medium">
          Đã chấm {assignment.graded}/{assignment.targets}
        </p>
        <ProgressBar value={percent} label="Tiến độ chấm bài" />
      </div>
      <div role="group" aria-label="Lọc theo trạng thái chấm" className="flex gap-2">
        {FILTERS.map((f) => (
          <button
            key={f.value}
            type="button"
            aria-pressed={filter === f.value}
            onClick={() => setFilter(f.value)}
            className={cn(
              'focus-ring min-h-target rounded-control border px-3 text-body',
              filter === f.value
                ? 'border-border-selected bg-selected font-medium'
                : 'border-border bg-surface',
            )}
          >
            {f.label}
          </button>
        ))}
      </div>
      {rows.length === 0 ? (
        assignment.submitted === 0 && filter === 'TAT_CA' ? (
          <StateView kind="empty" title="Chưa có em nào nộp bài">
            Hạn nộp {formatDateTime(assignment.due_at)}. Bài nộp của các em sẽ hiện ở đây.
          </StateView>
        ) : filter === 'CHUA_CHAM' && allGraded ? (
          <StateView kind="empty" title="Đã chấm hết bài của lớp">
            Các em xem kết quả ở màn Kết quả bài.
          </StateView>
        ) : (
          <StateView kind="empty" title="Không có em nào trong mục này" />
        )
      ) : (
        <ul className="flex flex-col gap-2" aria-label="Danh sách em">
          {rows.map((r) => (
            <li key={r.student_id}>
              <Link
                to={`/gv/lop/${classId}/bai-giao/${assignmentId}/cham/${r.student_id}`}
                className="focus-ring flex flex-col gap-1 rounded-control border border-border bg-surface px-3 py-2.5 hover:bg-hover"
              >
                <span className="font-semibold text-fg">{r.full_name}</span>
                <span className="flex flex-wrap items-center gap-2">
                  <Tag tone={r.submit_state === 'DA_NOP' ? 'info' : 'neutral'}>
                    {r.submit_state === 'DA_NOP' ? 'Đã nộp' : 'Chưa nộp'}
                  </Tag>
                  {r.is_late && <Tag tone="warning">Nộp muộn</Tag>}
                  {resubmitText(r.attempt_count) && <Tag>{resubmitText(r.attempt_count)}</Tag>}
                  <span className={cn('text-caption', r.graded ? 'text-fg' : 'text-fg-muted')}>
                    {gradeText(r)}
                  </span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
