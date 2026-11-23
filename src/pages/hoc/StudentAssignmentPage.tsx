// HT-03 Chi tiết bài tập và HT-05 Kết quả bài (khung HT03_ds, _muon, _het_han, _tai, _loi; HT05_cham, _chua_xong, _tai, _loi).
// Chỉ đọc. Nút Nộp bài (HT-04) ẩn vì kho tệp R2 chưa có (anh chốt 23/11: ẩn mọi ô đính kèm, nộp ảnh).
import { Link, useParams } from 'react-router';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/datetime';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useChildren, usePortalAssignment } from './portalData';

const BACK = (
  <Link to="/hoc/bai-tap" className="font-medium text-link hover:underline">
    Về danh sách bài tập
  </Link>
);

export function StudentAssignmentPage() {
  const { id } = useParams();
  const children = useChildren();
  const student = children.data?.[0];
  const query = usePortalAssignment(student?.id, id);

  if (children.isPending || (student !== undefined && query.isPending))
    return <Spinner label="Đang tải bài tập…" />;
  if (children.isError || query.isError)
    return (
      <div className="flex flex-col gap-3">
        <Alert tone="danger">{errorOf(children.error ?? query.error).message}</Alert>
        <div className="flex gap-3">
          <Button
            onClick={() => {
              void children.refetch();
              void query.refetch();
            }}
          >
            Thử lại
          </Button>
          {BACK}
        </div>
      </div>
    );
  if (student === undefined || query.data === undefined)
    return (
      <StateView kind="not-found" title="Không thấy bài tập" actions={BACK}>
        Bài tập không còn hoặc không dành cho em.
      </StateView>
    );

  const { assignment: a, window_state: state, submission: sub, result, files } = query.data;
  return (
    <div className="flex flex-col gap-4">
      {BACK}
      <div className="flex flex-col gap-1">
        <h1 className="text-h2">{a.title}</h1>
        <p className="text-caption text-fg-muted">
          {[a.subject_name, a.class_code].filter(Boolean).join(' · ')}
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Tag tone={state === 'CON_HAN' ? 'info' : 'danger'}>
          {state === 'CON_HAN' ? 'Còn hạn' : 'Quá hạn'}
        </Tag>
        {state === 'QUA_HAN_NHAN_MUON' && <Tag tone="warning">Vẫn nhận bài muộn</Tag>}
        {sub?.is_late && <Tag tone="warning">Nộp muộn</Tag>}
        <span className="text-caption text-fg-muted">Hạn nộp: {formatDateTime(a.due_at)}</span>
      </div>
      <section aria-label="Đề bài" className="rounded-lg border border-border bg-surface p-3">
        <p className="whitespace-pre-wrap">{a.description}</p>
        {files.length > 0 && (
          <p className="mt-2 text-caption text-fg-muted">
            Tệp đề: {files.map((f) => f.file_name).join(', ')}
          </p>
        )}
      </section>
      {sub?.submitted_at && (
        <p className="text-body">Em đã nộp lúc {formatDateTime(sub.submitted_at)}.</p>
      )}
      {state === 'QUA_HAN_KHONG_NHAN' && !sub?.submitted_at && (
        <Alert tone="warning">Bài đã quá hạn và không nhận bài muộn.</Alert>
      )}
      {sub?.graded_at && result && (
        <section
          aria-label="Kết quả"
          className="flex flex-col gap-2 rounded-lg border border-border bg-surface p-3"
        >
          <h2 className="text-h3">Kết quả</h2>
          <div className="flex flex-wrap items-center gap-2">
            {result.score !== null && <Tag tone="success">{result.score}/5</Tag>}
            {result.status_name && <Tag>{result.status_name}</Tag>}
          </div>
          {result.note && <p className="whitespace-pre-wrap">{result.note}</p>}
        </section>
      )}
    </div>
  );
}
