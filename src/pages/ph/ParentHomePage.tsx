// PH-01 Trang chủ (cổng Phụ huynh, điện thoại 390): việc cần chú ý và thẻ từng con. Chỉ xem; một lần gọi app.ph_home.
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { Tag } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import {
  attentionLine,
  attentionTitle,
  hoursText,
  lastSessionText,
  newReviewsText,
  type HomeAttention,
  type HomeChild,
  type ParentHome,
} from './homeLogic';

export function ParentHomePage() {
  const supabase = useDb();
  const query = useQuery({
    queryKey: ['ph-home'],
    queryFn: () => rpc<ParentHome>(supabase, 'ph_home', {}),
    refetchOnWindowFocus: true,
  });

  if (query.isPending) {
    return (
      <div className="flex flex-col gap-3">
        <h1 className="text-h2">Xin chào quý phụ huynh</h1>
        <div role="status" aria-label="Đang tải" className="flex flex-col gap-2">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-20 animate-pulse rounded-control bg-surface-subtle" />
          ))}
        </div>
      </div>
    );
  }
  if (query.isError) {
    return (
      <QueryErrorView
        error={query.error}
        subject="trang chủ"
        onRetry={() => void query.refetch()}
      />
    );
  }
  const { children, attention } = query.data;
  if (children.length === 0) {
    return (
      <StateView kind="empty" title="Chưa có thông tin của con">
        Quý phụ huynh vui lòng liên hệ cơ sở để được cập nhật.
      </StateView>
    );
  }
  return (
    <div className="flex flex-col gap-5">
      <h1 className="text-h2">Xin chào quý phụ huynh</h1>
      <section aria-label="Việc cần chú ý" className="flex flex-col gap-2">
        <h2 className="text-caption font-semibold uppercase text-fg-muted">
          Việc cần chú ý{attention.length > 0 ? ` · ${attention.length}` : ''}
        </h2>
        {attention.length === 0 ? (
          <p className="rounded-control border border-border bg-surface p-4 text-fg-muted">
            Hiện không có việc cần chú ý.
          </p>
        ) : (
          attention.map((item, i) => <AttentionCard key={i} item={item} />)
        )}
      </section>
      <section aria-label="Các con" className="flex flex-col gap-2">
        <h2 className="text-caption font-semibold uppercase text-fg-muted">Các con</h2>
        {children.map((c) => (
          <ChildCard key={c.id} child={c} />
        ))}
      </section>
    </div>
  );
}

function AttentionCard({ item }: { item: HomeAttention }) {
  const isHours = item.kind === 'GIO_THAP';
  return (
    <Link
      to={isHours ? '/ph/hoc-phi' : '/ph/de-nghi'}
      className="focus-ring flex min-h-14 items-center gap-3 rounded-control border border-border bg-surface p-3"
    >
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{attentionTitle(item)}</span>
        <span className="block text-fg-muted">{attentionLine(item)}</span>
      </span>
      <Tag tone={isHours ? 'warning' : 'info'}>{isHours ? 'Sắp hết' : 'Đang xử lý'}</Tag>
    </Link>
  );
}

function ChildCard({ child }: { child: HomeChild }) {
  const rows: [string, string][] = [
    ['Buổi gần nhất', lastSessionText(child)],
    ['Nhận xét mới', newReviewsText(child.new_reviews)],
    ['Giờ còn', hoursText(child.hours_left)],
  ];
  return (
    <article className="rounded-control border border-border bg-surface p-3">
      <h3 className="font-medium">{child.full_name}</h3>
      {child.classes.length > 0 && <p className="text-fg-muted">{child.classes.join(', ')}</p>}
      <dl className="mt-2 flex flex-col gap-1">
        {rows.map(([k, v]) => (
          <div key={k} className="flex justify-between gap-3">
            <dt className="text-fg-muted">{k}</dt>
            <dd className="text-right">{v}</dd>
          </div>
        ))}
      </dl>
    </article>
  );
}
