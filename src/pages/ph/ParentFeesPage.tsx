// PH-03 Học phí và giờ học (cổng Phụ huynh, điện thoại 390): giờ còn, ngày hết dự kiến, đơn hàng, phiếu thu gần đây. Chỉ xem, không thanh toán.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, StateView } from '../../ui/Feedback';
import { hoursText } from './homeLogic';
import { useChildren } from '../hoc/portalData';
import { ChildChips } from './ChildChips';
import {
  lowHoursNotice,
  orderStatusText,
  orderSubtitle,
  projectedEndText,
  receiptTitle,
  type FeesData,
} from './feesLogic';

const TITLE = 'Học phí và giờ học';

export function ParentFeesPage() {
  const supabase = useDb();
  const children = useChildren();
  const [picked, setPicked] = useState<string | null>(null);
  const list = children.data ?? [];
  const child = list.find((c) => c.id === picked) ?? list[0];
  const query = useQuery({
    queryKey: ['ph-fees', child?.id],
    enabled: child !== undefined,
    queryFn: () => rpc<FeesData>(supabase, 'ph_hours_orders', { p_student_id: child?.id }),
    refetchOnWindowFocus: true,
  });

  const header = <h1 className="text-h2">{TITLE}</h1>;
  if (children.isPending || (child !== undefined && query.isPending)) {
    return (
      <div className="flex flex-col gap-3">
        {header}
        <div role="status" aria-label="Đang tải" className="flex flex-col gap-2">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-16 animate-pulse rounded-control bg-surface-subtle" />
          ))}
        </div>
      </div>
    );
  }
  if (children.isError || query.isError) {
    return (
      <div className="flex flex-col gap-3">
        {header}
        <StateView
          kind="error"
          title="Không tải được dữ liệu"
          headingLevel={2}
          actions={
            <Button
              onClick={() => {
                void children.refetch();
                void query.refetch();
              }}
            >
              Thử lại
            </Button>
          }
        >
          Kiểm tra kết nối mạng rồi thử lại. Dữ liệu của quý phụ huynh không bị mất.
        </StateView>
      </div>
    );
  }
  if (child === undefined || query.data === undefined) {
    return (
      <div className="flex flex-col gap-3">
        {header}
        <StateView kind="empty" title="Chưa có thông tin của con" headingLevel={2}>
          Quý phụ huynh vui lòng liên hệ cơ sở để được cập nhật.
        </StateView>
      </div>
    );
  }
  const data = query.data;
  return (
    <div className="flex flex-col gap-4">
      {header}
      <ChildChips items={list} value={child.id} onChange={setPicked} />
      {data.is_low && data.hours_left > 0 && (
        <Alert tone="warning">{lowHoursNotice(child.full_name, data)}</Alert>
      )}
      <section aria-label="Giờ học" className="rounded-control border border-border bg-surface p-3">
        <dl className="flex flex-col gap-1">
          <div className="flex justify-between gap-3">
            <dt className="text-fg-muted">Giờ còn</dt>
            <dd className="font-medium">{hoursText(data.hours_left)}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-fg-muted">Ngày hết dự kiến</dt>
            <dd>{projectedEndText(data.projected_end)}</dd>
          </div>
        </dl>
        <p className="mt-2 text-caption text-fg-muted">
          Ngày hết dự kiến tính theo lịch học hiện tại, có thể đổi khi con nghỉ hoặc học bù.
        </p>
      </section>
      {data.orders.length === 0 ? (
        <StateView kind="empty" title="Chưa có đơn hàng" headingLevel={2}>
          Khi con đăng ký khoá học, đơn và phiếu thu sẽ hiện ở đây.
        </StateView>
      ) : (
        <>
          <section aria-label="Đơn hàng" className="flex flex-col gap-2">
            <h2 className="text-caption font-semibold uppercase text-fg-muted">Đơn hàng</h2>
            {data.orders.map((o) => (
              <Link
                key={o.id}
                to={`/ph/hoc-phi/${o.id}`}
                className="focus-ring flex min-h-14 items-center gap-3 rounded-control border border-border bg-surface p-3"
              >
                <span className="min-w-0 flex-1">
                  <span className="block font-medium">Đơn {o.code}</span>
                  <span className="block text-fg-muted">{orderSubtitle(o)}</span>
                </span>
                <Tag tone={o.remaining > 0 ? 'warning' : 'success'}>{orderStatusText(o)}</Tag>
              </Link>
            ))}
          </section>
          {data.receipts.length > 0 && (
            <section aria-label="Phiếu thu gần đây" className="flex flex-col gap-2">
              <h2 className="text-caption font-semibold uppercase text-fg-muted">
                Phiếu thu gần đây
              </h2>
              {data.receipts.map((r) => (
                <div
                  key={r.code}
                  className="flex justify-between gap-3 rounded-control border border-border bg-surface p-3"
                >
                  <span>{receiptTitle(r)}</span>
                  <span className="font-medium">{formatMoney(r.amount)}</span>
                </div>
              ))}
            </section>
          )}
        </>
      )}
    </div>
  );
}
