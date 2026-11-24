// HT-08 Nhận xét các buổi (cổng học sinh): lời nhận xét của giáo viên, mới nhất trước, phân trang ở máy chủ. Chỉ đọc.
// Khung HT08_ds, _tai, _trong, _loi (canvas 9189). Chỉ chữ của giáo viên (R-V2-39); em vắng không có nhận xét (R-GV-04).
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useChildren } from './portalData';
import { shortDate, usePortalReviews } from './portalResults';

const PAGE_SIZE = 20; // allow-number: số nhận xét mỗi lần tải thêm (≤ list_page_size_max)

export function StudentReviewsPage() {
  const children = useChildren();
  const student = children.data?.[0];
  const [limit, setLimit] = useState(PAGE_SIZE);
  const query = usePortalReviews(student?.id, limit, 0);

  const header = (
    <div className="flex flex-col gap-1">
      <h1 className="text-h2">Nhận xét</h1>
      <Link to="/hoc/ket-qua" className="focus-ring text-caption text-accent">
        Quay lại kết quả
      </Link>
    </div>
  );
  if (children.isPending || (student !== undefined && query.isPending))
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Spinner label="Đang tải nhận xét…" />
      </div>
    );
  if (children.isError || query.isError)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Alert tone="danger">{errorOf(children.error ?? query.error).message}</Alert>
        <div>
          <Button
            onClick={() => {
              void children.refetch();
              void query.refetch();
            }}
          >
            Thử lại
          </Button>
        </div>
      </div>
    );
  const rows = query.data?.rows ?? [];
  if (student === undefined || rows.length === 0)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <StateView kind="empty" title="Chưa có nhận xét" headingLevel={2}>
          Nhận xét sẽ hiện sau khi giáo viên viết cho các buổi em có mặt.
        </StateView>
      </div>
    );
  const total = query.data?.total ?? rows.length;
  return (
    <div className="flex flex-col gap-3">
      {header}
      <ul className="flex flex-col gap-2">
        {rows.map((r) => (
          <li
            key={r.session_id}
            className="flex flex-col gap-1 rounded-lg border border-border bg-surface p-3"
          >
            <div className="flex items-center justify-between gap-2">
              <p className="font-semibold">
                {r.subject_name ?? r.class_code} · Buổi {r.session_no}
              </p>
              <p className="tabular text-caption text-fg-muted">{shortDate(r.session_date)}</p>
            </div>
            <p className="whitespace-pre-line">{r.comment}</p>
          </li>
        ))}
      </ul>
      {rows.length < total && (
        <div>
          <Button
            variant="secondary"
            loading={query.isFetching}
            onClick={() => setLimit(limit + PAGE_SIZE)}
          >
            Xem thêm
          </Button>
        </div>
      )}
    </div>
  );
}
