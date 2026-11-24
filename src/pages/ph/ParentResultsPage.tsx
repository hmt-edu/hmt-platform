// PH-02 Kết quả và nhận xét (cổng Phụ huynh): chuyên cần, BTVN, điểm theo buổi và nhận xét của giáo viên, theo từng con. Chỉ xem.
// Khung PH02_ds, PH02_nhan_xet, PH02_tai, PH02_trong, PH02_loi (canvas 9189). Dùng chung dữ liệu HT-07, HT-08 (portal_results, portal_reviews).
import { useState } from 'react';
import { Link, useLocation } from 'react-router';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useChildren } from '../hoc/portalData';
import { shortDate, usePortalResults, usePortalReviews } from '../hoc/portalResults';
import { ClassResult } from '../hoc/StudentResultsPage';
import { ChildChips } from './ChildChips';

const PAGE_SIZE = 20; // allow-number: số nhận xét mỗi lần tải thêm (≤ list_page_size_max)

export function ParentResultsPage() {
  const reviewsView = useLocation().pathname.endsWith('/nhan-xet');
  const children = useChildren();
  const list = children.data ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const [pickedClass, setPickedClass] = useState<string | null>(null);
  const [limit, setLimit] = useState(PAGE_SIZE);
  const child = list.find((c) => c.id === picked) ?? list[0];
  const results = usePortalResults(reviewsView ? undefined : child?.id);
  const reviews = usePortalReviews(reviewsView ? child?.id : undefined, limit, 0);
  const query = reviewsView ? reviews : results;

  const header = (
    <div className="flex flex-col gap-1">
      <h1 className="text-h2">{reviewsView ? 'Nhận xét các buổi' : 'Kết quả của con'}</h1>
      {reviewsView && (
        <Link to="/ph/ket-qua" className="focus-ring text-caption text-accent">
          Quay lại kết quả
        </Link>
      )}
    </div>
  );
  if (children.isPending || (child !== undefined && query.isPending))
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Spinner label="Đang tải…" />
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
  const chips = (
    <ChildChips
      items={list}
      value={child?.id ?? ''}
      onChange={(id) => {
        setPicked(id);
        setPickedClass(null);
        setLimit(PAGE_SIZE);
      }}
    />
  );

  if (reviewsView) {
    const rows = reviews.data?.rows ?? [];
    const total = reviews.data?.total ?? rows.length;
    return (
      <div className="flex flex-col gap-3">
        {header}
        {chips}
        {child === undefined || rows.length === 0 ? (
          <StateView kind="empty" title="Chưa có nhận xét" headingLevel={2}>
            Nhận xét sẽ hiện sau khi giáo viên viết và gửi cho các buổi con có mặt.
          </StateView>
        ) : (
          <>
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
                    <p className="tabular text-caption text-fg-muted">
                      {shortDate(r.session_date)}
                    </p>
                  </div>
                  <p className="whitespace-pre-line">{r.comment}</p>
                </li>
              ))}
            </ul>
            {rows.length < total && (
              <div>
                <Button
                  variant="secondary"
                  loading={reviews.isFetching}
                  onClick={() => setLimit(limit + PAGE_SIZE)}
                >
                  Xem thêm
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    );
  }

  const classes = results.data?.classes ?? [];
  const current = classes.find((c) => c.class_id === pickedClass) ?? classes[0];
  return (
    <div className="flex flex-col gap-4">
      {header}
      {chips}
      {child === undefined || current === undefined ? (
        <StateView kind="empty" title="Chưa có kết quả" headingLevel={2}>
          Kết quả sẽ hiện sau khi giáo viên điểm danh và nhận xét các buổi học.
        </StateView>
      ) : (
        <>
          {classes.length > 1 && (
            <div className="flex flex-wrap gap-2" role="group" aria-label="Chọn lớp">
              {classes.map((c) => (
                <Button
                  key={c.class_id}
                  variant={c.class_id === current.class_id ? 'primary' : 'secondary'}
                  aria-pressed={c.class_id === current.class_id}
                  onClick={() => setPickedClass(c.class_id)}
                >
                  {c.subject_name ?? c.class_code}
                </Button>
              ))}
            </div>
          )}
          <ClassResult cls={current} />
          <Link
            to="/ph/ket-qua/nhan-xet"
            className="focus-ring text-body font-semibold text-accent"
          >
            Xem tất cả nhận xét
          </Link>
        </>
      )}
    </div>
  );
}
