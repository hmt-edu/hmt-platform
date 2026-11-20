// GV-17 Bài đã giao của lớp (cổng giáo viên, điện thoại trước), theo canvas bổ sung 20/11 (GV17_chinh, trống, đang tải, lỗi, không quyền).
// Danh sách do app.lms_list_assignments (phân công, công tắc HOC_TAP, phân trang máy chủ). Trạng thái: Đang mở, Quá hạn, Đã chấm hết, Đã gỡ.
// Chưa có trạng thái «Nháp» và nút «Lưu nháp» của khung: máy chủ chưa có bài nháp (ghi vào PR).
import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import type { ClassOverview } from './classOverviewLogic';
import { LMS_STATE_TEXT, lmsState, type LmsList } from './lms';

const PAGE_SIZE = 100; // allow-number: tối đa một trang theo quy ước hiệu năng (máy chủ cũng chặn 100)

export function LmsAssignmentsPage() {
  const supabase = useDb();
  const { classId = '' } = useParams();
  const klass = useQuery({
    queryKey: ['gv-class', classId],
    queryFn: () => rpc<ClassOverview>(supabase, 'teacher_class_overview', { p_class_id: classId }),
  });
  const list = useQuery({
    queryKey: ['gv-lms-list', classId],
    queryFn: () =>
      rpc<LmsList>(supabase, 'lms_list_assignments', {
        p_class_id: classId,
        p_limit: PAGE_SIZE,
        p_offset: 0,
      }),
    refetchOnWindowFocus: true,
  });
  const classTitle = klass.data
    ? `${klass.data.class.subject_name ?? ''} · ${klass.data.class.code}`.replace(/^ · /, '')
    : '';
  const back = (
    <Link className="text-link underline" to={`/gv/lop/${classId}`}>
      Lớp
    </Link>
  );
  if (list.isPending)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">Bài đã giao</h1>
        <Spinner />
      </div>
    );
  if (list.isError)
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
        <h1 className="text-h2">Bài đã giao</h1>
        <QueryErrorView
          error={list.error}
          subject="bài đã giao của lớp này"
          onRetry={() => void list.refetch()}
        />
      </div>
    );
  const now = new Date();
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-3 p-3">
      <p className="text-caption text-fg-muted">{back} › Bài đã giao</p>
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-h2">Bài đã giao</h1>
          {classTitle && <p className="text-fg-muted">{classTitle}</p>}
        </div>
        <ButtonLink variant="primary" icon="plus" to={`/gv/lop/${classId}/bai-giao/moi`}>
          Giao bài
        </ButtonLink>
      </div>
      {list.data.rows.length === 0 ? (
        <StateView kind="empty" title="Lớp này chưa giao bài nào">
          Bấm Giao bài để giao bài cho cả lớp hoặc từng em.
        </StateView>
      ) : (
        <ul className="flex flex-col gap-2" aria-label="Bài đã giao">
          {list.data.rows.map((a) => {
            const state = LMS_STATE_TEXT[lmsState(a, now)];
            return (
              <li key={a.id}>
                <Link
                  to={`/gv/lop/${classId}/bai-giao/${a.id}`}
                  className="focus-ring flex flex-col gap-1 rounded-control border border-border bg-surface px-3 py-2.5 hover:bg-hover"
                >
                  <span className="font-semibold text-fg">{a.title}</span>
                  <span className="flex flex-wrap items-center gap-2">
                    <Tag tone={state.tone}>{state.label}</Tag>
                    <span className="text-caption text-fg-muted">
                      {a.submitted}/{a.targets} em đã nộp
                    </span>
                  </span>
                  <span className="text-caption text-fg-muted">
                    Giao ở Buổi {a.session_no ?? '?'} · Hạn {formatDateTime(a.due_at)}
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
